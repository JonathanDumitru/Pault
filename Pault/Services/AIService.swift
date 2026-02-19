// Pault/Services/AIService.swift
import Foundation
import os

private let aiLogger = Logger(subsystem: "com.pault.app", category: "ai")

// MARK: - Types

struct AIConfig {
    enum Provider: String, CaseIterable {
        case claude, openai, ollama
        var displayName: String {
            switch self {
            case .claude: "Claude"
            case .openai: "OpenAI"
            case .ollama: "Ollama (Local)"
            }
        }
    }
    var provider: Provider
    var model: String
    var baseURL: String? // for ollama only

    static let defaults: [Provider: String] = [
        .claude: "claude-opus-4-6",
        .openai: "gpt-4o",
        .ollama: "llama3"
    ]
}

struct QualityScore {
    let clarity: Int        // 1-10
    let specificity: Int
    let roleDefinition: Int
    let outputFormat: Int
    let clarityReason: String
    let specificityReason: String
    let roleDefinitionReason: String
    let outputFormatReason: String

    var overall: Double {
        Double(clarity + specificity + roleDefinition + outputFormat) / 4.0
    }
}

struct VariableSuggestion {
    let originalText: String  // text to replace
    let suggestedName: String // suggested {{variable_name}}
    let reason: String
}

// MARK: - AIService Actor

actor AIService {
    static let shared = AIService()

    private let keychain = KeychainService()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Improve

    func improve(content: String, instruction: String, config: AIConfig) async throws -> String {
        let systemPrompt = """
        You are an expert prompt engineer. The user will provide a prompt and an instruction.
        Rewrite the prompt following the instruction exactly. Return ONLY the improved prompt text, no commentary.
        """
        let userMessage = "Instruction: \(instruction)\n\nPrompt:\n\(content)"
        return try await complete(system: systemPrompt, user: userMessage, config: config)
    }

    // MARK: - Suggest Variables

    func suggestVariables(for content: String, config: AIConfig) async throws -> [VariableSuggestion] {
        let systemPrompt = """
        Analyze the following prompt and identify literal values that should be template variables.
        Return a JSON array of objects with keys: "originalText", "suggestedName", "reason".
        Only suggest values that vary between uses. Return ONLY valid JSON.
        """
        let response = try await complete(system: systemPrompt, user: content, config: config)
        let data = Data(response.utf8)
        let raw = try JSONDecoder().decode([[String: String]].self, from: data)
        return raw.compactMap { dict in
            guard let orig = dict["originalText"],
                  let name = dict["suggestedName"],
                  let reason = dict["reason"] else { return nil }
            return VariableSuggestion(originalText: orig, suggestedName: name, reason: reason)
        }
    }

    // MARK: - Auto-tag

    func autoTag(content: String, existingTags: [String], config: AIConfig) async throws -> [String] {
        let systemPrompt = """
        Suggest 1-3 tags for the following prompt from this list: \(existingTags.joined(separator: ", ")).
        If no existing tag fits, suggest a new short lowercase tag.
        Return ONLY a JSON array of strings. Example: ["research","writing"]
        """
        let response = try await complete(system: systemPrompt, user: content, config: config)
        return (try? JSONDecoder().decode([String].self, from: Data(response.utf8))) ?? []
    }

    // MARK: - Quality Score

    func qualityScore(for content: String, config: AIConfig) async throws -> QualityScore {
        let systemPrompt = """
        Rate the following prompt on four axes (1-10 each) and give one sentence of reasoning per axis.
        Return ONLY valid JSON with keys: clarity, specificity, roleDefinition, outputFormat,
        clarityReason, specificityReason, roleDefinitionReason, outputFormatReason.
        """
        let response = try await complete(system: systemPrompt, user: content, config: config)
        let data = Data(response.utf8)
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        return QualityScore(
            clarity: Int(dict["clarity"] ?? "5") ?? 5,
            specificity: Int(dict["specificity"] ?? "5") ?? 5,
            roleDefinition: Int(dict["roleDefinition"] ?? "5") ?? 5,
            outputFormat: Int(dict["outputFormat"] ?? "5") ?? 5,
            clarityReason: dict["clarityReason"] ?? "",
            specificityReason: dict["specificityReason"] ?? "",
            roleDefinitionReason: dict["roleDefinitionReason"] ?? "",
            outputFormatReason: dict["outputFormatReason"] ?? ""
        )
    }

    // MARK: - Streaming Run

    func streamRun(content: String, config: AIConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try buildRequest(
                        system: "You are a helpful assistant.",
                        user: content,
                        config: config,
                        stream: true
                    )
                    let (bytes, _) = try await session.bytes(for: request)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8),
                              let token = parseStreamToken(data: data) else { continue }
                        if token == "[DONE]" { break }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func complete(system: String, user: String, config: AIConfig) async throws -> String {
        let request = try buildRequest(system: system, user: user, config: config, stream: false)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, data)
        }
        return try parseCompletionResponse(data: data, config: config)
    }

    private func buildRequest(system: String, user: String, config: AIConfig, stream: Bool) throws -> URLRequest {
        let apiKey: String
        do {
            apiKey = try keychain.load(key: "ai.apikey.\(config.provider.rawValue)") ?? ""
        } catch {
            throw AIError.missingAPIKey
        }
        guard !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let url: URL
        let body: [String: Any]

        switch config.provider {
        case .claude:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            body = [
                "model": config.model,
                "max_tokens": 2048,
                "system": system,
                "messages": [["role": "user", "content": user]],
                "stream": stream
            ]
        case .openai, .ollama:
            let base = config.provider == .ollama ? (config.baseURL ?? "http://localhost:11434") : "https://api.openai.com"
            url = URL(string: "\(base)/v1/chat/completions")!
            body = [
                "model": config.model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ],
                "stream": stream
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch config.provider {
        case .claude:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .openai, .ollama:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseCompletionResponse(data: Data, config: AIConfig) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        switch config.provider {
        case .claude:
            if let content = (json?["content"] as? [[String: Any]])?.first,
               let text = content["text"] as? String { return text }
        case .openai, .ollama:
            if let choices = json?["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let text = message["content"] as? String { return text }
        }
        throw AIError.parseError(data)
    }

    private func parseStreamToken(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        // Claude streaming
        if let delta = json["delta"] as? [String: Any], let text = delta["text"] as? String { return text }
        // OpenAI streaming
        if let choices = json["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let text = delta["content"] as? String { return text }
        return nil
    }
}

enum AIError: LocalizedError {
    case missingAPIKey
    case httpError(Int, Data)
    case parseError(Data)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No API key configured. Add one in Settings → AI."
        case .httpError(let code, _): return "API request failed with status \(code)."
        case .parseError: return "Could not parse the AI response."
        }
    }
}
