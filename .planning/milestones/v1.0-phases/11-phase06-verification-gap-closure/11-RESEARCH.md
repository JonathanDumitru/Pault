# Phase 11: Phase 06 Verification & Gap Closure - Research

**Researched:** 2026-04-27
**Domain:** Documentation correction, code verification, gap closure for Import/Export (R9.1–R9.3)
**Confidence:** HIGH — all findings sourced from direct codebase inspection and existing planning artifacts

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Verification Depth**
- Code evidence only: match each R9.x sub-requirement to concrete code (file + function/method)
- Same approach as Phase 10 (AI Assist verification) — consistent pattern across gap closure phases
- Do NOT re-run functional tests — Phase 06 already has 25 tests and a human-verified checkpoint
- VERIFICATION.md uses per-requirement verdicts (SATISFIED/UNSATISFIED/PARTIAL) with code citations

**SUMMARY ID Corrections**
- 06-01-SUMMARY.md: change `requirements-completed: [R8.1, R8.2]` to `requirements-completed: [R9.1]`
- 06-02-SUMMARY.md: change `requirements-completed: [R8.1, R8.2]` to `requirements-completed: [R9.2]`
- R9.3 (Interoperability) was never claimed — add to whichever SUMMARY covers it (likely 06-02 since it wired Copy as Markdown and Share sheet)

**Gap Handling**
- Small code gaps found during verification: fix in this phase (same as Phase 10 fixing R5.3)
- Large gaps (new features or significant refactors): document in VERIFICATION.md for a future phase
- Threshold: if a fix touches more than ~3 files or adds >50 lines, it's "large"

### Claude's Discretion
- Exact VERIFICATION.md format and section structure (follow Phase 10 pattern)
- How to cite code evidence (file:line vs file:function — whatever is clearest)
- Whether to group R9.x verdicts by SUMMARY plan or by requirement

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R9.1 | Export — individual prompts as JSON or Markdown; library archive; includes template variables, tags, block compositions | ExportService.swift provides exportLibraryJSON, exportMarkdown, buildRecord with all fields; 06-01-PLAN covers this |
| R9.2 | Import — JSON or Markdown files; archive with conflict resolution (skip/overwrite/duplicate); drag-drop | ImportOrchestrator.swift provides prepare/applyImport with full conflict resolution; 06-02-PLAN covers this |
| R9.3 | Interoperability — Copy prompt as Markdown to clipboard; Share sheet integration for macOS | PromptDetailView.swift lines 359-377: ShareLink + Copy as Markdown button; ExportService.copyAsMarkdown; 06-02-PLAN covers this |
</phase_requirements>

---

## Summary

Phase 11 is a documentation correction and verification phase with no new feature implementation required. The Import/Export system was fully built during Phase 06, but two administrative errors prevent those requirements from being tracked: (1) both SUMMARY files claim wrong requirement IDs (R8.1/R8.2 instead of R9.1/R9.2), and (2) no VERIFICATION.md exists for Phase 06.

Code inspection confirms that R9.1 (Export), R9.2 (Import), and R9.3 (Interoperability) are all implemented. ExportService.swift provides JSON and Markdown export with v2 DTOs and YAML frontmatter. ImportOrchestrator.swift provides the full preview-based import pipeline with skip/overwrite/keepBoth conflict resolution. PromptDetailView.swift wires both ShareLink (macOS share sheet) and Copy as Markdown (clipboard) toolbar buttons.

The phase work is: fix two SUMMARY frontmatter fields, add R9.3 to 06-02-SUMMARY, inspect code for any small gaps, and produce 06-VERIFICATION.md following the Phase 10 template pattern.

**Primary recommendation:** Follow Phase 10 VERIFICATION.md structure exactly. Fix SUMMARY IDs first (trivial edits), then do a thorough code read of all 4 Phase 06 source files to produce file:line evidence for each R9.x sub-requirement, then write 06-VERIFICATION.md.

---

## Standard Stack

This phase involves no new libraries or packages. It is purely:

| Operation | Tool/Pattern | Notes |
|-----------|-------------|-------|
| SUMMARY correction | Direct file edit (frontmatter YAML field) | Two one-line changes |
| Code verification | Read source files, cite file:line | Same as Phase 10 pattern |
| VERIFICATION.md | Markdown document authoring | Follow Phase 10 template |
| Small gap fixes | Swift file edits | Only if gaps found |

**Installation:** None required.

---

## Architecture Patterns

### Phase 06 File Structure (already exists)

```
.planning/phases/06-import-export/
├── 06-01-PLAN.md         # Export layer plan
├── 06-01-SUMMARY.md      # Needs: requirements-completed: [R9.1]
├── 06-02-PLAN.md         # Import system + UI plan
├── 06-02-SUMMARY.md      # Needs: requirements-completed: [R9.2, R9.3]
├── 06-CONTEXT.md         # Original context
├── 06-RESEARCH.md        # Original research
├── 06-VALIDATION.md      # Test map (was draft, tests now green)
└── 06-VERIFICATION.md    # TO CREATE in this phase

Pault/
├── ExportService.swift              # R9.1 + R9.3 evidence
├── MarkdownFrontmatterParser.swift  # R9.1 + R9.2 evidence
├── ImportOrchestrator.swift         # R9.2 evidence
├── ImportPreviewSheet.swift         # R9.2 evidence (UI)
├── PromptDetailView.swift           # R9.3 evidence (ShareLink + Copy as Markdown)
└── ContentView.swift                # R9.2 evidence (drag-drop, File menu)
```

### Pattern 1: Verification Document Format (Phase 10 Template)

**What:** Per-requirement verdict table with SATISFIED/UNSATISFIED/PARTIAL status and file:line citations.

**Structure (from 10-VERIFICATION.md):**
- YAML frontmatter with `requirements_completed`, `status`, `score`, `human_verification` items
- Observable Truths table with numbered rows
- Required Artifacts table
- Key Link Verification table (wiring between components)
- Requirements Coverage table (one row per R-ID)
- Anti-Patterns Found section
- Human Verification Required section (items that need running app)

**Example frontmatter:**
```yaml
---
phase: 06-import-export
verified: 2026-04-27T12:00:00Z
status: passed  # or human_needed
score: N/N must-haves verified
requirements_completed: [R9.1, R9.2, R9.3]
human_verification:
  - test: "..."
    expected: "..."
    why_human: "..."
---
```

### Pattern 2: SUMMARY Frontmatter Correction

**What:** The `requirements-completed` YAML array in SUMMARY file frontmatter is the machine-readable claim that a plan delivered specific requirements. The audit tool reads this field to check coverage.

**Current (wrong):**
```yaml
requirements-completed: [R8.1, R8.2]
```

**Target for 06-01-SUMMARY:**
```yaml
requirements-completed: [R9.1]
```

**Target for 06-02-SUMMARY:**
```yaml
requirements-completed: [R9.2, R9.3]
```

### Anti-Patterns to Avoid
- **Do not re-run tests as verification:** Phase 06 already has 25 tests green and a human checkpoint. Verification is code evidence only.
- **Do not create a new SUMMARY file:** SUMMARY files are retrospective records of completed plans. Editing the existing frontmatter field is the correct action.
- **Do not add R9.3 to 06-01-SUMMARY:** R9.3 (Copy as Markdown + Share sheet) was wired in Plan 02 (PromptDetailView.swift), not Plan 01.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Verification format | Custom structure | Phase 10 VERIFICATION.md template | Consistency — auditor and planner both expect same shape |
| SUMMARY correction | New SUMMARY file | Edit existing frontmatter field | SUMMARY = retrospective record; adding a new one is wrong |
| Gap assessment threshold | New policy | "3 files / 50 lines" from CONTEXT.md | Already decided |

---

## Common Pitfalls

### Pitfall 1: Claiming R9.3 for 06-01-SUMMARY
**What goes wrong:** R9.3 (Copy as Markdown, Share sheet) is attributed to Plan 01 (Export Layer), but it was actually wired in Plan 02.
**Why it happens:** ExportService.copyAsMarkdown() was built in Plan 01, but the toolbar buttons in PromptDetailView (the user-facing wiring) were added in Plan 02.
**How to avoid:** R9.3 belongs in 06-02-SUMMARY. The sub-requirements are "Copy prompt as Markdown to clipboard" AND "Share sheet integration" — both wired in Plan 02's PromptDetailView changes.
**Warning signs:** If you put R9.3 in 06-01-SUMMARY, the evidence will be incomplete (missing the share button).

### Pitfall 2: Missing R9.1 Sub-Requirement — Block Compositions
**What goes wrong:** R9.1 requires export to include "template variables, tags, block compositions." blockCompositionData is a v2 optional field.
**Why it happens:** It's easy to verify tags and templateVariables but miss the blockCompositionData field.
**How to avoid:** Check ExportService.buildRecord() line 116: `blockCompositionData: prompt.blockCompositionData` — it IS included. Cite it explicitly.

### Pitfall 3: Missing R9.2 Sub-Requirement — Drag-Drop
**What goes wrong:** R9.2 requires "drag-drop import support." This is in ContentView.swift (onDrop handler), not ImportOrchestrator.
**Why it happens:** ImportOrchestrator handles parsing; ContentView handles the drag-drop trigger.
**How to avoid:** Cite ContentView.swift for drag-drop evidence, ImportOrchestrator for the parsing/conflict-resolution logic.

### Pitfall 4: Wrong Status for Human-Only Items
**What goes wrong:** Setting status to `passed` when share sheet behavior requires a running app.
**Why it happens:** The share sheet wiring (ShareLink) is code-verifiable, but actual share sheet presentation requires macOS UI.
**How to avoid:** Use `human_needed` status and list share sheet testing in the Human Verification Required section, matching Phase 10 pattern exactly.

---

## Code Examples

All evidence is sourced directly from codebase inspection:

### R9.1 Export Evidence

```swift
// ExportService.swift — buildRecord includes all R9.1 required fields
// Source: Pault/ExportService.swift lines 97-125
static func buildRecord(from prompt: Prompt) -> PromptExportRecord {
    PromptExportRecord(
        ...
        tags: prompt.tags.map(\.name),                          // tags included
        templateVariables: prompt.templateVariables...,          // template variables included
        blockCompositionData: prompt.blockCompositionData,       // block compositions included
        ...
    )
}

// JSON export — line 143
static func exportLibraryJSON(prompts: [Prompt], collectionName: String? = nil) -> Bool

// Markdown export — line 190
static func exportMarkdown(prompts: [Prompt]) -> Bool

// Library archive (JSON bundle) — line 15-27
struct PromptExportBundle: Codable {
    let version: Int       // v2 bundle
    let prompts: [PromptExportRecord]
    let collectionName: String?
}
```

### R9.2 Import Evidence

```swift
// ImportOrchestrator.swift — prepare() parses JSON and Markdown, detects duplicates
// Source: Pault/ImportOrchestrator.swift lines 66-112
static func prepare(jsonURLs: [URL], markdownURLs: [URL], context: ModelContext) -> ImportSession?

// applyImport() — conflict resolution: skip / overwrite / keepBoth
// Source: Pault/ImportOrchestrator.swift lines 173-253
static func applyImport(session: ImportSession, context: ModelContext, promptService: PromptService) -> ImportResult

// ConflictResolution enum — lines 17-21
enum ConflictResolution: String, CaseIterable {
    case skip
    case overwrite
    case keepBoth
}

// Drag-drop — ContentView.swift (onDrop handler with UTType.fileURL + pathExtension filter)
// File menu — PaultApp.swift (CommandGroup with Import Prompts Cmd+Opt+I)
```

### R9.3 Interoperability Evidence

```swift
// PromptDetailView.swift — ShareLink (macOS share sheet)
// Source: Pault/PromptDetailView.swift lines 359-367
ShareLink(item: compiledText) {
    Image(systemName: "square.and.arrow.up")
}
.help("Share prompt text")

// PromptDetailView.swift — Copy as Markdown button
// Source: Pault/PromptDetailView.swift lines 369-377
Button(action: { ExportService.copyAsMarkdown(prompt: prompt) }) {
    Image(systemName: "arrow.down.doc")
}
.help("Copy as Markdown")

// ExportService.copyAsMarkdown — writes to NSPasteboard.general
// Source: Pault/ExportService.swift lines 228-242
static func copyAsMarkdown(prompt: Prompt) -> Bool {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    return pasteboard.setString(markdown, forType: .string)
}
```

---

## Key Implementation Facts (from direct code inspection)

### What Plan 01 Built (R9.1 scope)
- `MarkdownFrontmatterParser` — serialize, parse, slugify, parsePlain (pure enum, static methods)
- `PromptExportRecord` v2 DTOs — 9 base fields + 6 v2 optional fields (blockCompositionData, qualityScore, lastUsedAt, editingModeRaw, variantB, attachmentFileNames)
- `PromptExportBundle` — v2 bundle with version, exportedAt, collectionName
- `ExportService.buildRecord()` — maps all Prompt fields including v2 metadata
- `ExportService.exportLibraryJSON()` — NSSavePanel + JSON write
- `ExportService.exportMarkdown()` — NSOpenPanel folder picker + per-file Markdown write
- `ExportService.copyAsMarkdown()` — NSPasteboard.general write
- 16 unit tests (10 MarkdownFrontmatterParserTests + 6 ExportServiceTests)

### What Plan 02 Built (R9.2 + R9.3 scope)
- `ImportOrchestrator` — parseJSON (v1+v2), parseMarkdown, prepare, applyImport with skip/overwrite/keepBoth
- `ImportPreviewSheet` — SwiftUI sheet with per-row conflict pickers, expandable diff, Apply to All
- File menu: Export Library as JSON, Export Library as Markdown, Import Prompts (Cmd+Opt+I)
- Drag-drop: .json/.md files onto ContentView main window
- Context menus: Export submenu (As JSON / As Markdown) on collections and prompts
- PromptDetailView: ShareLink button + Copy as Markdown button (R9.3)
- Export spinner overlay + import result banner
- 9 ImportOrchestratorTests

### R9.3 Attribution
R9.3 sub-requirements:
1. "Copy prompt as Markdown to clipboard" — `ExportService.copyAsMarkdown` (Plan 01) wired to button in `PromptDetailView` (Plan 02)
2. "Share sheet integration for macOS" — `ShareLink(item: compiledText)` in `PromptDetailView` (Plan 02)

Both user-facing entry points were created in Plan 02. Correct attribution: R9.3 → 06-02-SUMMARY.

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from config.json — treat as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest |
| Config file | Xcode scheme (no separate config file) |
| Quick run command | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests -only-testing:PaultTests/MarkdownFrontmatterParserTests -only-testing:PaultTests/ImportOrchestratorTests` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R9.1 | Export individual prompts as JSON | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ✅ |
| R9.1 | Export library as JSON bundle | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ✅ |
| R9.1 | Export as Markdown with YAML frontmatter | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/MarkdownFrontmatterParserTests` | ✅ |
| R9.1 | Export includes template variables, tags, block compositions | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ✅ |
| R9.2 | Import JSON (v1 + v2) | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ✅ |
| R9.2 | Import Markdown files | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ✅ |
| R9.2 | Conflict resolution skip/overwrite/keepBoth | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ✅ |
| R9.2 | Drag-drop import | manual | Visual confirmation — drag .json/.md onto main window | N/A |
| R9.3 | Copy as Markdown to clipboard | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ✅ |
| R9.3 | Share sheet integration | manual | Click share button, verify system picker appears | N/A |

### Sampling Rate
- **Per task commit:** Quick run command (phase-specific tests)
- **Per wave merge:** Full suite command
- **Phase gate:** Full suite green before VERIFICATION.md is written

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements. 25 tests exist (16 Export + 9 Import).

---

## Open Questions

1. **R9.2 "library archive with conflict resolution" — does overwrite auto-snapshot correctly?**
   - What we know: ImportOrchestrator.applyImport() case .overwrite calls `promptService.saveSnapshot(for: existingPrompt, changeNote: "Before import overwrite", source: .manual)` before updating fields (lines 205-212)
   - What's unclear: Whether PromptService.saveSnapshot() takes `changeNote` as a parameter — the Phase 10 gap fix used `source:` only
   - Recommendation: Read ImportOrchestrator.swift line 206-209 and PromptService.swift during planning to confirm saveSnapshot signature. This is LOW risk since Plan 02 compiled and 9 tests passed.

2. **R9.3 "Share sheet integration for macOS" — is ShareLink sufficient?**
   - What we know: `ShareLink(item: compiledText)` in PromptDetailView line 360 — SwiftUI's built-in share sheet mechanism on macOS
   - What's unclear: Whether R9.3 expects NSSharingServicePicker or ShareLink (SwiftUI)
   - Recommendation: ShareLink IS macOS share sheet integration — it presents the system NSSharingServicePicker. Mark SATISFIED with note that live-app verification is human-only.

---

## Sources

### Primary (HIGH confidence)
- Direct file read: `Pault/ExportService.swift` — all export functions, DTOs, copyAsMarkdown
- Direct file read: `Pault/ImportOrchestrator.swift` — prepare, applyImport, conflict resolution
- Direct file read: `Pault/MarkdownFrontmatterParser.swift` — serialize, parse, slugify
- Direct file read: `Pault/PromptDetailView.swift` lines 359-377 — ShareLink + Copy as Markdown
- Direct file read: `.planning/phases/06-import-export/06-01-SUMMARY.md` — wrong ID confirmed
- Direct file read: `.planning/phases/06-import-export/06-02-SUMMARY.md` — wrong ID confirmed
- Direct file read: `.planning/phases/10-phase04-verification-gap-closure/10-VERIFICATION.md` — template pattern
- Direct file read: `.planning/v1.0-MILESTONE-AUDIT.md` — gap catalog, R9.x orphaned status confirmed
- Direct file read: `.planning/REQUIREMENTS.md` — R9.1/R9.2/R9.3 sub-requirements verbatim

### Secondary (MEDIUM confidence)
- `.planning/phases/06-import-export/06-VALIDATION.md` — test commands confirmed still applicable

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries; all operations are file edits and document authoring
- Architecture: HIGH — template is Phase 10 VERIFICATION.md (read directly); SUMMARY correction is a known frontmatter field
- Pitfalls: HIGH — identified from direct code inspection; R9.3 attribution and block composition field verified from source
- Code evidence: HIGH — all file:line citations are from direct reads in this session

**Research date:** 2026-04-27
**Valid until:** 2026-05-27 (stable — Phase 06 code is complete and not being modified)
