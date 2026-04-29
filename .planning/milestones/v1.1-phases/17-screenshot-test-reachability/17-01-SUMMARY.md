---
phase: 17-screenshot-test-reachability
plan: 01
subsystem: testing
tags: [xcuitest, accessibility, swiftui, screenshot-mode, prostatusmanager]
gap_closure: true

# Dependency graph
requires:
  - phase: 16-testing-verification
    provides: ScreenshotTests targeting app.buttons["Analytics"] and app.groups["analytics-view"]
  - phase: 15-ux-polish
    provides: ProStatusManager.refreshStatus() --screenshot-mode override (async path)
provides:
  - Synchronous Pro unlock in ProStatusManager.init() before any view body runs
  - XCUI-reachable Analytics toolbar button via .accessibilityLabel("Analytics")
  - Correctly-scoped analytics-view accessibility identifier (inside NavigationStack render tree)
  - Working end-to-end testShot06_AnalyticsDashboard producing a verified screenshot
affects: [future screenshot tests, App Store marketing assets, accessibility audits, CI screenshot capture]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AX identifiers must live inside the rendered view subtree (inside NavigationStack), not on the outer container view"
    - "DEBUG-gated launch-arg overrides applied synchronously in init() to eliminate first-render races for @Observable state"
    - ".accessibilityLabel matches XCUI button query strings; .help is tooltip-only and not XCUI-visible"

key-files:
  created: []
  modified:
    - Pault/ContentView.swift
    - Pault/Services/ProStatusManager.swift
    - Pault/AnalyticsView.swift

key-decisions:
  - "Use .accessibilityLabel(\"Analytics\") instead of .accessibilityIdentifier(...) so app.buttons[\"Analytics\"] resolves with no test-side change"
  - "Apply synchronous --screenshot-mode override in init() before scheduling async refreshStatus to eliminate first-render race"
  - "Keep #if DEBUG guard on the new init() override to mirror the precedent at refreshStatus():65-70 and prevent release-build exposure"
  - "Move .accessibilityIdentifier(\"analytics-view\") into the inner Group inside NavigationStack so XCUI query app.groups[\"analytics-view\"] resolves (Rule-3 deviation discovered during Task 4)"

patterns-established:
  - "AX identifier placement: identifiers placed on a view that is conditionally rendered or sits outside the active navigation hierarchy will not surface to XCUITest. Place them inside the rendered subtree."
  - "Screenshot-mode init pattern: ProcessInfo arguments override pattern in init() (sync) + refreshStatus() (async), both DEBUG-guarded, ensures both first paint and refresh paths show Pro UI."

requirements-completed: [TEST-01, UX-03]

# Metrics
duration: ~25min
completed: 2026-04-29
---

# Phase 17 Plan 01: Screenshot Test Reachability Summary

**Closed two integration gaps from the v1.1 audit: Analytics toolbar Button is now XCUI-reachable via `app.buttons["Analytics"]`, and ProStatusManager applies `--screenshot-mode` synchronously in `init()` so Pro UI is visible on first paint — `testShot06_AnalyticsDashboard` now runs to completion and captures a verified Analytics screenshot.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-29 (plan execution)
- **Completed:** 2026-04-29
- **Tasks:** 5 (1 deviation sub-task)
- **Files modified:** 3

## Accomplishments

- TEST-01 gap closed — `testShot06_AnalyticsDashboard` reaches the Analytics view and produces screenshot 06 (verified end-to-end and visually approved)
- UX-03 gap closed — Pro UI is visible on the very first SwiftUI render in screenshot mode (no first-frame race against async refresh)
- Discovered and fixed a third reachability gap (`analytics-view` AX identifier placed outside NavigationStack subtree) via Rule-3 deviation
- Documented the macOS Stage Manager / XCUITest incompatibility for future CI/local screenshot runs

## Task Commits

Each task was committed atomically:

1. **Task 1: Add `.accessibilityLabel("Analytics")` to Analytics toolbar Button** — `be0a518` (feat)
2. **Task 2: Synchronous `--screenshot-mode` override in `ProStatusManager.init()`** — `fedffee` (feat)
3. **Task 3: Build Pault scheme and confirm clean compile** — verification-only (no commit)
4. **Task 4a (Rule-3 deviation): Move `analytics-view` AX identifier into rendered Group** — `94d6966` (fix)
5. **Task 4: Run `testShot06_AnalyticsDashboard` end-to-end** — verification-only (test pass + screenshot at `/tmp/06-analytics-dashboard-final.png`)
6. **Task 5: Visual sign-off** — approved by user

**Plan metadata:** This SUMMARY commit (docs(17-01))

## Files Created/Modified

- `Pault/ContentView.swift` — Added `.accessibilityLabel("Analytics")` (line 354) to the Analytics toolbar Button so `app.buttons["Analytics"]` resolves in XCUITest.
- `Pault/Services/ProStatusManager.swift` — Added DEBUG-guarded synchronous `--screenshot-mode` override inside `init()` before scheduling `Task { await refreshStatus() }`, so `isProUnlocked = true` on the very first SwiftUI render in screenshot mode.
- `Pault/AnalyticsView.swift` — Moved `.accessibilityIdentifier("analytics-view")` (line 64) from the outer view (above NavigationStack) into the inner rendered Group so `app.groups["analytics-view"]` resolves in the XCUI hierarchy. (Rule-3 deviation — discovered during Task 4 verification.)

## Verification

- **Build:** `xcodebuild ... build` completed with `** BUILD SUCCEEDED **` after all three edits.
- **End-to-end test:** `xcodebuild test -only-testing:PaultUITests/ScreenshotTests/testShot06_AnalyticsDashboard` exited 0; `Test Case '-[PaultUITests.ScreenshotTests testShot06_AnalyticsDashboard]' passed`. The hard assertion at `ScreenshotTests.swift:317` (`XCTAssertTrue(analyticsView.waitForExistence(timeout: 5))`) succeeded — the Analytics sheet opened, the AX hierarchy resolved, and `captureScreenshot(name: "06-analytics-dashboard")` ran.
- **Screenshot artifact:** `/tmp/06-analytics-dashboard-final.png` captured.
- **Visual sign-off:** User approved the screenshot — Analytics view content is visible (charts/copy event metrics) over the ContentView, Pro features are unlocked, no paywall or empty state.

### Phase-Level Verification

1. TEST-01 closed — `grep -n '\.accessibilityLabel("Analytics")' Pault/ContentView.swift` returns one match on the Analytics toolbar Button.
2. UX-03 closed — `grep -c '\-\-screenshot-mode' Pault/Services/ProStatusManager.swift` returns 2 (init + refreshStatus); inspection confirms init() override is BEFORE the async Task and inside `#if DEBUG`.
3. End-to-end test passed (xcodebuild test exit 0).
4. Screenshot 06 produced and visually verified.

## Decisions Made

See key-decisions in frontmatter. Highlights:

- `.accessibilityLabel` (not `.accessibilityIdentifier`) on the toolbar Button — matches the XCUI query `app.buttons["Analytics"]` string-for-string with zero test-side change.
- Synchronous override placed BEFORE async `Task { await refreshStatus() }` — ensures Pro UI is visible on the first render frame, eliminating the @Observable first-frame race.
- `analytics-view` identifier moved INSIDE the rendered Group (inside NavigationStack) — outer placement was structurally invisible to XCUITest. Future SwiftUI sheet-based AX identifiers should follow the same rule.

## Deviations from Plan

The plan listed `files_modified: [Pault/ContentView.swift, Pault/Services/ProStatusManager.swift]`. Actual scope expanded to 3 files; one Rule-3 (blocking) deviation was applied automatically.

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Move `analytics-view` AX identifier into rendered Group inside NavigationStack**

- **Found during:** Task 4 (running `testShot06_AnalyticsDashboard` end-to-end)
- **Issue:** After Task 1 + Task 2 landed, the test still failed at `XCTAssertTrue(analyticsView.waitForExistence(timeout: 5))` — `app.groups["analytics-view"]` did not resolve. The `.accessibilityIdentifier("analytics-view")` modifier was attached to the outer view at `Pault/AnalyticsView.swift:74`, OUTSIDE the `NavigationStack` subtree. SwiftUI did not surface that identifier into the XCUITest accessibility hierarchy.
- **Fix:** Moved the `.accessibilityIdentifier("analytics-view")` modifier into the inner rendered Group inside NavigationStack at line 64. One-line move, no logic change.
- **Files modified:** `Pault/AnalyticsView.swift` (1 line moved)
- **Verification:** Test re-run reached `analyticsView.waitForExistence` true and progressed to `captureScreenshot`; screenshot rendered correctly.
- **Committed in:** `94d6966` (fix(17-01): move analytics-view AX identifier into rendered Group)

---

**Total deviations:** 1 auto-fixed (1 blocking — Rule 3).
**Impact on plan:** Necessary for plan success criterion #3 (test runs to completion). The deviation surfaces a generalizable pattern (AX identifier placement) now captured under patterns-established. No scope creep beyond the gap closure mandate.

## Issues Encountered

### Known Constraints (operational)

**macOS Stage Manager interferes with XCUITest window discovery.** During Task 4 attempts, XCUITest could not consistently discover the launched app's window when Stage Manager was enabled — windows were grouped under Stage Manager's strip rather than registered as a top-level window for XCUI to query. Stage Manager must be **disabled** during screenshot test runs (locally and in CI). This is a macOS XCUITest limitation, not a fix-by-code item.

Recommended action for any future invocation of the screenshot test suite:

1. System Settings → Desktop & Dock → Stage Manager → Off.
2. Run `xcodebuild test -only-testing:PaultUITests/ScreenshotTests/...`.
3. Optionally re-enable Stage Manager after the test session.

This constraint is environmental — there is no code-side workaround in XCUITest as of macOS 25.4.

## User Setup Required

None — no external service configuration required. (Operational note about Stage Manager above is documented for future test runs but not a setup step.)

## Next Phase Readiness

- Phase 17 goal met: TEST-01 and UX-03 transition from "partial/gap" to "satisfied". The v1.1 audit gap closure is complete.
- v1.1 milestone: with Phase 17 done, all v1.1 requirements are accounted for and screenshot infrastructure is operational end-to-end.
- Future screenshot tests can now rely on the established patterns: `.accessibilityLabel` for toolbar buttons, AX identifiers placed inside the rendered subtree, and synchronous DEBUG init overrides for `@Observable` state.

---
*Phase: 17-screenshot-test-reachability*
*Completed: 2026-04-29*

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: `Pault/ContentView.swift` — `.accessibilityLabel("Analytics")` at line 354
- FOUND: `Pault/Services/ProStatusManager.swift` — 2 occurrences of `--screenshot-mode` (init + refreshStatus)
- FOUND: `Pault/AnalyticsView.swift` — `.accessibilityIdentifier("analytics-view")` at line 64 (inside rendered Group within NavigationStack)

**Commits verified in git log:**
- FOUND: `be0a518` — feat(17-01): add accessibilityLabel to Analytics toolbar button
- FOUND: `fedffee` — feat(17-01): synchronous --screenshot-mode override in ProStatusManager.init()
- FOUND: `94d6966` — fix(17-01): move analytics-view AX identifier into rendered Group

**Verification artifacts confirmed:**
- Task 4 ran `testShot06_AnalyticsDashboard` end-to-end (xcodebuild test exit 0; test reported as passed).
- Screenshot captured at `/tmp/06-analytics-dashboard-final.png`.
- Task 5 visual sign-off: user approved (Analytics view content visible, Pro features unlocked, no paywall/empty state).
