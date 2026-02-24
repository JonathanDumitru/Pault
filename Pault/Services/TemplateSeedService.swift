//
//  TemplateSeedService.swift
//  Pault
//

import Foundation
import SwiftData
import os

private let seedLogger = Logger(subsystem: "com.pault.app", category: "TemplateSeed")

enum TemplateSeedService {

    /// Seeds built-in templates if none exist yet. Safe to call multiple times.
    static func seed(into context: ModelContext) {
        let descriptor = FetchDescriptor<PromptTemplate>(
            predicate: #Predicate { $0.isBuiltIn == true }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else {
            seedLogger.debug("Built-in templates already seeded (\(existingCount) found)")
            return
        }

        for def in bundledTemplates {
            let template = PromptTemplate(
                name: def.name,
                content: def.content,
                category: def.category,
                isBuiltIn: true,
                iconName: def.icon
            )
            context.insert(template)
        }

        do {
            try context.save()
            seedLogger.info("Seeded \(bundledTemplates.count) built-in templates")
        } catch {
            seedLogger.error("Failed to seed templates: \(error.localizedDescription)")
        }
    }

    // MARK: - Bundled Template Definitions

    private struct TemplateDef {
        let name: String
        let content: String
        let category: String
        let icon: String
    }

    private static let bundledTemplates: [TemplateDef] = [
        TemplateDef(
            name: "Email Drafter",
            content: """
            Write a {{tone}} email to {{recipient}} about {{subject}}.

            Key points to cover:
            {{key_points}}

            Keep it {{length}} and professional.
            """,
            category: "Writing",
            icon: "envelope"
        ),
        TemplateDef(
            name: "Code Review Checklist",
            content: """
            Review the following {{language}} code for:

            1. Correctness — does it do what it claims?
            2. Edge cases — what inputs could break it?
            3. Performance — any obvious inefficiencies?
            4. Readability — is it clear to a new developer?

            Code to review:
            {{code}}
            """,
            category: "Engineering",
            icon: "checkmark.circle"
        ),
        TemplateDef(
            name: "Bug Report",
            content: """
            ## Summary
            {{summary}}

            ## Steps to Reproduce
            1. {{step_1}}
            2. {{step_2}}
            3. {{step_3}}

            ## Expected Behavior
            {{expected}}

            ## Actual Behavior
            {{actual}}

            ## Environment
            {{environment}}
            """,
            category: "Engineering",
            icon: "ladybug"
        ),
        TemplateDef(
            name: "Meeting Notes Extractor",
            content: """
            Extract structured notes from the following meeting transcript:

            {{transcript}}

            Format as:
            - **Decisions:** key decisions made
            - **Action Items:** who does what by when
            - **Open Questions:** unresolved topics
            """,
            category: "Productivity",
            icon: "note.text"
        ),
        TemplateDef(
            name: "Content Summarizer",
            content: """
            Summarize the following {{content_type}} in {{length}} sentences:

            {{content}}

            Focus on the key takeaways and main arguments.
            """,
            category: "Writing",
            icon: "text.justify.left"
        ),
        TemplateDef(
            name: "Creative Writing Starter",
            content: """
            Write a {{genre}} story opening with:
            - Setting: {{setting}}
            - Main character: {{character}}
            - Mood: {{mood}}

            Start with an engaging hook that draws the reader in.
            """,
            category: "Writing",
            icon: "pencil.and.outline"
        ),
        TemplateDef(
            name: "API Documentation",
            content: """
            Document the following API endpoint:

            **Endpoint:** {{method}} {{path}}
            **Description:** {{description}}

            ### Request
            {{request_body}}

            ### Response
            {{response_body}}

            ### Error Codes
            {{error_codes}}
            """,
            category: "Engineering",
            icon: "doc.plaintext"
        ),
        TemplateDef(
            name: "Decision Framework",
            content: """
            Help me decide between {{option_a}} and {{option_b}}.

            Context: {{context}}

            Evaluate each option on:
            1. Cost/effort
            2. Risk
            3. Long-term impact
            4. Reversibility

            Recommend the better choice with reasoning.
            """,
            category: "Productivity",
            icon: "arrow.triangle.branch"
        ),
    ]
}
