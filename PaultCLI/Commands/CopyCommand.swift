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
        // NSApplication.shared must be referenced before using NSPasteboard in a CLI process;
        // without it, the process isn't registered with the window server and the pasteboard
        // write may not be visible to other apps after the process exits.
        _ = NSApplication.shared
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        fputs("Copied '\(prompt.title)' to clipboard.\n", stderr)
    }
}
