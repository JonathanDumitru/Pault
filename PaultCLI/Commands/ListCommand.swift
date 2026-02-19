// PaultCLI/Commands/ListCommand.swift
import Foundation
import ArgumentParser
import SwiftData

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List prompts in the library"
    )

    @Option(name: .shortAndLong, help: "Filter by tag name")
    var tag: String?

    @Flag(name: .shortAndLong, help: "Show only favorites")
    var favorites = false

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    func run() throws {
        let store = try PaultStore()
        var prompts = store.prompts.filter { !$0.isArchived }
        if let tag { prompts = prompts.filter { $0.tags.contains(where: { $0.name == tag }) } }
        if favorites { prompts = prompts.filter(\.isFavorite) }

        if json {
            let output = prompts.map { ["id": $0.id.uuidString, "title": $0.title] }
            let data = try JSONSerialization.data(withJSONObject: output, options: .prettyPrinted)
            print(String(data: data, encoding: .utf8) ?? "")
        } else {
            for prompt in prompts {
                print(prompt.title)
            }
        }
    }
}
