# Phase 1: Compliance & Test Infrastructure - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate all hard blockers that would cause automatic App Store rejection (privacy manifest, entitlements), and establish the test infrastructure that all subsequent phases build on. No new features, no UI changes — purely compliance and test foundation.

</domain>

<decisions>
## Implementation Decisions

### Entitlement cleanup
- Remove `com.apple.security.temporary-exception.apple-events` entitlement entirely — the paste-to-frontmost-app feature was removed in build 2.5B and no CGEvent/NSAppleScript usage remains
- Remove the paste-action migration code at PaultApp.swift:140-143 — migration has been shipping long enough
- Remaining entitlements (sandbox, network.client, files.user-selected.read-write) are all justified and stay as-is

### Privacy manifest
- Create `PrivacyInfo.xcprivacy` for the Pault app target only (not Schemap)
- Declare two required-reason API categories:
  - UserDefaults (reason code CA92.1 — app-specific preferences)
  - File timestamp access (reason code C617.1 or DDA9.1 — ErrorLogger log rotation within app container)
- Researcher should verify current Apple reason codes before implementation (may have updated)
- Privacy nutrition labels: declare "Data Not Collected" for now — update in Phase 4 when AI proxy calls are added
- No telemetry, no analytics data leaves device

### Test container strategy
- Create a single `TestHelpers.swift` file with static factory functions:
  - `makeTestModelContainer()` → `ModelContainer` (lists all model types once)
  - `makeTestModelContext()` → `ModelContext` (convenience for most tests)
- Migrate all 13 test files that duplicate container setup to use the shared factory
- Audit and strip unnecessary SwiftData imports from pure logic tests (TagTests, KeychainServiceTests, DiffEngineTests, etc.)

### Test framework
- All new tests use Swift Testing (`@Test` macro, struct-based suites) — no XCTest
- Consistent with existing test pattern across the codebase

### Block editor test coverage
- Coverage approach: critical paths + gaps (not exhaustive, not minimal)
- Fix broken/bit-rotted tests first before writing new ones — run full suite as step one
- PromptStudioModel (34 tests): expand to cover all major state transitions
- BlockSuggestionEngine (4 tests): significantly expand to cover all heuristics — biggest gap
- SlashCommandState (13 tests): fill remaining gaps in filtering and selection
- Include one key integration test: block composition → compiled preview pipeline (establishes the pattern for Phase 2)
- Snapshot testing: research compatibility with Swift Testing @Test macro in Phase 1, but defer actual snapshot test implementation to Phase 2

### Claude's Discretion
- Exact privacy manifest XML structure and placement in Xcode project
- Which PromptStudioModel state transitions are "major" vs. negligible
- Test organization within TestHelpers.swift
- Whether to use `@Suite` grouping for related test cases

</decisions>

<specifics>
## Specific Ideas

- Fix broken tests first as baseline — "no point building new infrastructure on a broken foundation"
- Integration test should prove the compose → compile → preview pipeline end-to-end
- Pure logic tests should be fast and free of SwiftData overhead

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PromptStudioModelTests.swift` (571 lines, 34 tests): existing test structure to extend, uses `makeContext()` helper pattern
- `BlockSuggestionEngineTests.swift` (49 lines, 4 tests): minimal but establishes the testing pattern
- `SlashCommandStateTests.swift` (151 lines, 13 tests): moderate coverage, pattern to follow
- `ErrorLogger.swift` (Pault/BlockEditor/Services/): uses file timestamps that trigger privacy manifest requirement

### Established Patterns
- Swift Testing framework with `@Test` macro and struct-based test suites
- In-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)` for test isolation
- `@MainActor` annotation on test structs that touch SwiftData
- All SwiftData models listed explicitly in container creation: Prompt, TemplateVariable, Tag, Attachment, CopyEvent, PromptRun, PromptVersion

### Integration Points
- `Pault.entitlements`: direct edit to remove apple-events exception
- `PaultApp.swift`: remove paste migration code at lines 140-143
- `PrivacyInfo.xcprivacy`: new file added to Pault app target
- `PaultTests/`: all 13 test files with container setup need migration to shared helper

</code_context>

<deferred>
## Deferred Ideas

- Paste-to-frontmost-app via Accessibility API — would need accessibility entitlement, noted for potential future phase

</deferred>

---

*Phase: 01-compliance-test-infrastructure*
*Context gathered: 2026-03-14*
