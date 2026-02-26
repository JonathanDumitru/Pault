//
//  BlockCategory.swift
//  Pault
//
//  Block category enumeration (from Schemap)
//

import SwiftUI

/// Block categories form the constrained API surface (color-coded)
enum BlockCategory: String, CaseIterable, Identifiable {
    case intent = "Intent & Framing"
    case rolePerspective = "Role & Perspective"
    case inputs = "Inputs & Context"
    case instructions = "Instructions"
    case constraints = "Constraints & Guardrails"
    case toneStyle = "Tone & Style"
    case structure = "Structure & Layout"
    case logic = "Logic & Control"
    case reasoning = "Reasoning & Process"
    case verification = "Verification & Quality"
    case transforms = "Transforms"
    case reuse = "Reuse & Governance"
    case execution = "Execution & Control"
    case modelConfig = "Model Configuration"  // Phase 2: AI model parameters

    // New categories for expanded prompt building
    case softwareEngineering = "Software Engineering"
    case agenticWorkflows = "Agentic Workflows"
    case dataAnalysis = "Data & Analysis"
    case creativeContent = "Creative & Content"
    case domainSpecific = "Domain-Specific"

    // Content component categories
    case communicationPatterns = "Communication Patterns"
    case taskTemplates = "Task Templates"
    case outputStructures = "Output Structures"
    case interactionModes = "Interaction Modes"
    case perspectiveFrames = "Perspective Frames"
    case qualityControls = "Quality Controls"
    case metaPrompting = "Meta-Prompting"

    var id: String { rawValue }

    /// Sophisticated color palette with rich saturation and brightness
    var color: Color {
        switch self {
        case .intent:
            // Rich indigo - deep and purposeful
            return Color(hue: 0.65, saturation: 0.70, brightness: 0.85)
        case .rolePerspective:
            // Warm cognac - authoritative and grounded
            return Color(hue: 0.08, saturation: 0.60, brightness: 0.75)
        case .inputs:
            // Vibrant azure - clear and informative
            return Color(hue: 0.58, saturation: 0.65, brightness: 0.90)
        case .instructions:
            // Royal purple - commanding and structured
            return Color(hue: 0.78, saturation: 0.68, brightness: 0.82)
        case .constraints:
            // Crimson - boundaries and limits
            return Color(hue: 0.98, saturation: 0.70, brightness: 0.85)
        case .toneStyle:
            // Aqua cyan - expressive and fluid
            return Color(hue: 0.52, saturation: 0.55, brightness: 0.88)
        case .structure:
            // Tangerine - organized and architectural
            return Color(hue: 0.12, saturation: 0.72, brightness: 0.92)
        case .logic:
            // Vibrant teal - logical and precise
            return Color(hue: 0.50, saturation: 0.75, brightness: 0.82)
        case .reasoning:
            // Fresh mint - analytical and clear
            return Color(hue: 0.42, saturation: 0.60, brightness: 0.88)
        case .verification:
            // Emerald green - validation and quality
            return Color(hue: 0.38, saturation: 0.68, brightness: 0.80)
        case .transforms:
            // Hot pink - dynamic transformation
            return Color(hue: 0.92, saturation: 0.65, brightness: 0.90)
        case .reuse:
            // Slate gray - foundational and reusable
            return Color(hue: 0.62, saturation: 0.12, brightness: 0.70)
        case .execution:
            // Golden yellow - action and energy
            return Color(hue: 0.15, saturation: 0.78, brightness: 0.95)
        case .modelConfig:
            // Electric violet - AI-powered and advanced
            return Color(hue: 0.75, saturation: 0.65, brightness: 0.88)
        case .softwareEngineering:
            // Terminal green - code and development
            return Color(hue: 0.35, saturation: 0.80, brightness: 0.75)
        case .agenticWorkflows:
            // Electric blue - autonomous and dynamic
            return Color(hue: 0.55, saturation: 0.85, brightness: 0.92)
        case .dataAnalysis:
            // Data orange - analytical and insights
            return Color(hue: 0.06, saturation: 0.75, brightness: 0.88)
        case .creativeContent:
            // Creative magenta - artistic and expressive
            return Color(hue: 0.85, saturation: 0.70, brightness: 0.85)
        case .domainSpecific:
            // Professional navy - specialized and authoritative
            return Color(hue: 0.60, saturation: 0.55, brightness: 0.65)
        case .communicationPatterns:
            // Warm coral - conversational and engaging
            return Color(hue: 0.02, saturation: 0.65, brightness: 0.90)
        case .taskTemplates:
            // Steel blue - structured and methodical
            return Color(hue: 0.58, saturation: 0.45, brightness: 0.75)
        case .outputStructures:
            // Sage green - organized and clear
            return Color(hue: 0.30, saturation: 0.40, brightness: 0.80)
        case .interactionModes:
            // Warm purple - interactive and responsive
            return Color(hue: 0.80, saturation: 0.55, brightness: 0.85)
        case .perspectiveFrames:
            // Deep amber - insightful and analytical
            return Color(hue: 0.10, saturation: 0.70, brightness: 0.80)
        case .qualityControls:
            // Forest green - reliable and trustworthy
            return Color(hue: 0.35, saturation: 0.60, brightness: 0.70)
        case .metaPrompting:
            // Cosmic purple - self-aware and recursive
            return Color(hue: 0.72, saturation: 0.75, brightness: 0.80)
        }
    }
}
