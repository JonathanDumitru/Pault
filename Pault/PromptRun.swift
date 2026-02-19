import Foundation
import SwiftData

@Model
final class PromptRun {
    var id: UUID
    var prompt: Prompt?          // nullable — prompt may be deleted
    var promptTitle: String      // snapshot at run time
    var resolvedInput: String    // variables already substituted
    var output: String
    var model: String            // e.g. "claude-opus-4-6"
    var provider: String         // "claude" | "openai" | "ollama"
    var latencyMs: Int
    var inputTokens: Int?
    var outputTokens: Int?
    var createdAt: Date
    var variantLabel: String?    // "A"/"B" for A/B; "refine-1"..."refine-5" for loop; nil for plain
    var userRating: Int?         // 1–5; nil if not rated
    var metadata: String?        // JSON blob for refinement session context

    init(
        promptTitle: String,
        resolvedInput: String,
        output: String,
        model: String,
        provider: String,
        latencyMs: Int,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        variantLabel: String? = nil,
        userRating: Int? = nil,
        metadata: String? = nil
    ) {
        self.id = UUID()
        self.promptTitle = promptTitle
        self.resolvedInput = resolvedInput
        self.output = output
        self.model = model
        self.provider = provider
        self.latencyMs = latencyMs
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.createdAt = Date()
        self.variantLabel = variantLabel
        self.userRating = userRating
        self.metadata = metadata
    }
}
