---
name: Phase 17 Context — Screenshot Test Reachability
description: Locked decisions for closing TEST-01 and UX-03 integration gaps from v1.1 audit
type: project
phase: 17
gathered: 2026-04-29
source: PRD Express Path (.planning/v1.1-MILESTONE-AUDIT.md)
---

# Phase 17: Screenshot Test Reachability — Context

**Gathered:** 2026-04-29
**Status:** Ready for planning
**Source:** Audit-as-PRD path (`.planning/v1.1-MILESTONE-AUDIT.md`)

<domain>
## Phase Boundary

Closes the two integration gaps surfaced by the v1.1 milestone audit so that `testShot06_AnalyticsDashboard` runs to completion and `ProStatusManager` applies the screenshot-mode override on the first synchronous render.

**In scope:**
- Make the Analytics toolbar button in `Pault/ContentView.swift` reachable by XCUI via `app.buttons["Analytics"]`.
- Make `ProStatusManager.init()` synchronously honor `--screenshot-mode` before scheduling the async `refreshStatus()` Task.
- Verify the existing `testShot06_AnalyticsDashboard` test produces screenshot 06 end-to-end.

**Out of scope:**
- Replacing the 5 fixed-duration `Thread.sleep` calls in `ScreenshotTests.swift` (tracked as tech debt, not a v1.1 closure item).
- Removing the legacy single-arg `CopyEvent` init (tech debt only).
- Wiring tests for the orphan `menu-bar-content` accessibility identifier (tech debt only).
- Nyquist retrofit for Phases 14/15/16 (audit notes this is acknowledged out-of-scope per REQUIREMENTS.md:48).

</domain>

<decisions>
## Implementation Decisions

### Locked decisions (from audit)

**Analytics toolbar accessibility (TEST-01)**
- Fix the toolbar button at `Pault/ContentView.swift:347-354`.
- Use `.accessibilityLabel("Analytics")` so the existing test query `app.buttons["Analytics"]` at `ScreenshotTests.swift:304` resolves with no test-side change.
- Rationale: minimum-diff fix that keeps the human-readable string contract on the production side, matching the same pattern other accessibility identifiers use across the codebase (Phase 16 added `analytics-view` on the sheet content; this completes the chain).

**ProStatusManager screenshot-mode race (UX-03)**
- In `Pault/Services/ProStatusManager.swift:24-29`, synchronously set `isProUnlocked = true` inside `init()` when `ProcessInfo.processInfo.arguments.contains("--screenshot-mode")` is true, **before** scheduling `Task { await refreshStatus() }`.
- Keep the existing async `refreshStatus()` flow untouched — the new code is additive and runs only under the `--screenshot-mode` flag. Wrap in `#if DEBUG` to mirror the existing override in `refreshStatus()` and prevent the override path from shipping in Release builds.
- Rationale: eliminates the initial-render race so every frame in screenshot mode shows Pro UI. Mirrors the existing DEBUG-gated override at `refreshStatus()` lines 65-70 for consistency.

**Verification of testShot06 (Success Criterion 3)**
- Run the existing `testShot06_AnalyticsDashboard` UI test against the fixed app and confirm it completes without hard-failing the `analyticsView.waitForExistence(timeout: 5)` assertion at `ScreenshotTests.swift:317`.
- Confirm screenshot 06 is produced in the test output (existing test infrastructure handles capture).

### Claude's Discretion

- Naming/placement of the `.accessibilityLabel("Analytics")` modifier within the existing modifier chain (after `.buttonStyle(.plain)`, before/after `.help`).
- Whether to retain or remove the redundant fallback at `ScreenshotTests.swift:307` (`app.outlines.cells.staticTexts["Analytics"]`). Default: keep it — it's defensive and harmless once the primary query works.
- Exact phrasing of any inline comment explaining the synchronous override (default per CLAUDE.md: no comment unless WHY is non-obvious).

</decisions>

<specifics>
## Specific Ideas

### Files modified
1. `Pault/ContentView.swift` — toolbar button accessibility label
2. `Pault/Services/ProStatusManager.swift` — synchronous init override

### Reference patterns in codebase
- Existing `--screenshot-mode` override pattern: `ProStatusManager.swift:65-70` (inside `refreshStatus()`, gated by `#if DEBUG`).
- Existing accessibility identifier pattern: Phase 16 added `.accessibilityIdentifier("analytics-view")` to `AnalyticsView`. Phase 17 closes the matching upstream selector on the toolbar button.
- Existing test query: `ScreenshotTests.swift:304` queries `app.buttons["Analytics"]` (label-based match, not identifier-based).

### Audit cross-references
- Gap 1 detail: `.planning/v1.1-MILESTONE-AUDIT.md` lines 116-123
- Gap 2 detail: `.planning/v1.1-MILESTONE-AUDIT.md` lines 125-138
- Integration check: `.planning/phases/v1.1-INTEGRATION-CHECK.md`

</specifics>

<deferred>
## Deferred Ideas

- Replacing `Thread.sleep` waits in `ScreenshotTests.swift` with `waitForExistence` (Phase 16 tech debt).
- Removing legacy single-arg `CopyEvent` init (Phase 14 tech debt).
- Tests exercising `menu-bar-content` accessibility identifier (Phase 16 tech debt).
- Nyquist validation retrofit for Phases 14/15/16 (out-of-scope per v1.1 milestone scope).

</deferred>

---

*Phase: 17-screenshot-test-reachability*
*Context gathered: 2026-04-29 via audit-as-PRD path*
