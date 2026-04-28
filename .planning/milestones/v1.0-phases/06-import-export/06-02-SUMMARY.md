---
phase: 06-import-export
plan: 02
subsystem: ui
tags: [swiftdata, swiftui, import, export, drag-drop, share-sheet, conflict-resolution]

requires:
  - phase: 06-01
    provides: ExportService v2, MarkdownFrontmatterParser, PromptExportBundle/Record DTOs

provides:
  - ImportOrchestrator: JSON/Markdown parsing, UUID duplicate detection, skip/overwrite/keepBoth resolution
  - ImportPreviewSheet: SwiftUI sheet with per-prompt conflict pickers, expandable diff, Apply to All
  - File menu: Export Library as JSON, Export Library as Markdown, Import Prompts (Cmd+Opt+I)
  - Drag-drop: .json/.md files onto main window trigger import preview
  - Context menus: Export submenu on collections and prompts
  - Share button and Copy as Markdown on PromptDetailView toolbar
  - Export spinner overlay during export operations
  - Import result summary banner with auto-dismiss

affects: [all views using ContentView, SidebarView, PromptDetailView]

tech-stack:
  added: []
  patterns:
    - ImportSession + ImportCandidate model for preview-based conflict resolution
    - In-memory tag cache within import loop to avoid redundant SwiftData fetches
    - onDrop with UTType.fileURL + pathExtension filtering (per research pitfall 5)
    - Notification-based export/import triggering from File menu to ContentView

key-files:
  created:
    - Pault/ImportOrchestrator.swift
    - Pault/ImportPreviewSheet.swift
    - PaultTests/ImportOrchestratorTests.swift
  modified:
    - Pault/ExportService.swift
    - Pault/PaultApp.swift
    - Pault/ContentView.swift
    - Pault/SidebarView.swift
    - Pault/PromptDetailView.swift
    - Pault/PreferencesView.swift

key-decisions:
  - "ImportPreviewSheet uses Binding<ImportSession?> with item-based sheet — session identity drives presentation"
  - "ImportCandidateRow is private struct within ImportPreviewSheet file to avoid namespace pollution"
  - "DiffView renamed to ImportDiffView — avoided conflict with existing DiffView in RefinementLoopView.swift"
  - "PreferencesView Import button now posts .importPrompts notification — delegates to ContentView's preview flow"
  - "onDrop accepts UTType.fileURL and filters by pathExtension (research pitfall 5 applied)"
  - "Export spinner uses isExporting Bool state — NSSavePanel blocks main thread so spinner shows synchronously"
  - "Swift Testing @MainActor struct pattern used for ImportOrchestratorTests (consistent with existing test pattern)"
  - "Pault.Tag disambiguation required in test file (Tag is ambiguous with Foundation.Tag)"

patterns-established:
  - "Import preview: prepare() builds ImportSession, applyImport() executes resolutions — two-phase pattern"
  - "In-memory cache [String: Tag] in import loop for tag dedup without repeated FetchDescriptor queries"

requirements-completed: [R9.2, R9.3]

duration: 14min
completed: 2026-04-09
---

# Phase 06 Plan 02: Import System and UI Entry Points Summary

**Preview-based import with per-prompt skip/overwrite/keepBoth conflict resolution, File menu, drag-drop, share sheet, and context menus wired for complete data portability**

## Performance

- **Duration:** 14 min
- **Started:** 2026-04-09T16:22:10Z
- **Completed:** 2026-04-09T16:36:00Z
- **Tasks:** 3 of 3 (all tasks complete including human-verify checkpoint)
- **Files modified:** 8

## Accomplishments
- ImportOrchestrator parses JSON (v1+v2) and Markdown files, detects UUID duplicates, applies skip/overwrite/keepBoth per prompt
- Overwrite auto-snapshots with "Before import overwrite" note via PromptService.saveSnapshot
- keepBoth creates new Prompt with fresh UUID and " (Imported)" title suffix
- Auto-detects {{variables}} in content, merges with frontmatter-defined variables (frontmatter takes precedence)
- ImportPreviewSheet renders accessible SwiftUI sheet with per-row conflict pickers, expandable inline diff, Apply to All, and summary banner
- File menu wired: Export Library as JSON, Export Library as Markdown, Import Prompts (Cmd+Opt+I)
- Drag-drop of .json/.md files onto main window triggers import preview
- Collection and prompt context menus have Export submenu (As JSON / As Markdown)
- PromptDetailView has ShareLink button and Copy as Markdown toolbar button
- Export spinner overlay during export operations; import result banner auto-dismisses after 5 seconds
- PreferencesView Import button now uses new preview flow via notification

## Task Commits

1. **Task 1: ImportOrchestrator, ImportPreviewSheet, and tests (TDD)** - `74c27dd` (feat)
2. **Task 2: Wire UI entry points** - `2886657` (feat)
3. **Task 3: Human verify** - checkpoint approved (all 11 steps passed)

## Files Created/Modified
- `Pault/ImportOrchestrator.swift` - Import parsing, duplicate detection, conflict application
- `Pault/ImportPreviewSheet.swift` - SwiftUI import preview sheet with diff view
- `PaultTests/ImportOrchestratorTests.swift` - 9 tests covering all import scenarios
- `Pault/ExportService.swift` - resolveTag made internal for ImportOrchestrator reuse
- `Pault/PaultApp.swift` - Notification.Name extensions + File menu CommandGroup
- `Pault/ContentView.swift` - Import/export state, notification handlers, drag-drop, overlays
- `Pault/SidebarView.swift` - Export submenus on prompt and collection context menus
- `Pault/PromptDetailView.swift` - ShareLink button, Copy as Markdown button, Export context menu
- `Pault/PreferencesView.swift` - Import button now posts notification to use preview flow

## Decisions Made
- DiffView renamed to ImportDiffView to avoid conflict with existing DiffView in RefinementLoopView.swift
- Swift Testing `@MainActor struct` pattern used for tests (consistent with project pattern, not XCTestCase)
- `Pault.Tag` disambiguation required in test file
- onDrop accepts UTType.fileURL and filters by pathExtension per research pitfall 5

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DiffView name conflict**
- **Found during:** Task 1 (ImportPreviewSheet creation)
- **Issue:** Declared `private struct DiffView` conflicted with existing public `struct DiffView` in RefinementLoopView.swift
- **Fix:** Renamed to `ImportDiffView` — scoped to import preview usage
- **Files modified:** Pault/ImportPreviewSheet.swift
- **Verification:** Build succeeded
- **Committed in:** 74c27dd (Task 1 commit)

**2. [Rule 1 - Bug] `foregroundStyle(.accentColor)` invalid ShapeStyle**
- **Found during:** Task 2 (ContentView drop indicator)
- **Issue:** `.accentColor` shorthand not valid as ShapeStyle on macOS 15 target
- **Fix:** Changed to `Color.accentColor` explicit Color type
- **Files modified:** Pault/ContentView.swift
- **Verification:** Build succeeded
- **Committed in:** 2886657 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
- `Tag` type ambiguous in test file (conflict with possible Foundation type) — resolved with `Pault.Tag` disambiguation
- Test framework mismatch: XCTestCase + `MainActor.run{}` requires async test methods; switched to `@MainActor struct` + `@Test` macro pattern consistent with rest of project

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete import/export system built, tested, and human-verified (all 11 steps passed)
- Phase 6 is complete — full data portability via JSON v2 and Markdown export/import
- No blockers for subsequent phases

---
*Phase: 06-import-export*
*Completed: 2026-04-09*
