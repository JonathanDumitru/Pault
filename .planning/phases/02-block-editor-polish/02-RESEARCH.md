# Phase 2: Block Editor Polish — Research

**Researched:** 2026-03-25
**Domain:** SwiftUI macOS — drag-drop reordering, undo/redo, VoiceOver accessibility, animations, performance
**Confidence:** HIGH (most findings verified against official Apple docs or authoritative Swift community sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Drag-Drop & Reordering**
- Full drag reordering within canvas (not just keyboard)
- Line indicator between blocks for drop position
- Library blocks droppable at specific canvas positions (not just append)
- Compact preview (title + category) while dragging
- Drag handle icon only (not entire header)
- Interrupt and snap for rapid reorder (no queued animations)
- Always draggable even when expanded (auto-collapse during drag, re-expand on drop)
- Illustrated drop zone for empty canvas with dashed border + guidance text
- Grab cursor on drag handle hover
- Dim drag handle when single block
- Both drag AND keyboard (Option+Arrow) reordering
- Auto-scroll canvas when dragging near top/bottom edges
- Lift effect (scale + shadow) when block picked up
- Animation only for drop confirmation (no toast/sound)

**Undo/Redo**
- Structural operations only (add, remove, reorder, duplicate, modifiers). Text inputs use standard macOS TextField undo
- Undo after save marks composition dirty again
- Menu + keyboard only (Cmd+Z / Shift+Cmd+Z) — no toolbar buttons
- Unlimited undo depth per session
- Removed block returns to exact original position on undo
- Full state restore on redo (block + inputs + modifiers)
- Clear redo stack on new action (standard linear undo)
- Shared undo stack across Build/Edit/Debug tabs
- Clear undo stack on navigation away from prompt
- Standard menu dimming when stacks are empty

**VoiceOver & Accessibility**
- Full navigation + custom actions (Move Up/Down, Delete via .accessibilityAction)
- Accessible actions menu for drag-drop (not drag gestures)
- Polite VoiceOver announcements for preview updates
- Full VO support for slash command palette (per-item announcements, selection tracking)
- Respect Reduce Motion (replace spring animations with cross-fades/instant)
- Visible focus ring on selected block (system accent color, 2pt border)
- Icons + color for placeholder status indicators
- Structured tab order: Library → Canvas → Preview
- Announce category with each block ("Role block: System Prompt, position 1 of 5")
- Respect system text size (Dynamic Type)
- Announce block count changes ("Block added. 5 blocks on canvas.")
- Announce suggestion banner as polite alert
- Help rotor item with keyboard shortcut summary
- Support high contrast mode (@Environment(\.colorSchemeContrast))
- Support Differentiate Without Color (patterns/shapes alongside category colors)
- Disable auto-collapse when VoiceOver is active
- Keyboard shortcut guide via ? button / Cmd+?
- Validation errors announced on field exit (not live)
- Library blocks get 'Add to Canvas' accessibility action
- Token estimate and warnings as part of canvas summary
- Panel expand/collapse state announced
- Modifier picker traps VoiceOver focus when open (modal)
- Block elements are separate navigable children (not combined)

**Animation & Layout Polish**
- Height animation for expand/collapse (slide, not fade)
- Invisible performance optimization (no visible loading indicators for 20+ blocks)
- Subtle shimmer/pulse on preview during compilation
- Animated reflow for surrounding blocks on add/remove
- Fade + scale pop for slash command palette opening (<100ms)
- Fix compilation cache bug (include modifiers in cache key)
- Responsive panels with min widths (auto-collapse below threshold)
- Underline slide for preview tab transitions
- Skeleton shimmer for initial load of 10+ block prompts
- Enforce minimum canvas width (~300px, panels auto-collapse first)
- Spacing + shadow sufficient for block separation (no dividers)
- Verify and fix dark mode across all block editor views
- Soft block count limit with warning at ~30 blocks

**Scroll Behavior**
- Auto-scroll to new block when added
- Scroll + focus to first error field on validation failure
- Keep selected block visible during keyboard navigation
- Preserve scroll position when toggling panels
- Cmd+Home/End for jump to first/last block
- Independent scroll per panel

**Keyboard Shortcuts**
- Option+Up/Down for block reordering
- Cmd+D for block duplication
- Enter/Return toggles expand/collapse on selected block
- Floating panel for shortcut help (Cmd+?)
- Layered Esc: palette → picker → help → deselect → collapse
- Context-dependent Tab
- Cmd+Shift+E toggles all blocks expanded/collapsed
- Cmd+Shift+C copies compiled prompt to clipboard
- Delete, Forward Delete, AND Cmd+Backspace all remove block
- Right-click context menu on blocks
- Only Cmd+/ opens palette (no bare / key — note: currently bare / opens it, must change)
- Cmd+1/2/3 for panel focus

**Focus Management**
- Esc from text field → back to block header (not canvas)
- After block delete → focus next block (or previous if last)
- After slash palette insert → focus new block's first input (auto-expand)
- After library 'Add to Canvas' → focus jumps to canvas
- After undo remove → focus restored block
- After undo reorder → focus moved block

**Testing Strategy**
- Snapshot tests for key visual states
- Both light and dark mode snapshots
- Programmatic accessibility audit tests
- Targeted performance benchmarks
- Comprehensive undo/redo unit tests
- Feature-based test files: DragDropTests, UndoRedoTests, AccessibilityTests, KeyboardNavigationTests, PerformanceBenchmarkTests, CanvasSnapshotTests
- Extend existing Phase 1 test files for model-level undo/redo/duplicate
- CI-ready (unit + a11y + perf in CI; UI + snapshot tests optional)

**Edge Cases**
- Long content: inputs grow (max ~500px then scroll)
- Rapid add: abbreviated animations
- Delete last block: allowed, shows empty canvas drop zone
- No delete confirmation (trust undo)
- Concurrent editing: warn banner
- Undo across sessions: no persistence (clear per session)

**Theme/Appearance**
- System font (SF Pro) + monospace (SF Mono) for preview
- Solid backgrounds with rounded corners (no material vibrancy)
- 8pt grid spacing system (centralized in AppConstants)
- Standardized corner radii: .small (4pt), .medium (8pt), .large (12pt)
- 3-level shadow scale: .subtle (rest), .medium (hover/selected), .elevated (overlays)
- Neutral gray shadows (no category color tinting)
- System accent color border for keyboard focus ring (not glow)

### Claude's Discretion (Tune During Implementation)
- Exact auto-collapse timing values
- Specific shadow radius/opacity values for each level
- Compilation diagnostic format in Debug tab
- Coach mark positioning and exact copy
- Performance optimization techniques for 20+ blocks
- Exact skeleton shimmer implementation
- TextToBlocksService parsing improvements
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R1.1 | Canvas UX Edge Cases: drag-drop edge cases, slash command reliability, smooth animations, auto-collapse, undo/redo | Drag-drop via DragGesture+dropDestination; undo via UndoManager with environment injection; animation via withAnimation + accessibilityReduceMotion |
| R1.3 | Block Editor Accessibility: VoiceOver navigation, keyboard-only workflow, Dynamic Type, color contrast | accessibilityAction(named:), accessibilityLabel, AccessibilityNotification.Announcement, @Environment(\.accessibilityReduceMotion), accessibilityDifferentiateWithoutColor |
| R1.4 | Block Editor Performance: 20+ blocks responsive, preview <300ms, palette <100ms, stable memory | LazyVStack for lazy rendering; existing CompilationCache extended to include modifiers; XCTest measure() for benchmarks |
</phase_requirements>

---

## Summary

Phase 2 polishes the block editor from ~95% to production-ready. The codebase already has the core plumbing: `PromptStudioModel` has `addToCanvas`, `removeFromCanvas`, `moveOnCanvas` operations; `CompositionCanvasView` uses `.draggable` + `.onMove` + `.dropDestination`; `CompilationCache` exists (but has a known bug — modifiers excluded from cache key); `SlashCommandPaletteView` is built. What is missing: undo/redo system entirely, VoiceOver/accessibility modifiers entirely, position-aware drop with line indicator, a dozen keyboard shortcuts, focus management after operations, and the known cache bug fix.

The work splits cleanly into two plans as designed: **02-01** covers canvas UX edge cases (drag-drop position indicator, keyboard shortcuts, focus management, undo/redo, edge cases) and **02-02** covers accessibility + performance (VoiceOver custom actions, announcements, Reduce Motion, snapshot tests, performance benchmarks).

**Primary recommendation:** Use `@Environment(\.undoManager)` to inject the system UndoManager into `PromptStudioModel`; register inverse operations at each canvas mutation. For drag-drop position indicator, use per-row `.dropDestination` with an `isTargeted` flag plus a `@State var dropTargetIndex: Int?` tracked at the canvas level. For VoiceOver, add `.accessibilityAction(named:)` on each `BlockRowView` and post `AccessibilityNotification.Announcement` after state changes.

---

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| SwiftUI | macOS 15+ | All UI | Already in use |
| XCTest + Swift Testing | Xcode 16+ | Testing | Both already used (XCTestCase + @Test) |
| UndoManager | Foundation | Undo/redo | System-provided, inject via @Environment |

### New Testing Dependency
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| swift-snapshot-testing | 1.17.x | Snapshot tests for canvas states | Supports Swift Testing @Test macro + macOS NSHostingController |

**Installation:**
```bash
# Add via Xcode Package Manager or Package.swift:
# https://github.com/pointfreeco/swift-snapshot-testing
# Version: Up To Next Major from 1.17.0
```

### No New Runtime Dependencies
All runtime work uses SwiftUI built-ins: `@Environment(\.undoManager)`, `@Environment(\.accessibilityReduceMotion)`, `@Environment(\.accessibilityDifferentiateWithoutColor)`, `@Environment(\.colorSchemeContrast)`, `AccessibilityNotification.Announcement`.

---

## Architecture Patterns

### Recommended Project Structure Changes

```
Pault/BlockEditor/
├── PromptStudioModel.swift      # Add: undo/redo, duplication, cache fix
├── Views/
│   ├── CompositionCanvasView.swift   # Add: position drop, keyboard shortcuts, scroll, focus
│   ├── BlockRowView.swift            # Add: accessibilityActions, focus ring, context menu
│   ├── BlockLibraryView.swift        # Add: accessibilityAction("Add to Canvas")
│   └── SlashCommandPaletteView.swift # Add: keyboard nav polish, VO announcements
├── Services/
│   └── CompilationCache.swift        # Fix: include modifiers in cache key
└── Constants.swift (new file)        # 8pt grid, corner radii, shadow scale

PaultTests/
├── DragDropTests.swift          (new)
├── UndoRedoTests.swift          (new)
├── AccessibilityTests.swift     (new)
├── KeyboardNavigationTests.swift (new)
├── PerformanceBenchmarkTests.swift (new)
└── CanvasSnapshotTests.swift    (new)
```

### Pattern 1: UndoManager via Environment

**What:** Inject `undoManager` from SwiftUI environment into `PromptStudioModel`. Register inverse operations at each structural mutation so the system provides Cmd+Z / Shift+Cmd+Z and menu item dimming automatically.

**When to use:** Every canvas mutation: addToCanvas, removeFromCanvas, moveOnCanvas, duplicate, addModifier, removeModifier.

**Key insight:** macOS provides Edit > Undo/Redo menu items and keyboard shortcuts automatically when you use the system UndoManager. You do NOT need to add toolbar buttons or custom menu items.

**How it works:** Inside an undo registration block, register the inverse operation. When the system performs an undo, any undo registration inside that block is treated as a redo registration.

```swift
// Source: https://nilcoalescing.com/blog/HandlingUndoAndRedoInSwiftUI/
// Pattern for injecting undoManager into @MainActor ObservableObject

// In PromptStudioModel:
weak var undoManager: UndoManager?

func addToCanvas(_ block: Block) {
    let new = Block(/* ... */)
    canvasBlocks.append(new)
    // ... setup inputs ...
    undoManager?.registerUndo(withTarget: self) { model in
        // This closure runs on undo. Registering undo here = redo.
        model.removeFromCanvas(byID: new.id, registerUndo: true)
    }
    undoManager?.setActionName("Add Block")
    markDirty()
    compileNow()
}

// In BlockEditorView (or wherever PromptStudioModel is created):
@Environment(\.undoManager) var undoManager

.onAppear {
    model.undoManager = undoManager
}
```

**Undo state capture for remove:** Before removing, capture the full block + inputs + modifiers + position. On undo, re-insert at exact original index.

```swift
struct CanvasUndoSnapshot {
    let block: Block
    let index: Int
    let inputs: [String: String]
    let modifiers: [BlockModifier]
    let modifierInputs: [UUID: [String: String]]
}

func removeFromCanvas(at offsets: IndexSet, registerUndo: Bool = true) {
    let snapshots = offsets.map { CanvasUndoSnapshot(
        block: canvasBlocks[$0],
        index: $0,
        inputs: blockInputs[canvasBlocks[$0].id] ?? [:],
        modifiers: blockModifiers[canvasBlocks[$0].id] ?? [],
        modifierInputs: /* collect */
    )}
    // ... remove ...
    if registerUndo {
        undoManager?.registerUndo(withTarget: self) { model in
            model.restoreBlocks(snapshots: snapshots)
        }
        undoManager?.setActionName("Remove Block")
    }
}
```

**Clear on navigation:** `undoManager?.removeAllActions()` when navigating away from the prompt.

### Pattern 2: Position-Aware Drop with Line Indicator

**What:** Replace the current canvas-level `.dropDestination` (append-only) with per-row drop zones. Each row's top half targets "insert before this index", bottom half targets "insert after". A line indicator renders between rows when a drop is pending.

**When to use:** When dragging from library OR reordering within canvas.

**The two approaches:**
1. `.onMove` (ForEach modifier) — handles within-canvas reorder automatically with system UI. Already implemented. **Keep this for canvas-to-canvas reorder.**
2. Per-row `.dropDestination` — needed for library-to-canvas drops at specific positions.

**Current state:** The canvas uses both `.draggable` on rows + `.onMove` on ForEach (canvas reorder) AND a canvas-level `.dropDestination` (library append-only). The canvas-level drop must be replaced with per-row drops.

```swift
// Source: SwiftUI dropDestination docs + Apple Developer Forums thread/732076
// Track insertion index at canvas level
@State private var dropTargetIndex: Int? = nil

// Render a line indicator between rows:
ForEach(Array(model.canvasBlocks.enumerated()), id: \.element.id) { index, block in
    // Drop insertion line above this block
    if dropTargetIndex == index {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: 2)
            .padding(.horizontal, 8)
    }

    BlockRowView(/* ... */)
        .dropDestination(for: Block.self) { items, location in
            let insertAt = location.y < blockRowHeight / 2 ? index : index + 1
            for block in items {
                model.insertOnCanvas(block, at: insertAt)
            }
            dropTargetIndex = nil
            return true
        } isTargeted: { isTargeted in
            dropTargetIndex = isTargeted ? index : nil
        }
}
```

**Lift effect (scale + shadow) when dragging:** Apply to `.draggable` preview or use `@State var isDragging`. The `BlockDragPreview` already exists — it just needs the scale/shadow effect.

**Auto-scroll during drag:** Use `ScrollViewReader` + a geometry-tracking overlay. When drag position is within ~60pt of top/bottom edge, programmatically scroll.

**Rapid reorder:** Use `withTransaction { transaction.animation = nil }` to cancel in-progress animations before starting a new snap. Or use `.animation(nil, value: draggedBlockID)`.

### Pattern 3: VoiceOver Custom Actions on BlockRowView

**What:** Each `BlockRowView` gets `.accessibilityActions` providing VoiceOver users non-drag equivalents of all block operations.

**Source:** WWDC24 "Catch up on accessibility in SwiftUI" + `.accessibilityAction(named:)` docs

```swift
// Source: https://www.createwithswift.com/accessibility-actions/
// and Apple Developer Documentation: accessibilityAction(_:_:)

BlockRowView(/* ... */)
    .accessibilityLabel("\(block.category.displayName) block: \(block.title), position \(index + 1) of \(totalCount)")
    .accessibilityActions {
        Button("Move Up") { model.moveBlock(id: block.id, direction: -1) }
        Button("Move Down") { model.moveBlock(id: block.id, direction: 1) }
        Button("Delete") { model.removeFromCanvas(byID: block.id) }
        Button("Duplicate") { model.duplicateBlock(id: block.id) }
        Button(isExpanded ? "Collapse" : "Expand") { isExpanded.toggle() }
    }
```

### Pattern 4: Accessibility Announcements (Polite)

**What:** After state changes (block added/removed, reorder, paste), post a low-priority announcement so VoiceOver reads it without interrupting current speech.

```swift
// Source: WWDC23 "Build accessible apps with SwiftUI and UIKit"
// AccessibilityNotification.Announcement is in Accessibility framework (macOS 13+)
import Accessibility

// In PromptStudioModel, after addToCanvas:
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    AccessibilityNotification.Announcement(
        "Block added. \(self.canvasBlocks.count) blocks on canvas."
    ).post()
}
```

**Priority levels** (set via AttributedString key `accessibilitySpeechAnnouncementPriority`):
- `.high` — interrupts current speech (use for errors only)
- `.default` — interrupts but interruptible
- `.low` — queued, spoken when speech completes (use for canvas state changes)

For preview compilation updates, use `.low` so it does not interrupt block navigation.

### Pattern 5: Reduce Motion Compliance

```swift
// Source: Apple Developer Documentation: accessibilityReduceMotion
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Replace spring animations:
var blockAnimation: Animation {
    reduceMotion ? .linear(duration: 0) : .spring(response: 0.3, dampingFraction: 0.8)
}

// For expand/collapse:
withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
    isExpanded.toggle()
}
```

**Also disable auto-collapse when VoiceOver is active:**
```swift
@Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
// In AutoCollapseManager: guard !voiceOverEnabled else { return }
```

### Pattern 6: Compilation Cache Fix (Modifier Cache Key)

**What:** Current `generateCacheKey` in `CompilationCache.swift` only hashes `blocks` and `blockInputs`. Per STATE.md known bug: "Compilation cache does not include modifiers in cache key."

**Fix:** Extend the key to include modifier IDs, snippets, and modifierInputs.

```swift
func generateCacheKey(
    blocks: [BlockData],
    blockInputs: [UUID: [String: String]],
    blockModifiers: [UUID: [BlockModifier]],  // ADD
    modifierInputs: [UUID: [String: String]]  // ADD
) -> String {
    var keyComponents: [String] = []
    // existing block/input hashing...
    // Add modifiers per block:
    for block in blocks {
        let mods = blockModifiers[block.id] ?? []
        for mod in mods.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            keyComponents.append("mod:\(mod.id.uuidString):\(mod.snippet.hashValue)")
            let inputs = modifierInputs[mod.id] ?? [:]
            for (k, v) in inputs.sorted(by: { $0.key < $1.key }) {
                keyComponents.append("\(k)=\(v.hashValue)")
            }
        }
    }
    return keyComponents.joined(separator: "|")
}
```

### Pattern 7: Snapshot Tests with swift-snapshot-testing

**What:** swift-snapshot-testing 1.17.x supports both XCTest and Swift Testing `@Test` macro. macOS snapshots use `NSHostingController`.

**Source:** https://github.com/pointfreeco/swift-snapshot-testing — "Supports any platform that supports Swift. Write snapshot tests for iOS, Linux, macOS, and tvOS."

```swift
// Source: swift-snapshot-testing README + TrozWare SwiftUI Snapshots article
import SnapshotTesting
import SwiftUI
import XCTest

class CanvasSnapshotTests: XCTestCase {
    func testEmptyCanvas() {
        let view = CompositionCanvasView(/* ... */)
        let vc = NSHostingController(rootView: view)
        vc.view.frame = CGRect(x: 0, y: 0, width: 500, height: 600)
        assertSnapshot(of: vc, as: .image)
    }

    func testEmptyCanvasDarkMode() {
        let view = CompositionCanvasView(/* ... */)
            .preferredColorScheme(.dark)
        let vc = NSHostingController(rootView: view)
        vc.view.frame = CGRect(x: 0, y: 0, width: 500, height: 600)
        assertSnapshot(of: vc, as: .image)
    }
}
```

**Note from Phase 1 blocker:** "swift-snapshot-testing + Swift Testing `@Test` macro compatibility unconfirmed." As of 1.17.x, this is now confirmed supported — assertSnapshot dynamically detects XCTest vs Swift Testing context.

### Pattern 8: Performance Benchmarks via XCTest measure()

```swift
// Source: Apple Developer Documentation + Swift with Majid performance testing
class PerformanceBenchmarkTests: XCTestCase {
    func testPaletteFilterPerformance() {
        let allBlocks = /* seed ~100 blocks */
        measure {
            _ = SlashCommandState.filterBlocks(allBlocks, query: "role")
        }
        // Baseline must be < 10ms (palette must open < 100ms including UI)
    }

    func testCompilationPerformance() throws {
        let model = /* model with 20 blocks, all filled */
        measure {
            model.compileNow()
        }
        // Baseline must be < 300ms
    }
}
```

### Anti-Patterns to Avoid

- **Registering undo in deinit or async contexts without @MainActor:** UndoManager must be called on the main thread. `PromptStudioModel` is already `@MainActor`.
- **Storing UndoManager strongly:** Always `weak var undoManager: UndoManager?` to avoid retain cycles.
- **Animating undo:** Do NOT wrap undo execution in `withAnimation`. The action itself calls the mutation method which can animate normally.
- **Canvas-level .dropDestination for position-aware inserts:** This gives a single drop point for the entire canvas, not per-row positions. Per-row `.dropDestination` is required.
- **Using bare `/` to open palette:** Context.md locks this to Cmd+/ only. Current code opens on bare `/` — this must be changed.
- **Snapshot tests against window-hosted views for CI:** NSHostingController without a window may produce blank snapshots on CI. Set `.frame` explicitly and use `.image(size: CGSize)` strategy, or use a test window.
- **Calling UndoManager.removeAllActions() during saves:** Only call on navigation away, not on save. Save should not clear undo history.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Undo/redo system | Custom stack array | Foundation `UndoManager` via `@Environment(\.undoManager)` | macOS provides menu items, Cmd+Z, Shift+Cmd+Z, canUndo/canRedo, action names — all free |
| Edit > Undo menu integration | Custom NSMenuItem | UndoManager automatic | macOS wires Edit menu to the first responder's undoManager automatically |
| VoiceOver action routing | Custom gesture recognizer | `.accessibilityActions {}` with Button labels | System handles the swipe-up interaction pattern and Switch Control menu |
| Announcement queue | Custom queue | `AccessibilityNotification.Announcement(...).post()` | Foundation handles speech queue and priorities |
| Snapshot comparison | Custom pixel diff | `swift-snapshot-testing` assertSnapshot | Handles reference image management, diff output, record mode |
| Performance baseline tracking | Manual timing | `XCTestCase.measure {}` | Xcode stores baselines, fails CI on regression, runs 10x for statistical validity |
| Tab order across panels | Custom focus management | `.accessibilityElement(children: .contain)` + SwiftUI focus system | Tab order follows SwiftUI view hierarchy order |

**Key insight:** The system UndoManager is the correct tool on macOS. Building a custom undo stack means losing menu integration, action naming, grouping, and unlimited depth for free.

---

## Common Pitfalls

### Pitfall 1: Undo Clears Text Field Undo History
**What goes wrong:** Calling `undoManager?.removeAllActions()` or using the same UndoManager for structural operations as TextFields use internally causes TextField's own undo history (character-by-character) to be wiped when a block operation is undone.
**Why it happens:** SwiftUI TextFields use the window's undoManager by default. Structural block operations share the same manager.
**How to avoid:** Only register structural operations (add/remove/reorder/duplicate/modifiers). Do NOT intercept text input changes. The Context.md decision confirms this: "Structural operations only. Text inputs use standard macOS TextField undo."
**Warning signs:** Typing in a text field and pressing Cmd+Z jumps to block-level undo instead of undoing the last typed character.

### Pitfall 2: .onMove Conflicts with .dropDestination for Library Drops
**What goes wrong:** Having both `.onMove` on the ForEach and per-row `.dropDestination` for the same `Block.self` transferable type causes ambiguity — system does not know which handler to invoke.
**Why it happens:** Both accept `Block.self` drops. The system may prefer the `.dropDestination` or `.onMove`, but behavior is undefined.
**How to avoid:** Use `.onMove` for within-canvas reordering (drag handle gesture). Use `.dropDestination` only for library→canvas drops with a separate transferable type wrapper or by checking the drag source. Alternatively: use `.onMove` for reorder, and for library drops use a separate `LibraryBlockTransfer` type that wraps `Block`.
**Warning signs:** Dragging a block from the library inserts it correctly, but canvas-to-canvas reorder no longer works.

### Pitfall 3: Snapshot Tests Produce Blank Images on CI
**What goes wrong:** `NSHostingController` snapshots taken without an NSWindow backing produce all-white or blank images on headless CI.
**Why it happens:** On macOS, view layout requires a window to trigger layout pass.
**How to avoid:** Either (a) mark snapshot tests as optional in CI per the testing strategy, or (b) use a test window:
```swift
let window = NSWindow()
window.setContentSize(vc.view.frame.size)
window.contentViewController = vc
window.makeKeyAndOrderFront(nil)
// take snapshot
window.close()
```
Per Context.md decision: "UI + snapshot tests optional" in CI. Run locally only.

### Pitfall 4: AccessibilityNotification.Announcement Race Conditions
**What goes wrong:** Posting an announcement immediately after a state change causes VoiceOver to read the old state (before SwiftUI re-renders).
**Why it happens:** VoiceOver reads accessibility tree which may not have updated yet.
**How to avoid:** Use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` before posting. This is an established pattern confirmed by Apple's own examples.
**Warning signs:** VoiceOver announces "3 blocks on canvas" after adding a block, but the count was 3 before (not after).

### Pitfall 5: Drop Indicator State Not Cleared on Drop Cancel
**What goes wrong:** User starts dragging, moves over canvas showing line indicator, then drags item outside the window and releases. The line indicator `dropTargetIndex` stays visible.
**Why it happens:** `isTargeted` closure fires `false` when leaving but the drop cancels without firing the action closure.
**How to avoid:** Also set `dropTargetIndex = nil` in `isTargeted: { if !isTargeted { dropTargetIndex = nil } }` for EVERY row simultaneously. Use a single `@State var dropTargetIndex: Int?` at canvas level so all rows share it.

### Pitfall 6: Compilation Cache Key Hash Collisions
**What goes wrong:** After fixing the cache to include modifiers, hash collisions on snippet content cause stale compiled output to be served.
**Why it happens:** Using `.hashValue` (Swift's non-stable hash) works within a session but is not deterministic. Two different strings can theoretically produce the same hash.
**How to avoid:** Instead of `.hashValue`, use the actual string content for small snippets (they're short — direct string inclusion is fine). Or use SHA256 for a stable, collision-resistant key.

### Pitfall 7: UndoManager Not Available in Init
**What goes wrong:** Trying to capture `@Environment(\.undoManager)` in `PromptStudioModel.init` fails — environment values are only available in View body.
**Why it happens:** `PromptStudioModel` is a class, not a View. It cannot read `@Environment`.
**How to avoid:** Inject the undoManager via `.onAppear` or via a property setter from the View that holds the model:
```swift
// In BlockEditorView:
.onAppear { model.undoManager = undoManager }
.onChange(of: undoManager) { model.undoManager = $0 }
```

---

## Code Examples

Verified patterns from official and high-confidence sources:

### Accessibility Action Registration
```swift
// Source: Apple Developer Documentation + createwithswift.com/accessibility-actions
.accessibilityLabel("\(block.category.displayName) block: \(block.title), position \(index + 1) of \(total)")
.accessibilityActions {
    Button("Move Up") { onMoveUp() }
    Button("Move Down") { onMoveDown() }
    Button("Delete") { onRemove() }
    Button("Duplicate") { onDuplicate() }
}
```

### Polite Announcement
```swift
// Source: WWDC23 "Build accessible apps with SwiftUI and UIKit"
// + cvs-health ios-swiftui-accessibility-techniques examples
import Accessibility

func announceCanvasChange(_ message: String) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        AccessibilityNotification.Announcement(message).post()
    }
}
// Usage: announceCanvasChange("Block added. \(canvasBlocks.count) blocks on canvas.")
```

### Reduce Motion Conditional Animation
```swift
// Source: Apple Developer Documentation: accessibilityReduceMotion
// + Hacking with Swift: Supporting specific accessibility needs
@Environment(\.accessibilityReduceMotion) var reduceMotion

func animate(action: () -> Void) {
    if reduceMotion {
        action()
    } else {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            action()
        }
    }
}
```

### Differentiate Without Color
```swift
// Source: Apple Developer Documentation: accessibilityDifferentiateWithoutColor
@Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

// In placeholder status indicator:
HStack {
    if differentiateWithoutColor {
        Image(systemName: status.symbolName) // ✖/⚠/✔
            .foregroundColor(status.color)
    } else {
        Circle().fill(status.color).frame(width: 8, height: 8)
    }
}
```

### UndoManager Structural Registration
```swift
// Source: nilcoalescing.com/blog/HandlingUndoAndRedoInSwiftUI/
// Pattern: register inverse inside undo block to enable redo
func addToCanvas(_ block: Block) {
    let new = Block(title: block.title, category: block.category,
                    valueType: block.valueType, snippet: block.snippet)
    canvasBlocks.append(new)
    // ... setup inputs ...
    undoManager?.registerUndo(withTarget: self) { [weak self] model in
        self?.removeFromCanvas(byID: new.id)
    }
    undoManager?.setActionName("Add Block")
    markDirty()
    compileNow()
}
```

### High Contrast Support
```swift
// Source: Apple Developer Documentation: colorSchemeContrast
@Environment(\.colorSchemeContrast) var colorContrast

var categoryBorderWidth: CGFloat {
    colorContrast == .increased ? 3 : 2
}

var categoryColor: Color {
    // Ensure 7:1 contrast ratio when increased contrast is active
    colorContrast == .increased ? block.category.highContrastColor : block.category.color
}
```

### Performance Benchmark (XCTest.measure)
```swift
// Source: Apple Developer Documentation: measure(_:)
// + Swift with Majid performance testing article
func testCanvasCompilationPerformance() throws {
    let context = try TestHelpers.makeTestModelContext()
    let prompt = Prompt(title: "Perf Test", content: "")
    context.insert(prompt)
    let model = PromptStudioModel(prompt: prompt)

    // Add 20 blocks
    for _ in 0..<20 {
        let block = model.library[.instructions]!.first!
        model.addToCanvas(block)
    }

    measure {
        CompilationCache.shared.clear()
        model.compileNow()
    }
    // XCTest stores baseline; fail if > 300ms average
}
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `UIAccessibility.post(notification:)` | `AccessibilityNotification.Announcement(...).post()` | Newer API, iOS 15+/macOS 12+; current project targets macOS 15 so use new API |
| Manual undo stack (arrays) | `UndoManager` via environment | UndoManager is the blessed pattern on macOS for document-model apps |
| `SnapshotTesting` XCTest-only | `swift-snapshot-testing` 1.17 with Swift Testing | Both frameworks now supported in same assertSnapshot call |
| `.onDrag` / `.onDrop` | `.draggable` / `.dropDestination` | Newer Transferable-based API; already used in codebase |
| `EditMode` for reorder | `.onMove` on ForEach | More flexible; already used in codebase |

**Deprecated/outdated in this project's context:**
- Bare `/` opening slash palette: locked to Cmd+/ per decisions
- Canvas-level append-only drop: must become per-row position-aware

---

## Open Questions

1. **Does `.onMove` conflict with per-row `.dropDestination` for `Block.self` type?**
   - What we know: Both accept the same transferable type. Apple's docs don't explicitly address this combination.
   - What's unclear: Will the system correctly dispatch canvas→canvas drag to `.onMove` and library→canvas drag to `.dropDestination`?
   - Recommendation: Use a `LibraryBlockDrop` wrapper type (conforms to Transferable) for library-to-canvas transfers, keeping `Block.self` transferable only for canvas→canvas `.onMove`. This eliminates ambiguity.

2. **swift-snapshot-testing 1.17 on macOS with @MainActor context**
   - What we know: Library supports Swift Testing @Test. macOS works with NSHostingController.
   - What's unclear: Whether snapshot tests for @MainActor views require special test configuration on macOS in Xcode 16.
   - Recommendation: Start with XCTestCase subclass for snapshot tests (more mature path). Use `@Test` for unit/model tests only.

3. **AutoCollapseManager and VoiceOver detection**
   - What we know: `@Environment(\.accessibilityVoiceOverEnabled)` is the correct API.
   - What's unclear: Whether `AutoCollapseManager` (a service class) can access environment values.
   - Recommendation: Pass `voiceOverEnabled` as a parameter from the View layer to AutoCollapseManager, or inject via a protocol. Do not attempt to read @Environment in a non-View class.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, ~30 test files) + Swift Testing @Test (existing in PromptStudioModelTests) |
| Config file | None — Xcode scheme based |
| Quick run command | `xcodebuild test -scheme Pault -only-testing PaultTests/PromptStudioModelTests` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R1.1 | addToCanvas registers undo; undo restores block at original position | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ Wave 0 |
| R1.1 | removeFromCanvas restores full state (inputs + modifiers) on undo | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ Wave 0 |
| R1.1 | moveOnCanvas registers undo; redo re-applies move | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ Wave 0 |
| R1.1 | duplicateBlock places copy after original | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ Wave 0 |
| R1.1 | Slash palette filter returns results on empty query | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/SlashCommandStateTests` | ✅ |
| R1.1 | Drop on empty canvas shows illustrated drop zone | snapshot | Snapshot optional / local only | ❌ Wave 0 |
| R1.3 | BlockRowView has accessibilityLabel with category + title + position | unit (a11y audit) | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ❌ Wave 0 |
| R1.3 | BlockRowView has accessibilityActions for Move Up/Down/Delete | unit (a11y audit) | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ❌ Wave 0 |
| R1.3 | Reduce Motion: animations disabled when accessibilityReduceMotion=true | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ❌ Wave 0 |
| R1.4 | compileNow() with 20 blocks completes < 300ms average | performance | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ❌ Wave 0 |
| R1.4 | SlashCommandState.filterBlocks(100 blocks) completes < 10ms | performance | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ❌ Wave 0 |
| R1.4 | CompilationCache key includes modifiers (regression for known bug) | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` (or relevant new file)
- **Per wave merge:** `xcodebuild test -scheme Pault -destination 'platform=macOS'` (full unit suite)
- **Phase gate:** Full suite green + performance benchmarks within baseline before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `PaultTests/UndoRedoTests.swift` — covers R1.1 undo/redo for all structural operations
- [ ] `PaultTests/AccessibilityTests.swift` — covers R1.3 accessibilityLabel, accessibilityActions, reduceMotion
- [ ] `PaultTests/PerformanceBenchmarkTests.swift` — covers R1.4 compilation + palette benchmarks
- [ ] `PaultTests/DragDropTests.swift` — covers R1.1 drag-drop model operations (addToCanvas, insertAt, moveOnCanvas)
- [ ] `PaultTests/KeyboardNavigationTests.swift` — covers R1.1 keyboard shortcuts at model level
- [ ] `PaultTests/CanvasSnapshotTests.swift` — snapshot coverage (optional CI, required local)
- [ ] SPM dependency: `swift-snapshot-testing` 1.17.x — add to Xcode project

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `accessibilityReduceMotion`, `accessibilityDifferentiateWithoutColor`, `colorSchemeContrast`, `accessibilityAction(_:_:)`, `dropDestination(for:action:isTargeted:)`, `UndoManager`
- WWDC24 "Catch up on accessibility in SwiftUI" (developer.apple.com/videos/play/wwdc2024/10073/)
- WWDC23 "Build accessible apps with SwiftUI and UIKit" (developer.apple.com/videos/play/wwdc2023/10036/)
- `AccessibilityNotification.Announcement` Apple Developer Documentation (developer.apple.com/documentation/accessibility/accessibilitynotification/announcement)
- swift-snapshot-testing GitHub README — macOS support, Swift Testing support, NSHostingController pattern (github.com/pointfreeco/swift-snapshot-testing)
- Existing Pault codebase: `PromptStudioModel.swift`, `CompositionCanvasView.swift`, `CompilationCache.swift`, `BlockRowView.swift`

### Secondary (MEDIUM confidence)
- nilcoalescing.com/blog/HandlingUndoAndRedoInSwiftUI/ — UndoManager pattern with provider, macOS automatic menu support, redo via nested registration
- createwithswift.com/accessibility-actions/ — `.accessibilityActions {}` with Button labels, VoiceOver swipe navigation
- cvs-health/ios-swiftui-accessibility-techniques — `AccessibilityNotification.Announcement(...).post()` with 0.1s delay pattern
- swiftdevjournal.com/moving-list-items-using-drag-and-drop-in-swiftui-mac-apps/ — onMove + macOS drag pattern
- Apple Developer Forums thread/732076 — dropDestination location parameter for per-row positioning

### Tertiary (LOW confidence — validate during implementation)
- One source only, no Apple doc verification: the specific behavior of `.onMove` + `.dropDestination` interaction on the same ForEach. Validate empirically.
- swift-snapshot-testing @MainActor + macOS behavior — confirmed in README but not in official Apple docs.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are system-provided (UndoManager, Accessibility) or well-established open source (swift-snapshot-testing)
- Architecture: HIGH — UndoManager pattern verified via multiple sources; drag-drop per-row pattern is well-documented
- Pitfalls: MEDIUM-HIGH — most verified empirically by community; Pitfall 2 (onMove + dropDestination conflict) is LOW confidence, verify first
- Accessibility patterns: HIGH — all from Apple official sources (WWDC23, WWDC24, official docs)

**Research date:** 2026-03-25
**Valid until:** 2026-06-25 (90 days — stable APIs, no fast-moving dependencies)
