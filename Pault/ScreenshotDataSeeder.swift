//
//  ScreenshotDataSeeder.swift
//  Pault
//
//  Creates realistic seed data for App Store screenshot capture.
//  Activated by the --screenshot-mode launch argument.
//

import Foundation
import SwiftData

enum ScreenshotDataSeeder {

    // MARK: - Public Entry Point

    /// Populates the given ModelContext with realistic screenshot seed data.
    /// Call this when `--screenshot-mode` launch argument is present.
    static func seed(context: ModelContext) {
        let tags = createTags(context: context)
        let prompts = createPrompts(context: context, tags: tags)
        createVersionHistory(context: context, prompt: prompts.codeReview)
        createCopyEvents(context: context, prompts: prompts)
        createPromptRuns(context: context, prompt: prompts.sqlOptimizer)

        if ProcessInfo.processInfo.arguments.contains("--screenshot-mode-ai-streaming") {
            UserDefaults.standard.set(true, forKey: "screenshot_ai_streaming_active")
        }

        try? context.save()
    }

    // MARK: - Tag Creation

    private struct Tags {
        let development: Tag
        let productivity: Tag
        let documentation: Tag
        let communication: Tag
        let database: Tag
        let product: Tag
        let agile: Tag
        let qa: Tag
    }

    private static func createTags(context: ModelContext) -> Tags {
        func makeTag(_ name: String, color: String) -> Tag {
            let t = Tag(name: name, color: color)
            context.insert(t)
            return t
        }

        return Tags(
            development:   makeTag("development",   color: "indigo"),
            productivity:  makeTag("productivity",  color: "green"),
            documentation: makeTag("documentation", color: "blue"),
            communication: makeTag("communication", color: "orange"),
            database:      makeTag("database",      color: "purple"),
            product:       makeTag("product",       color: "pink"),
            agile:         makeTag("agile",         color: "teal"),
            qa:            makeTag("qa",            color: "red")
        )
    }

    // MARK: - Prompt Holder

    private struct Prompts {
        let codeReview: Prompt
        let apiDocGenerator: Prompt
        let sqlOptimizer: Prompt
        let meetingSummary: Prompt
        let emailFollowUp: Prompt
        let bugReport: Prompt
        let prd: Prompt
        let userStory: Prompt
        let interviewQuestions: Prompt
        let releaseNotes: Prompt
    }

    // MARK: - Prompt Creation

    // swiftlint:disable function_body_length
    private static func createPrompts(context: ModelContext, tags: Tags) -> Prompts {

        // a. Code Review Assistant — AI Assist hero prompt
        let codeReview = Prompt(
            title: "Code Review Assistant",
            content: """
            You are an expert software engineer performing a thorough code review. \
            Analyse the following code for:
            - Correctness and potential bugs
            - Performance bottlenecks and unnecessary allocations
            - Security vulnerabilities (injection, SSRF, auth bypass, etc.)
            - Maintainability and code clarity
            - Adherence to SOLID principles and idiomatic patterns

            Provide structured feedback with severity labels (Critical / Major / Minor / Suggestion). \
            For each issue, include the line reference, a concise explanation, and a suggested fix.

            Code to review:
            {{code}}
            """,
            isFavorite: true,
            createdAt: daysAgo(14),
            updatedAt: daysAgo(2),
            tags: [tags.development],
            lastUsedAt: daysAgo(1)
        )
        context.insert(codeReview)

        // b. API Documentation Generator — block editor mode
        let blockSnapshot = makeAPIDocBlockComposition()
        let apiDocData = try? JSONEncoder().encode(blockSnapshot)
        let apiDoc = Prompt(
            title: "API Documentation Generator",
            content: "You are a technical writer specialising in REST API documentation. "
                + "Given an endpoint definition, generate complete, developer-friendly documentation "
                + "including description, request/response schemas, example cURL commands, and common error codes. "
                + "Follow OpenAPI 3.1 style conventions. Endpoint: {{endpoint_definition}}",
            isFavorite: false,
            createdAt: daysAgo(21),
            updatedAt: daysAgo(5),
            tags: [tags.development, tags.documentation],
            blockCompositionData: apiDocData,
            editingModeRaw: "blocks"
        )
        context.insert(apiDoc)

        // c. SQL Query Optimizer — API Runner screenshot
        let sqlOptimizer = Prompt(
            title: "SQL Query Optimizer",
            content: """
            You are a database performance expert. Analyse the SQL query below and:
            1. Identify performance bottlenecks (missing indexes, full table scans, N+1 patterns)
            2. Suggest specific index strategies with CREATE INDEX statements
            3. Rewrite the query using CTEs or window functions where beneficial
            4. Estimate relative performance improvement

            Schema context: {{schema}}
            Query to optimise:
            {{query}}
            """,
            isFavorite: false,
            createdAt: daysAgo(30),
            updatedAt: daysAgo(10),
            tags: [tags.database],
            lastUsedAt: daysAgo(3)
        )
        context.insert(sqlOptimizer)

        // d. Meeting Summary Template — with template variables
        let meetingSummary = Prompt(
            title: "Meeting Summary Template",
            content: """
            Write a concise meeting summary for the following meeting notes.
            Attendees: {{attendees}}
            Date: {{date}}

            Structure the output as:
            ## Key Decisions
            ## Action Items (owner + deadline)
            ## Open Questions
            ## Next Meeting Agenda
            """,
            isFavorite: false,
            createdAt: daysAgo(45),
            updatedAt: daysAgo(7),
            tags: [tags.productivity]
        )
        context.insert(meetingSummary)

        // e. Email Draft: Client Follow-up
        let emailFollowUp = Prompt(
            title: "Email Draft: Client Follow-up",
            content: """
            Write a professional follow-up email to a client after an initial discovery call. \
            The tone should be warm but concise. Recap the main points discussed, confirm the \
            next steps agreed, and propose a time for the next meeting. Keep it under 200 words.
            Client name: {{client_name}}
            Company: {{company}}
            Topics discussed: {{topics}}
            """,
            isFavorite: true,
            createdAt: daysAgo(18),
            updatedAt: daysAgo(4),
            tags: [tags.communication],
            lastUsedAt: daysAgo(2)
        )
        context.insert(emailFollowUp)

        // f. Bug Report Template — with variables
        let bugReport = Prompt(
            title: "Bug Report Template",
            content: """
            ## Bug Report

            **Component:** {{component}}
            **Severity:** {{severity}}

            ### Steps to Reproduce
            {{steps}}

            ### Expected Behaviour
            [Describe what should happen]

            ### Actual Behaviour
            [Describe what actually happens]

            ### Environment
            - OS: macOS 15+
            - App version: [version]
            - Reproducible: Always / Sometimes / Rarely
            """,
            isFavorite: false,
            createdAt: daysAgo(60),
            updatedAt: daysAgo(20),
            tags: [tags.development, tags.qa]
        )
        context.insert(bugReport)

        // g. Product Requirements Doc
        let prd = Prompt(
            title: "Product Requirements Doc",
            content: """
            Write a structured Product Requirements Document for the following feature. \
            Include sections for: Problem Statement, User Personas, Success Metrics (with \
            specific measurable targets), Functional Requirements (prioritised as MoSCoW), \
            Non-Functional Requirements, Out of Scope, Open Questions, and Timeline.
            Feature: {{feature_description}}
            """,
            isFavorite: false,
            createdAt: daysAgo(35),
            updatedAt: daysAgo(12),
            tags: [tags.product, tags.documentation]
        )
        context.insert(prd)

        // h. User Story Generator
        let userStory = Prompt(
            title: "User Story Generator",
            content: """
            Generate 5–7 well-formed agile user stories for the feature described below. \
            Format each story as: "As a [persona], I want to [action], so that [benefit]." \
            Include acceptance criteria (Given / When / Then format) for each story. \
            Estimate story points on a Fibonacci scale (1, 2, 3, 5, 8, 13).
            Feature: {{feature}}
            """,
            isFavorite: false,
            createdAt: daysAgo(28),
            updatedAt: daysAgo(9),
            tags: [tags.agile, tags.product]
        )
        context.insert(userStory)

        // i. Technical Interview Questions — archived
        let interviewQuestions = Prompt(
            title: "Technical Interview Questions",
            content: """
            Generate a balanced set of technical interview questions for a {{role}} role at \
            {{seniority}} level. Include:
            - 5 coding/algorithm questions with expected complexity analysis
            - 3 system design questions appropriate to seniority
            - 4 behavioural questions using STAR format prompts
            - 2 domain-specific knowledge questions

            For each question, provide a model answer outline and common pitfalls to watch for.
            """,
            isFavorite: false,
            isArchived: true,
            createdAt: daysAgo(90),
            updatedAt: daysAgo(60),
            tags: [tags.development]
        )
        context.insert(interviewQuestions)

        // j. Release Notes Writer
        let releaseNotes = Prompt(
            title: "Release Notes Writer",
            content: """
            Write polished App Store release notes for the following version update. \
            Highlight the most impactful improvements for end users (not engineers). \
            Use clear, enthusiastic language. Keep it under 250 words. Group changes under \
            New Features, Improvements, and Bug Fixes. Begin with a one-sentence hook.
            Version: {{version}}
            Changes: {{changelog}}
            """,
            isFavorite: true,
            createdAt: daysAgo(25),
            updatedAt: daysAgo(3),
            tags: [tags.documentation],
            lastUsedAt: daysAgo(1)
        )
        context.insert(releaseNotes)

        return Prompts(
            codeReview: codeReview,
            apiDocGenerator: apiDoc,
            sqlOptimizer: sqlOptimizer,
            meetingSummary: meetingSummary,
            emailFollowUp: emailFollowUp,
            bugReport: bugReport,
            prd: prd,
            userStory: userStory,
            interviewQuestions: interviewQuestions,
            releaseNotes: releaseNotes
        )
    }
    // swiftlint:enable function_body_length

    // MARK: - Block Composition for API Documentation Generator

    private static func makeAPIDocBlockComposition() -> BlockCompositionSnapshot {
        let block1ID = UUID()
        let block2ID = UUID()
        let block3ID = UUID()
        let block4ID = UUID()
        let block5ID = UUID()

        let blocks: [BlockCompositionSnapshot.BlockSnapshot] = [
            .init(id: block1ID,
                  title: "Role & Persona",
                  categoryRaw: "Role & Perspective",
                  valueTypeRaw: "object",
                  snippet: "You are a senior technical writer specialising in REST and GraphQL API documentation."),
            .init(id: block2ID,
                  title: "Endpoint Definition",
                  categoryRaw: "Inputs & Context",
                  valueTypeRaw: "object",
                  snippet: "{{endpoint_definition}}"),
            .init(id: block3ID,
                  title: "Documentation Format",
                  categoryRaw: "Instructions",
                  valueTypeRaw: "object",
                  snippet: "Generate complete documentation following OpenAPI 3.1 conventions "
                      + "including: description, request/response schemas (with examples), "
                      + "authentication requirements, cURL command, common errors."),
            .init(id: block4ID,
                  title: "Output Structure",
                  categoryRaw: "Structure & Layout",
                  valueTypeRaw: "object",
                  snippet: "Format the output as structured Markdown with sections: "
                      + "Overview, Authentication, Request, Response, Error Codes, Examples."),
            .init(id: block5ID,
                  title: "Quality Constraints",
                  categoryRaw: "Constraints & Guardrails",
                  valueTypeRaw: "object",
                  snippet: "Keep descriptions developer-friendly and accurate. "
                      + "Do not invent behaviour not present in the endpoint definition."),
        ]

        let inputs: [String: [String: String]] = [
            block2ID.uuidString: ["value": "POST /api/v1/users/{{userId}}/sessions"]
        ]

        return BlockCompositionSnapshot(
            blocks: blocks,
            blockInputs: inputs,
            blockModifiers: [:],
            lastCompiledHash: nil
        )
    }

    // MARK: - Version History

    private static func createVersionHistory(context: ModelContext, prompt: Prompt) {
        let versions: [(String, String, VersionSource, Int)] = [
            (
                "Initial draft",
                "Review the following code and identify any bugs or issues you can find:\n{{code}}",
                .manual,
                18
            ),
            (
                "Added severity labels",
                "You are an expert software engineer. Review the following code and identify any bugs or issues. "
                    + "Categorise each finding as Critical, Major, or Minor.\n\nCode:\n{{code}}",
                .manual,
                12
            ),
            (
                "AI Improve: expanded review criteria",
                "You are an expert software engineer performing a thorough code review. Analyse the code for: "
                    + "correctness, performance, security, and maintainability. "
                    + "Provide structured feedback with severity labels. Code: {{code}}",
                .aiImprove,
                7
            ),
            (
                "Added SOLID principles + fix suggestions",
                """
                You are an expert software engineer performing a thorough code review. \
                Analyse the following code for:
                - Correctness and potential bugs
                - Performance bottlenecks
                - Security vulnerabilities
                - Maintainability and code clarity
                - Adherence to SOLID principles

                Provide structured feedback with severity labels (Critical / Major / Minor). \
                For each issue, include the line reference and a suggested fix.

                Code to review:
                {{code}}
                """,
                .manual,
                2
            ),
        ]

        for (note, content, source, daysBack) in versions {
            let version = PromptVersion(
                prompt: prompt,
                title: prompt.title,
                content: content,
                savedAt: daysAgo(daysBack),
                changeNote: note,
                source: source
            )
            context.insert(version)
        }
    }

    // MARK: - Copy Events (Analytics Data)

    private static func createCopyEvents(context: ModelContext, prompts: Prompts) {
        // Spread 18 copy events across the top 5 prompts over the last 30 days.
        // This populates the analytics dashboard with realistic usage data.
        let eventDistribution: [(Prompt, Int)] = [
            (prompts.codeReview,    7),   // most popular
            (prompts.emailFollowUp, 4),
            (prompts.releaseNotes,  3),
            (prompts.sqlOptimizer,  2),
            (prompts.meetingSummary, 2),
        ]

        for (prompt, count) in eventDistribution {
            for _ in 0..<count {
                let event = CopyEvent(promptID: prompt.id, type: .copy)
                context.insert(event)
            }
        }
    }

    // MARK: - Prompt Runs (API Runner History)

    // swiftlint:disable function_body_length
    private static func createPromptRuns(context: ModelContext, prompt: Prompt) {
        let run1 = PromptRun(
            promptTitle: prompt.title,
            resolvedInput: """
            Schema context: users(id, email, created_at), \
            orders(id, user_id, total, created_at, status), \
            order_items(id, order_id, product_id, qty, price)
            Query to optimise:
            SELECT u.email, COUNT(o.id) as order_count, SUM(o.total) as lifetime_value
            FROM users u
            LEFT JOIN orders o ON u.id = o.user_id
            WHERE o.created_at >= '2024-01-01'
            GROUP BY u.id, u.email
            ORDER BY lifetime_value DESC
            """,
            output: """
            ## Analysis

            **Issues Identified:**
            1. **Missing index on `orders.created_at`** (Critical) — Full table scan on orders for every user.
            2. **Missing composite index on `orders(user_id, created_at)`** — Improves join + filter combined.
            3. **LEFT JOIN with WHERE on right table** — Implicitly converts to INNER JOIN; clarify intent.

            ## Recommended Indexes

            ```sql
            CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);
            CREATE INDEX idx_orders_created_at   ON orders(created_at);
            ```

            ## Optimised Query

            ```sql
            SELECT u.email,
                   COUNT(o.id)    AS order_count,
                   SUM(o.total)   AS lifetime_value
            FROM   orders o
            JOIN   users  u  ON u.id = o.user_id
            WHERE  o.created_at >= '2024-01-01'
              AND  o.status      != 'cancelled'
            GROUP  BY u.id, u.email
            ORDER  BY lifetime_value DESC;
            ```

            **Estimated improvement:** 10–50x depending on table size once indexes are applied.
            """,
            model: "claude-opus-4-5",
            provider: "claude",
            latencyMs: 1843,
            inputTokens: 312,
            outputTokens: 487,
            userRating: 5
        )
        run1.prompt = prompt
        context.insert(run1)

        let run2 = PromptRun(
            promptTitle: prompt.title,
            resolvedInput: """
            Schema context: products(id, name, category_id, price, stock), categories(id, name)
            Query to optimise:
            SELECT p.name, c.name as category, p.price
            FROM products p, categories c
            WHERE p.category_id = c.id AND p.price > 50
            """,
            output: """
            ## Analysis

            **Issues Identified:**
            1. **Implicit JOIN syntax** (Minor) — Old-style comma join; prefer explicit `JOIN` for clarity.
            2. **No index on `products.price`** (Major) — Range scan on price requires full scan.
            3. **No index on `products.category_id`** (Major) — Join key unindexed.

            ## Recommended Indexes

            ```sql
            CREATE INDEX idx_products_category ON products(category_id);
            CREATE INDEX idx_products_price    ON products(price);
            ```

            ## Optimised Query

            ```sql
            SELECT p.name, c.name AS category, p.price
            FROM   products   p
            JOIN   categories c ON c.id = p.category_id
            WHERE  p.price > 50;
            ```

            **Estimated improvement:** 5–20x with covering index on (category_id, price).
            """,
            model: "claude-opus-4-5",
            provider: "claude",
            latencyMs: 1122,
            inputTokens: 198,
            outputTokens: 341,
            userRating: 4
        )
        run2.prompt = prompt
        context.insert(run2)
    }
    // swiftlint:enable function_body_length

    // MARK: - Helpers

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}
