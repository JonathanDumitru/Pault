---
phase: 05-pro-features-versioning-analytics-smart-collections
plan: 02
subsystem: analytics
tags: [analytics, swift-charts, swiftdata, pro-features]
dependency_graph:
  requires: [CopyEvent, PromptRun, AnalyticsService, PromptStatsView, PromptService]
  provides: [UsageEventType enum, dailyEvents, tokenTotals, promptIDsRunWith, AnalyticsView charts]
  affects: [AnalyticsView, PromptStatsView, PromptService, CopyEvent, AnalyticsService, PromptDiffView]
tech_stack:
  added: [Charts framework]
  patterns: [Swift Charts LineMark+AreaMark, Segmented Picker for date range, SwiftData FetchDescriptor for token aggregation]
key_files:
  created: []
  modified:
    - Pault/CopyEvent.swift
    - Pault/AnalyticsService.swift
    - Pault/AnalyticsView.swift
    - Pault/PromptStatsView.swift
    - Pault/PromptService.swift
    - Pault/PromptDiffView.swift
decisions:
  - formatTokenCount is a module-level func in PromptStatsView.swift (not private) so AnalyticsView can share it without duplication
  - drilldownPromptID: UUID? pattern used instead of drilldownPrompt: Prompt? to avoid Identifiable conformance conflict with SwiftData PersistentModel
  - PromptDiffView extended with Target enum (versionToCurrent / versionToVersion) to fix pre-existing compile error blocking build
metrics:
  duration: ~9 minutes
  completed_date: 2026-04-09
  tasks: 2
  files_modified: 6
requirements-completed: [R4.1, R4.2]
---

# Phase 5 Plan 02: Analytics Dashboard and Event Tracking Summary

Extended analytics event tracking to all prompt lifecycle events and built a visual analytics dashboard with Swift Charts line chart, date range filtering, and token consumption summaries.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend CopyEvent model and AnalyticsService | 2daaa74 | CopyEvent.swift, AnalyticsService.swift, PromptService.swift, PromptDiffView.swift |
| 2 | Build visual analytics dashboard | f116901 | AnalyticsView.swift, PromptStatsView.swift |

## What Was Built

### CopyEvent.swift
- Added `UsageEventType` enum with `.copy`, `.created`, `.edited`, `.deleted` raw string values
- Added `var eventType: String = "copy"` with backward-compatible default (existing rows stay as "copy")
- Added computed `var type: UsageEventType` accessor following the `editingModeRaw`/`editingMode` pattern
- Added `init(promptID:type:)` convenience initializer

### AnalyticsService.swift
- `recordEvent(_:for:)` — creates and inserts a CopyEvent with the given type
- `recordCopy(for:)` — thin wrapper that delegates to `recordEvent(.copy, ...)`, preserving existing call sites
- `dailyEvents(days:)` — aggregates all event types by day for the last N days, fills zero-count days for chart continuity
- `tokenTotals(days:)` — sums input/output tokens from PromptRun records over the date range, sets `hasPartialData` if any runs had nil tokens
- `promptIDsRunWith(model:)` — returns Set<UUID> of prompt IDs run with a specific model (for Plan 05-03 smart collections)

### PromptService.swift
- `createPrompt` wired: records `.created` event after insertion
- `deletePrompt` wired: records `.deleted` event before model deletion (captures promptID while still valid)
- `saveSnapshot` wired: records `.edited` event whenever a version snapshot is saved

### AnalyticsView.swift (rebuilt)
- `import Charts` + `LineMark` + `AreaMark` (0.1 opacity blue fill) with `.catmullRom` interpolation
- Segmented `Picker` with 7/30/90 day options driving chart and token summary
- X axis: adaptive stride (1d for 7d, 5d for 30d, 14d for 90d) with `.dateTime.month().day()` format
- Token summary row: input/output with K formatting and `~` prefix when partial data
- Ranked prompt list with chevron drill-down to `PromptStatsView` sheet
- Pro-gated via `ProFeature.isUnlocked(.analytics)` (existing pattern)

### PromptStatsView.swift
- Added token breakdown section (Input Tokens / Output Tokens) using `formatTokenCount` helper
- Shows only when at least one run exists for the prompt
- Applies `~` prefix when any run had nil token counts
- `formatTokenCount(_:)` extracted as module-level function (shared with AnalyticsView)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed PromptDiffView to support Target enum for V2V comparison**
- **Found during:** Task 1 build verification
- **Issue:** `PromptVersionHistoryView.swift` called `PromptDiffView(target: .versionToVersion(...), prompt:)` but `PromptDiffView` only had `init(version:prompt:)` — pre-existing compile error blocking build
- **Fix:** Added `Target` enum with `.versionToCurrent` and `.versionToVersion` cases; added convenience `init(target:prompt:)` and `init(version:prompt:)` wrappers; restored buttons hidden/adapted for V2V mode; `onAppear` diffs against `newContent` (current prompt for V2C, newer version content for V2V)
- **Files modified:** `PromptDiffView.swift`
- **Commit:** 2daaa74

**2. [Rule 1 - Bug] Removed duplicate Identifiable conformance for Prompt**
- **Found during:** Task 2 build verification
- **Issue:** `extension Prompt: Identifiable {}` caused "type does not conform to PersistentModel" — SwiftData `@Model` types already have `PersistentModel` conformance which handles `Identifiable`
- **Fix:** Replaced `@State private var drilldownPrompt: Prompt?` with `@State private var drilldownPromptID: UUID?` and used `Binding<Bool>` sheet presentation
- **Files modified:** `AnalyticsView.swift`
- **Commit:** f116901

## Verification

- Build: `xcodebuild build -scheme Pault` -> BUILD SUCCEEDED
- Tests: `xcodebuild test -scheme Pault -only-testing:PaultTests/AnalyticsServiceTests` -> TEST SUCCEEDED (4/4 tests)
- CopyEvent backward compatible: existing rows without eventType default to "copy" via `var eventType: String = "copy"`

## Key Decisions

- `formatTokenCount` is a module-level (internal) function in `PromptStatsView.swift` so `AnalyticsView` can reference it without duplication
- `drilldownPromptID: UUID?` pattern used instead of `drilldownPrompt: Prompt?` to avoid Identifiable conformance conflict with SwiftData PersistentModel
- `PromptDiffView.Target` enum added to support both V2C and V2V comparison modes cleanly

## Self-Check: PASSED

All created/modified files exist on disk. Both task commits (2daaa74, f116901) verified in git history. Build and analytics tests pass.
