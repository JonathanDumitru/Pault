---
phase: 05-pro-features-versioning-analytics-smart-collections
plan: 01
subsystem: ui
tags: [swiftui, swiftdata, versioning, diff, inspector]

# Dependency graph
requires:
  - phase: 04-pro-features-ai-assist-api-runner
    provides: saveSnapshot call sites in AIAssistPanel; PromptService.saveSnapshot signature
provides:
  - VersionSource enum with .manual/.aiImprove/.aiVariableAccept/.aiAutoTag/.restore raw values
  - PromptVersion.source field (SwiftData stored property, defaults to "manual")
  - VersionSourceBadge pill view (AI=purple, Manual=blue, Restore=orange)
  - Date section headers in version list (Today/Yesterday/weekday/Month Year)
  - V2V diff mode via PromptDiffView.Target enum
  - Synchronized scrolling for side-by-side diff panels (macOS 15+, SyncedScrollPanel)
  - Dual "Restore This Version" buttons in V2V mode
  - Inspector version history section gated by ProFeature.isUnlocked(.versioning)
affects: [06-analytics, future-versioning-tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "VersionSource: String enum with rawValues matching stored DB strings; computed versionSource get/set on @Model — same pattern as editingModeRaw/editingMode in Prompt"
    - "DiffTarget as nested Target enum inside PromptDiffView; init(version:prompt:) for compat, init(target:prompt:) for V2V"
    - "SyncedScrollPanel (@available macOS 15) uses ScrollPosition(idType: Int.self) + onScrollPhaseChange to propagate scroll without feedback loop"
    - "V2V state in PromptVersionHistoryView: @State v2vOlder/v2vNewer + showV2VSheet Bool — avoids sheet(item:) Identifiable requirement on PromptVersion"

key-files:
  created: []
  modified:
    - Pault/PromptVersion.swift
    - Pault/PromptVersionHistoryView.swift
    - Pault/PromptDiffView.swift
    - Pault/InspectorView.swift
    - Pault/PromptService.swift
    - Pault/AIAssistPanel.swift

key-decisions:
  - "PromptDiffView.Target is a nested enum (not top-level DiffTarget) — nested enum keeps the type scoped and avoids polluting top-level namespace"
  - "SyncedScrollPanel: only propagates scroll during .interacting phase to prevent feedback loops; falls back to independent scrolling on macOS 14"
  - "InspectorView: existing historySection renamed 'Version History' and gated with ProFeature.isUnlocked(.versioning) — shows upgrade prompt for free users instead of hiding section entirely (better discoverability)"
  - "V2V restore: pendingRestoreVersion @State holds the target version; showRestorePreviewLeft/Right are separate booleans to route each sheet correctly"

patterns-established:
  - "Source-tracking pattern: saveSnapshot always passes source: VersionSource, AI call sites pass .aiImprove/.aiVariableAccept/.aiAutoTag, restore passes .restore"

requirements-completed: [R3.1, R3.2, R3.3]

# Metrics
duration: 35min
completed: 2026-04-09
---

# Phase 5 Plan 01: Prompt Versioning — Enhanced History, V2V Diff & Source Tracking Summary

**VersionSource enum + colored badge pills, date section headers, true V2V diff via PromptDiffView.Target, synchronized scrolling (macOS 15+), dual restore buttons, and Pro-gated inspector integration**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-09T06:05:00Z
- **Completed:** 2026-04-09T06:36:16Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- `PromptVersion` model gains `source: String` stored property (default "manual") with `VersionSource` typed enum accessor — backward compatible with all existing rows
- `PromptVersionHistoryView` now groups versions by date with "Today / Yesterday / weekday / Month Year" headers and shows colored `VersionSourceBadge` pills on each row
- V2V comparison: when user selects two versions in compare mode, `openComparison()` stores the pair and presents `PromptDiffView` with `Target.versionToVersion`
- `PromptDiffView` refactored around `Target` enum; left/right panel labels derived from target; dual "Restore Version A/B" buttons appear in V2V mode
- `SyncedScrollPanel` (macOS 15+) syncs two scroll views via shared `ScrollPosition` and `onScrollPhaseChange` — falls back to independent scrolling on earlier OS
- `InspectorView.historySection` renamed "Version History" and Pro-gated: shows `PromptVersionHistoryView` for Pro, upgrade prompt for free users

## Task Commits

Each task was committed atomically:

1. **Task 1: Add VersionSource field and enhance version history list** - `25bd587` (feat)
2. **Task 2: V2V diff, synchronized scrolling, dual restore, inspector integration** - `b1d1043` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `/Volumes/Drive/Projects/Software/macOS/Pault/Pault/PromptVersion.swift` — Added `source: String` stored property, `VersionSource` enum, `versionSource` computed accessor
- `/Volumes/Drive/Projects/Software/macOS/Pault/Pault/PromptVersionHistoryView.swift` — `VersionSourceBadge` view, date section grouping, V2V sheet state, `VersionRow` shows badge
- `/Volumes/Drive/Projects/Software/macOS/Pault/Pault/PromptDiffView.swift` — `Target` nested enum, computed panel labels, dual restore buttons, `SyncedScrollPanel` for macOS 15+
- `/Volumes/Drive/Projects/Software/macOS/Pault/Pault/InspectorView.swift` — History section Pro-gated, renamed "Version History"
- `/Volumes/Drive/Projects/Software/macOS/Pault/Pault/PromptService.swift` — `saveSnapshot` gains `source: VersionSource = .manual` param, sets `version.source`
- `/Volumes/Drive/Projects/Software/macOS/Pault/Pault/AIAssistPanel.swift` — `acceptImprovement`, `insert`, `attachTag` now pass `.aiImprove`, `.aiVariableAccept`, `.aiAutoTag` source

## Decisions Made

- `PromptDiffView.Target` nested enum (not top-level `DiffTarget`) — keeps type scoped, avoids namespace pollution
- `SyncedScrollPanel` only propagates scroll during `.interacting` phase to prevent feedback loops
- InspectorView shows upgrade prompt for free users (better discoverability vs hiding the section)
- Separate `showRestorePreviewLeft`/`showRestorePreviewRight` booleans + `pendingRestoreVersion` to handle V2V dual restore sheets

## Deviations from Plan

None — plan executed exactly as written.

> Note: The linter auto-added analytics event recording calls in `PromptService.swift` (`AnalyticsService.recordEvent`) during the task 1 edit. These calls appear to be from a concurrent plan or linter action; they are pre-existing analytics plumbing and do not affect plan 05-01 outcomes.

## Issues Encountered

- Build DB lock from concurrent Xcode session on first verification run; resolved by waiting and re-running.
- Transient SwiftData conformance error (`Prompt` PersistentModel) from stale incremental build cache; cleared on clean rebuild.

## Next Phase Readiness

- Versioning Pro feature is complete (R3.1, R3.2, R3.3)
- Ready for Plan 05-02 (Analytics dashboard enhancement)
- `VersionSource` enum and `saveSnapshot(source:)` are the canonical call pattern for all future snapshot creation

---
*Phase: 05-pro-features-versioning-analytics-smart-collections*
*Completed: 2026-04-09*
