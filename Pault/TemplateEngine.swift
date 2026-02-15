//
//  TemplateEngine.swift
//  Pault
//
//  Parses {{variable}} placeholders from prompt content,
//  resolves them with filled values, and syncs the
//  TemplateVariable model to match the content.
//

import Foundation
import SwiftData

enum TemplateEngine {

    private static let variablePattern = /\{\{\s*(\w+)\s*\}\}/

    /// Extract unique variable names from content, in order of first appearance.
    /// Whitespace inside braces is tolerated: `{{ name }}` is treated as `name`.
    static func extractVariableNames(from content: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for match in content.matches(of: variablePattern) {
            let name = String(match.1).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }
        return ordered
    }

    /// Replace {{variable}} markers with their filled values.
    /// Variables with an empty defaultValue are left as-is. Whitespace
    /// inside braces is tolerated: `{{ name }}` resolves the same as `{{name}}`.
    static func resolve(content: String, variables: [TemplateVariable]) -> String {
        let lookup = Dictionary(uniqueKeysWithValues: variables.map { ($0.name, $0.defaultValue) })
        var result = content
        for match in content.matches(of: variablePattern).reversed() {
            let name = String(match.1).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            if let value = lookup[name], !value.isEmpty {
                let range = match.range
                result.replaceSubrange(range, with: value)
            }
        }
        return result
    }

    /// Sync a prompt's templateVariables to match the {{variables}} found in its content.
    /// Creates new variables, removes stale ones, and preserves existing values.
    static func syncVariables(for prompt: Prompt, in context: ModelContext) {
        let parsedNames = extractVariableNames(from: prompt.content)
        let existingByName = Dictionary(uniqueKeysWithValues: prompt.templateVariables.map { ($0.name, $0) })

        // Determine which to keep, create, or remove
        let parsedSet = Set(parsedNames)
        let existingSet = Set(existingByName.keys)

        // Remove variables no longer in content
        let toRemove = existingSet.subtracting(parsedSet)
        for name in toRemove {
            if let variable = existingByName[name] {
                context.delete(variable)
            }
        }

        // Build the final list in parsed order
        var updatedVariables: [TemplateVariable] = []
        for (index, name) in parsedNames.enumerated() {
            if let existing = existingByName[name] {
                existing.sortOrder = index
                updatedVariables.append(existing)
            } else {
                let newVar = TemplateVariable(name: name, sortOrder: index)
                context.insert(newVar)
                updatedVariables.append(newVar)
            }
        }

        prompt.templateVariables = updatedVariables
    }
}
