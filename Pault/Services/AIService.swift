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
    var baseURL: String?
    static let defaults: [Provider: AIConfig] = [
        .claude:  AIConfig(provider: .claude,  model: "claude-opus-4-6"),
        .openai:  AIConfig(provider: .openai,  model: "gpt-4o"),
        .ollama:  AIConfig(provider: .ollama,  model: "llama3", baseURL: "http://localhost:11434"),
    ]
}

struct QualityScore {
    var clarity: Double
    var specificity: Double
    var completeness: Double
    var conciseness: Double
    var overall: Double { (clarity + specificity + completeness + conciseness) / 4 }
}

struct VariableSuggestion {
    var placeholder: String
    var description: String
}

struct CollectionSuggestion: Codable {
    var name: String
    var icon: String         // SF Symbol name
    var promptTitles: [String]
}

enum AIError: LocalizedError {
    case missingAPIKey
    case httpError(Int, Data)
    case parseError(Data)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No API key configured for this provider."
        case .httpError(let code, _): return "HTTP error \(code)."
        case .parseError: return "Failed to parse the AI response."
        }
    }
}

// MARK: - AIService

actor AIService {
    static let shared = AIService()
    private let keychain = KeychainService()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    func improve(prompt: String, config: AIConfig) async throws -> String {
        let system = """
        You are an expert prompt engineer. \
        Rewrite the prompt to be clearer, more specific, and more effective. \
        Return ONLY the improved prompt text, no commentary.
        """
        return try await complete(system: system, user: prompt, config: config)
    }

    func generatePrompt(from description: String, config: AIConfig) async throws -> String {
        let system = """
        You are an expert prompt engineer. Based on the user's description, \
        create a well-structured, reusable prompt template. \
        Use {{variable_name}} syntax for parts the user should fill in each time. \
        Return ONLY the prompt text, no commentary or explanation.
        """
        return try await complete(system: system, user: description, config: config)
    }

    func suggestVariables(prompt: String, config: AIConfig) async throws -> [VariableSuggestion] {
        let system = """
        Analyze the following prompt and identify literal values that should be \
        template variables using {{placeholder}} syntax. \
        Return ONLY a JSON array of objects with keys "placeholder" and "description". \
        Example: [{"placeholder":"{{topic}}","description":"The main topic"}]
        """
        let response = try await complete(system: system, user: prompt, config: config)
        let data = Data(response.utf8)
        guard let raw = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            throw AIError.parseError(data)
        }
        return raw.compactMap { dict in
            guard let placeholder = dict["placeholder"],
                  let description = dict["description"] else { return nil }
            return VariableSuggestion(placeholder: placeholder, description: description)
        }
    }

    func autoTag(prompt: String, config: AIConfig) async throws -> [String] {
        let system = """
        Suggest 1-3 short lowercase tags that best categorise the following prompt. \
        Return ONLY a JSON array of strings. Example: ["research","writing"]
        """
        let response = try await complete(system: system, user: prompt, config: config)
        let data = Data(response.utf8)
        guard let tags = try? JSONDecoder().decode([String].self, from: data) else {
            throw AIError.parseError(data)
        }
        return tags
    }

    func qualityScore(prompt: String, config: AIConfig) async throws -> QualityScore {
        let system = """
        Rate the following prompt on four axes (0-10 each): \
        clarity, specificity, completeness, conciseness. \
        Return ONLY valid JSON: \
        {"clarity": <n>, "specificity": <n>, "completeness": <n>, "conciseness": <n>}
        """
        let response = try await complete(system: system, user: prompt, config: config)
        let data = Data(response.utf8)
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.parseError(data)
        }
        func num(_ key: String) -> Double {
            if let d = dict[key] as? Double { return d }
            if let i = dict[key] as? Int { return Double(i) }
            return 5.0
        }
        return QualityScore(
            clarity: num("clarity"),
            specificity: num("specificity"),
            completeness: num("completeness"),
            conciseness: num("conciseness")
        )
    }

    func clusterPrompts(titles: [String], config: AIConfig) async throws -> [CollectionSuggestion] {
        let titleList = titles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let system = """
        You are a prompt organization expert. Group the following prompts into 3–6 thematic collections.
        Return ONLY a JSON array. Each object must have:
        - "name": short collection name (2–4 words)
        - "icon": an SF Symbol name that fits the theme (e.g. "pencil", "code", "magnifyingglass")
        - "promptTitles": array of prompt titles from the input list that belong to this collection
        Do not include prompts in multiple collections. Every prompt must appear exactly once.
        """
        let response = try await complete(system: system, user: titleList, config: config)
        // Strip optional markdown code fences (LLMs often add ```json … ``` even when asked not to)
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.drop(while: { $0 != "\n" }).dropFirst()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard let data = cleaned.data(using: .utf8),
              let suggestions = try? JSONDecoder().decode([CollectionSuggestion].self, from: data) else {
            throw AIError.parseError(response.data(using: .utf8) ?? Data())
        }
        return suggestions
    }

    func streamRun(prompt: String, variables: [String: String], config: AIConfig) async throws -> AsyncThrowingStream<String, Error> {
        var resolved = prompt
        for (key, value) in variables {
            resolved = resolved.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        let request = try await buildStreamRequest(user: resolved, config: config)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await self.session.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        continuation.finish(throwing: AIError.httpError(http.statusCode, Data()))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let token = self.parseStreamToken(data: data, config: config) else { continue }
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
        let request = try await buildRequest(system: system, user: user, config: config)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.httpError(code, data)
        }
        return try parseCompletionResponse(data: data, config: config)
    }

    private func buildRequest(system: String, user: String, config: AIConfig) async throws -> URLRequest {
        let apiKeyOrNil: String?
        do {
            apiKeyOrNil = try keychain.load(key: "ai.apikey.\(config.provider.rawValue)")
        } catch {
            throw AIError.missingAPIKey
        }
        guard let apiKey = apiKeyOrNil, !apiKey.isEmpty else { throw AIError.missingAPIKey }

        let url: URL
        let body: [String: Any]

        switch config.provider {
        case .claude:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            body = [
                "model": config.model,
                "max_tokens": 2048,
                "system": system,
                "messages": [["role": "user", "content": user]]
            ]
        case .openai:
            url = URL(string: "https://api.openai.com/v1/chat/completions")!
            body = [
                "model": config.model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ]
            ]
        case .ollama:
            let base = config.baseURL ?? "http://localhost:11434"
            url = URL(string: "\(base)/api/chat")!
            body = [
                "model": config.model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ]
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch config.provider {
        case .claude:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .ollama:
            break
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildStreamRequest(user: String, config: AIConfig) async throws -> URLRequest {
        let system = "You are a helpful assistant."
        var request = try await buildRequest(system: system, user: user, config: config)
        if var body = request.httpBody,
           var dict = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            dict["stream"] = true
            body = (try? JSONSerialization.data(withJSONObject: dict)) ?? body
            request.httpBody = body
        }
        return request
    }

    private func parseCompletionResponse(data: Data, config: AIConfig) throws -> String {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
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

    private func parseStreamToken(data: Data, config: AIConfig) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        switch config.provider {
        case .claude:
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String { return text }
        case .openai, .ollama:
            if let choices = json["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let text = delta["content"] as? String { return text }
        }
        return nil
    }
}
