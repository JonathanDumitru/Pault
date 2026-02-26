//
//  BlockSuggestionEngine.swift
//  Pault
//
//  Engine for suggesting next blocks based on canvas state.
//  Analyzes which ConsolidatedBlockCategory values are present
//  and suggests what type of block to add next.
//

import Foundation

/// Suggestion from the engine
struct BlockSuggestion {
    let message: String
    let suggestedCategories: [ConsolidatedBlockCategory]
}

/// Engine for suggesting next blocks based on canvas state
enum BlockSuggestionEngine {

    /// Suggest next blocks based on current canvas categories
    static func suggest(canvasCategories: [ConsolidatedBlockCategory]) -> BlockSuggestion? {
        let categorySet = Set(canvasCategories)

        // Empty canvas
        if categorySet.isEmpty {
            return BlockSuggestion(
                message: "Start with a Role block to define who the AI should be, or use a Template",
                suggestedCategories: [.role]
            )
        }

        // Has role but no task or context
        if categorySet.contains(.role) && !categorySet.contains(.task) && !categorySet.contains(.context) {
            return BlockSuggestion(
                message: "Add a Task to define what the AI should do, or Context for background info",
                suggestedCategories: [.task, .context]
            )
        }

        // Has role and task but no format
        if categorySet.contains(.role) && categorySet.contains(.task) && !categorySet.contains(.format) {
            return BlockSuggestion(
                message: "Consider adding a Format block for structured output",
                suggestedCategories: [.format, .constraints]
            )
        }

        // Has task but no role
        if categorySet.contains(.task) && !categorySet.contains(.role) {
            return BlockSuggestion(
                message: "Consider adding a Role to establish expertise",
                suggestedCategories: [.role]
            )
        }

        // Has most essentials but no constraints
        if categorySet.count >= 3 && !categorySet.contains(.constraints) {
            return BlockSuggestion(
                message: "Add Constraints to focus the response",
                suggestedCategories: [.constraints]
            )
        }

        // Canvas looks complete
        if categorySet.count >= 4 {
            return nil
        }

        // Default: suggest examples
        if !categorySet.contains(.examples) {
            return BlockSuggestion(
                message: "Add Examples for few-shot learning",
                suggestedCategories: [.examples]
            )
        }

        return nil
    }

    /// Check if suggestion should be shown based on token count
    static func shouldShowTokenWarning(tokenCount: Int) -> BlockSuggestion? {
        if tokenCount > 3000 {
            return BlockSuggestion(
                message: "Prompt is getting long (~\(tokenCount) tokens). Consider adding Constraints to focus.",
                suggestedCategories: [.constraints]
            )
        }
        return nil
    }
}
