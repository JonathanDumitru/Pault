//
//  InputValidator.swift
//  Pault
//
//  Service for validating user input (from Schemap)
//

import Foundation

/// Service for validating placeholder names and values
struct InputValidator {

    /// Validates a placeholder name
    /// - Parameter name: The placeholder name to validate
    /// - Returns: Validation result with error message if invalid
    static func validatePlaceholderName(_ name: String) -> ValidationResult {
        // Empty name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid("Placeholder name cannot be empty")
        }

        // Check for valid identifier format (alphanumeric, underscore, dot)
        let pattern = "^[a-zA-Z0-9_.]+$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil else {
            return .invalid("Placeholder name must contain only letters, numbers, underscores, and dots")
        }

        // Check length (reasonable limit)
        let maxLength = 100
        guard name.count <= maxLength else {
            return .invalid("Placeholder name must be \(maxLength) characters or less")
        }

        // Check for reserved keywords (basic check)
        let reserved = ["if", "else", "for", "while", "function", "var", "let", "const", "return"]
        if reserved.contains(name.lowercased()) {
            return .invalid("Placeholder name cannot be a reserved keyword")
        }

        return .valid
    }

    /// Validates a placeholder value
    /// - Parameters:
    ///   - value: The placeholder value to validate
    ///   - maxLength: Maximum allowed length (default: 10000)
    /// - Returns: Validation result with error message if invalid
    static func validatePlaceholderValue(_ value: String, maxLength: Int = 10000) -> ValidationResult {
        // Check length
        guard value.count <= maxLength else {
            return .invalid("Input value must be \(maxLength) characters or less")
        }

        return .valid
    }

    /// Validates that required placeholders have values
    /// - Parameters:
    ///   - placeholders: List of placeholder names
    ///   - inputs: Dictionary of placeholder -> value
    ///   - required: Set of required placeholder names
    /// - Returns: Validation result with list of missing required placeholders
    static func validateRequiredPlaceholders(
        placeholders: [String],
        inputs: [String: String],
        required: Set<String>
    ) -> ValidationResult {
        let missing = required.filter { placeholder in
            placeholders.contains(placeholder) && (inputs[placeholder]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }

        if !missing.isEmpty {
            return .invalid("Missing required inputs: \(missing.joined(separator: ", "))")
        }

        return .valid
    }

    /// Validates all placeholders in a snippet
    /// - Parameter snippet: The snippet containing placeholders
    /// - Returns: Array of validation results for each placeholder found
    static func validatePlaceholdersInSnippet(_ snippet: String) -> [String: ValidationResult] {
        let placeholders = extractPlaceholderNames(from: snippet)
        var results: [String: ValidationResult] = [:]

        for placeholder in placeholders {
            results[placeholder] = validatePlaceholderName(placeholder)
        }

        return results
    }

    /// Extracts placeholder names from a snippet
    /// - Parameter snippet: The snippet text
    /// - Returns: Array of placeholder names found
    static func extractPlaceholderNames(from snippet: String) -> [String] {
        let pattern = #"\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: snippet, range: NSRange(snippet.startIndex..., in: snippet))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: snippet) else {
                return nil
            }
            return String(snippet[range])
        }
    }
}

/// Result of validation
enum ValidationResult {
    case valid
    case invalid(String)

    var isValid: Bool {
        switch self {
        case .valid: return true
        case .invalid: return false
        }
    }

    var errorMessage: String? {
        switch self {
        case .valid: return nil
        case .invalid(let message): return message
        }
    }
}
