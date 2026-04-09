//
//  MarkdownFrontmatterParser.swift
//  Pault
//
//  Serializes PromptExportRecord to Markdown with YAML frontmatter,
//  and parses Markdown (with or without frontmatter) back to MarkdownImportRecord.
//

import Foundation

// MARK: - MarkdownImportRecord

/// Intermediate record produced by parsing a Markdown file.
struct MarkdownImportRecord {
    let id: String?
    let title: String
    let content: String
    let tags: [String]
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: Date?
    let updatedAt: Date?
    let qualityScore: Int?
    let variables: [(name: String, defaultValue: String)]
}

// MARK: - MarkdownFrontmatterParser

enum MarkdownFrontmatterParser {

    // MARK: - Serialize

    /// Produces a Markdown string with YAML frontmatter from a PromptExportRecord.
    static func serialize(record: PromptExportRecord) -> String {
        var lines: [String] = ["---"]

        // id (for round-trip identity)
        lines.append("id: \(quoteYAML(record.id))")

        // title — always quoted to handle colons, brackets, hashes
        lines.append("title: \(quoteYAML(record.title))")

        // tags — inline array
        let tagList = record.tags.map { quoteYAML($0) }.joined(separator: ", ")
        lines.append("tags: [\(tagList)]")

        // booleans
        lines.append("favorite: \(record.isFavorite ? "true" : "false")")
        lines.append("archived: \(record.isArchived ? "true" : "false")")

        // dates — ISO8601
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        lines.append("created_at: \(iso.string(from: Date(timeIntervalSince1970: record.createdAt)))")
        lines.append("updated_at: \(iso.string(from: Date(timeIntervalSince1970: record.updatedAt)))")

        // optional quality score
        if let score = record.qualityScore {
            lines.append("quality_score: \(score)")
        }

        // variables — block sequence
        if !record.templateVariables.isEmpty {
            lines.append("variables:")
            for v in record.templateVariables.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                lines.append("  - name: \(quoteYAML(v.name))")
                lines.append("    default: \(quoteYAML(v.defaultValue))")
            }
        }

        lines.append("---")
        lines.append("")
        lines.append("# \(record.title)")
        lines.append("")
        lines.append(record.content)

        return lines.joined(separator: "\n")
    }

    // MARK: - Parse

    /// Parses a Markdown string (with or without YAML frontmatter) into a MarkdownImportRecord.
    static func parse(markdown: String, filename: String) -> MarkdownImportRecord {
        let trimmed = markdown.trimmingCharacters(in: .newlines)
        guard trimmed.hasPrefix("---") else {
            return parsePlain(markdown: markdown, filename: filename)
        }

        // Split on the closing ---
        let lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2 else {
            return parsePlain(markdown: markdown, filename: filename)
        }

        // Find the closing --- delimiter (skip the first line which is the opening ---)
        var closingIndex: Int? = nil
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let closeIdx = closingIndex else {
            return parsePlain(markdown: markdown, filename: filename)
        }

        let frontmatterLines = Array(lines[1..<closeIdx])
        let bodyLines = Array(lines[(closeIdx + 1)...])
        let bodyText = bodyLines.joined(separator: "\n").trimmingCharacters(in: .newlines)

        // Strip leading H1 from body (it's the title)
        let content: String
        if bodyText.hasPrefix("# ") {
            let bodyAfterH1 = bodyText.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            content = bodyAfterH1.trimmingCharacters(in: .newlines)
        } else {
            content = bodyText
        }

        // Parse frontmatter key-value pairs
        var kvMap: [String: String] = [:]
        var variablesBlock: [(name: String, defaultValue: String)] = []
        var parsingVariables = false
        var currentVarName: String? = nil
        var currentVarDefault: String? = nil

        for line in frontmatterLines {
            if line.hasPrefix("  - name:") || line.hasPrefix("  -name:") {
                // Flush previous variable if any
                if let name = currentVarName {
                    variablesBlock.append((name: name, defaultValue: currentVarDefault ?? ""))
                }
                let value = extractValue(from: line, key: "  - name")
                currentVarName = value
                currentVarDefault = nil
            } else if (line.hasPrefix("    default:") || line.hasPrefix("    default :")) && parsingVariables {
                currentVarDefault = extractValue(from: line, key: "    default")
            } else if line.hasPrefix("variables:") {
                parsingVariables = true
            } else if !line.hasPrefix("  ") {
                // Back to top-level — flush any pending variable
                if parsingVariables, let name = currentVarName {
                    variablesBlock.append((name: name, defaultValue: currentVarDefault ?? ""))
                    currentVarName = nil
                    currentVarDefault = nil
                }
                parsingVariables = false
                if let colonIdx = line.firstIndex(of: ":") {
                    let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let rawValue = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    kvMap[key] = unquoteYAML(rawValue)
                }
            }
        }

        // Flush final variable if any
        if parsingVariables, let name = currentVarName {
            variablesBlock.append((name: name, defaultValue: currentVarDefault ?? ""))
        }

        // Extract fields
        let titleFromFM = kvMap["title"] ?? titleFromFilename(filename)
        let id = kvMap["id"]
        let tags = parseInlineArray(kvMap["tags"] ?? "[]")
        let isFavorite = kvMap["favorite"] == "true"
        let isArchived = kvMap["archived"] == "true"

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let createdAt = kvMap["created_at"].flatMap { iso.date(from: $0) }
        let updatedAt = kvMap["updated_at"].flatMap { iso.date(from: $0) }
        let qualityScore = kvMap["quality_score"].flatMap { Int($0) }

        return MarkdownImportRecord(
            id: id,
            title: titleFromFM,
            content: content,
            tags: tags,
            isFavorite: isFavorite,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt,
            qualityScore: qualityScore,
            variables: variablesBlock
        )
    }

    // MARK: - parsePlain

    /// Parses plain Markdown (no YAML frontmatter) — title from first H1 or filename.
    static func parsePlain(markdown: String, filename: String) -> MarkdownImportRecord {
        let lines = markdown.components(separatedBy: "\n")
        var title: String? = nil
        var contentLines: [String] = []
        var foundH1 = false

        for line in lines {
            if !foundH1, line.hasPrefix("# ") {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                foundH1 = true
            } else {
                contentLines.append(line)
            }
        }

        let resolvedTitle = title ?? titleFromFilename(filename)
        let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .newlines)

        return MarkdownImportRecord(
            id: nil,
            title: resolvedTitle,
            content: content,
            tags: [],
            isFavorite: false,
            isArchived: false,
            createdAt: nil,
            updatedAt: nil,
            qualityScore: nil,
            variables: []
        )
    }

    // MARK: - Slugify

    /// Converts a title to a lowercase-alphanumeric-hyphen filename slug.
    /// Appends -2, -3 etc. on collision.
    static func slugify(_ title: String, existing: Set<String>) -> String {
        // Lowercase, replace non-alphanumeric with hyphens
        var slug = title.lowercased()
        slug = slug.unicodeScalars.map { scalar in
            let value = scalar.value
            // Keep a-z, 0-9; convert everything else to hyphen
            if (value >= 97 && value <= 122) || (value >= 48 && value <= 57) {
                return String(scalar)
            }
            return "-"
        }.joined()

        // Collapse consecutive hyphens
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }

        // Trim leading/trailing hyphens
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        // Handle empty slug
        if slug.isEmpty { slug = "prompt" }

        // Collision dedup
        if !existing.contains(slug) { return slug }
        var counter = 2
        while existing.contains("\(slug)-\(counter)") {
            counter += 1
        }
        return "\(slug)-\(counter)"
    }

    // MARK: - Private Helpers

    /// Wraps a string value in double quotes, escaping internal double quotes.
    private static func quoteYAML(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
                           .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Removes surrounding double quotes from a YAML value, unescaping internal quotes.
    private static func unquoteYAML(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespaces)
        if v.hasPrefix("\"") && v.hasSuffix("\"") && v.count >= 2 {
            v = String(v.dropFirst().dropLast())
            v = v.replacingOccurrences(of: "\\\"", with: "\"")
             .replacingOccurrences(of: "\\\\", with: "\\")
        }
        return v
    }

    /// Parses an inline YAML array like `["swift", "ios"]` into a [String] array.
    private static func parseInlineArray(_ raw: String) -> [String] {
        var trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return [] }
        trimmed = String(trimmed.dropFirst().dropLast()) // remove [ and ]
        if trimmed.trimmingCharacters(in: .whitespaces).isEmpty { return [] }

        // Split by comma, then unquote each element
        return trimmed.components(separatedBy: ",").compactMap { element in
            let unquoted = unquoteYAML(element.trimmingCharacters(in: .whitespaces))
            return unquoted.isEmpty ? nil : unquoted
        }
    }

    /// Extracts the value portion from a "  - key: value" or "    key: value" line.
    private static func extractValue(from line: String, key: String) -> String {
        let prefix = key + ":"
        if let range = line.range(of: prefix) {
            let raw = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return unquoteYAML(raw)
        }
        return ""
    }

    /// Derives a title from a filename by stripping the .md extension.
    private static func titleFromFilename(_ filename: String) -> String {
        var name = filename
        if name.lowercased().hasSuffix(".md") {
            name = String(name.dropLast(3))
        }
        return name
    }
}
