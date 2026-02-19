// PaultCLI/Commands/RunCommand.swift
import Foundation
import ArgumentParser
import Security

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a prompt against the configured LLM (Pro)"
    )

    @Argument(help: "Prompt title")
    var title: String

    @Option(name: .customLong("var"), parsing: .upToNextOption, help: "Variable bindings: key=value")
    var variables: [String] = []

    // Keychain service and account key format from KeychainService.swift / AIService.swift:
    // service = "com.pault.app", account = "ai.apikey.<provider.rawValue>"
    private static let providers: [(name: String, apiKey: String)] = [
        ("claude", "ai.apikey.claude"),
        ("openai", "ai.apikey.openai"),
        ("ollama", "ai.apikey.ollama"),
    ]

    func run() async throws {
        guard let (providerName, apiKey) = Self.providers.compactMap({ p -> (String, String)? in
            guard let key = loadKeychainValue(key: p.apiKey) else { return nil }
            return (p.name, key)
        }).first else {
            throw ValidationError("No API key configured. Open Pault → Preferences → AI to add one.")
        }

        let store = try PaultStore()
        guard let prompt = store.findPrompt(title: title) else {
            throw ValidationError("No prompt found matching '\(title)'")
        }

        var content = prompt.content
        var bindings: [String: String] = [:]
        for pair in variables {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { bindings[String(parts[0])] = String(parts[1]) }
        }
        for (key, value) in bindings {
            content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        let result = try await runPrompt(content: content, provider: providerName, apiKey: apiKey)
        print(result)
    }

    private func loadKeychainValue(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.pault.app",
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func runPrompt(content: String, provider: String, apiKey: String) async throws -> String {
        var request: URLRequest
        let body: [String: Any]

        switch provider {
        case "claude":
            request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": "claude-opus-4-6",
                "max_tokens": 4096,
                "messages": [["role": "user", "content": content]]
            ]
        case "openai":
            request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": "gpt-4o",
                "messages": [
                    ["role": "system", "content": "You are a helpful assistant."],
                    ["role": "user", "content": content]
                ]
            ]
        default: // ollama
            request = URLRequest(url: URL(string: "http://localhost:11434/api/chat")!)
            body = [
                "model": "llama3",
                "stream": false,
                "messages": [["role": "user", "content": content]]
            ]
        }

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ValidationError("HTTP \(code) from \(provider) API.")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ValidationError("Could not parse response from \(provider) API.")
        }

        switch provider {
        case "claude":
            if let text = (json["content"] as? [[String: Any]])?.first?["text"] as? String {
                return text
            }
        case "openai":
            if let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text
            }
        default: // ollama non-streaming: { "message": { "role": ..., "content": ... }, "done": true }
            if let message = json["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text
            }
        }
        throw ValidationError("Unexpected response format from \(provider) API.")
    }
}
