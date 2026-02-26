//
//  BlockValueType.swift
//  Pault
//
//  Block value type enumeration (from Schemap)
//

import Foundation

/// Type system for blocks: geometry enforces what snaps where
enum BlockValueType: String, CaseIterable, Codable {
    // Original types
    case string        // Single-line text input
    case boolean       // True/false toggle
    case object        // Multi-line text (renamed semantically from "object" for clarity)

    // Phase 2: New advanced types
    case number        // Integer or decimal numeric input
    case array         // List of items (comma-separated or multi-line)
    case json          // Structured JSON data with validation
    case selection     // Dropdown choice from predefined options
    case reference     // Reference to a registry object (project, snippet, etc.)

    /// Display name for UI
    var displayName: String {
        switch self {
        case .string: return "Text"
        case .boolean: return "Boolean"
        case .object: return "Multi-line"
        case .number: return "Number"
        case .array: return "Array"
        case .json: return "JSON"
        case .selection: return "Selection"
        case .reference: return "Reference"
        }
    }

    /// Icon for UI representation
    var icon: String {
        switch self {
        case .string: return "textformat"
        case .boolean: return "checkmark.circle"
        case .object: return "text.alignleft"
        case .number: return "number"
        case .array: return "list.bullet"
        case .json: return "curlybraces"
        case .selection: return "list.bullet.circle"
        case .reference: return "link"
        }
    }

    /// Whether this type supports multi-line input
    var isMultiline: Bool {
        switch self {
        case .object, .array, .json:
            return true
        case .string, .boolean, .number, .selection, .reference:
            return false
        }
    }

    /// Whether this type needs validation
    var requiresValidation: Bool {
        switch self {
        case .number, .json, .array:
            return true
        case .string, .boolean, .object, .selection, .reference:
            return false
        }
    }
}
