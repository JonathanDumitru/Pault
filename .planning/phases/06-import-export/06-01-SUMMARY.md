---
phase: 06-import-export
plan: 01
subsystem: api
tags: [swift, codable, json, yaml, markdown, export, clipboard, nsopenpanel, nssavepanel]

# Dependency graph
requires:
  - phase: 05-pro-features-versioning-analytics-smart-collections
    provides: qualityScore, lastUsedAt, variantB, editingModeRaw, blockCompositionData fields on Prompt model

provides:
  - v2 PromptExportRecord DTO with all metadata fields as optionals
  - PromptExportBundle with collectionName optional
  - MarkdownFrontmatterParser (serialize, parse, parsePlain, slugify)
  - MarkdownImportRecord struct for import pipeline
  - ExportService.buildRecord(from:) helper
  - ExportService.exportLibraryJSON(prompts:collectionName:)
  - ExportService.exportMarkdown(prompts:)
  - ExportService.copyAsMarkdown(prompt:)
  - 16 unit tests (MarkdownFrontmatterParserTests + ExportServiceTests)

affects: [06-import-export plan 02 (import pipeline reuses DTOs and MarkdownFrontmatterParser)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "v2 optional fields on Codable DTOs allow v1 JSON to decode cleanly (nil optionals)"
    - "MarkdownFrontmatterParser is a pure enum (no instances) with static methods for serialize/parse/slugify"
    - "YAML string values always double-quoted to handle colons, brackets, hashes (RESEARCH pitfall 1)"
    - "exportAll delegates to exportLibraryJSON for backward compat while producing v2 bundles"
    - "NSOpenPanel (canChooseDirectories=true, canChooseFiles=false) for folder picker per RESEARCH pitfall 2"
    - "buildRecord(from:) centralizes prompt-to-DTO mapping for all export paths"

key-files:
  created:
    - Pault/MarkdownFrontmatterParser.swift
    - PaultTests/MarkdownFrontmatterParserTests.swift
    - PaultTests/ExportServiceTests.swift
  modified:
    - Pault/ExportService.swift

key-decisions:
  - "MarkdownImportRecord uses optional Date? for createdAt/updatedAt since plain Markdown has no date metadata"
  - "slugify uses Unicode scalar comparison instead of CharacterSet for precise alphanumeric filtering"
  - "exportAll backward compat: delegates to exportLibraryJSON(collectionName: nil) — callers unchanged"
  - "attachmentFileNames is nil (not empty array) when prompt has no attachments, to avoid polluting v2 JSON with empty arrays"

patterns-established:
  - "TDD pattern: write failing tests first, then implement to make green"
  - "YAML inline array format for tags: [\"tag1\", \"tag2\"] — always quoted elements"
  - "YAML block sequence for variables with name: + default: sub-keys"
  - "ISO8601 with .withInternetDateTime for date serialization (includes timezone)"

requirements-completed: [R9.1]

# Metrics
duration: 6min
completed: 2026-04-09
---

# Phase 6 Plan 01: Export Layer Summary

**v2 JSON/Markdown export system with YAML frontmatter parser: PromptExportRecord v2 DTOs, MarkdownFrontmatterParser (serialize/parse/slugify), exportLibraryJSON, exportMarkdown (folder picker), copyAsMarkdown (clipboard), 16 tests green**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-09T16:12:57Z
- **Completed:** 2026-04-09T16:18:43Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- MarkdownFrontmatterParser: YAML frontmatter serializer and parser with full round-trip fidelity, plain Markdown fallback, colon-in-title handling, slug collision dedup
- PromptExportRecord v2: 6 new optional fields (blockCompositionData, qualityScore, lastUsedAt, editingModeRaw, variantB, attachmentFileNames) — v1 JSON decodes cleanly with nil optionals
- ExportService: buildRecord helper + exportLibraryJSON + exportMarkdown (folder picker) + copyAsMarkdown (clipboard) + backward-compat exportAll
- 16 unit tests all green; pre-existing ProStatusManager/RunTabView failures confirmed not caused by this plan

## Task Commits

Each task was committed atomically:

1. **Task 1: v2 DTOs, MarkdownFrontmatterParser, and unit tests** - `c1513c0` (feat)
2. **Task 2: Extend ExportService with v2 JSON export, Markdown export, and Copy as Markdown** - `faf42c0` (feat)

_Note: Task 1 used TDD (tests written first, then implementation to pass)_

## Files Created/Modified
- `Pault/MarkdownFrontmatterParser.swift` - YAML frontmatter serializer/parser, slugify, MarkdownImportRecord
- `Pault/ExportService.swift` - v2 DTOs, buildRecord, exportLibraryJSON, exportMarkdown, copyAsMarkdown
- `PaultTests/MarkdownFrontmatterParserTests.swift` - 10 tests: round-trip, plain MD, colon edge case, slugify
- `PaultTests/ExportServiceTests.swift` - 6 tests: v2 encode/decode, v1 backward compat, collectionName, slugify

## Decisions Made
- `MarkdownImportRecord` uses `Date?` (not `Double`) for dates since plain Markdown has no date metadata — clean nil sentinel
- `slugify` uses Unicode scalar value comparison (97-122 for a-z, 48-57 for 0-9) instead of CharacterSet for explicit control
- `exportAll` backward compat: now delegates to `exportLibraryJSON(collectionName: nil)` — produces v2 bundles, call site unchanged
- `attachmentFileNames` is nil (not `[]`) when a prompt has no attachments, avoiding empty array noise in v2 JSON

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed optional Date type mismatch in test**
- **Found during:** Task 1 (compile error in MarkdownFrontmatterParserTests)
- **Issue:** Test used `.timeIntervalSince1970` directly on `Date?` — Swift requires unwrapping
- **Fix:** Used `XCTUnwrap` to unwrap optional dates before comparison
- **Files modified:** PaultTests/MarkdownFrontmatterParserTests.swift
- **Verification:** Tests compiled and all 16 passed
- **Committed in:** c1513c0 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in test code)
**Impact on plan:** Trivial compile fix. No scope creep.

## Issues Encountered
- Pre-existing test failures in ProStatusManagerTests (3 StoreKit tests) and RunTabViewTests — confirmed pre-existing by running same tests against previous commit (git stash). Not caused by this plan.

## Next Phase Readiness
- All DTOs and MarkdownFrontmatterParser ready for Plan 02 import pipeline
- `MarkdownImportRecord` is the bridge type Plan 02 will use to create Prompt objects from parsed Markdown
- `PromptExportBundle` v2 decode path handles both v1 and v2 JSON for import

---
*Phase: 06-import-export*
*Completed: 2026-04-09*
