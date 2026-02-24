//
//  ModifierCategory.swift
//  Pault
//
//  Modifier category enumeration for block modifiers (from Schemap)
//

import SwiftUI

/// Modifier categories for organizing block modifiers
enum ModifierCategory: String, CaseIterable, Identifiable {
    case quality = "Quality"
    case priority = "Priority"
    case scope = "Scope"
    case behavior = "Behavior"
    case format = "Format"
    case tone = "Tone"
    case safety = "Safety"
    case targeting = "Targeting"

    var id: String { rawValue }

    /// Color palette for modifier categories - using lighter, accent-style colors
    var color: Color {
        switch self {
        case .quality:
            // Emerald - trust and verification
            return Color(hue: 0.40, saturation: 0.65, brightness: 0.75)
        case .priority:
            // Ruby red - importance and urgency
            return Color(hue: 0.98, saturation: 0.70, brightness: 0.80)
        case .scope:
            // Amber - boundaries and limits
            return Color(hue: 0.10, saturation: 0.75, brightness: 0.85)
        case .behavior:
            // Electric purple - actions and dynamics
            return Color(hue: 0.75, saturation: 0.60, brightness: 0.85)
        case .format:
            // Sky blue - structure and presentation
            return Color(hue: 0.55, saturation: 0.50, brightness: 0.90)
        case .tone:
            // Coral pink - voice and expression
            return Color(hue: 0.95, saturation: 0.55, brightness: 0.90)
        case .safety:
            // Warning orange - caution and protection
            return Color(hue: 0.08, saturation: 0.80, brightness: 0.90)
        case .targeting:
            // Teal - audience and focus
            return Color(hue: 0.48, saturation: 0.60, brightness: 0.80)
        }
    }

    /// Icon for the modifier category
    var icon: String {
        switch self {
        case .quality: return "checkmark.seal.fill"
        case .priority: return "exclamationmark.triangle.fill"
        case .scope: return "scope"
        case .behavior: return "arrow.triangle.2.circlepath"
        case .format: return "text.alignleft"
        case .tone: return "waveform"
        case .safety: return "shield.fill"
        case .targeting: return "target"
        }
    }
}
