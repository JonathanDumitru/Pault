---
phase: 16-testing-verification
plan: 01
subsystem: testing
tags: [xcuitest, accessibility, swiftui, screenshot-tests]

requires:
  - phase: 15-ux-polish
    provides: Pro status override in screenshot mode (UX-03) required for correct screenshot test state

provides:
  - Real .accessibilityIdentifier modifiers in 5 production SwiftUI views
  - ScreenshotTests.swift with identifier-based element queries replacing best-guess patterns

affects: [screenshot-tests, accessibility-tree, app-store-submission]

tech-stack:
  added: []
  patterns:
    - "SwiftUI .accessibilityIdentifier() modifiers placed on outermost container of each screenshottable view"
    - "XCUI element queries use app.groups/buttons/scrollViews[identifier] with waitForExistence instead of immediate .exists checks"

key-files:
  created: []
  modified:
    - Pault/ContentView.swift
    - Pault/AIAssistPanel.swift
    - Pault/BlockEditor/Views/CompositionCanvasView.swift
    - Pault/AnalyticsView.swift
    - Pault/MenuBarContentView.swift
    - PaultUITests/ScreenshotTests.swift

key-decisions:
  - "Inline identifier strings rather than constants file — identifiers appear in exactly two places (production view + test)"
  - "block-canvas identifier placed on ScrollView modifier inside ScrollViewReader — matches app.scrollViews XCUI query type"
  - "analytics-view placed on NavigationStack container — AnalyticsView is presented as a sheet so groups[] is the correct XCUI type"
  - "Removed app.statusItems[pault-menu-bar-item] fallback entirely — API does not exist in XCUI for NSStatusItem-based menu bar extras"

patterns-established:
  - "Screenshottable views get .accessibilityIdentifier on their outermost or primary interactive container"
  - "XCUI element queries use waitForExistence(timeout:) never immediate .exists as a guard"

requirements-completed: [TEST-01]

duration: 3min
completed: 2026-04-28
---

# Phase 16 Plan 01: Accessibility Identifiers for Screenshot Tests Summary

**5 production SwiftUI views annotated with .accessibilityIdentifier and ScreenshotTests updated to use those real identifiers, eliminating all best-guess queries**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-28T03:42:55Z
- **Completed:** 2026-04-28T03:46:43Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added `.accessibilityIdentifier()` to sidebar-toggle (ContentView), ai-assist-panel (AIAssistPanel), block-canvas (CompositionCanvasView), analytics-view (AnalyticsView), and menu-bar-content (MenuBarContentView)
- Replaced ternary fallback in testShot01 with direct `waitForExistence` on `ai-assist-panel`
- Replaced `Thread.sleep` fallback chain in testShot02 with `XCTAssertTrue(blockCanvas.waitForExistence(...))`
- Simplified testShot04 sidebar toggle (removed unreliable `.isSelected` check)
- Removed non-existent `app.statusItems["pault-menu-bar-item"]` fallback from testShot05
- Added `analyticsView.waitForExistence` verification in testShot06
- Updated file-level NOTE from vague "adjust based on accessibility tree" to precise identifier documentation
- Removed all "best-guess" and "adjust based on actual accessibility tree" comments

## Task Commits

Each task was committed atomically:

1. **Task 1: Add accessibility identifiers to production SwiftUI views** - `dda891b` (feat)
2. **Task 2: Update ScreenshotTests to use real accessibility identifiers** - `0f3dc61` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `Pault/ContentView.swift` - Added `.accessibilityIdentifier("sidebar-toggle")` to toolbar sidebar toggle button
- `Pault/AIAssistPanel.swift` - Added `.accessibilityIdentifier("ai-assist-panel")` to root VStack
- `Pault/BlockEditor/Views/CompositionCanvasView.swift` - Added `.accessibilityIdentifier("block-canvas")` to blockList ScrollView
- `Pault/AnalyticsView.swift` - Added `.accessibilityIdentifier("analytics-view")` to NavigationStack container
- `Pault/MenuBarContentView.swift` - Added `.accessibilityIdentifier("menu-bar-content")` to root VStack
- `PaultUITests/ScreenshotTests.swift` - Updated 5 of 6 test methods + file-level comment; removed all best-guess patterns

## Decisions Made
- Inline identifier strings rather than a constants file — each string appears in exactly two places (production view + test), making a constants file unnecessary coupling
- `block-canvas` placed on the ScrollView modifier (inside `ScrollViewReader`) rather than the outer `ZStack` — ScrollView maps to `app.scrollViews` in XCUI which is the correct query path
- `analytics-view` placed on the `NavigationStack` container — AnalyticsView is presented as a sheet and its NavigationStack maps to `app.groups` in XCUI
- `app.statusItems["pault-menu-bar-item"]` fallback removed entirely — this XCUI API does not exist for `NSStatusItem`-based menu bar extras; `app.menuBars.buttons["Pault"]` is the correct query

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- TEST-01 complete: ScreenshotTests now use real accessibility identifiers
- TEST-02 and TEST-03 are human verification tasks (sign-off checklists, no code) — ready to proceed

---
*Phase: 16-testing-verification*
*Completed: 2026-04-28*
