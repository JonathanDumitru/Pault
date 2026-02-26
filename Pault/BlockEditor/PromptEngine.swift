//
//  PromptEngine.swift
//  Pault
//
//  Core prompt specification, mapping, rendering, validation, and optimization.
//  Adapted from Schemap -- pure logic with no persistence dependencies.
//

import Foundation

// MARK: - Prompt Spec

public struct PromptSpec: Equatable {
    // Phase 1: Identity & Scope
    public var role: String = ""
    public var persona: String = ""
    public var audience: String = ""
    public var domainScope: String = ""
    public var authorityLevel: String = ""
    public var styleTone: String = ""

    // Phase 2: Objective & Task
    public var objective: String = ""
    public var immediateTask: String = ""
    public var successCriteria: String = ""

    // Phase 3: Context & Inputs
    public var context: String = ""
    public var variables: [String] = []
    public var exampleInputs: [String] = []
    public var exampleOutputs: [String] = []

    // Phase 4: Constraints & Guardrails
    public var constraints: [String] = []
    public var forbiddenContent: [String] = []
    public var refusalPolicy: String = ""
    public var complianceRule: String = ""

    // Phase 5: Output Contract
    public var outputFormat: String = ""
    public var structureRequirements: String = ""
    public var lengthLimits: String = ""

    // Phase 6: Quality & Verification
    public var qualityChecks: [String] = []
    public var verificationSteps: [String] = []
    public var evaluationRubric: String = ""
}

// MARK: - Validation

public struct PromptValidation: Equatable {
    public var missingCriticalPhases: [String] = []
    public var emptyRequiredFields: [String] = []
    public var unpairedExamples: Int = 0
    public var conflictingConstraints: [String] = []
    public var completenessScore: Double = 0.0
    public var warnings: [String] = []
    public var recommendations: [String] = []
}

// MARK: - Mapper

public enum PromptMapper {
    /// Build a PromptSpec from an ordered list of blocks and their filled inputs.
    static func buildPromptSpec(from blocks: [Block], inputs: [String: String]) -> PromptSpec {
        var spec = PromptSpec()

        func fill(_ text: String) -> String {
            var result = text
            for (k, v) in inputs { result = result.replacingOccurrences(of: "{{\(k)}}", with: v) }
            return result
        }

        for block in blocks {
            let title = canonicalize(block.title)
            let content = fill(block.snippet)

            switch title {
            case "role", "identity", "role definition":
                appendText(&spec.role, content)
            case "persona":
                appendText(&spec.persona, content)
            case "audience", "target audience":
                appendText(&spec.audience, content)
            case "scope", "domain", "domain scope":
                appendText(&spec.domainScope, content)
            case "authority", "authority level":
                appendText(&spec.authorityLevel, content)
            case "style", "tone", "style tone", "communication style":
                appendText(&spec.styleTone, content)

            case "objective", "goal":
                appendText(&spec.objective, content)
            case "task", "immediate task":
                appendText(&spec.immediateTask, content)
            case "success", "success criteria":
                appendText(&spec.successCriteria, content)

            case "context", "background":
                appendText(&spec.context, content)
            case "variables", "inputs":
                spec.variables.append(contentsOf: splitLines(content))
            case "example input":
                spec.exampleInputs.append(content)
            case "example output", "expected output":
                spec.exampleOutputs.append(content)

            case "constraints", "guardrails":
                spec.constraints.append(contentsOf: splitLines(content))
            case "forbidden", "forbidden content":
                spec.forbiddenContent.append(contentsOf: splitLines(content))
            case "refusal policy":
                appendText(&spec.refusalPolicy, content)
            case "compliance", "compliance rule":
                appendText(&spec.complianceRule, content)

            case "output format", "format":
                appendText(&spec.outputFormat, content)
            case "structure", "structure requirements":
                appendText(&spec.structureRequirements, content)
            case "length", "length limits":
                appendText(&spec.lengthLimits, content)

            case "quality checks":
                spec.qualityChecks.append(contentsOf: splitLines(content))
            case "verification", "verification steps":
                spec.verificationSteps.append(contentsOf: splitLines(content))
            case "rubric", "evaluation rubric":
                appendText(&spec.evaluationRubric, content)

            default:
                break
            }
        }

        return spec
    }

    private static func canonicalize(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    private static func splitLines(_ s: String) -> [String] {
        return s.split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    private static func appendText(_ field: inout String, _ new: String) { field = field.isEmpty ? new : field + "\n\n" + new }
}

// MARK: - Renderer

public enum PromptRenderer {
    public static func renderUniversalPrompt(from spec: PromptSpec) -> String {
        var sections: [String] = []

        // Phase 1
        var phase1: [String] = []
        appendIfNotEmpty(&phase1, header("## Role"), spec.role)
        appendIfNotEmpty(&phase1, header("## Persona"), spec.persona)
        appendIfNotEmpty(&phase1, header("## Audience"), spec.audience)
        appendIfNotEmpty(&phase1, header("### Domain & Scope"), spec.domainScope)
        appendIfNotEmpty(&phase1, header("### Authority Level"), spec.authorityLevel)
        appendIfNotEmpty(&phase1, header("### Style & Tone"), spec.styleTone)
        if !phase1.isEmpty { sections.append(header("# Identity & Scope") + "\n\n" + phase1.joined(separator: "\n\n")) }

        // Phase 2
        var phase2: [String] = []
        appendIfNotEmpty(&phase2, header("## Objective"), spec.objective)
        appendIfNotEmpty(&phase2, header("## Immediate Task"), spec.immediateTask)
        appendIfNotEmpty(&phase2, header("## Success Criteria"), spec.successCriteria)
        if !phase2.isEmpty { sections.append(header("# Objective & Task") + "\n\n" + phase2.joined(separator: "\n\n")) }

        // Phase 3
        var phase3: [String] = []
        appendIfNotEmpty(&phase3, header("## Context"), spec.context)
        if !spec.variables.isEmpty { phase3.append(header("### Variables")); phase3.append(spec.variables.map { "- \($0)" }.joined(separator: "\n")) }
        if !spec.exampleInputs.isEmpty { phase3.append(header("### Example Inputs")); phase3.append(spec.exampleInputs.enumerated().map { "\($0.offset+1). \($0.element)" }.joined(separator: "\n")) }
        if !spec.exampleOutputs.isEmpty { phase3.append(header("### Example Outputs")); phase3.append(spec.exampleOutputs.enumerated().map { "\($0.offset+1). \($0.element)" }.joined(separator: "\n")) }
        if !phase3.isEmpty { sections.append(header("# Context & Inputs") + "\n\n" + phase3.joined(separator: "\n\n")) }

        // Phase 4
        var phase4: [String] = []
        if !spec.constraints.isEmpty { phase4.append(header("## Constraints")); phase4.append(spec.constraints.map { "- \($0)" }.joined(separator: "\n")) }
        if !spec.forbiddenContent.isEmpty { phase4.append(header("## Forbidden Content")); phase4.append(spec.forbiddenContent.map { "- \($0)" }.joined(separator: "\n")) }
        appendIfNotEmpty(&phase4, header("### Refusal Policy"), spec.refusalPolicy)
        appendIfNotEmpty(&phase4, header("### Compliance Rule"), spec.complianceRule)
        if !phase4.isEmpty { sections.append(header("# Constraints & Guardrails") + "\n\n" + phase4.joined(separator: "\n\n")) }

        // Phase 5
        var phase5: [String] = []
        appendIfNotEmpty(&phase5, header("## Output Format"), spec.outputFormat)
        appendIfNotEmpty(&phase5, header("## Structure Requirements"), spec.structureRequirements)
        appendIfNotEmpty(&phase5, header("## Length Limits"), spec.lengthLimits)
        if !phase5.isEmpty { sections.append(header("# Output Contract") + "\n\n" + phase5.joined(separator: "\n\n")) }

        // Phase 6
        var phase6: [String] = []
        if !spec.qualityChecks.isEmpty { phase6.append(header("## Quality Checks")); phase6.append(spec.qualityChecks.map { "- \($0)" }.joined(separator: "\n")) }
        if !spec.verificationSteps.isEmpty { phase6.append(header("## Verification Steps")); phase6.append(spec.verificationSteps.map { "- \($0)" }.joined(separator: "\n")) }
        appendIfNotEmpty(&phase6, header("### Evaluation Rubric"), spec.evaluationRubric)
        if !phase6.isEmpty { sections.append(header("# Quality & Verification") + "\n\n" + phase6.joined(separator: "\n\n")) }

        return sections.joined(separator: "\n\n")
    }

    private static func header(_ s: String) -> String { s }
    private static func appendIfNotEmpty(_ arr: inout [String], _ heading: String, _ body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { arr.append(heading); arr.append(trimmed) }
    }
}

// MARK: - Validation & Optimization

public enum PromptValidator {
    public static func validatePromptSpec(_ spec: PromptSpec) -> PromptValidation {
        var val = PromptValidation()

        // Critical phases present?
        if spec.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { val.missingCriticalPhases.append("Role") }
        if spec.immediateTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { val.missingCriticalPhases.append("Immediate Task") }
        if spec.constraints.isEmpty && spec.refusalPolicy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && spec.complianceRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            val.missingCriticalPhases.append("Guardrails")
        }

        // Empty required fields (detect remaining placeholders)
        let allTextFields: [(String, String)] = [
            ("Role", spec.role), ("Objective", spec.objective), ("Immediate Task", spec.immediateTask), ("Output Format", spec.outputFormat)
        ]
        for (name, value) in allTextFields {
            if value.contains("{{") && value.contains("}}") { val.emptyRequiredFields.append(name) }
        }

        // Unpaired examples
        val.unpairedExamples = abs(spec.exampleInputs.count - spec.exampleOutputs.count)
        if val.unpairedExamples > 0 { val.warnings.append("Example inputs/outputs are unpaired.") }

        // Conflicting constraints
        let lower = Set(spec.constraints.map { $0.lowercased() })
        for c in lower {
            if c.contains("do not") {
                let positive = c.replacingOccurrences(of: "do not ", with: "")
                if lower.contains(positive) { val.conflictingConstraints.append("Conflict between: \(c) and \(positive)") }
            }
        }

        // Completeness score
        let checks: [Bool] = [
            !spec.role.isEmpty,
            !spec.immediateTask.isEmpty,
            !spec.outputFormat.isEmpty,
            !(spec.constraints.isEmpty && spec.refusalPolicy.isEmpty && spec.complianceRule.isEmpty),
            !spec.objective.isEmpty,
            !spec.context.isEmpty
        ]
        let score = Double(checks.filter { $0 }.count) / Double(checks.count)
        val.completenessScore = max(0.0, min(1.0, score))

        // Recommendations
        if spec.audience.isEmpty { val.recommendations.append("Specify the audience to tailor tone and examples.") }
        if spec.successCriteria.isEmpty { val.recommendations.append("Add success criteria to make evaluation objective.") }
        if spec.verificationSteps.isEmpty { val.recommendations.append("Define verification steps for quality control.") }

        return val
    }
}

public enum PromptOptimizer {
    public static func optimizePromptSpec(_ spec: PromptSpec) -> PromptSpec {
        var out = spec
        // Deduplicate constraints
        let deduped = Array(NSOrderedSet(array: out.constraints.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })).compactMap { $0 as? String }.filter { !$0.isEmpty }
        out.constraints = deduped

        // Remove redundant examples (exact duplicates)
        out.exampleInputs = Array(NSOrderedSet(array: out.exampleInputs)) as? [String] ?? out.exampleInputs
        out.exampleOutputs = Array(NSOrderedSet(array: out.exampleOutputs)) as? [String] ?? out.exampleOutputs

        // Merge related role definitions (Authority Level into Role)
        if !out.authorityLevel.isEmpty {
            out.role = out.role.isEmpty ? out.authorityLevel : out.role + "\n\nAuthority: " + out.authorityLevel
            out.authorityLevel = ""
        }

        return out
    }
}
