//
//  BlockSchema.swift
//  Pault
//
//  Structured schema definitions for block placeholders (from Schemap)
//

import Foundation

/// Schema definition for a block with structured placeholder metadata
struct BlockSchema: Codable, Equatable {
    /// List of placeholder definitions
    var placeholders: [PlaceholderSchema]

    /// Set of required placeholder names (must have non-empty values)
    var requiredPlaceholders: Set<String>

    /// Default values for placeholders
    var defaultValues: [String: String]

    init(
        placeholders: [PlaceholderSchema] = [],
        requiredPlaceholders: Set<String> = [],
        defaultValues: [String: String] = [:]
    ) {
        self.placeholders = placeholders
        self.requiredPlaceholders = requiredPlaceholders
        self.defaultValues = defaultValues
    }

    /// Get placeholder schema by name
    func placeholder(named name: String) -> PlaceholderSchema? {
        placeholders.first { $0.name == name }
    }

    /// Validate that all required placeholders have values
    func validateRequired(inputs: [String: String]) -> [String] {
        requiredPlaceholders.filter { placeholder in
            inputs[placeholder]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        }
    }
}

/// Schema definition for a single placeholder
struct PlaceholderSchema: Codable, Equatable, Identifiable {
    var id: String { name }

    /// Placeholder name (matches {{name}} in snippet)
    var name: String

    /// Value type for this placeholder
    var type: BlockValueType

    /// Display name for UI (human-readable)
    var displayName: String

    /// Help text / description
    var helpText: String?

    /// Validation rules to apply
    var validationRules: [ValidationRule]

    /// For selection type: available choices
    var choices: [String]?

    /// For number type: minimum value
    var minValue: Double?

    /// For number type: maximum value
    var maxValue: Double?

    /// For string/array: maximum length
    var maxLength: Int?

    /// Default value
    var defaultValue: String?

    init(
        name: String,
        type: BlockValueType,
        displayName: String? = nil,
        helpText: String? = nil,
        validationRules: [ValidationRule] = [],
        choices: [String]? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        maxLength: Int? = nil,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.type = type
        self.displayName = displayName ?? name.capitalized
        self.helpText = helpText
        self.validationRules = validationRules
        self.choices = choices
        self.minValue = minValue
        self.maxValue = maxValue
        self.maxLength = maxLength
        self.defaultValue = defaultValue
    }

    /// Validate a value against this placeholder's rules
    func validate(_ value: String) -> ValidationResult {
        // Check type-specific validation
        switch type {
        case .number:
            guard let number = Double(value) else {
                return .invalid("Must be a valid number")
            }
            if let min = minValue, number < min {
                return .invalid("Must be at least \(min)")
            }
            if let max = maxValue, number > max {
                return .invalid("Must be at most \(max)")
            }

        case .json:
            // Validate JSON syntax
            guard let data = value.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                return .invalid("Invalid JSON format")
            }

        case .selection:
            // Validate against choices
            if let choices = choices, !choices.isEmpty, !choices.contains(value) {
                return .invalid("Must be one of: \(choices.joined(separator: ", "))")
            }

        case .array:
            // Basic array validation (comma-separated or newline-separated)
            if value.isEmpty {
                return .invalid("Array cannot be empty")
            }

        default:
            break
        }

        // Check length limits
        if let maxLength = maxLength, value.count > maxLength {
            return .invalid("Maximum length is \(maxLength) characters")
        }

        // Apply custom validation rules
        for rule in validationRules {
            let result = rule.validate(value)
            if !result.isValid {
                return result
            }
        }

        return .valid
    }
}

/// Validation rule that can be applied to placeholder values
enum ValidationRule: Codable, Equatable {
    case required
    case maxLength(Int)
    case minLength(Int)
    case pattern(String) // Regex pattern
    case noSpecialChars
    case alphanumeric
    case email
    case url
    case custom(String) // Custom validation identifier

    func validate(_ value: String) -> ValidationResult {
        switch self {
        case .required:
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .invalid("This field is required")
                : .valid

        case .maxLength(let max):
            return value.count > max
                ? .invalid("Maximum length is \(max) characters")
                : .valid

        case .minLength(let min):
            return value.count < min
                ? .invalid("Minimum length is \(min) characters")
                : .valid

        case .pattern(let regex):
            guard let pattern = try? NSRegularExpression(pattern: regex),
                  pattern.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil else {
                return .invalid("Does not match required format")
            }
            return .valid

        case .noSpecialChars:
            let allowed = CharacterSet.alphanumerics.union(.whitespaces)
            return value.unicodeScalars.allSatisfy { allowed.contains($0) }
                ? .valid
                : .invalid("No special characters allowed")

        case .alphanumeric:
            return value.allSatisfy { $0.isLetter || $0.isNumber }
                ? .valid
                : .invalid("Only letters and numbers allowed")

        case .email:
            let emailPattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
            guard let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive),
                  regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil else {
                return .invalid("Invalid email format")
            }
            return .valid

        case .url:
            guard URL(string: value) != nil else {
                return .invalid("Invalid URL format")
            }
            return .valid

        case .custom:
            // Custom validation would be handled by application logic
            return .valid
        }
    }
}
