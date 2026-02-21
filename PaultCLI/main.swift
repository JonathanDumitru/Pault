// PaultCLI/main.swift
import Foundation
import ArgumentParser

// @main is not used here because this file is named main.swift, which is the implicit Swift
// entry point. Using @main in main.swift causes a "multiple entry point" compiler error.
// Instead, call .main() directly — AsyncParsableCommand.main() is the ArgumentParser entry point.

/// Version is read from the CLI target's Info.plist (CFBundleShortVersionString) so it stays
/// in sync with the Xcode project version setting. Falls back to the embedded constant when
/// running without a bundle (e.g., in tests or from a plain binary).
private let cliVersion: String =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

struct PaultCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pault",
        abstract: "Pault prompt library — terminal access",
        version: cliVersion,
        subcommands: [ListCommand.self, GetCommand.self, CopyCommand.self, RunCommand.self]
    )
}

PaultCLI.main()
