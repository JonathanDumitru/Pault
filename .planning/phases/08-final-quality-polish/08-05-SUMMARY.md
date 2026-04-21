---
phase: 08-final-quality-polish
plan: 05
subsystem: ui
tags: [accessibility, reduce-motion, swiftui, animation]

# Dependency graph
requires:
  - phase: 08-final-quality-polish
    provides: "08-04 established reduceMotion ? nil : animation pattern across animated views and modifiers"
provides:
  - "Complete Reduce Motion compliance — all withAnimation and .animation() call sites guarded"
  - "R8.4 UX Consistency Pass fully satisfied"
affects:
  - app-store-submission
  - 08-final-quality-polish

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "reduceMotion ? nil : animation — universal guard pattern for all withAnimation calls"
    - "View-layer .animation(reduceMotion ? nil : ..., value:) for @Published state changes from ObservableObject managers"
    - "expandCollapseAnimation computed property: Animation? returns reduceMotion ? nil : .easeInOut(duration: 0.2)"

key-files:
  created: []
  modified:
    - Pault/BlockEditor/Views/BlockEditorView.swift
    - Pault/Services/AutoCollapseManager.swift
    - Pault/MenuBarContentView.swift

key-decisions:
  - "[Phase 08-05]: AutoCollapseManager.enterWarningPhase() removes withAnimation wrapper — ObservableObject classes cannot access @Environment; view-layer AutoCollapseWarningModifier already applies .animation(reduceMotion ? nil : ..., value: isInWarningPhase)"
  - "[Phase 08-05]: MenuBarContentView adds @Environment(\.accessibilityReduceMotion) after @State properties — consistent placement with other views that declare reduceMotion"

patterns-established:
  - "ObservableObject managers must NOT call withAnimation — delegate all animation to view-layer modifiers that can read @Environment"

requirements-completed: [R8.4]

# Metrics
duration: 8min
completed: 2026-04-21
---

# Phase 08 Plan 05: Reduce Motion Gap Closure Summary

**Guarded the 3 remaining unguarded animation call sites (BlockEditorView.dismissOnboarding, AutoCollapseManager.enterWarningPhase, MenuBarContentView x2) completing full R8.4 Reduce Motion compliance**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-21T05:15:00Z
- **Completed:** 2026-04-21T05:22:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed BlockEditorView.dismissOnboarding() to use `reduceMotion ? nil : .easeIn(duration: 0.2)`
- Removed redundant withAnimation from AutoCollapseManager.enterWarningPhase() — view-layer AutoCollapseWarningModifier already handles the animation and reduce motion guard
- Added `@Environment(\.accessibilityReduceMotion)` to MenuBarContentView and guarded both animation call sites (expand/collapse row, copy toast)
- ReduceMotionUITests pass (1 test, 0 failures, 3.079s)
- Grep audit confirms all production withAnimation calls are guarded — no unguarded call sites remain

## Task Commits

Each task was committed atomically:

1. **Task 1: Guard remaining 3 Reduce Motion animation call sites** - `3ffc0c7` (fix)
2. **Task 2: Verify Reduce Motion coverage is now complete** - verification only, no code changes

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `Pault/BlockEditor/Views/BlockEditorView.swift` - dismissOnboarding() guards withAnimation with reduceMotion ? nil
- `Pault/Services/AutoCollapseManager.swift` - enterWarningPhase() simplified to direct state assignment (withAnimation removed)
- `Pault/MenuBarContentView.swift` - Added @Environment(\.accessibilityReduceMotion), both withAnimation calls guarded

## Decisions Made
- AutoCollapseManager.enterWarningPhase(): withAnimation removed entirely. The pattern is correct: ObservableObject classes cannot read @Environment values, so the view layer (AutoCollapseWarningModifier) must own the animation + guard. Direct state assignment (`isInWarningPhase = true`) lets the view modifier handle animation via its `.animation(reduceMotion ? nil : .easeInOut(...), value: manager.isInWarningPhase)`.
- Grep audit confirmed `withAnimation { showPanel = false }` at AutoCollapseManager.swift line 258 is in a `#Preview` block (non-production) and the `///` doc comment example — not a compliance gap.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None — all three fixes applied cleanly and the project compiled without errors.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- R8.4 Reduce Motion compliance is now complete and fully verified
- Phase 08 (final quality polish) is complete across all 5 plans
- App is ready for App Store submission: hardened runtime, sandbox, accessibility, animations all compliant

## Self-Check: PASSED

- Pault/BlockEditor/Views/BlockEditorView.swift: FOUND
- Pault/Services/AutoCollapseManager.swift: FOUND
- Pault/MenuBarContentView.swift: FOUND
- .planning/phases/08-final-quality-polish/08-05-SUMMARY.md: FOUND
- Commit 3ffc0c7: FOUND

---
*Phase: 08-final-quality-polish*
*Completed: 2026-04-21*
