---
phase: 02-block-editor-polish
plan: 01
subsystem: ui
tags: [undo-redo, UndoManager, CompilationCache, AppConstants, SwiftData, XCTest]

# Dependency graph
requires:
  - phase: 01-compliance-test-infrastructure
    provides: TestHelpers.makeTestModelContext() used by UndoRedoTests

provides:
  - UndoManager integration for all 6 structural canvas operations (add, remove, reorder, duplicate, modifier add/remove)
  - CompilationCache modifier fix (cache key now includes modifier IDs, snippets, and modifier inputs)
  - AppConstants centralized design tokens (spacing, corner radii, shadows, animations, canvas layout)
  - CanvasUndoSnapshot struct for capturing block state before removal
  - UndoRedoTests.swift with 12 comprehensive unit tests

affects:
  - 02-drag-drop (drag operations must register undo via same UndoManager)
  - 02-accessibility (VoiceOver actions trigger same structural operations)
  - All plans that add structural canvas operations

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "UndoManager grouping: public methods wrap registerUndo in beginUndoGrouping/endUndoGrouping for groupsByEvent=false compatibility"
    - "Undo injection: weak var undoManager on @MainActor model, injected from view via NSApp.keyWindow.undoManager"
    - "Snapshot pattern: CanvasUndoSnapshot captures full block state (block, index, inputs, modifiers, modifierInputs) before removal"
    - "Test isolation: @MainActor undo operations tested via async XCTestCase with MainActor.run blocks"

key-files:
  created:
    - Pault/BlockEditor/Constants.swift (AppConstants with spacing/radius/shadow/animation/canvas constants)
    - PaultTests/UndoRedoTests.swift (12 XCTestCase tests for all 6 structural operations)
  modified:
    - Pault/BlockEditor/PromptStudioModel.swift (undoManager property, CanvasUndoSnapshot, 6 operations with undo)
    - Pault/BlockEditor/Services/CompilationCache.swift (generateCacheKey now accepts blockModifiers + modifierInputs)
    - Pault/BlockEditor/Views/BlockEditorView.swift (injects undoManager on appear, clears on prompt navigation)

key-decisions:
  - "UndoManager groupsByEvent=false required explicit beginUndoGrouping/endUndoGrouping on all public structural operations — auto-grouping is event-loop-based and not available in tests"
  - "Private undo callback methods (restoreFromSnapshot, removeModifierFromBlock private, restoreModifier) do NOT call begin/endUndoGrouping — UndoManager already has an implicit redo group open during undo execution"
  - "Tests use XCTestCase async with MainActor.run instead of Swift Testing — @Suite(.serialized) + @MainActor causes SEGV crash on macOS 26 (swift_task_isMainExecutorImpl bug); @MainActor XCTestCase causes ABRT; async MainActor.run is the safe pattern"
  - "UndoManager injected via NSApp.keyWindow.undoManager (not @Environment) to avoid SwiftUI + Swift Concurrency crash on macOS 26"
  - "clearUndoHistory() called on prompt navigation (not on save) per research anti-pattern"

patterns-established:
  - "UndoManager grouping pattern: beginUndoGrouping before registerUndo, setActionName, endUndoGrouping after — required for groupsByEvent=false"
  - "Private undo callbacks: no explicit grouping needed, UndoManager handles redo group automatically"
  - "XCTest + @MainActor: use async func test with await MainActor.run {} not @MainActor on class"

requirements-completed: [R1.1]

# Metrics
duration: ~90min
completed: 2026-03-26
---

# Phase 02 Plan 01: Undo/Redo, CompilationCache Fix, AppConstants Summary

**UndoManager wired to all 6 structural canvas operations with snapshot-based restore, modifier-aware CompilationCache, and centralized AppConstants — 294 tests pass**

## Performance

- **Duration:** ~90 min
- **Started:** 2026-03-26T12:58:00Z
- **Completed:** 2026-03-26T17:30:00Z
- **Tasks:** 2 (Task 1 was pre-committed at 0680ede)
- **Files modified:** 5

## Accomplishments
- Full Cmd+Z/Shift+Cmd+Z support for add, remove, reorder, duplicate, modifier add, modifier remove
- CompilationCache.generateCacheKey now includes modifier IDs, snippets, and modifier inputs — fixes Phase 1 deferred bug
- AppConstants centralizes all design tokens (8pt grid, corner radii, shadow scale, animations, canvas layout) for use by all subsequent plans
- 12 comprehensive undo/redo unit tests covering all operations including sequential chains and dirty tracking

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AppConstants, fix CompilationCache, add CanvasUndoSnapshot** - `0680ede` (feat)
2. **Task 2: Integrate UndoManager into PromptStudioModel with comprehensive tests** - `cb94dfd` (feat)

## Files Created/Modified
- `Pault/BlockEditor/Constants.swift` - AppConstants enum with Spacing/CornerRadius/Shadow/StandardAnimation/Canvas/Panels namespaces
- `Pault/BlockEditor/PromptStudioModel.swift` - undoManager property, CanvasUndoSnapshot struct, all 6 operations with undo registration and grouping
- `Pault/BlockEditor/Services/CompilationCache.swift` - generateCacheKey extended with blockModifiers + modifierInputs parameters
- `Pault/BlockEditor/Views/BlockEditorView.swift` - undoManager injection on appear via NSApp.keyWindow, clearUndoHistory on prompt change
- `PaultTests/UndoRedoTests.swift` - 12 XCTestCase async tests, all passing

## Decisions Made
- UndoManager groupsByEvent=false requires explicit begin/endUndoGrouping on all public operations — without this, registerUndo throws NSInternalInconsistencyException in test environments without a run loop
- Tests use XCTestCase async + MainActor.run instead of Swift Testing macros — macOS 26 has a known crash (swift_task_isMainExecutorImpl) when @Suite(.serialized) + @MainActor are combined, and @MainActor XCTestCase also crashes with ABRT when UndoManager.undo() is called from ObjC test infrastructure
- NSApp.keyWindow.undoManager instead of @Environment(\.undoManager) to avoid SwiftUI+Swift Concurrency crash on macOS 26 beta

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UndoManager groups required for groupsByEvent=false mode**
- **Found during:** Task 2 (UndoRedoTests execution)
- **Issue:** UndoManager with groupsByEvent=false throws "must begin a group before registering undo" when registerUndo is called without an explicit open group. All tests threw NSInternalInconsistencyException.
- **Fix:** Added beginUndoGrouping() before and endUndoGrouping() after registerUndo in all 6 public structural operations. Private undo-callback methods left without grouping (UndoManager manages the implicit redo group).
- **Files modified:** Pault/BlockEditor/PromptStudioModel.swift
- **Verification:** 294 tests pass after fix
- **Committed in:** cb94dfd (Task 2 commit)

**2. [Rule 1 - Bug] Swift Testing test crashes on macOS 26 with UndoManager**
- **Found during:** Task 2 (test execution)
- **Issue:** @Suite(.serialized) + @MainActor → SEGV crash. @MainActor XCTestCase → ABRT crash. Both are macOS 26 bugs with ObjC + Swift concurrency interop.
- **Fix:** Rewrote UndoRedoTests as XCTestCase with async test methods using await MainActor.run {}. This correctly isolates all model operations on the main actor while avoiding ObjC runtime crashes.
- **Files modified:** PaultTests/UndoRedoTests.swift
- **Verification:** All 12 tests pass, 294 total
- **Committed in:** cb94dfd (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes necessary for correct operation. UndoManager grouping improves production reliability (explicit groups even in run-loop context). Test approach change is implementation detail with no behavior impact.

## Issues Encountered
- macOS 26 (Sequoia/Tahoe) has unresolved Swift Concurrency + ObjC runtime crashes specific to test execution context. Documented as known macOS 26 beta issue. XCTestCase async + MainActor.run is the stable workaround.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Undo/redo foundation is in place for drag-drop (02-02) and accessibility (02-03)
- Drag-drop operations should use the same registerUndo pattern with beginUndoGrouping/endUndoGrouping
- AppConstants is ready for use in all subsequent UI plans
- CompilationCache modifier bug is resolved — no more test cache-clearing workarounds needed

---
*Phase: 02-block-editor-polish*
*Completed: 2026-03-26*
