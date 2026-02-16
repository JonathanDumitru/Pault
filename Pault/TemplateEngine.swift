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

    /// A segment of prompt content: either literal text or a variable placeholder.
    enum ContentSegment: Equatable {
        case text(String)
        case variable(name: String)
    }

    /// Split content into ordered segments of literal text and variable placeholders.
    /// Unlike `extractVariableNames` (which deduplicates), this preserves every occurrence.
    static func splitContent(_ content: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var lastEnd = content.startIndex

        for match in content.matches(of: variablePattern) {
            let name = String(match.1).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            if lastEnd < match.range.lowerBound {
                segments.append(.text(String(content[lastEnd..<match.range.lowerBound])))
            }
            segments.append(.variable(name: name))
            lastEnd = match.range.upperBound
        }

        if lastEnd < content.endIndex {
            segments.append(.text(String(content[lastEnd..<content.endIndex])))
        }
        return segments
    }

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

    /// Extract every variable occurrence from content, counting per-name.
    /// Returns `(name, occurrenceIndex)` tuples in content order.
    /// For `"{{a}} {{b}} {{a}}"` this returns `[("a", 0), ("b", 0), ("a", 1)]`.
    static func extractAllOccurrences(from content: String) -> [(name: String, occurrenceIndex: Int)] {
        var counts: [String: Int] = [:]
        var result: [(name: String, occurrenceIndex: Int)] = []
        for match in content.matches(of: variablePattern) {
            let name = String(match.1).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let index = counts[name, default: 0]
            counts[name] = index + 1
            result.append((name: name, occurrenceIndex: index))
        }
        return result
    }

    /// Replace {{variable}} markers with their filled values using positional replacement.
    /// Each occurrence resolves to its own TemplateVariable's value independently.
    /// Variables with an empty defaultValue are left as-is.
    static func resolve(content: String, variables: [TemplateVariable]) -> String {
        let matches = content.matches(of: variablePattern)
        guard !matches.isEmpty else { return content }

        // Build a lookup from sortOrder → value for O(1) per-match access
        let byPosition = Dictionary(uniqueKeysWithValues: variables.map { ($0.sortOrder, $0.defaultValue) })

        var result = content
        // Process in reverse to preserve earlier string indices
        for (position, match) in matches.enumerated().reversed() {
            if let value = byPosition[position], !value.isEmpty {
                result.replaceSubrange(match.range, with: value)
            }
        }
        return result
    }

    /// Sync a prompt's templateVariables to match every {{variable}} occurrence in its content.
    /// Each occurrence gets its own TemplateVariable, keyed by `(name, occurrenceIndex)`.
    /// Creates new variables, removes stale ones, and preserves existing values.
    static func syncVariables(for prompt: Prompt, in context: ModelContext) {
        let parsedOccurrences = extractAllOccurrences(from: prompt.content)

        // Key existing variables by (name, occurrenceIndex) for lookup
        let existingByKey = Dictionary(
            uniqueKeysWithValues: prompt.templateVariables.map {
                (VariableKey(name: $0.name, occurrenceIndex: $0.occurrenceIndex), $0)
            }
        )

        // Determine which (name, occurrenceIndex) pairs we need
        let parsedKeys = Set(parsedOccurrences.map { VariableKey(name: $0.name, occurrenceIndex: $0.occurrenceIndex) })

        // Remove variables no longer in content
        for (key, variable) in existingByKey where !parsedKeys.contains(key) {
            context.delete(variable)
        }

        // Build the final list in content order
        var updatedVariables: [TemplateVariable] = []
        for (sortOrder, occurrence) in parsedOccurrences.enumerated() {
            let key = VariableKey(name: occurrence.name, occurrenceIndex: occurrence.occurrenceIndex)
            if let existing = existingByKey[key] {
                existing.sortOrder = sortOrder
                updatedVariables.append(existing)
            } else {
                let newVar = TemplateVariable(
                    name: occurrence.name,
                    sortOrder: sortOrder,
                    occurrenceIndex: occurrence.occurrenceIndex
                )
                context.insert(newVar)
                updatedVariables.append(newVar)
            }
        }

        prompt.templateVariables = updatedVariables
    }

    /// Composite key for matching existing variables to parsed occurrences.
    private struct VariableKey: Hashable {
        let name: String
        let occurrenceIndex: Int
    }
}
