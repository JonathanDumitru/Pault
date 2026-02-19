// PaultCLI/main.swift
import Foundation
import ArgumentParser

// @main is not used here because this file is named main.swift, which is the implicit Swift
// entry point. Using @main in main.swift causes a "multiple entry point" compiler error.
// Instead, call .main() directly — AsyncParsableCommand.main() is the ArgumentParser entry point.
struct PaultCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pault",
        abstract: "Pault prompt library — terminal access",
        version: "1.0.0",
        subcommands: [ListCommand.self, GetCommand.self, CopyCommand.self, RunCommand.self]
    )
}

PaultCLI.main()
