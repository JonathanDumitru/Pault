// Pault/Models/ProFeature.swift
// Single source of truth for all Pro feature gating.
// All feature checks go through ProFeature.isUnlocked — never call
// ProStatusManager.shared.isProUnlocked directly from views.

import Foundation

enum ProFeature: String, CaseIterable {
    case aiAssist
    case versioning
    case analytics
    case apiRunner
    case smartCollections
    case unlimitedBlocks

    // MARK: - Display Metadata

    var displayName: String {
        switch self {
        case .aiAssist:          return "AI Assist"
        case .versioning:        return "Prompt Versioning"
        case .analytics:         return "Usage Analytics"
        case .apiRunner:         return "API Runner"
        case .smartCollections:  return "Smart Collections"
        case .unlimitedBlocks:   return "Unlimited Blocks"
        }
    }

    var description: String {
        switch self {
        case .aiAssist:
            return "Improve prompts, suggest variables, and score quality using AI."
        case .versioning:
            return "Track every change with full version history and diffs."
        case .analytics:
            return "See which prompts you use most with visual dashboards."
        case .apiRunner:
            return "Run prompts directly against any LLM without leaving Pault."
        case .smartCollections:
            return "Auto-generated and custom collections that update dynamically."
        case .unlimitedBlocks:
            return "Build complex prompt compositions with unlimited blocks."
        }
    }

    var sfSymbol: String {
        switch self {
        case .aiAssist:          return "sparkles"
        case .versioning:        return "clock.arrow.circlepath"
        case .analytics:         return "chart.bar.xaxis"
        case .apiRunner:         return "play.circle.fill"
        case .smartCollections:  return "folder.badge.gearshape"
        case .unlimitedBlocks:   return "square.stack.3d.up.fill"
        }
    }

    // MARK: - Gate

    /// Maximum number of canvas blocks allowed for free users.
    static let freeBlockLimit = 5

    /// Returns true if the given feature is accessible to the current user.
    /// Delegates to ProStatusManager — do not call the manager directly from views.
    static func isUnlocked(_ feature: ProFeature) -> Bool {
        ProStatusManager.shared.isProUnlocked
    }
}
