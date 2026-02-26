//
//  PromptStudioModel.swift
//  Pault
//
//  Main view model for prompt studio (adapted from Schemap).
//  Operates on a Pault `Prompt` SwiftData model instead of Schemap's
//  standalone `CanvasComposition`.
//

import SwiftUI
import Combine

/// Preview mode for displaying compiled templates
enum PreviewMode: String, CaseIterable, Identifiable {
    case diff = "Diff"
    case filled = "Filled Example"
    case raw = "Raw Template"
    var id: String { rawValue }

    /// Short label for segmented control display
    var shortLabel: String {
        switch self {
        case .raw: return "Raw"
        case .filled: return "Filled"
        case .diff: return "Diff"
        }
    }
}

/// Canvas properties
struct CanvasProperties {
    var title: String = "Untitled Canvas"
    var notes: String = ""
}

/// Main view model for the prompt studio
@MainActor
final class PromptStudioModel: ObservableObject {

    // MARK: - Prompt Reference

    /// The Pault Prompt being edited
    let prompt: Prompt

    // MARK: - Active Tab

    @Published var tab: StudioTab = .build

    // MARK: - Block Library

    @Published var library: [BlockCategory: [Block]] = [:]

    // MARK: - Modifier Library

    @Published var modifierLibrary: [ModifierCategory: [BlockModifier]] = [:]

    // MARK: - Canvas State

    @Published var canvasBlocks: [Block] = []
    @Published var blockModifiers: [UUID: [BlockModifier]] = [:]
    @Published var blockInputs: [UUID: [String: String]] = [:]
    @Published var modifierInputs: [UUID: [String: String]] = [:]
    @Published var validationErrors: [UUID: [String: String]] = [:]

    // MARK: - Preview State

    @Published var previewMode: PreviewMode = .diff
    @Published var isRunning: Bool = false
    @Published var compiledTemplate: String = ""
    @Published var filledExample: String = ""
    @Published var rawTemplate: String = ""
    @Published var tokenEstimate: Int = 0

    /// Flattened dictionary of all placeholder inputs (from blocks and modifiers)
    var allInputs: [String: String] {
        var result: [String: String] = [:]
        for (_, inputs) in blockInputs {
            for (key, value) in inputs { result[key] = value }
        }
        for (_, inputs) in modifierInputs {
            for (key, value) in inputs { result[key] = value }
        }
        return result
    }

    // MARK: - Canvas Selection & Properties

    @Published var selectedCanvasBlockID: UUID? = nil
    @Published var canvasProperties: CanvasProperties = .init()

    // MARK: - Compatibility

    private(set) var compatibility: [String: [(title: String, level: CompatibilityLevel)]] = [:]

    // MARK: - Expanded Shadow Context

    @Published var expandedShadowForBlockIDs: Set<UUID> = []

    // MARK: - Compilation Performance

    private var compileWorkItem: DispatchWorkItem?
    private let compilationDebounceDelay: TimeInterval = 0.3
    @Published var isCompiling: Bool = false

    // MARK: - Dirty State

    @Published var isDirty: Bool = false
    @Published var lastSaved: Date?

    // MARK: - Init

    init(prompt: Prompt) {
        self.prompt = prompt
        seedLibrary()
        seedModifierLibrary()
        seedCompatibility()
        loadFromPrompt()
        compileNow()
    }

    // MARK: - Prompt Persistence

    /// Load canvas state from the prompt's block composition snapshot
    func loadFromPrompt() {
        guard let snapshot = prompt.blockComposition else {
            // Empty prompt -- start with blank canvas
            canvasBlocks = []
            blockInputs = [:]
            blockModifiers = [:]
            modifierInputs = [:]
            return
        }

        // Decode blocks
        canvasBlocks = snapshot.blocks.compactMap { $0.toBlock() }

        // Decode block inputs (convert String keys back to UUIDs)
        var loadedInputs: [UUID: [String: String]] = [:]
        for (key, value) in snapshot.blockInputs {
            if let uuid = UUID(uuidString: key) {
                loadedInputs[uuid] = value
            }
        }
        blockInputs = loadedInputs

        // Decode block modifiers and modifier inputs
        var loadedModifiers: [UUID: [BlockModifier]] = [:]
        for (key, modSnapshots) in snapshot.blockModifiers {
            if let blockUUID = UUID(uuidString: key) {
                let mods = modSnapshots.compactMap { $0.toModifier() }
                if !mods.isEmpty {
                    loadedModifiers[blockUUID] = mods
                }
                // Initialise modifier inputs for each loaded modifier
                for mod in mods {
                    let placeholders = Self.placeholders(in: mod.snippet)
                    if !placeholders.isEmpty {
                        var defaults: [String: String] = [:]
                        for name in placeholders { defaults[name] = "" }
                        modifierInputs[mod.id] = defaults
                    }
                }
            }
        }
        blockModifiers = loadedModifiers
    }

    /// Save current canvas state back to the prompt
    func saveToPrompt() {
        // Build block snapshots
        let blockSnapshots = canvasBlocks.map {
            BlockCompositionSnapshot.BlockSnapshot(block: $0)
        }

        // Build block inputs with String keys
        var snapshotInputs: [String: [String: String]] = [:]
        for (uuid, inputs) in blockInputs {
            snapshotInputs[uuid.uuidString] = inputs
        }

        // Build modifier snapshots
        var snapshotModifiers: [String: [BlockCompositionSnapshot.BlockModifierSnapshot]] = [:]
        for (blockID, modifiers) in blockModifiers {
            let modSnapshots = modifiers.map {
                BlockCompositionSnapshot.BlockModifierSnapshot(modifier: $0)
            }
            if !modSnapshots.isEmpty {
                snapshotModifiers[blockID.uuidString] = modSnapshots
            }
        }

        // Compute hash from compiled template
        let hash = String(compiledTemplate.hashValue)

        let snapshot = BlockCompositionSnapshot(
            blocks: blockSnapshots,
            blockInputs: snapshotInputs,
            blockModifiers: snapshotModifiers,
            lastCompiledHash: hash
        )

        prompt.blockComposition = snapshot
        prompt.content = compiledTemplate
        prompt.blockSyncState = .synced
        prompt.updatedAt = Date()

        isDirty = false
        lastSaved = Date()
    }

    // MARK: - Library Seeding

    func seedLibrary() {
        func make(_ title: String, _ cat: BlockCategory, _ type: BlockValueType, _ snippet: String) -> Block {
            .init(title: title, category: cat, valueType: type, snippet: snippet)
        }
        library = [
            .intent: [
                make("Objective", .intent, .object, "OBJECTIVE: {{goal}}\nPriority: {{priority}}\nMustHave: {{must_have}}\nNiceToHave: {{nice_to_have}}"),
                make("Audience", .intent, .object, "AUDIENCE: {{audience}}\nExpertise: {{expertise_level}}\nAssumptions: {{assumptions}}"),
                make("Use Case", .intent, .string, "USE_CASE: {{use_case}}"),
                make("Success Criteria", .intent, .object, "SUCCESS_CRITERIA:\n{{criteria}}"),
                make("Non-Goals", .intent, .object, "NON_GOALS:\n- {{item1}}\n- {{item2}}"),
                make("Context Summary", .intent, .string, "CONTEXT: {{summary}}")
            ],
            .rolePerspective: [
                make("Role", .rolePerspective, .string, "ROLE: {{role}}"),
                make("Persona", .rolePerspective, .object, "PERSONA:\nTone={{tone}}\nValues={{values}}\nBiases={{biases}}\nVersionPin={{persona_version}}"),
                make("Point of View", .rolePerspective, .string, "POV: {{point_of_view}}"),
                make("Authority Level", .rolePerspective, .string, "AUTHORITY: {{level}}"),
                make("Domain Expertise", .rolePerspective, .object, "DOMAIN_EXPERTISE:\n- {{domain1}}\n- {{domain2}}")
            ],
            .inputs: [
                make("Variable", .inputs, .string, "${{variable}}"),
                make("User Notes", .inputs, .string, "NOTES: {{notes}}"),
                make("File", .inputs, .object, "[file:name.ext] mode={{parsing_mode}} summaryDepth={{summary_depth}}"),
                make("External Context", .inputs, .object, "CONTEXT_SRC:\n- {{url1}}\n- {{url2}}\nPaste:\n{{pasted}}"),
                make("Example Input", .inputs, .object, "EXAMPLE_INPUT:\n{{input}}\nEXPECTED_OUTPUT:\n{{expected}}"),
                make("Conversation History", .inputs, .object, "CONVERSATION_HISTORY:\nInclude Last: {{num_exchanges}}\nSummarize: {{summarize_older}}\nFocus On: {{focus_topics}}"),
                make("User Preferences", .inputs, .object, "USER_PREFERENCES:\nKnown Preferences: {{preferences}}\nApply To: {{apply_areas}}\nOverridable: {{overridable}}"),
                make("Previous Output", .inputs, .object, "PREVIOUS_OUTPUT:\nReference: {{output_reference}}\nRelationship: {{relationship}}\nBuild Upon: {{build_upon}}"),
                make("Negative Examples", .inputs, .object, "NEGATIVE_EXAMPLES:\nWhat NOT to do: {{anti_patterns}}\nWhy: {{explanations}}\nContrast With: {{positive_examples}}"),
                make("Edge Cases", .inputs, .object, "EDGE_CASES:\nSpecial Cases: {{special_cases}}\nHandling: {{handling_rules}}\nFallback: {{fallback_behavior}}")
            ],
            .instructions: [
                make("Primary Instruction", .instructions, .string, "DO: {{task}}"),
                make("Subtask", .instructions, .object, "SUBTASK:\n- {{step1}}\n- {{step2}}"),
                make("Instruction Group", .instructions, .object, "GROUP {{name}}:\n{{body}}"),
                make("Priority Instruction", .instructions, .string, "PRIORITY: {{directive}}"),
                make("Do First", .instructions, .object, "DO_FIRST:\nPreliminary: {{preliminary_action}}\nBefore: {{before_main_task}}\nReason: {{reason}}"),
                make("Do Last", .instructions, .object, "DO_LAST:\nWrap Up: {{wrap_up_action}}\nAfter: {{after_main_task}}\nAlways: {{always_do}}"),
                make("Skip If", .instructions, .object, "SKIP_IF:\nSection: {{section_to_skip}}\nCondition: {{skip_condition}}\nAlternative: {{alternative_action}}"),
                make("Emphasize", .instructions, .object, "EMPHASIZE:\nFocus Area: {{focus_area}}\nExtra Attention: {{attention_aspects}}\nReason: {{emphasis_reason}}"),
                make("De-emphasize", .instructions, .object, "DE_EMPHASIZE:\nLow Priority: {{low_priority_area}}\nMinimize: {{minimize_aspects}}\nStill Include: {{still_include}}"),
                make("Mandatory Include", .instructions, .object, "MANDATORY_INCLUDE:\nRequired Elements: {{required_elements}}\nFormat: {{required_format}}\nValidation: {{validation_check}}")
            ],
            .constraints: [
                make("Constraint", .constraints, .string, "CONSTRAINT(severity={{severity}}): {{rule}}"),
                make("Format Constraint", .constraints, .object, "FORMAT: {{format}}\nSchema: {{schema}}"),
                make("Length Constraint", .constraints, .string, "LENGTH: {{units}}={{amount}}"),
                make("Forbidden Content", .constraints, .object, "FORBIDDEN:\n- {{item1}}\n- {{item2}}"),
                make("Compliance Rule", .constraints, .object, "COMPLIANCE: {{policy}}\nNotes: {{notes}}")
            ],
            .toneStyle: [
                make("Tone", .toneStyle, .string, "TONE: {{tone}}"),
                make("Writing Style", .toneStyle, .string, "STYLE: {{style}}"),
                make("Verbosity Level", .toneStyle, .string, "VERBOSITY: {{level}}"),
                make("Language Variant", .toneStyle, .string, "LANGUAGE: {{variant}}")
            ],
            .structure: [
                make("Heading", .structure, .string, "# {{heading}}"),
                make("Section", .structure, .object, "## {{sectionTitle}}\n{{sectionBody}}"),
                make("Subsection", .structure, .object, "### {{subsectionTitle}}\n{{subsectionBody}}"),
                make("Checklist", .structure, .object, "- [ ] {{item1}}\n- [ ] {{item2}}"),
                make("Table Schema", .structure, .object, "TABLE:\nColumns: {{columns}}\nRows: {{rows}}"),
                make("Ordered Flow", .structure, .object, "FLOW:\n1) {{first}}\n2) {{second}}\n3) {{third}}"),
                make("Card Layout", .structure, .object, "CARD:\nTitle: {{card_title}}\nBody: {{card_body}}\nActions: {{card_actions}}\nMetadata: {{card_metadata}}"),
                make("Timeline", .structure, .object, "TIMELINE:\nEvents: {{events}}\nDate Format: {{date_format}}\nConnectors: {{show_connectors}}"),
                make("Comparison Table", .structure, .object, "COMPARISON_TABLE:\nItems: {{items}}\nFeatures: {{features}}\nHighlight: {{highlight_differences}}"),
                make("Decision Tree Output", .structure, .object, "DECISION_TREE:\nRoot Question: {{root_question}}\nBranches: {{branches}}\nRecommendations: {{leaf_recommendations}}"),
                make("FAQ Format", .structure, .object, "FAQ:\nQuestions: {{questions}}\nCategories: {{categories}}\nExpand All: {{expand_all}}"),
                make("Step-by-Step Guide", .structure, .object, "STEP_GUIDE:\nSteps: {{steps}}\nPrerequisites: {{prerequisites}}\nEstimated Time: {{time_per_step}}")
            ],
            .logic: [
                make("If", .logic, .boolean, "IF({{cond}}) -> {{then}} ELSE {{else}}"),
                make("Else", .logic, .boolean, "ELSE_IF({{cond}}) -> {{then}}"),
                make("Guard", .logic, .boolean, "GUARD({{cond}}) -> {{then}}"),
                make("Fallback", .logic, .object, "TRY {{primary}} ELSE {{backup}}"),
                make("Retry Rule", .logic, .object, "RETRY count={{count}} strategy={{strategy}}"),
                make("For Each", .logic, .array, "FOR_EACH({{item}}) IN {{collection}}:\n{{action}}"),
                make("While", .logic, .boolean, "WHILE({{condition}}):\n{{action}}\nMAX_ITERATIONS: {{max_iter}}"),
                make("Switch Case", .logic, .object, "SWITCH({{variable}}):\nCASE {{case1}}: {{action1}}\nCASE {{case2}}: {{action2}}\nDEFAULT: {{default_action}}"),
                make("Try-Catch", .logic, .object, "TRY:\n{{try_block}}\nCATCH({{error_type}}):\n{{catch_block}}"),
                make("Pattern Match", .logic, .object, "MATCH({{input}}):\nPATTERN {{pattern1}}: {{action1}}\nPATTERN {{pattern2}}: {{action2}}\nDEFAULT: {{default_action}}"),
                make("State Machine", .logic, .object, "STATE_MACHINE:\nStates: {{states}}\nInitial: {{initial_state}}\nTransitions: {{transitions}}\nTriggers: {{triggers}}"),
                make("Pipeline", .logic, .object, "PIPELINE:\nStages: {{stages}}\nInput: {{pipeline_input}}\nCheckpoints: {{checkpoints}}\nOutput: {{pipeline_output}}"),
                make("Map-Reduce", .logic, .object, "MAP_REDUCE:\nMap: {{map_function}}\nReduce: {{reduce_function}}\nParallel: {{parallel_count}}\nCombine: {{combine_strategy}}"),
                make("Recursion Guard", .logic, .object, "RECURSE:\nBase Case: {{base_case}}\nRecursive Case: {{recursive_case}}\nMax Depth: {{max_depth}}\nAccumulator: {{accumulator}}")
            ],
            .reasoning: [
                make("Analysis Mode", .reasoning, .string, "ANALYZE: {{mode}}"),
                make("Decision Framework", .reasoning, .object, "DECIDE: {{framework}}\nCriteria: {{criteria}}"),
                make("Assumption Declaration", .reasoning, .object, "ASSUMPTIONS:\n- {{assumption1}}\n- {{assumption2}}"),
                make("Tradeoff Analysis", .reasoning, .object, "TRADEOFFS:\nPros: {{pros}}\nCons: {{cons}}"),
                make("Self-Critique Pass", .reasoning, .object, "SELF_CRITIQUE strictness={{level}}\nNotes: {{notes}}"),
                make("Chain of Thought", .reasoning, .object, "CHAIN_OF_THOUGHT:\nStep 1: {{step1}}\nStep 2: {{step2}}\nStep 3: {{step3}}\nConclusion: {{conclusion}}"),
                make("Tree of Thought", .reasoning, .object, "TREE_OF_THOUGHT:\nBranch A: {{branch_a}}\nBranch B: {{branch_b}}\nBest Path: {{best_path}}"),
                make("Self-Reflection", .reasoning, .object, "SELF_REFLECTION:\nInitial Thought: {{initial}}\nReflection: {{reflection}}\nRevised Thought: {{revised}}"),
                make("Evidence Gathering", .reasoning, .object, "EVIDENCE:\nClaim: {{claim}}\nSupporting: {{supporting}}\nContradicting: {{contradicting}}\nConclusion: {{conclusion}}"),
                make("Devil's Advocate", .reasoning, .object, "DEVILS_ADVOCATE:\nPosition: {{current_position}}\nCounter Arguments: {{counter_arguments}}\nWeaknesses: {{weaknesses}}\nStrength Test: {{strength_assessment}}"),
                make("Socratic Questioning", .reasoning, .object, "SOCRATIC:\nInitial Claim: {{initial_claim}}\nProbing Questions: {{probing_questions}}\nAssumptions Revealed: {{assumptions}}\nRefined Understanding: {{refined_understanding}}"),
                make("First Principles", .reasoning, .object, "FIRST_PRINCIPLES:\nProblem: {{problem}}\nFundamentals: {{fundamental_truths}}\nDecomposition: {{breakdown}}\nRebuilt Solution: {{rebuilt_solution}}"),
                make("Analogical Reasoning", .reasoning, .object, "ANALOGY:\nSource Domain: {{source_domain}}\nTarget Domain: {{target_domain}}\nMappings: {{mappings}}\nInsights: {{transferred_insights}}\nLimitations: {{analogy_limits}}"),
                make("Confidence Calibration", .reasoning, .object, "CONFIDENCE:\nClaim: {{claim}}\nConfidence Level: {{confidence_percent}}\nEvidence Strength: {{evidence_strength}}\nUncertainty Sources: {{uncertainty_sources}}\nCaveats: {{caveats}}"),
                make("Counterfactual Analysis", .reasoning, .object, "COUNTERFACTUAL:\nActual Outcome: {{actual}}\nWhat If: {{counterfactual_condition}}\nAlternative Outcome: {{alternative}}\nCausal Insight: {{causal_insight}}")
            ],
            .verification: [
                make("Consistency Check", .verification, .object, "CONSISTENCY:\n{{checks}}"),
                make("Fact Confidence Marker", .verification, .object, "CONFIDENCE:\n{{facts}}"),
                make("Schema Validator", .verification, .object, "VALIDATE schema={{schema}}\nOutput={{output}}"),
                make("Red Flag Detector", .verification, .object, "DETECT_RED_FLAGS:\n{{rules}}"),
                make("Output Scorer", .verification, .object, "SCORE threshold={{threshold}} rules={{rules}}"),
                make("Regression Check", .verification, .object, "REGRESSION:\nPrevious Behavior: {{previous_behavior}}\nCurrent Behavior: {{current_behavior}}\nPreserve: {{must_preserve}}\nAllowed Changes: {{allowed_changes}}"),
                make("Edge Case Generator", .verification, .object, "EDGE_CASES:\nInput Space: {{input_space}}\nBoundaries: {{boundaries}}\nCorner Cases: {{corner_cases}}\nStress Tests: {{stress_tests}}"),
                make("Adversarial Test", .verification, .object, "ADVERSARIAL:\nTarget: {{target_output}}\nAttack Vectors: {{attack_vectors}}\nManipulation Attempts: {{manipulation_attempts}}\nDefense Check: {{defense_verification}}"),
                make("Cross-Reference", .verification, .object, "CROSS_REFERENCE:\nPrimary Source: {{primary_source}}\nSecondary Sources: {{secondary_sources}}\nAgreement: {{agreement_check}}\nDiscrepancies: {{discrepancy_handling}}"),
                make("Hallucination Detector", .verification, .object, "HALLUCINATION_CHECK:\nClaims: {{claims_to_verify}}\nVerifiable: {{verifiable_claims}}\nUnverifiable: {{unverifiable_flags}}\nConfidence: {{confidence_markers}}")
            ],
            .transforms: [
                make("Rewrite", .transforms, .object, "REWRITE({{text}}) style={{style}}"),
                make("Summarize", .transforms, .object, "SUMMARIZE({{text}})"),
                make("Extract", .transforms, .object, "EXTRACT({{fields}}) FROM {{text}}"),
                make("Reformat", .transforms, .object, "REFORMAT({{text}}) to={{format}}"),
                make("Translate", .transforms, .object, "TRANSLATE({{text}}) to={{language}}"),
                make("JSON Parse", .transforms, .json, "JSON_PARSE({{json_string}})"),
                make("JSON Extract", .transforms, .string, "JSON_EXTRACT({{path}}) FROM {{json}}"),
                make("Regex Match", .transforms, .string, "REGEX_MATCH({{pattern}}) IN {{text}}"),
                make("Regex Replace", .transforms, .string, "REGEX_REPLACE({{pattern}}) WITH {{replacement}} IN {{text}}"),
                make("Split Text", .transforms, .string, "SPLIT({{text}}) BY {{delimiter}}"),
                make("Join Array", .transforms, .array, "JOIN({{array}}) WITH {{delimiter}}"),
                make("Format Number", .transforms, .number, "FORMAT_NUMBER({{number}}) AS {{format}}"),
                make("Format Date", .transforms, .string, "FORMAT_DATE({{date}}) AS {{format}}"),
                make("Code Translation", .transforms, .object, "CODE_TRANSLATE:\nSource Lang: {{source_lang}}\nTarget Lang: {{target_lang}}\nPreserve: {{preserve_comments}}\nIdiomatic: {{use_idioms}}"),
                make("Schema Migration", .transforms, .object, "SCHEMA_MIGRATE:\nSource Schema: {{source_schema}}\nTarget Schema: {{target_schema}}\nMapping: {{field_mapping}}\nDefaults: {{default_values}}"),
                make("Markup Conversion", .transforms, .object, "MARKUP_CONVERT:\nSource Format: {{source_format}}\nTarget Format: {{target_format}}\nPreserve: {{preserve_elements}}"),
                make("Unit Conversion", .transforms, .object, "UNIT_CONVERT:\nValue: {{value}}\nFrom Unit: {{from_unit}}\nTo Unit: {{to_unit}}\nPrecision: {{precision}}"),
                make("Anonymization", .transforms, .object, "ANONYMIZE:\nText: {{text}}\nReplace: {{identifiers_to_replace}}\nMethod: {{anonymization_method}}\nConsistency: {{maintain_consistency}}"),
                make("Enrichment", .transforms, .object, "ENRICH:\nData: {{data}}\nAdd Fields: {{fields_to_add}}\nSources: {{enrichment_sources}}\nFallback: {{enrichment_fallback}}")
            ],
            .reuse: [
                make("Snippet", .reuse, .object, "SNIPPET {{name}}:\n{{body}}"),
                make("Canonical Definition", .reuse, .object, "CANONICAL {{name}} v{{version}}:\n{{definition}}"),
                make("Policy", .reuse, .object, "POLICY {{name}}:\n{{policy}}"),
                make("House Style", .reuse, .object, "HOUSE_STYLE:\n{{rules}}"),
                make("Example Bank", .reuse, .object, "EXAMPLE_BANK:\n- Input: {{in1}}\n  Output: {{out1}}"),
                make("Negative Example", .reuse, .object, "NEGATIVE_EXAMPLE:\nInput: {{bad_in}}\nOutput: {{bad_out}}")
            ],
            .execution: [
                make("Execution Notes", .execution, .string, "EXECUTION_NOTES: {{notes}}"),
                make("Block Weighting", .execution, .string, "WEIGHT: {{weight}}"),
                make("Order Enforcement", .execution, .string, "ORDER_ENFORCEMENT: {{mode}}"),
                make("Token Budget Guard", .execution, .string, "TOKEN_BUDGET: {{limit}}"),
                make("Preview Mode Toggle", .execution, .string, "PREVIEW_MODE: {{mode}}")
            ],
            .modelConfig: [
                make("Temperature", .modelConfig, .number, "TEMPERATURE: {{value}}"),
                make("Max Tokens", .modelConfig, .number, "MAX_TOKENS: {{limit}}"),
                make("Top P", .modelConfig, .number, "TOP_P: {{value}}"),
                make("Presence Penalty", .modelConfig, .number, "PRESENCE_PENALTY: {{value}}"),
                make("Frequency Penalty", .modelConfig, .number, "FREQUENCY_PENALTY: {{value}}"),
                make("Stop Sequences", .modelConfig, .array, "STOP_SEQUENCES:\n{{sequences}}"),
                make("Random Seed", .modelConfig, .number, "SEED: {{value}}")
            ],
            .softwareEngineering: [
                make("Code Spec", .softwareEngineering, .object, "CODE_SPEC:\nLanguage: {{language}}\nFramework: {{framework}}\nPatterns: {{patterns}}\nStyle Guide: {{style_guide}}"),
                make("Architecture Pattern", .softwareEngineering, .object, "ARCHITECTURE:\nPattern: {{pattern}}\nLayers: {{layers}}\nDependencies: {{dependencies}}\nRationale: {{rationale}}"),
                make("API Contract", .softwareEngineering, .object, "API_CONTRACT:\nEndpoint: {{endpoint}}\nMethod: {{method}}\nRequest: {{request_schema}}\nResponse: {{response_schema}}\nAuth: {{auth_type}}"),
                make("Database Schema", .softwareEngineering, .object, "DB_SCHEMA:\nTables: {{tables}}\nRelationships: {{relationships}}\nIndexes: {{indexes}}\nConstraints: {{constraints}}"),
                make("Test Requirements", .softwareEngineering, .object, "TEST_REQUIREMENTS:\nTypes: {{test_types}}\nCoverage: {{coverage_target}}\nFramework: {{test_framework}}\nMocking: {{mock_strategy}}"),
                make("Error Handling Strategy", .softwareEngineering, .object, "ERROR_HANDLING:\nError Types: {{error_types}}\nRecovery: {{recovery_strategy}}\nLogging: {{logging_level}}\nUser Message: {{user_message_format}}"),
                make("Security Requirements", .softwareEngineering, .object, "SECURITY:\nAuth: {{auth_method}}\nValidation: {{input_validation}}\nSanitization: {{sanitization_rules}}\nOWASP: {{owasp_rules}}"),
                make("Performance Constraints", .softwareEngineering, .object, "PERFORMANCE:\nTime Complexity: {{time_complexity}}\nMemory Limit: {{memory_limit}}\nOptimizations: {{optimization_hints}}\nBenchmarks: {{benchmarks}}"),
                make("Dependency Spec", .softwareEngineering, .object, "DEPENDENCIES:\nRequired: {{required_packages}}\nVersions: {{version_constraints}}\nAlternatives: {{alternatives}}\nLock: {{lock_strategy}}"),
                make("Code Review Checklist", .softwareEngineering, .object, "CODE_REVIEW:\nCriteria: {{review_criteria}}\nSeverity Levels: {{severity_levels}}\nAuto-fix: {{autofix_hints}}\nBlocking: {{blocking_rules}}"),
                make("Refactor Directive", .softwareEngineering, .object, "REFACTOR:\nTarget Smell: {{code_smell}}\nPattern: {{refactor_pattern}}\nScope: {{scope_limits}}\nPreserve: {{preserve_behavior}}"),
                make("Migration Plan", .softwareEngineering, .object, "MIGRATION:\nFrom: {{from_version}}\nTo: {{to_version}}\nBreaking Changes: {{breaking_changes}}\nRollback: {{rollback_plan}}"),
                make("Debug Context", .softwareEngineering, .object, "DEBUG_CONTEXT:\nError: {{error_message}}\nStack Trace: {{stack_trace}}\nExpected: {{expected_behavior}}\nActual: {{actual_behavior}}\nSteps to Reproduce: {{repro_steps}}"),
                make("Documentation Style", .softwareEngineering, .object, "DOC_STYLE:\nFormat: {{docstring_format}}\nExamples: {{examples_required}}\nAPI Docs: {{api_doc_format}}\nChangelog: {{changelog_format}}"),
                make("Git Commit Style", .softwareEngineering, .object, "COMMIT_STYLE:\nFormat: {{commit_format}}\nScopes: {{allowed_scopes}}\nBreaking Change: {{breaking_change_format}}\nFooter: {{footer_format}}")
            ],
            .agenticWorkflows: [
                make("Tool Definition", .agenticWorkflows, .object, "TOOL_DEF:\nName: {{tool_name}}\nDescription: {{description}}\nParameters: {{parameters}}\nReturns: {{return_type}}\nExamples: {{usage_examples}}"),
                make("Tool Selection Rule", .agenticWorkflows, .object, "TOOL_SELECTION:\nCondition: {{when_to_use}}\nTools: {{tool_priority}}\nFallback: {{fallback_tool}}\nExclusions: {{never_use_when}}"),
                make("Planning Strategy", .agenticWorkflows, .object, "PLANNING:\nMethod: {{decomposition_method}}\nFormat: {{plan_format}}\nGranularity: {{step_granularity}}\nValidation: {{plan_validation}}"),
                make("Step Verification", .agenticWorkflows, .object, "STEP_VERIFY:\nCheck: {{verification_check}}\nSuccess Criteria: {{success_criteria}}\nRollback: {{rollback_condition}}\nContinue: {{continue_condition}}"),
                make("Human-in-Loop", .agenticWorkflows, .object, "HUMAN_IN_LOOP:\nPause When: {{pause_condition}}\nAsk: {{question_template}}\nTimeout: {{timeout_action}}\nDefault: {{default_if_no_response}}"),
                make("Memory Instruction", .agenticWorkflows, .object, "MEMORY:\nRemember: {{what_to_remember}}\nForget: {{what_to_forget}}\nSummarize: {{summarization_rules}}\nPriority: {{memory_priority}}"),
                make("Context Window Management", .agenticWorkflows, .object, "CONTEXT_MGMT:\nPriority Content: {{priority_content}}\nCompression: {{compression_rules}}\nEviction: {{eviction_policy}}\nReserved: {{reserved_tokens}}"),
                make("Parallel Execution", .agenticWorkflows, .object, "PARALLEL:\nTasks: {{independent_tasks}}\nMerge Strategy: {{merge_strategy}}\nConflict Resolution: {{conflict_resolution}}\nTimeout: {{parallel_timeout}}"),
                make("Delegation Rule", .agenticWorkflows, .object, "DELEGATE:\nSub-agent: {{subagent_spec}}\nHandoff: {{handoff_protocol}}\nContext Sharing: {{context_to_share}}\nReturn: {{return_format}}"),
                make("Progress Reporting", .agenticWorkflows, .object, "PROGRESS:\nFrequency: {{update_frequency}}\nFormat: {{report_format}}\nMetrics: {{tracked_metrics}}\nVisibility: {{visibility_level}}"),
                make("Termination Condition", .agenticWorkflows, .object, "TERMINATION:\nSuccess: {{success_condition}}\nMax Iterations: {{max_iterations}}\nAbort: {{abort_rules}}\nCleanup: {{cleanup_actions}}"),
                make("Recovery Strategy", .agenticWorkflows, .object, "RECOVERY:\nOn Failure: {{failure_action}}\nRetry With: {{retry_modifications}}\nEscalate: {{escalation_path}}\nLog: {{error_logging}}")
            ],
            .dataAnalysis: [
                make("Data Schema", .dataAnalysis, .object, "DATA_SCHEMA:\nFields: {{fields}}\nTypes: {{data_types}}\nConstraints: {{constraints}}\nExamples: {{sample_data}}"),
                make("Query Spec", .dataAnalysis, .object, "QUERY:\nFilter: {{filter_conditions}}\nSort: {{sort_order}}\nAggregate: {{aggregations}}\nJoin: {{join_logic}}\nLimit: {{result_limit}}"),
                make("Statistical Analysis", .dataAnalysis, .object, "STATISTICS:\nMethods: {{stat_methods}}\nConfidence: {{confidence_level}}\nAssumptions: {{assumptions}}\nOutput: {{output_format}}"),
                make("Visualization Spec", .dataAnalysis, .object, "VISUALIZATION:\nChart Type: {{chart_type}}\nX-Axis: {{x_axis}}\nY-Axis: {{y_axis}}\nColors: {{color_scheme}}\nAnnotations: {{annotations}}"),
                make("Data Cleaning Rules", .dataAnalysis, .object, "DATA_CLEANING:\nNull Handling: {{null_strategy}}\nOutliers: {{outlier_treatment}}\nNormalization: {{normalization_method}}\nValidation: {{validation_rules}}"),
                make("Aggregation Strategy", .dataAnalysis, .object, "AGGREGATION:\nGroup By: {{group_fields}}\nMetrics: {{metrics}}\nRollup: {{rollup_levels}}\nFilters: {{post_aggregation_filters}}"),
                make("Comparison Framework", .dataAnalysis, .object, "COMPARISON:\nBaseline: {{baseline}}\nDimensions: {{comparison_dimensions}}\nSignificance: {{significance_test}}\nVisualize: {{comparison_visual}}"),
                make("Trend Analysis", .dataAnalysis, .object, "TREND:\nTime Window: {{time_window}}\nSeasonality: {{seasonality_handling}}\nForecast: {{forecast_method}}\nConfidence: {{prediction_interval}}"),
                make("Anomaly Detection", .dataAnalysis, .object, "ANOMALY:\nThresholds: {{thresholds}}\nPatterns: {{anomaly_patterns}}\nAlert Rules: {{alert_rules}}\nFalse Positive: {{fp_handling}}")
            ],
            .creativeContent: [
                make("Narrative Structure", .creativeContent, .object, "NARRATIVE:\nArc: {{story_arc}}\nBeats: {{story_beats}}\nPacing: {{pacing_style}}\nPOV: {{point_of_view}}"),
                make("Character Spec", .creativeContent, .object, "CHARACTER:\nName: {{character_name}}\nTraits: {{personality_traits}}\nVoice: {{speech_patterns}}\nMotivations: {{motivations}}\nArc: {{character_arc}}"),
                make("World Building", .creativeContent, .object, "WORLD:\nSetting: {{setting_description}}\nRules: {{world_rules}}\nConstraints: {{world_constraints}}\nHistory: {{relevant_history}}"),
                make("Dialogue Style", .creativeContent, .object, "DIALOGUE:\nSubtext: {{subtext_level}}\nRhythm: {{dialogue_rhythm}}\nVoice Distinction: {{voice_distinction}}\nConflict: {{dialogue_conflict}}"),
                make("Brainstorm Mode", .creativeContent, .object, "BRAINSTORM:\nMode: {{divergent_or_convergent}}\nQuantity: {{ideas_count}}\nConstraints: {{creative_constraints}}\nWildcard: {{wildcard_factor}}"),
                make("Ideation Framework", .creativeContent, .object, "IDEATION:\nMethod: {{ideation_method}}\nPrompts: {{thought_prompts}}\nCombinations: {{combination_rules}}\nEvaluation: {{idea_evaluation}}"),
                make("Content Adaptation", .creativeContent, .object, "ADAPTATION:\nSource: {{source_format}}\nTarget: {{target_format}}\nPreserve: {{elements_to_preserve}}\nTransform: {{elements_to_transform}}"),
                make("SEO Requirements", .creativeContent, .object, "SEO:\nKeywords: {{target_keywords}}\nDensity: {{keyword_density}}\nMeta: {{meta_description}}\nStructure: {{heading_structure}}"),
                make("Brand Voice", .creativeContent, .object, "BRAND_VOICE:\nPersonality: {{brand_personality}}\nDo: {{voice_dos}}\nDont: {{voice_donts}}\nExamples: {{voice_examples}}")
            ],
            .domainSpecific: [
                make("Legal Disclaimer", .domainSpecific, .object, "LEGAL_DISCLAIMER:\nJurisdiction: {{jurisdiction}}\nScope: {{scope}}\nLiability: {{liability_limits}}\nNot Advice: {{not_legal_advice}}"),
                make("Medical Context", .domainSpecific, .object, "MEDICAL_CONTEXT:\nDisclaimer: {{medical_disclaimer}}\nEvidence Level: {{evidence_level}}\nContraindications: {{contraindications}}\nConsult: {{consult_professional}}"),
                make("Financial Disclosure", .domainSpecific, .object, "FINANCIAL:\nRisk Warning: {{risk_warning}}\nRegulatory: {{regulatory_compliance}}\nDisclaimer: {{investment_disclaimer}}\nNot Advice: {{not_financial_advice}}"),
                make("Academic Citation", .domainSpecific, .object, "CITATION:\nStyle: {{citation_style}}\nSources Required: {{source_requirements}}\nVerification: {{verification_level}}\nPlagiarism: {{plagiarism_rules}}"),
                make("Compliance Framework", .domainSpecific, .object, "COMPLIANCE:\nFramework: {{compliance_framework}}\nRules: {{specific_rules}}\nAudit Trail: {{audit_requirements}}\nExceptions: {{exception_handling}}"),
                make("Ethical Boundaries", .domainSpecific, .object, "ETHICS:\nRed Lines: {{absolute_limits}}\nEdge Cases: {{edge_case_handling}}\nEscalation: {{ethics_escalation}}\nTransparency: {{transparency_requirements}}")
            ],
            .communicationPatterns: [
                make("Explain Like", .communicationPatterns, .object, "EXPLAIN_LIKE:\nConcept: {{concept}}\nAudience Type: {{audience_type}}\nAnalogies: {{use_analogies}}\nDepth: {{explanation_depth}}"),
                make("Compare & Contrast", .communicationPatterns, .object, "COMPARE_CONTRAST:\nItem A: {{item_a}}\nItem B: {{item_b}}\nDimensions: {{comparison_dimensions}}\nConclusion: {{draw_conclusion}}"),
                make("Persuade", .communicationPatterns, .object, "PERSUADE:\nPosition: {{position}}\nEvidence Types: {{evidence_types}}\nCounterarguments: {{address_counterarguments}}\nCall to Action: {{call_to_action}}"),
                make("Teach Concept", .communicationPatterns, .object, "TEACH:\nTopic: {{topic}}\nPrerequisites: {{prerequisites}}\nExamples: {{examples}}\nExercises: {{include_exercises}}\nAssessment: {{assessment_method}}"),
                make("Debate Position", .communicationPatterns, .object, "DEBATE:\nIssue: {{issue}}\nSide A: {{side_a}}\nSide B: {{side_b}}\nConclusion Method: {{conclusion_method}}"),
                make("Narrative Explanation", .communicationPatterns, .object, "NARRATIVE_EXPLAIN:\nConcept: {{concept}}\nScenario: {{story_scenario}}\nCharacters: {{characters}}\nLesson: {{embedded_lesson}}"),
                make("Analogy Builder", .communicationPatterns, .object, "ANALOGY:\nComplex Thing: {{complex_thing}}\nFamiliar Thing: {{familiar_thing}}\nMapping: {{mapping_points}}\nLimitations: {{analogy_limitations}}"),
                make("Socratic Dialogue", .communicationPatterns, .object, "SOCRATIC_DIALOGUE:\nTopic: {{topic}}\nStarting Question: {{starting_question}}\nDepth: {{questioning_depth}}\nGoal: {{understanding_goal}}"),
                make("Critique & Improve", .communicationPatterns, .object, "CRITIQUE_IMPROVE:\nInput: {{input_to_critique}}\nCriteria: {{critique_criteria}}\nTone: {{critique_tone}}\nImprovements: {{suggest_improvements}}"),
                make("Steelman Argument", .communicationPatterns, .object, "STEELMAN:\nOpposing View: {{opposing_view}}\nStrongest Version: {{strongest_version}}\nValid Points: {{valid_points}}\nResponse: {{then_respond}}")
            ],
            .taskTemplates: [
                make("Classification Task", .taskTemplates, .object, "CLASSIFY:\nInput: {{input}}\nCategories: {{categories}}\nCriteria: {{classification_criteria}}\nExplain: {{explain_reasoning}}"),
                make("Ranking Task", .taskTemplates, .object, "RANK:\nItems: {{items}}\nCriteria: {{ranking_criteria}}\nOrder: {{ascending_or_descending}}\nExplain: {{explain_ordering}}"),
                make("Gap Analysis", .taskTemplates, .object, "GAP_ANALYSIS:\nCurrent State: {{current_state}}\nDesired State: {{desired_state}}\nIdentify Gaps: {{gap_categories}}\nRecommendations: {{include_recommendations}}"),
                make("Root Cause Analysis", .taskTemplates, .object, "ROOT_CAUSE:\nProblem: {{problem}}\nMethod: {{analysis_method}}\nDepth: {{depth_of_analysis}}\nAction Items: {{include_actions}}"),
                make("SWOT Analysis", .taskTemplates, .object, "SWOT:\nSubject: {{subject}}\nStrengths: {{strengths_focus}}\nWeaknesses: {{weaknesses_focus}}\nOpportunities: {{opportunities_focus}}\nThreats: {{threats_focus}}"),
                make("Pros Cons List", .taskTemplates, .object, "PROS_CONS:\nOption: {{option}}\nPros: {{pros_categories}}\nCons: {{cons_categories}}\nWeighting: {{weight_by_importance}}\nVerdict: {{include_verdict}}"),
                make("Decision Matrix", .taskTemplates, .object, "DECISION_MATRIX:\nOptions: {{options}}\nCriteria: {{criteria}}\nWeights: {{criteria_weights}}\nScoring: {{scoring_method}}\nRecommendation: {{include_recommendation}}"),
                make("Timeline Creation", .taskTemplates, .object, "TIMELINE:\nProject: {{project}}\nStart: {{start_date}}\nEnd: {{end_date}}\nMilestones: {{key_milestones}}\nDependencies: {{show_dependencies}}"),
                make("Breakdown Structure", .taskTemplates, .object, "BREAKDOWN:\nLarge Item: {{large_item}}\nGranularity: {{breakdown_level}}\nCategories: {{breakdown_categories}}\nEstimates: {{include_estimates}}"),
                make("Dependency Mapping", .taskTemplates, .object, "DEPENDENCY_MAP:\nElements: {{elements}}\nRelationship Types: {{relationship_types}}\nVisualize: {{visualization_format}}\nCritical Path: {{identify_critical_path}}"),
                make("Risk Assessment", .taskTemplates, .object, "RISK_ASSESSMENT:\nPlan: {{plan}}\nRisk Categories: {{risk_categories}}\nLikelihood Scale: {{likelihood_scale}}\nImpact Scale: {{impact_scale}}\nMitigation: {{include_mitigation}}"),
                make("Feasibility Check", .taskTemplates, .object, "FEASIBILITY:\nIdea: {{idea}}\nDimensions: {{feasibility_dimensions}}\nConstraints: {{known_constraints}}\nVerdict: {{feasibility_verdict}}")
            ],
            .outputStructures: [
                make("Bullet Summary", .outputStructures, .object, "BULLET_SUMMARY:\nContent: {{content}}\nMax Bullets: {{max_bullets}}\nWords Per Bullet: {{max_words_per_bullet}}\nHierarchy: {{use_hierarchy}}"),
                make("TL;DR Block", .outputStructures, .object, "TLDR:\nContent: {{content}}\nSummary Length: {{summary_length}}\nThen Details: {{include_details}}\nKey Takeaways: {{num_takeaways}}"),
                make("Executive Brief", .outputStructures, .object, "EXECUTIVE_BRIEF:\nTopic: {{topic}}\nKey Finding: {{key_finding}}\nRecommendation: {{recommendation}}\nSupporting Points: {{num_supporting_points}}"),
                make("Q&A Format", .outputStructures, .object, "QA_FORMAT:\nTopic: {{topic}}\nNum Questions: {{num_questions}}\nQuestion Style: {{question_style}}\nAnswer Length: {{answer_length}}"),
                make("Step-by-Step", .outputStructures, .object, "STEP_BY_STEP:\nProcess: {{process}}\nDetail Level: {{detail_level}}\nInclude Warnings: {{include_warnings}}\nInclude Tips: {{include_tips}}"),
                make("Before/After", .outputStructures, .object, "BEFORE_AFTER:\nSubject: {{subject}}\nChange: {{change_description}}\nHighlight Differences: {{highlight_differences}}\nImpact: {{describe_impact}}"),
                make("Problem-Solution", .outputStructures, .object, "PROBLEM_SOLUTION:\nProblem: {{problem}}\nContext: {{problem_context}}\nSolution: {{solution}}\nOutcome: {{expected_outcome}}"),
                make("STAR Format", .outputStructures, .object, "STAR:\nSituation: {{situation}}\nTask: {{task}}\nAction: {{action}}\nResult: {{result}}"),
                make("Thesis-Evidence-Conclusion", .outputStructures, .object, "THESIS_EVIDENCE:\nThesis: {{thesis}}\nEvidence Points: {{num_evidence_points}}\nCounterargument: {{address_counter}}\nConclusion: {{conclusion_style}}"),
                make("Hook-Body-CTA", .outputStructures, .object, "HOOK_BODY_CTA:\nHook Type: {{hook_type}}\nBody Structure: {{body_structure}}\nCTA: {{call_to_action}}\nTone: {{overall_tone}}"),
                make("Abstract Block", .outputStructures, .object, "ABSTRACT:\nBackground: {{background}}\nMethods: {{methods}}\nResults: {{results}}\nConclusion: {{conclusion}}\nWord Limit: {{word_limit}}"),
                make("Changelog Entry", .outputStructures, .object, "CHANGELOG:\nVersion: {{version}}\nDate: {{date}}\nCategories: {{change_categories}}\nBreaking Changes: {{highlight_breaking}}")
            ],
            .interactionModes: [
                make("Ask Before Acting", .interactionModes, .object, "ASK_BEFORE:\nAction: {{proposed_action}}\nClarifications Needed: {{clarifications}}\nDefault If No Response: {{default_action}}"),
                make("Confirm Understanding", .interactionModes, .object, "CONFIRM_UNDERSTANDING:\nRequest: {{original_request}}\nRestate As: {{restatement_format}}\nAsk Confirmation: {{confirmation_question}}"),
                make("Offer Alternatives", .interactionModes, .object, "OFFER_ALTERNATIVES:\nRequest: {{request}}\nNum Alternatives: {{num_alternatives}}\nComparison: {{include_comparison}}\nRecommendation: {{include_recommendation}}"),
                make("Progressive Disclosure", .interactionModes, .object, "PROGRESSIVE_DISCLOSURE:\nTopic: {{topic}}\nStart With: {{summary_level}}\nExpandable Sections: {{expandable_sections}}\nDepth Available: {{max_depth}}"),
                make("Guided Input", .interactionModes, .object, "GUIDED_INPUT:\nGoal: {{goal}}\nRequired Info: {{required_fields}}\nOrder: {{question_order}}\nValidation: {{validation_rules}}"),
                make("Checkpoint", .interactionModes, .object, "CHECKPOINT:\nAt Point: {{checkpoint_trigger}}\nSummarize: {{summarize_progress}}\nAsk: {{continuation_question}}\nOptions: {{available_options}}"),
                make("Preference Learning", .interactionModes, .object, "LEARN_PREFERENCE:\nAspect: {{preference_aspect}}\nInfer From: {{inference_source}}\nApply To: {{apply_going_forward}}\nConfirm: {{confirm_preference}}"),
                make("Disambiguation", .interactionModes, .object, "DISAMBIGUATE:\nAmbiguous Term: {{ambiguous_term}}\nPossible Meanings: {{possible_meanings}}\nAsk Format: {{disambiguation_format}}"),
                make("Scope Negotiation", .interactionModes, .object, "NEGOTIATE_SCOPE:\nTask: {{task}}\nProposed Scope: {{proposed_scope}}\nConstraints: {{known_constraints}}\nFlexibility: {{negotiable_aspects}}"),
                make("Feedback Request", .interactionModes, .object, "REQUEST_FEEDBACK:\nOutput: {{output_reference}}\nAspects: {{feedback_aspects}}\nFormat: {{feedback_format}}\nIteration: {{iteration_approach}}")
            ],
            .perspectiveFrames: [
                make("Stakeholder View", .perspectiveFrames, .object, "STAKEHOLDER_VIEW:\nSituation: {{situation}}\nStakeholder: {{stakeholder}}\nConcerns: {{likely_concerns}}\nRecommendation Style: {{recommendation_style}}"),
                make("Time Horizon", .perspectiveFrames, .object, "TIME_HORIZON:\nDecision: {{decision}}\nShort Term: {{short_term_view}}\nMedium Term: {{medium_term_view}}\nLong Term: {{long_term_view}}"),
                make("Optimist/Pessimist", .perspectiveFrames, .object, "OPTIMIST_PESSIMIST:\nScenario: {{scenario}}\nOptimistic View: {{optimistic_framing}}\nPessimistic View: {{pessimistic_framing}}\nRealistic View: {{balanced_view}}"),
                make("Beginner Mind", .perspectiveFrames, .object, "BEGINNER_MIND:\nTopic: {{topic}}\nAssume No Knowledge: {{no_jargon}}\nQuestion Everything: {{fundamental_questions}}\nFresh Perspective: {{fresh_insights}}"),
                make("Expert Critique", .perspectiveFrames, .object, "EXPERT_CRITIQUE:\nWork: {{work_to_review}}\nExpert Domain: {{expert_domain}}\nCritique Depth: {{critique_depth}}\nConstructive: {{constructive_feedback}}"),
                make("User Journey", .perspectiveFrames, .object, "USER_JOURNEY:\nProcess: {{process}}\nUser Type: {{user_type}}\nTouchpoints: {{touchpoints}}\nPain Points: {{identify_pain_points}}\nOpportunities: {{identify_opportunities}}"),
                make("Historian View", .perspectiveFrames, .object, "HISTORIAN_VIEW:\nEvent: {{event}}\nHistorical Context: {{historical_context}}\nParallels: {{historical_parallels}}\nLessons: {{lessons_learned}}"),
                make("Futurist View", .perspectiveFrames, .object, "FUTURIST_VIEW:\nTrend: {{trend}}\nTimeframe: {{projection_timeframe}}\nScenarios: {{possible_scenarios}}\nImplications: {{implications}}"),
                make("Cross-Cultural", .perspectiveFrames, .object, "CROSS_CULTURAL:\nTopic: {{topic}}\nCulture: {{culture}}\nCultural Lens: {{cultural_considerations}}\nAdaptations: {{suggested_adaptations}}"),
                make("Contrarian View", .perspectiveFrames, .object, "CONTRARIAN:\nConventional Wisdom: {{conventional_wisdom}}\nContrarian Position: {{contrarian_position}}\nEvidence: {{supporting_evidence}}\nCaveats: {{caveats}}")
            ],
            .qualityControls: [
                make("Accuracy Mandate", .qualityControls, .object, "ACCURACY_MANDATE:\nScope: {{accuracy_scope}}\nSources: {{acceptable_sources}}\nUncertain Handling: {{uncertain_handling}}\nVerification: {{verification_method}}"),
                make("Uncertainty Flagging", .qualityControls, .object, "FLAG_UNCERTAINTY:\nClaims: {{claims_to_flag}}\nLevels: {{uncertainty_levels}}\nFormat: {{flagging_format}}\nThreshold: {{flagging_threshold}}"),
                make("Source Requirement", .qualityControls, .object, "REQUIRE_SOURCES:\nClaims: {{claims_needing_sources}}\nCitation Format: {{citation_format}}\nMin Sources: {{min_sources}}\nRecency: {{source_recency}}"),
                make("Completeness Check", .qualityControls, .object, "COMPLETENESS_CHECK:\nRequired Elements: {{required_elements}}\nOptional Elements: {{optional_elements}}\nValidation: {{validation_method}}"),
                make("Consistency Mandate", .qualityControls, .object, "CONSISTENCY_MANDATE:\nElements: {{elements_to_check}}\nConsistency Rules: {{consistency_rules}}\nConflict Resolution: {{conflict_resolution}}"),
                make("No Hallucination", .qualityControls, .object, "NO_HALLUCINATION:\nTopics: {{sensitive_topics}}\nUnsure Response: {{unsure_response}}\nVerification: {{verification_steps}}"),
                make("Scope Boundary", .qualityControls, .object, "SCOPE_BOUNDARY:\nIn Scope: {{in_scope}}\nOut of Scope: {{out_of_scope}}\nBoundary Response: {{boundary_response}}"),
                make("Recency Requirement", .qualityControls, .object, "RECENCY_REQUIREMENT:\nTopic: {{topic}}\nMax Age: {{max_age}}\nStale Handling: {{stale_handling}}"),
                make("Balanced Coverage", .qualityControls, .object, "BALANCED_COVERAGE:\nTopic: {{topic}}\nPerspectives: {{perspectives_to_cover}}\nBalance Method: {{balance_method}}"),
                make("Actionability Check", .qualityControls, .object, "ACTIONABILITY_CHECK:\nRecommendations: {{recommendations}}\nActionable Criteria: {{actionable_criteria}}\nNon-Actionable Handling: {{non_actionable_handling}}")
            ],
            .metaPrompting: [
                make("Show Your Work", .metaPrompting, .object, "SHOW_WORK:\nProblem: {{problem}}\nSteps Visible: {{show_steps}}\nReasoning Depth: {{reasoning_depth}}\nFinal Answer: {{final_answer_format}}"),
                make("Think Then Answer", .metaPrompting, .object, "THINK_THEN_ANSWER:\nQuestion: {{question}}\nThink About: {{thinking_aspects}}\nThinking Visible: {{thinking_visible}}\nAnswer Format: {{answer_format}}"),
                make("Draft Then Revise", .metaPrompting, .object, "DRAFT_REVISE:\nTask: {{task}}\nDraft Approach: {{draft_approach}}\nRevision Criteria: {{revision_criteria}}\nIterations: {{num_iterations}}"),
                make("Multiple Attempts", .metaPrompting, .object, "MULTIPLE_ATTEMPTS:\nTask: {{task}}\nNum Versions: {{num_versions}}\nVariation Method: {{variation_method}}\nSelection Criteria: {{selection_criteria}}"),
                make("Sanity Check", .metaPrompting, .object, "SANITY_CHECK:\nOutput: {{output_to_check}}\nChecks: {{sanity_checks}}\nFail Action: {{fail_action}}"),
                make("Assumption Surfacing", .metaPrompting, .object, "SURFACE_ASSUMPTIONS:\nAnalysis: {{analysis}}\nAssumption Categories: {{assumption_categories}}\nValidation: {{assumption_validation}}"),
                make("Limitation Acknowledgment", .metaPrompting, .object, "ACKNOWLEDGE_LIMITS:\nResponse: {{response}}\nLimitation Types: {{limitation_types}}\nAlternatives: {{suggest_alternatives}}"),
                make("Improvement Suggestion", .metaPrompting, .object, "SUGGEST_IMPROVEMENT:\nOutput: {{output}}\nImprovement Areas: {{improvement_areas}}\nPrompt Feedback: {{prompt_feedback}}"),
                make("Decompose First", .metaPrompting, .object, "DECOMPOSE_FIRST:\nQuestion: {{complex_question}}\nDecomposition Method: {{decomposition_method}}\nSynthesize: {{synthesis_approach}}"),
                make("Synthesize Sources", .metaPrompting, .object, "SYNTHESIZE:\nSources: {{sources}}\nSynthesis Goal: {{synthesis_goal}}\nConflict Handling: {{conflict_handling}}\nOutput Format: {{synthesis_format}}")
            ]
        ]
    }

    // MARK: - Modifier Library Seeding

    func seedModifierLibrary() {
        func mod(_ name: String, _ cat: ModifierCategory, _ snippet: String, _ desc: String = "") -> BlockModifier {
            .init(name: name, category: cat, snippet: snippet, description: desc)
        }
        modifierLibrary = [
            .quality: [
                mod("+Confidence", .quality, "[CONFIDENCE: {{level}}]", "Adds confidence level requirement (high/medium/low)"),
                mod("+Citation", .quality, "[CITE: {{source}}]", "Requires source attribution"),
                mod("+Verified", .quality, "[VERIFIED: {{verification_method}}]", "Marks as requiring verification"),
                mod("+Approximate", .quality, "[APPROXIMATE: \u{00B1}{{margin}}]", "Flags as estimate, not exact"),
                mod("+Authoritative", .quality, "[AUTHORITATIVE: {{source_type}}]", "Must come from authoritative source"),
                mod("+Dated", .quality, "[AS_OF: {{date}}]", "Information valid as of date")
            ],
            .priority: [
                mod("+Must", .priority, "[PRIORITY: MUST]", "Non-negotiable requirement"),
                mod("+Should", .priority, "[PRIORITY: SHOULD]", "Strong preference"),
                mod("+Could", .priority, "[PRIORITY: COULD]", "Nice-to-have"),
                mod("+MustNot", .priority, "[PRIORITY: MUST_NOT]", "Absolute prohibition"),
                mod("+Critical", .priority, "[PRIORITY: CRITICAL]", "Highest priority, blocking"),
                mod("+Optional", .priority, "[PRIORITY: OPTIONAL]", "Include if possible")
            ],
            .scope: [
                mod("+OnlyIf", .scope, "[ONLY_IF: {{condition}}]", "Conditional application"),
                mod("+Except", .scope, "[EXCEPT: {{exclusion}}]", "Exclusion condition"),
                mod("+Within", .scope, "[WITHIN: {{boundary}}]", "Scope boundary"),
                mod("+Until", .scope, "[UNTIL: {{limit}}]", "Temporal or conditional limit"),
                mod("+When", .scope, "[WHEN: {{trigger}}]", "Trigger condition"),
                mod("+Unless", .scope, "[UNLESS: {{exception}}]", "Exception condition")
            ],
            .behavior: [
                mod("+Retry", .behavior, "[RETRY: {{count}} times, {{strategy}}]", "Retry on failure"),
                mod("+Fallback", .behavior, "[FALLBACK: {{alternative}}]", "Alternative if primary fails"),
                mod("+Timeout", .behavior, "[TIMEOUT: {{duration}}]", "Time limit"),
                mod("+Cache", .behavior, "[CACHE: {{duration}}]", "Cache result"),
                mod("+Async", .behavior, "[ASYNC: {{callback}}]", "Execute asynchronously"),
                mod("+Batch", .behavior, "[BATCH: {{size}}]", "Process in batches"),
                mod("+Throttle", .behavior, "[THROTTLE: {{rate}}]", "Rate limit execution")
            ],
            .format: [
                mod("+AsBullets", .format, "[FORMAT: bullets, max={{count}}]", "Format as bullet list"),
                mod("+AsTable", .format, "[FORMAT: table, columns={{columns}}]", "Format as table"),
                mod("+AsCode", .format, "[FORMAT: code, lang={{language}}]", "Format as code block"),
                mod("+AsJSON", .format, "[FORMAT: json, schema={{schema}}]", "Format as JSON"),
                mod("+AsMarkdown", .format, "[FORMAT: markdown]", "Format as Markdown"),
                mod("+WithExamples", .format, "[INCLUDE: {{count}} examples]", "Include examples"),
                mod("+Verbose", .format, "[VERBOSITY: detailed]", "Expand detail"),
                mod("+Concise", .format, "[VERBOSITY: concise, max={{words}} words]", "Minimize length"),
                mod("+Numbered", .format, "[FORMAT: numbered_list]", "Format as numbered list"),
                mod("+Hierarchical", .format, "[FORMAT: hierarchy, depth={{depth}}]", "Format with hierarchy")
            ],
            .tone: [
                mod("+Formal", .tone, "[TONE: formal]", "Formal register"),
                mod("+Casual", .tone, "[TONE: casual]", "Casual register"),
                mod("+Technical", .tone, "[TONE: technical, level={{expertise}}]", "Technical language"),
                mod("+Simple", .tone, "[TONE: simple, grade_level={{level}}]", "Plain language"),
                mod("+Empathetic", .tone, "[TONE: empathetic]", "Warm, understanding tone"),
                mod("+Assertive", .tone, "[TONE: assertive]", "Confident, direct tone"),
                mod("+Neutral", .tone, "[TONE: neutral]", "Objective, unbiased tone"),
                mod("+Encouraging", .tone, "[TONE: encouraging]", "Supportive, positive tone")
            ],
            .safety: [
                mod("+Sanitize", .safety, "[SANITIZE: {{rules}}]", "Clean dangerous content"),
                mod("+Redact", .safety, "[REDACT: {{patterns}}]", "Remove sensitive info"),
                mod("+Audit", .safety, "[AUDIT: {{log_level}}]", "Log for review"),
                mod("+HumanReview", .safety, "[HUMAN_REVIEW: {{criteria}}]", "Flag for human check"),
                mod("+RateLimit", .safety, "[RATE_LIMIT: {{threshold}}]", "Apply rate limiting"),
                mod("+Quarantine", .safety, "[QUARANTINE_IF: {{condition}}]", "Isolate if condition met"),
                mod("+Encrypt", .safety, "[ENCRYPT: {{method}}]", "Encrypt sensitive output"),
                mod("+Anonymize", .safety, "[ANONYMIZE: {{fields}}]", "Remove identifying info")
            ],
            .targeting: [
                mod("+ForAudience", .targeting, "[AUDIENCE: {{audience_type}}]", "Target specific audience"),
                mod("+ForPlatform", .targeting, "[PLATFORM: {{platform}}]", "Platform-specific formatting"),
                mod("+ForLocale", .targeting, "[LOCALE: {{locale}}]", "Localization settings"),
                mod("+ForExpertise", .targeting, "[EXPERTISE: {{level}}]", "Match expertise level"),
                mod("+ForContext", .targeting, "[CONTEXT: {{context}}]", "Context-aware output"),
                mod("+ForDevice", .targeting, "[DEVICE: {{device_type}}]", "Device-specific formatting")
            ]
        ]
    }

    // MARK: - Modifier Management

    func addModifierToBlock(blockID: UUID, modifier: BlockModifier) {
        let newModifier = BlockModifier(
            name: modifier.name,
            category: modifier.category,
            snippet: modifier.snippet,
            description: modifier.description
        )
        if blockModifiers[blockID] == nil {
            blockModifiers[blockID] = []
        }
        blockModifiers[blockID]?.append(newModifier)

        let placeholders = Self.placeholders(in: newModifier.snippet)
        if !placeholders.isEmpty {
            var defaults: [String: String] = [:]
            for name in placeholders { defaults[name] = "" }
            modifierInputs[newModifier.id] = defaults
        }

        compileNow()
        markDirty()
    }

    func removeModifierFromBlock(blockID: UUID, modifierID: UUID) {
        blockModifiers[blockID]?.removeAll { $0.id == modifierID }
        modifierInputs.removeValue(forKey: modifierID)
        compileNow()
        markDirty()
    }

    func modifiersForBlock(_ blockID: UUID) -> [BlockModifier] {
        return blockModifiers[blockID] ?? []
    }

    func setModifierInput(modifierID: UUID, placeholder: String, value: String) {
        if modifierInputs[modifierID] == nil {
            modifierInputs[modifierID] = [:]
        }
        modifierInputs[modifierID]?[placeholder] = value
        markDirty()
        compileDebounced()
    }

    // MARK: - Compatibility

    func seedCompatibility() {
        compatibility = [
            "Objective": [("Success Criteria", .high), ("Non-Goals", .high), ("Audience", .med), ("Use Case", .med)],
            "Success Criteria": [("Example Input", .high), ("Format Constraint", .high), ("Output Scorer", .med)],
            "Audience": [("Tone", .high), ("Authority Level", .med), ("Domain Expertise", .med)],
            "Use Case": [("Primary Instruction", .high), ("Format Constraint", .high), ("Token Budget Guard", .med)],
            "Non-Goals": [("Constraint", .high), ("Forbidden Content", .med), ("Policy", .med)],
            "Context Summary": [("External Context", .med), ("Assumption Declaration", .high), ("Fact Confidence Marker", .med)],
            "Role": [("Persona", .high), ("Authority Level", .high), ("Decision Framework", .med)],
            "Persona": [("Tone", .high), ("Policy", .med), ("House Style", .med)],
            "Domain Expertise": [("Assumption Declaration", .med), ("Red Flag Detector", .med), ("Fact Confidence Marker", .high)],
            "Point of View": [("Format Constraint", .med), ("Tone", .med)],
            "Variable": [("Guard", .high), ("Fallback", .high), ("Example Input", .med)],
            "File": [("Extract", .high), ("Summarize", .high), ("Reformat", .med), ("Policy", .med)],
            "External Context": [("Fact Confidence Marker", .high), ("Policy", .high), ("Consistency Check", .med)],
            "Example Input": [("Example Input", .high), ("Negative Example", .med), ("Format Constraint", .med)],
            "User Notes": [("Block Weighting", .med), ("Context Summary", .med)],
            "Primary Instruction": [("Format Constraint", .high), ("Constraint", .high), ("Output Scorer", .med), ("Self-Critique Pass", .med)],
            "Subtask": [("Ordered Flow", .high), ("Tradeoff Analysis", .med), ("Consistency Check", .med)],
            "Instruction Group": [("Priority Instruction", .med), ("Token Budget Guard", .med)],
            "Priority Instruction": [("Non-Goals", .med)],
            "Constraint": [("Policy", .high), ("Schema Validator", .med), ("Fallback", .med)],
            "Forbidden Content": [("Policy", .high), ("Red Flag Detector", .high)],
            "Length Constraint": [("Token Budget Guard", .high)],
            "Tone": [("Audience", .high), ("House Style", .med), ("Verbosity Level", .high)],
            "Verbosity Level": [("Length Constraint", .high), ("Format Constraint", .med)],
            "House Style": [("Format Constraint", .med), ("Policy", .med)],
            "Heading": [("Section", .high), ("Ordered Flow", .med)],
            "Section": [("Checklist", .med), ("Table Schema", .med), ("Token Budget Guard", .med)],
            "Checklist": [("Output Scorer", .med), ("Self-Critique Pass", .high)],
            "Table Schema": [("Schema Validator", .high), ("Reformat", .med)],
            "If": [("Guard", .high), ("Else", .high), ("Fallback", .high)],
            "Guard": [("Fallback", .high)],
            "Fallback": [("Retry Rule", .high)],
            "Decision Framework": [("Tradeoff Analysis", .high), ("Assumption Declaration", .high)],
            "Assumption Declaration": [("Fact Confidence Marker", .high), ("Red Flag Detector", .med)],
            "Self-Critique Pass": [("Consistency Check", .high), ("Output Scorer", .med), ("Schema Validator", .med)],
            "Output Scorer": [("Success Criteria", .high), ("Retry Rule", .med)],
            "Schema Validator": [("Format Constraint", .high), ("Reformat", .med)],
            "Red Flag Detector": [("Policy", .high)],
            "Rewrite": [("Tone", .high), ("House Style", .high), ("Constraint", .med)],
            "Summarize": [("Length Constraint", .high), ("Audience", .med)],
            "Extract": [("Table Schema", .med), ("Format Constraint", .high), ("Schema Validator", .med)],
            "Reformat": [("Format Constraint", .high), ("Schema Validator", .med)]
        ]
    }

    // MARK: - Canvas Operations

    func addToCanvas(_ block: Block) {
        let new = Block(title: block.title, category: block.category, valueType: block.valueType, snippet: block.snippet)
        canvasBlocks.append(new)
        let placeholders = Self.placeholders(in: new.snippet)
        if !placeholders.isEmpty {
            var defaults: [String: String] = [:]
            for name in placeholders { defaults[name] = "" }
            blockInputs[new.id] = defaults
        }
        compileNow()
        markDirty()
    }

    func removeFromCanvas(at offsets: IndexSet) {
        let removed = offsets.map { canvasBlocks[$0].id }
        canvasBlocks.remove(atOffsets: offsets)
        for id in removed {
            blockInputs.removeValue(forKey: id)
            if let modifiers = blockModifiers[id] {
                for modifier in modifiers {
                    modifierInputs.removeValue(forKey: modifier.id)
                }
            }
            blockModifiers.removeValue(forKey: id)
        }
        if let sel = selectedCanvasBlockID, removed.contains(sel) { selectedCanvasBlockID = nil }
        compileNow()
        markDirty()
    }

    func moveOnCanvas(from source: IndexSet, to destination: Int) {
        canvasBlocks.move(fromOffsets: source, toOffset: destination)
        compileNow()
        markDirty()
    }

    // MARK: - Compilation

    /// Compile immediately (for critical operations). Also persists to prompt.
    func compileNow() {
        // Check cache first
        let blocks = canvasBlocks.map { block in
            BlockData(
                id: block.id,
                title: block.title,
                category: block.category.rawValue,
                valueType: block.valueType.rawValue,
                snippet: block.snippet
            )
        }
        let cacheKey = CompilationCache.shared.generateCacheKey(blocks: blocks, blockInputs: blockInputs)

        if let cached = CompilationCache.shared.get(key: cacheKey) {
            compiledTemplate = cached.compiledTemplate
            filledExample = cached.filledExample
            rawTemplate = cached.rawTemplate
            tokenEstimate = cached.tokenEstimate
            saveToPrompt()
            return
        }

        // Validate all placeholder names in snippets
        for block in canvasBlocks {
            let placeholders = Self.placeholders(in: block.snippet)
            for placeholder in placeholders {
                let validation = InputValidator.validatePlaceholderName(placeholder)
                if !validation.isValid {
                    ErrorLogger.shared.logMessage("Invalid placeholder '\(placeholder)' in block '\(block.title)': \(validation.errorMessage ?? "unknown error")", level: .warning)
                }
            }
        }

        // Build raw template from snippets (including modifiers)
        var rawLines: [String] = []
        for block in canvasBlocks {
            var blockRaw = block.snippet
            if let modifiers = blockModifiers[block.id], !modifiers.isEmpty {
                let modifierSnippets = modifiers.map { $0.snippet }.joined(separator: " ")
                blockRaw += "\n" + modifierSnippets
            }
            rawLines.append(blockRaw)
        }
        rawTemplate = rawLines.joined(separator: "\n\n")

        // Build filled example by applying per-block inputs and modifier inputs
        var filledLines: [String] = []
        for block in canvasBlocks {
            var text = block.snippet
            let inputs = blockInputs[block.id] ?? [:]
            for (key, value) in inputs {
                let placeholder = "{{\(key)}}"
                guard text.contains(placeholder) else {
                    ErrorLogger.shared.logMessage("Placeholder '\(key)' not found in block '\(block.title)'", level: .warning)
                    continue
                }
                text = text.replacingOccurrences(of: placeholder, with: value)
            }

            if let modifiers = blockModifiers[block.id], !modifiers.isEmpty {
                var modifierTexts: [String] = []
                for modifier in modifiers {
                    var modText = modifier.snippet
                    let modInputs = modifierInputs[modifier.id] ?? [:]
                    for (key, value) in modInputs {
                        let placeholder = "{{\(key)}}"
                        modText = modText.replacingOccurrences(of: placeholder, with: value)
                    }
                    modifierTexts.append(modText)
                }
                text += "\n" + modifierTexts.joined(separator: " ")
            }

            filledLines.append(text)
        }
        filledExample = filledLines.joined(separator: "\n\n")

        compiledTemplate = filledExample
        tokenEstimate = estimateTokens(for: compiledTemplate)

        // Cache the result
        let cacheEntry = CompilationCacheEntry(
            compiledTemplate: compiledTemplate,
            filledExample: filledExample,
            rawTemplate: rawTemplate,
            tokenEstimate: tokenEstimate,
            cacheKey: cacheKey,
            timestamp: Date()
        )
        CompilationCache.shared.set(key: cacheKey, entry: cacheEntry)

        // Save to prompt after compilation
        saveToPrompt()
    }

    func estimateTokens(for text: String) -> Int {
        max(1, text.count / 4)
    }

    func toggleRun() {
        isRunning.toggle()
        if isRunning {
            compiledTemplate = filledExample.uppercased()
        } else {
            compiledTemplate = filledExample
        }
        tokenEstimate = estimateTokens(for: compiledTemplate)
    }

    static func placeholders(in snippet: String) -> [String] {
        let pattern = #"\{\{\s*([a-zA-Z0-9_\.]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: snippet, range: NSRange(snippet.startIndex..., in: snippet))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: snippet) else {
                return nil
            }
            return String(snippet[range])
        }
    }

    func isLibraryBlockCompatible(_ libBlock: Block) -> CompatibilityLevel? {
        guard let selectedID = selectedCanvasBlockID,
              let selBlock = canvasBlocks.first(where: { $0.id == selectedID }),
              let compatList = compatibility[selBlock.title] else { return nil }
        for (title, level) in compatList {
            if title == libBlock.title {
                return level
            }
        }
        return nil
    }

    func compatibleItems(for block: Block) -> [(Block, CompatibilityLevel)] {
        guard let compatList = compatibility[block.title] else { return [] }
        var resolved: [(Block, CompatibilityLevel)] = []
        for (title, level) in compatList {
            if let found = library.values.flatMap({ $0 }).first(where: { $0.title == title }) {
                resolved.append((found, level))
            }
        }
        return resolved
    }

    func setBlockInput(blockID: UUID, placeholder: String, value: String) {
        if blockInputs[blockID] == nil {
            blockInputs[blockID] = [:]
        }
        blockInputs[blockID]?[placeholder] = value
        markDirty()
        compileDebounced()
    }

    /// Compile with debouncing (for user input)
    func compileDebounced() {
        compileWorkItem?.cancel()

        isCompiling = true

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.compileNow()
                self?.isCompiling = false
            }
        }

        compileWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + compilationDebounceDelay, execute: workItem)
    }

    // MARK: - Dirty State

    func markDirty() {
        isDirty = true
    }
}
