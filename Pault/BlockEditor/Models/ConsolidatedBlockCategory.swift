//
//  ConsolidatedBlockCategory.swift
//  Pault
//
//  Consolidated block categories (7 top-level groups from 20+ legacy categories)
//  for improved block discoverability in the Canvas-Centric UX.
//

import SwiftUI

/// Consolidated block categories that group the 20+ BlockCategory cases
/// into 7 top-level groups for better discoverability.
enum ConsolidatedBlockCategory: String, CaseIterable, Identifiable {
    case role = "Role"
    case context = "Context"
    case task = "Task"
    case format = "Format"
    case constraints = "Constraints"
    case examples = "Examples"
    case meta = "Meta"

    var id: String { rawValue }

    /// SF Symbol icon for this category
    var icon: String {
        switch self {
        case .role: return "person.fill"
        case .context: return "book.fill"
        case .task: return "checkmark.circle.fill"
        case .format: return "list.bullet.rectangle.fill"
        case .constraints: return "xmark.octagon.fill"
        case .examples: return "doc.text.fill"
        case .meta: return "gearshape.fill"
        }
    }

    /// Color for this category (derived from primary legacy category)
    var color: Color {
        switch self {
        case .role:
            // Warm cognac - from rolePerspective
            return Color(hue: 0.08, saturation: 0.60, brightness: 0.75)
        case .context:
            // Vibrant azure - from inputs
            return Color(hue: 0.58, saturation: 0.65, brightness: 0.90)
        case .task:
            // Royal purple - from instructions
            return Color(hue: 0.78, saturation: 0.68, brightness: 0.82)
        case .format:
            // Tangerine - from structure
            return Color(hue: 0.12, saturation: 0.72, brightness: 0.92)
        case .constraints:
            // Crimson - from constraints
            return Color(hue: 0.98, saturation: 0.70, brightness: 0.85)
        case .examples:
            // Sage green - from outputStructures
            return Color(hue: 0.30, saturation: 0.40, brightness: 0.80)
        case .meta:
            // Cosmic purple - from metaPrompting
            return Color(hue: 0.72, saturation: 0.75, brightness: 0.80)
        }
    }

    /// Legacy BlockCategory values that map to this consolidated category
    var legacyCategories: Set<BlockCategory> {
        switch self {
        case .role:
            return [.rolePerspective, .perspectiveFrames]
        case .context:
            return [.inputs, .domainSpecific]
        case .task:
            return [.intent, .instructions, .taskTemplates, .execution]
        case .format:
            return [.structure, .toneStyle, .outputStructures, .communicationPatterns]
        case .constraints:
            return [.constraints, .verification, .qualityControls]
        case .examples:
            return [.logic, .transforms, .interactionModes]
        case .meta:
            return [.reasoning, .metaPrompting, .reuse, .modelConfig,
                    .agenticWorkflows, .softwareEngineering, .dataAnalysis, .creativeContent]
        }
    }

    /// Map a legacy category to its consolidated parent
    static func from(legacy: BlockCategory) -> ConsolidatedBlockCategory {
        for consolidated in ConsolidatedBlockCategory.allCases {
            if consolidated.legacyCategories.contains(legacy) {
                return consolidated
            }
        }
        return .meta // Default fallback
    }
}
