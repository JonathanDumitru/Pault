// PaultCLI/Commands/CopyCommand.swift
import Foundation
import AppKit
import ArgumentParser

struct CopyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "copy",
        abstract: "Copy a prompt to the clipboard"
    )

    @Argument(help: "Prompt title (partial match supported)")
    var title: String

    @Flag(help: "Resolve template variables before copying")
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
        // Write to pasteboard using NSPasteboard (macOS only)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        fputs("Copied '\(prompt.title)' to clipboard.\n", stderr)
    }
}
