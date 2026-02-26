//
//  BlockTemplate.swift
//  Pault
//
//  A template containing pre-configured blocks for common prompt patterns.
//

import Foundation

/// A template containing pre-configured blocks for common prompt patterns
struct BlockTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let blocks: [BlockSnapshot]

    struct BlockSnapshot: Codable {
        let title: String
        let categoryRaw: String
        let valueTypeRaw: String
        let snippet: String

        func toBlock() -> Block? {
            guard let category = BlockCategory(rawValue: categoryRaw),
                  let valueType = BlockValueType(rawValue: valueTypeRaw) else {
                return nil
            }
            return Block(title: title, category: category, valueType: valueType, snippet: snippet)
        }
    }

    var estimatedTokens: Int {
        let totalChars = blocks.reduce(0) { $0 + $1.snippet.count }
        return max(1, totalChars / 4) // Rough estimate: 4 chars per token
    }

    /// Built-in templates
    static let builtIn: [BlockTemplate] = [
        BlockTemplate(
            id: "code-review",
            name: "Code Review",
            description: "Review code for bugs, style, and improvements",
            blocks: [
                .init(title: "Code Review Expert", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an expert code reviewer with deep knowledge of {{language}} best practices and design patterns."),
                .init(title: "Code Context", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Review the following code:\n```{{language}}\n{{code}}\n```"),
                .init(title: "Review Focus", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Focus your review on: {{focus_areas}}"),
                .init(title: "Structured Feedback", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Provide feedback in these sections:\n1. Summary\n2. Issues Found (with severity: Critical/Major/Minor)\n3. Suggestions for Improvement\n4. Positive Aspects"),
                .init(title: "Constructive Tone", categoryRaw: "Tone & Style", valueTypeRaw: "string", snippet: "Use a constructive and educational tone. Explain the 'why' behind each suggestion.")
            ]
        ),
        BlockTemplate(
            id: "writing-assistant",
            name: "Writing Assistant",
            description: "Help with drafting and editing text",
            blocks: [
                .init(title: "Writing Expert", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an expert writer and editor specializing in {{writing_type}}."),
                .init(title: "Writing Task", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "{{task_description}}"),
                .init(title: "Audience", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Target audience: {{audience}}"),
                .init(title: "Tone", categoryRaw: "Tone & Style", valueTypeRaw: "string", snippet: "Write in a {{tone}} tone.")
            ]
        ),
        BlockTemplate(
            id: "data-analysis",
            name: "Data Analysis",
            description: "Analyze datasets and extract insights",
            blocks: [
                .init(title: "Data Analyst", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are a data analyst with expertise in {{domain}}."),
                .init(title: "Dataset", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Analyze the following data:\n{{data}}"),
                .init(title: "Analysis Goals", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Focus on: {{analysis_goals}}"),
                .init(title: "Insight Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Present findings as:\n1. Key Insights\n2. Supporting Data\n3. Recommendations"),
                .init(title: "Statistical Rigor", categoryRaw: "Constraints & Guardrails", valueTypeRaw: "string", snippet: "Ensure statistical validity. Note any limitations or caveats.")
            ]
        ),
        BlockTemplate(
            id: "brainstorming",
            name: "Brainstorming",
            description: "Generate ideas with structured output",
            blocks: [
                .init(title: "Creative Partner", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are a creative thinking partner who generates diverse and innovative ideas."),
                .init(title: "Topic", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Topic: {{topic}}"),
                .init(title: "Brainstorm Task", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Generate {{count}} ideas for {{goal}}."),
                .init(title: "Idea Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "For each idea, provide:\n- Title\n- One-sentence description\n- Key benefit")
            ]
        ),
        BlockTemplate(
            id: "explanation",
            name: "Explanation",
            description: "Explain concepts at adjustable levels",
            blocks: [
                .init(title: "Teacher", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an expert teacher who explains complex topics clearly."),
                .init(title: "Concept", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Explain: {{concept}}"),
                .init(title: "Audience Level", categoryRaw: "Constraints & Guardrails", valueTypeRaw: "string", snippet: "Explain for a {{level}} audience (e.g., beginner, intermediate, expert)."),
                .init(title: "Explanation Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Structure as:\n1. Simple overview\n2. Key concepts\n3. Example\n4. Common misconceptions")
            ]
        ),
        BlockTemplate(
            id: "step-by-step",
            name: "Step-by-Step Guide",
            description: "Create tutorials or instructions",
            blocks: [
                .init(title: "Instructor", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an experienced instructor who creates clear, actionable guides."),
                .init(title: "Task", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Create a guide for: {{task}}"),
                .init(title: "Prerequisites", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Assume the reader has: {{prerequisites}}"),
                .init(title: "Guide Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Format as numbered steps. Each step should:\n- Start with an action verb\n- Be completable in 1-5 minutes\n- Include expected outcome"),
                .init(title: "Warnings", categoryRaw: "Constraints & Guardrails", valueTypeRaw: "string", snippet: "Highlight any warnings or common mistakes with WARNING: markers.")
            ]
        )
    ]
}
