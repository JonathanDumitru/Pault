// PaultCLI/main.swift
import Foundation
import ArgumentParser

@main
struct PaultCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pault",
        abstract: "Pault prompt library — terminal access",
        version: "1.0.0",
        subcommands: [ListCommand.self, GetCommand.self, CopyCommand.self, RunCommand.self]
    )
}
