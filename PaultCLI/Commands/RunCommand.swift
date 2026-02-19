// PaultCLI/Commands/RunCommand.swift
import Foundation
import ArgumentParser
import Security

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a prompt against the configured LLM (Pro)"
    )

    @Argument(help: "Prompt title")
    var title: String

    @Option(name: .customLong("var"), parsing: .upToNextOption, help: "Variable bindings: key=value")
    var variables: [String] = []

    func run() throws {
        // Keychain service and account key format verified from KeychainService.swift and AIService.swift:
        // service = "com.pault.app", account = "ai.apikey.<provider>"
        guard let apiKey = loadKeychainValue(key: "ai.apikey.claude") ??
                           loadKeychainValue(key: "ai.apikey.openai") else {
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

        let result = runPromptSync(content: content, apiKey: apiKey)
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

    private func runPromptSync(content: String, apiKey: String) -> String {
        var output = ""
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": "claude-opus-4-6",
                "max_tokens": 4096,
                "messages": [["role": "user", "content": content]]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = (json["content"] as? [[String: Any]])?.first?["text"] as? String {
                output = text
            } else {
                output = "Error: Failed to get response from API."
            }
            semaphore.signal()
        }

        semaphore.wait()
        return output
    }
}
