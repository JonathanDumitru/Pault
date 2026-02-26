//
//  TextToBlocksService.swift
//  Pault
//
//  AI-powered text-to-blocks parsing service for Pro users.
//  Analyzes prompt text and generates a BlockCompositionSnapshot.
//

import Foundation
import os

private let parseLogger = Logger(subsystem: "com.pault.app", category: "TextToBlocks")

// MARK: - Parsed Block Structure

/// Intermediate structure for AI-generated block data
struct ParsedBlock: Codable, Sendable {
    let title: String
    let category: String
    let snippet: String
    let inputs: [String: String]?
}

/// AI parsing response structure
struct ParseResponse: Codable, Sendable {
    let blocks: [ParsedBlock]
}

// MARK: - TextToBlocksService

/// Service for parsing text prompts into block compositions using AI
@MainActor
final class TextToBlocksService {
    static let shared = TextToBlocksService()

    private let keychain = KeychainService()
    private let session: URLSession

    /// Daily rate limit for Pro users
    private let dailyLimit = 10
    private var usageCount: Int = 0
    private var lastResetDate: Date?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Parse prompt text into a BlockCompositionSnapshot using AI
    /// - Parameters:
    ///   - text: The raw prompt text to analyze
    ///   - config: AI configuration (defaults to Claude)
    /// - Returns: A BlockCompositionSnapshot ready to load into PromptStudioModel
    func parseTextToBlocks(text: String, config: AIConfig = AIConfig.defaults[.claude]!) async throws -> BlockCompositionSnapshot {
        // Check rate limit
        try checkRateLimit()

        parseLogger.info("Parsing text to blocks (\(text.count) chars)")

        let systemPrompt = buildSystemPrompt()
        let response = try await complete(system: systemPrompt, user: text, config: config)

        // Parse the JSON response
        let snapshot = try parseResponse(response)

        // Increment usage
        incrementUsage()

        parseLogger.info("Successfully parsed \(snapshot.blocks.count) blocks")
        return snapshot
    }

    /// Check remaining parses for today
    var remainingParses: Int {
        resetIfNewDay()
        return max(0, dailyLimit - usageCount)
    }

    // MARK: - System Prompt

    private func buildSystemPrompt() -> String {
        let categories = BlockCategory.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")

        return """
        You are a prompt structure analyzer. Analyze the given prompt text and decompose it into logical blocks.

        Each block should represent a distinct semantic component of the prompt:
        - Role/persona definitions
        - Task objectives
        - Context/background information
        - Instructions and steps
        - Constraints and guardrails
        - Output format requirements
        - Examples (if present)

        Return ONLY valid JSON with this exact structure:
        {
          "blocks": [
            {
              "title": "Short descriptive title (2-4 words)",
              "category": "One of the valid categories",
              "snippet": "The actual text content for this block. Use {{placeholder}} for any values that should be customizable.",
              "inputs": {"placeholder": "value"}
            }
          ]
        }

        Valid categories: \(categories)

        Guidelines:
        1. Preserve the original meaning and intent
        2. Keep blocks focused on single concepts
        3. Use {{placeholder}} syntax for variable parts (e.g., {{topic}}, {{audience}})
        4. Order blocks logically (role → objective → context → instructions → constraints → output)
        5. Extract 3-8 blocks typically; more for complex prompts
        6. If the prompt has a clear persona/role, make that the first block
        7. Constraints and guardrails should be separate from instructions

        Return ONLY the JSON, no markdown code fences or commentary.
        """
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: String) throws -> BlockCompositionSnapshot {
        // Clean potential markdown fences
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.drop(while: { $0 != "\n" }).dropFirst())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw TextToBlocksError.invalidResponse
        }

        let parseResponse: ParseResponse
        do {
            parseResponse = try JSONDecoder().decode(ParseResponse.self, from: data)
        } catch {
            parseLogger.error("Failed to decode response: \(error.localizedDescription)")
            throw TextToBlocksError.parseError(cleaned)
        }

        // Convert to BlockCompositionSnapshot
        var blocks: [BlockCompositionSnapshot.BlockSnapshot] = []
        var blockInputs: [String: [String: String]] = [:]

        for parsedBlock in parseResponse.blocks {
            let (snapshot, inputs) = convertParsedBlock(parsedBlock)
            blocks.append(snapshot)
            if !inputs.isEmpty {
                blockInputs[snapshot.id.uuidString] = inputs
            }
        }

        return BlockCompositionSnapshot(
            blocks: blocks,
            blockInputs: blockInputs,
            blockModifiers: [:],
            lastCompiledHash: nil
        )
    }

    /// Convert a ParsedBlock to a BlockSnapshot with inputs
    private func convertParsedBlock(_ parsedBlock: ParsedBlock) -> (BlockCompositionSnapshot.BlockSnapshot, [String: String]) {
        // Try to match the category
        let category: BlockCategory
        if let cat = BlockCategory(rawValue: parsedBlock.category) {
            category = cat
        } else {
            // Fuzzy match on category name
            let normalizedCategory = parsedBlock.category.lowercased()
            let matchedCategory = BlockCategory.allCases.first { cat in
                cat.rawValue.lowercased().contains(normalizedCategory) ||
                normalizedCategory.contains(cat.rawValue.lowercased().replacingOccurrences(of: " & ", with: " "))
            }
            category = matchedCategory ?? .intent
            if matchedCategory == nil {
                parseLogger.warning("Unknown category: \(parsedBlock.category), defaulting to Intent")
            }
        }

        let snapshot = BlockCompositionSnapshot.BlockSnapshot(
            title: parsedBlock.title,
            categoryRaw: category.rawValue,
            valueTypeRaw: BlockValueType.object.rawValue,
            snippet: parsedBlock.snippet
        )

        return (snapshot, parsedBlock.inputs ?? [:])
    }

    // MARK: - Rate Limiting

    private func checkRateLimit() throws {
        resetIfNewDay()
        if usageCount >= dailyLimit {
            throw TextToBlocksError.rateLimitExceeded(dailyLimit)
        }
    }

    private func incrementUsage() {
        resetIfNewDay()
        usageCount += 1
        parseLogger.debug("Parse usage: \(self.usageCount)/\(self.dailyLimit)")
    }

    private func resetIfNewDay() {
        let calendar = Calendar.current
        let now = Date()

        if let lastReset = lastResetDate,
           calendar.isDate(lastReset, inSameDayAs: now) {
            return
        }

        usageCount = 0
        lastResetDate = now
        parseLogger.debug("Rate limit reset for new day")
    }

    // MARK: - Network

    private func complete(system: String, user: String, config: AIConfig) async throws -> String {
        let apiKey: String
        do {
            guard let key = try keychain.load(key: "ai.apikey.\(config.provider.rawValue)"),
                  !key.isEmpty else {
                throw TextToBlocksError.missingAPIKey
            }
            apiKey = key
        } catch {
            throw TextToBlocksError.missingAPIKey
        }

        let request = try buildRequest(system: system, user: user, apiKey: apiKey, config: config)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TextToBlocksError.networkError
        }

        guard http.statusCode == 200 else {
            parseLogger.error("HTTP error: \(http.statusCode)")
            throw TextToBlocksError.httpError(http.statusCode)
        }

        return try parseCompletionResponse(data: data, config: config)
    }

    private func buildRequest(system: String, user: String, apiKey: String, config: AIConfig) throws -> URLRequest {
        let url: URL
        let body: [String: Any]

        switch config.provider {
        case .claude:
            url = URL(string: "https://api.anthropic.com/v1/messages")!
            body = [
                "model": config.model,
                "max_tokens": 4096,
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

    private func parseCompletionResponse(data: Data, config: AIConfig) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TextToBlocksError.invalidResponse
        }

        switch config.provider {
        case .claude:
            if let content = (json["content"] as? [[String: Any]])?.first,
               let text = content["text"] as? String {
                return text
            }
        case .openai, .ollama:
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text
            }
        }

        throw TextToBlocksError.invalidResponse
    }
}

// MARK: - Errors

enum TextToBlocksError: LocalizedError {
    case missingAPIKey
    case networkError
    case httpError(Int)
    case invalidResponse
    case parseError(String)
    case rateLimitExceeded(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Please add your API key in Preferences."
        case .networkError:
            return "Network error. Please check your connection."
        case .httpError(let code):
            return "Server error (HTTP \(code)). Please try again."
        case .invalidResponse:
            return "Invalid response from AI service."
        case .parseError(let response):
            return "Failed to parse AI response. Raw: \(response.prefix(200))..."
        case .rateLimitExceeded(let limit):
            return "Daily limit of \(limit) AI parses reached. Try again tomorrow."
        }
    }
}
