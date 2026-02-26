//
//  BlockPlaceholderStatus.swift
//  Pault
//
//  Status of placeholder completion for a block.
//  Enables visual indicators (red/yellow/green dots) in the UI.
//

import SwiftUI

/// Status of placeholder completion for a block
enum BlockPlaceholderStatus: Equatable {
    case unfilled   // No placeholders filled (or has unfilled required ones)
    case partial    // Some but not all placeholders filled
    case complete   // All placeholders filled (or no placeholders exist)

    /// Calculate status from snippet and current inputs
    static func calculate(snippet: String, inputs: [String: String]) -> BlockPlaceholderStatus {
        let placeholders = PromptStudioModel.placeholders(in: snippet)

        guard !placeholders.isEmpty else {
            return .complete
        }

        let filledCount = placeholders.filter { placeholder in
            guard let value = inputs[placeholder] else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count

        if filledCount == 0 {
            return .unfilled
        } else if filledCount == placeholders.count {
            return .complete
        } else {
            return .partial
        }
    }

    /// Indicator color for this status
    var color: Color {
        switch self {
        case .unfilled: return .red
        case .partial: return .yellow
        case .complete: return .green
        }
    }

    /// SF Symbol for status indicator
    var icon: String {
        switch self {
        case .unfilled: return "circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .complete: return "checkmark.circle.fill"
        }
    }
}
