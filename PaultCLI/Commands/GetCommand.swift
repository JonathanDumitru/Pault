// PaultCLI/Commands/GetCommand.swift
import Foundation
import ArgumentParser

struct GetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Print prompt content"
    )

    @Argument(help: "Prompt title (partial match supported)")
    var title: String

    @Flag(help: "Resolve template variables")
    var resolve = false

    @Option(name: .customLong("var"), parsing: .upToNextOption, help: "Variable bindings: key=value")
    var variables: [String] = []

    func run() throws {
        let store = try PaultStore()
        guard let prompt = store.findPrompt(title: title) else {
            throw ValidationError("No prompt found matching '\(title)'")
        }
        var content = prompt.content
        if resolve {
            var bindings: [String: String] = [:]
            for pair in variables {
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 { bindings[String(parts[0])] = String(parts[1]) }
            }
            for (key, value) in bindings {
                content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
            }
        }
        print(content)
    }
}
