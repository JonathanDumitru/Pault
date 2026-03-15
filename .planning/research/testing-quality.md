# Testing & Quality Assurance Research: Pault

**Domain:** macOS 15+ SwiftUI/SwiftData app -- pre-App Store launch QA
**Researched:** 2026-03-14
**Confidence:** MEDIUM (training data + thorough codebase analysis; web verification tools were unavailable)

---

## 1. SwiftUI View Testing on macOS

### Recommendation: Snapshot testing, NOT ViewInspector

**ViewInspector** is a library that lets you introspect SwiftUI view hierarchies in unit tests. However, it is **not recommended for Pault** because:
- It depends on SwiftUI's internal structure, which changes between macOS versions
- macOS support consistently lags iOS support
- Tests are brittle -- refactoring view layout breaks tests even when behavior is unchanged
- It cannot test actual rendering, animations, or layout

**Use instead: PointFree's swift-snapshot-testing** (v1.17+)
- Renders SwiftUI views via `NSHostingView` to `NSImage`
- Compares pixel output against reference images stored in `__Snapshots__/` directories
- Catches genuine visual regressions (font changes, layout breaks, missing elements)
- Supports `perceptualPrecision` parameter to tolerate minor rendering differences across macOS versions

**Which views to snapshot test (prioritized):**
1. `PromptDetailView` -- the main editing surface users see most
2. `BlockEditor` canvas views (BlockRowView, library view) -- complex custom layout
3. `SidebarView` -- navigation structure
4. `HotkeyLauncherView` / `HotkeyLauncherWindow` -- separate window, easy to miss regressions
5. `PaywallView` / `ProBadge` -- revenue-critical; must look correct
6. `PreferencesView` -- settings layout

**Setup:**
```swift
// Package.swift dependency
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")

// Usage in test
import SnapshotTesting

@MainActor
@Test func sidebarView_rendersCorrectly() {
    let view = SidebarView(...)
        .frame(width: 260, height: 600)
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(x: 0, y: 0, width: 260, height: 600)
    assertSnapshot(of: hostingView, as: .image(perceptualPrecision: 0.98))
}
```

**Note on Swift Testing compatibility:** swift-snapshot-testing was originally built for XCTest. Check if the latest version supports Swift Testing's `@Test` macro natively, or if snapshot tests need to remain as XCTestCase subclasses. As of training data, a compatibility layer or XCTest wrapper may be needed. **Flag for validation.**

---

## 2. SwiftData Testing Patterns

### In-Memory Containers

Pault already uses the correct pattern:
```swift
let container = try ModelContainer(
    for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
         CopyEvent.self, PromptRun.self, PromptVersion.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
```

**Improvements needed:**

1. **Centralize the container factory.** The `makeContext()` helper is duplicated across 5+ test files with slightly different model lists. Create a single `TestModelContainer.make()` that registers ALL 10 @Model types:
   - Prompt, TemplateVariable, Tag, Attachment, CopyEvent, PromptRun, PromptVersion, SmartCollection, PromptTemplate, CustomBlock

2. **Test relationship cascades explicitly:**
```swift
@Test func deletingPrompt_cascadesDeleteToTemplateVariables() throws {
    let context = try TestModelContainer.makeContext()
    let prompt = Prompt(title: "Test", content: "{{name}}")
    context.insert(prompt)
    let variable = TemplateVariable(name: "name", prompt: prompt)
    context.insert(variable)
    try context.save()

    context.delete(prompt)
    try context.save()

    let remaining = try context.fetch(FetchDescriptor<TemplateVariable>())
    #expect(remaining.isEmpty) // cascade delete should remove variables
}
```

3. **Test FetchDescriptor predicates.** Production code likely uses filtered fetches. Test that predicates work correctly with edge cases (empty strings, nil optionals, special characters).

### Migration Testing

**This is critical if any @Model has changed since the first public release.**

Strategy:
1. Define `VersionedSchema` conformances for each schema version
2. Define `SchemaMigrationPlan` with migration stages
3. Test by creating a SQLite store with the old schema, running the migration, and verifying data integrity

```swift
// Example migration test structure
@Test func migration_v1_to_v2_preservesPrompts() throws {
    // 1. Copy a v1 .store fixture to a temp directory
    // 2. Open with current ModelContainer (triggers migration)
    // 3. Fetch all Prompts
    // 4. Verify data integrity
}
```

**If Pault has not yet shipped v1.0:** Start creating versioned schemas NOW, before the first release. The cost of adding schema versioning after users have data is much higher.

---

## 3. Testing Complex State Machines (PromptStudioModel)

The 948-line PromptStudioModel is the highest-risk component. Current tests cover initialization, basic CRUD, and compilation. The following areas need additional coverage:

### State Transition Matrix

Map every public method to its expected state changes:

| Method | Pre-condition | Post-condition | Tested? |
|--------|--------------|----------------|---------|
| `init(prompt:)` | Empty prompt | Empty canvas, seeded library, synced state | YES |
| `init(prompt:)` | Prompt with blockComposition | Restored canvas, correct inputs | YES |
| `addToCanvas(_:)` | Any | Block appended, inputs extracted, compilation triggered | YES |
| `removeFromCanvas(at:)` | Canvas has blocks | Block removed, inputs cleaned up | YES |
| `moveBlock(from:to:)` | Canvas has 2+ blocks | Order changed, compilation updated | CHECK |
| `setBlockInput(blockID:placeholder:value:)` | Block exists on canvas | Input stored, dirty flag set | YES |
| `addModifier(to:modifier:)` | Block on canvas | Modifier added, inputs extracted | CHECK |
| `removeModifier(from:at:)` | Block has modifiers | Modifier removed, inputs cleaned up | CHECK |
| `compileNow()` | Any | Template compiled, saved to prompt, dirty cleared | YES |
| `scheduleCompilation()` | Any | Debounced compile queued | SKIP (test compileNow instead) |
| `loadFromPrompt()` | Prompt has data | Canvas restored from snapshot | YES |
| `saveToPrompt()` | Canvas has state | Prompt updated with content + snapshot | YES |

### Edge Cases to Add

```swift
// Canvas at capacity
@Test func addToCanvas_manyBlocks_doesNotDegrade() throws { ... }

// Remove last block
@Test func removeFromCanvas_lastBlock_leavesEmptyCanvas() throws { ... }

// Rapid add/remove (undo-like behavior)
@Test func rapidAddRemove_stateRemainsConsistent() throws { ... }

// Block with no placeholders
@Test func addToCanvas_blockWithNoPlaceholders_noInputsCreated() throws { ... }

// Modifier on non-existent block
@Test func addModifier_toNonExistentBlock_handlesGracefully() throws { ... }

// Compilation with empty inputs (unfilled placeholders)
@Test func compileNow_withUnfilledPlaceholders_preservesPlaceholderSyntax() throws { ... }

// Unicode in inputs
@Test func compileNow_unicodeInputs_handledCorrectly() throws { ... }

// Very long input values
@Test func compileNow_longInputValues_noTruncation() throws { ... }
```

### Dirty State Tracking

The `isDirty` / `lastSaved` properties need thorough testing:
- Every mutation method should set `isDirty = true`
- `compileNow()` should clear dirty after save
- Multiple mutations before compile should all contribute to dirty state

---

## 4. macOS-Specific UI Testing Challenges

### XCUITest on macOS: Known Limitations

1. **Window management:** Unlike iOS, macOS apps can have multiple windows. XCUIElement queries search the frontmost window by default. Use `app.windows["identifier"]` for secondary windows like HotkeyLauncherWindow.

2. **Menu bar testing:** Access via `app.menuBars.menuBarItems["Menu Name"]`. Menu items may not be accessible until the menu is opened.

3. **System permissions:** Global hotkey registration and accessibility features may require permissions that are not granted in the test environment. XCUITests run in a sandboxed app instance.

4. **Text editor testing:** NSTextView-based editors (RichTextEditor) may not respond to XCUIElement `.typeText()` as expected. Use `.click()` then `.typeText()`, or use pasteboard injection.

5. **Sheets and popovers:** Query sheets via `app.sheets` and popovers via `app.popovers`. On macOS, these are separate window types.

### Recommended XCUITest Suite (keep small)

```swift
// 1. Launch and verify main window
@MainActor
func testAppLaunches_showsMainWindow() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssert(app.windows.count >= 1)
    // Verify sidebar is visible
    XCTAssert(app.outlines.firstMatch.exists) // sidebar outline view
}

// 2. Create prompt flow
@MainActor
func testCreatePrompt_appearsInSidebar() throws {
    let app = XCUIApplication()
    app.launch()
    // Click "New Prompt" button or use Cmd+N
    app.typeKey("n", modifierFlags: .command)
    // Verify a new prompt appears
    // (specifics depend on accessibility identifiers)
}

// 3. Copy to clipboard flow
@MainActor
func testCopyPrompt_populatesClipboard() throws {
    let app = XCUIApplication()
    app.launch()
    // Navigate to a prompt, trigger copy
    // Verify clipboard content via NSPasteboard
}

// 4. Preferences window opens
@MainActor
func testPreferencesWindow_opens() throws {
    let app = XCUIApplication()
    app.launch()
    app.typeKey(",", modifierFlags: .command)
    XCTAssert(app.windows.count >= 2) // main + preferences
}
```

### Accessibility Identifiers Strategy

Add `.accessibilityIdentifier()` only to elements you actually query in XCUITests:
- Sidebar prompt list items
- "New Prompt" button
- "Copy" button
- Block editor canvas area
- Preferences window root view
- Hotkey launcher window root view

Do NOT add identifiers to every view -- it pollutes the code and most will never be queried.

---

## 5. Performance Testing Before App Store Submission

### Automated Performance Tests (XCTest)

```swift
// Already exists: launch time
func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}

// Add: memory baseline
func testMemoryBaseline() throws {
    measure(metrics: [XCTMemoryMetric()]) {
        // Create 100 prompts, navigate through them
    }
}
```

### Instruments Profiling Checklist (Manual, Pre-Submission)

Run each of these Instruments templates against the release build:

| Template | What to Look For | Acceptable Threshold |
|----------|-----------------|---------------------|
| **Time Profiler** | Main thread blocked > 16ms (dropped frames) | No hangs > 100ms in normal usage |
| **Allocations** | Persistent memory growth during use | Steady state < 100MB for normal usage |
| **Leaks** | Any retain cycles, especially in view models | Zero leaks |
| **SwiftUI Instruments** | Excessive view body evaluations, unnecessary re-renders | No view redrawn > 10x without user interaction |
| **Core Data / SwiftData** | Slow fetches, excessive saves | All fetches < 50ms |
| **Network** (if applicable) | AI service calls, response times | N/A if no network in core flow |

### Specific Areas to Profile for Pault

1. **PromptStudioModel compilation** -- 0.3s debounce suggests compilation is not instant. Profile `compileNow()` with 10+ blocks.
2. **Sidebar with many prompts** -- Test with 500+ prompts. Check scroll performance and memory.
3. **Block library rendering** -- The consolidated library computation runs on every access. May need caching.
4. **Large prompt content** -- Template variable resolution with a 10KB+ prompt.
5. **Window opening/closing** -- HotkeyLauncherWindow should open in < 200ms since it's a global hotkey response.

---

## 6. Accessibility Testing

### Pre-Submission Checklist

1. **Accessibility Inspector audit** (Xcode > Open Developer Tool > Accessibility Inspector):
   - Run audit on every major view
   - Fix all "error" level findings
   - Address "warning" level findings for interactive elements
   - Verify every button, text field, and control has a meaningful label

2. **VoiceOver navigation test** (System Preferences > Accessibility > VoiceOver):
   - Tab through the entire app using VoiceOver
   - Verify all interactive elements are reachable
   - Verify reading order makes sense
   - Verify custom controls (block editor drag handles, canvas) are accessible

3. **Keyboard navigation** (no mouse):
   - Tab through all interactive elements
   - Verify focus rings are visible
   - Verify all actions are achievable via keyboard
   - Test Cmd+C (copy), Cmd+N (new), Cmd+, (preferences), etc.

4. **Dynamic Type / Text Size** (if applicable):
   - macOS does not have Dynamic Type like iOS, but test with larger system font sizes
   - Verify text is not truncated at larger sizes

5. **Reduce Motion**:
   - Enable "Reduce motion" in Accessibility settings
   - Verify animations are reduced/eliminated

6. **High Contrast**:
   - Enable "Increase contrast" in Accessibility settings
   - Verify all UI elements remain visible and distinguishable

### Automated Accessibility Tests

```swift
@MainActor
func testMainWindow_allButtonsHaveLabels() throws {
    let app = XCUIApplication()
    app.launch()

    let buttons = app.buttons.allElementsBoundByIndex
    for button in buttons {
        XCTAssertFalse(button.label.isEmpty,
            "Button at \(button.frame) has no accessibility label")
    }
}
```

### App Store Review Accessibility Requirements

Apple does not mandate full WCAG compliance, but App Store reviewers will flag:
- Buttons with no labels (VoiceOver reads "button" with no description)
- Text fields with no accessibility hints
- Custom controls that are invisible to assistive technology
- Focus trapping (keyboard user cannot escape a section)

---

## 7. Testing Global Hotkey and Clipboard Integrations

### Global Hotkey (GlobalHotkeyManager)

**The problem:** Uses Carbon `RegisterEventHotKey` API. Cannot be unit tested because:
- Requires a running Carbon event loop
- Registers system-wide hotkeys that conflict with other apps
- Singleton pattern prevents injection

**Solution: Three-layer approach**

1. **Protocol extraction** (see ARCHITECTURE.md):
   - Extract `HotkeyManaging` protocol
   - Unit test the callback routing with a mock
   - Test that the correct keyCode/modifiers are passed

2. **Integration test in XCUITest:**
   - Launch the app
   - Use `XCUIElement.typeKey()` to simulate the hotkey combination
   - Verify the hotkey launcher window appears

3. **Manual verification:**
   - Test hotkey registration when another app is focused
   - Test hotkey conflict with system shortcuts
   - Test hotkey after sleep/wake

### Clipboard Integration

**Already partially tested** in IntegrationTests.swift. Expand with:

```swift
// Rich text clipboard content
@Test func copyToClipboard_preservesPlainTextType() throws {
    // Verify .string type is set on pasteboard
}

// Empty prompt copy
@Test func copyToClipboard_emptyPrompt_copiesToClipboard() throws {
    // Should copy empty string, not crash
}

// Prompt with only unfilled variables
@Test func copyToClipboard_unfilledVariables_preservesMarkers() throws {
    // "{{name}}" should remain as-is in clipboard
}

// Copy event tracking
@Test func copyToClipboard_createsCopyEvent() throws {
    // Verify a CopyEvent is inserted into SwiftData
}

// Rapid consecutive copies
@Test func copyToClipboard_rapidCopies_allSucceed() throws {
    // Multiple copies in quick succession should not crash or lose data
}
```

---

## 8. Recommended Test Coverage Targets

### Coverage Targets by Layer

| Layer | Target | Rationale |
|-------|--------|-----------|
| @Model types (10) | 90%+ | Data integrity is paramount. Every property, relationship, computed accessor |
| PromptStudioModel | 85%+ | Core state machine. Cover every public method and state transition |
| Service layer (PromptService, TemplateEngine, DiffEngine, ExportService) | 85%+ | Business logic that drives user-facing behavior |
| Utility/helper code | 70%+ | Lower risk, but still important |
| Views (SwiftUI) | N/A | Do not measure view coverage. Snapshot test key views instead |
| Overall project | 65-75% | Healthy for a macOS app with significant UI code that should not be unit tested |

### Qualitative Targets (More Important Than Numbers)

- [ ] Every @Model cascade delete is tested
- [ ] Every PromptStudioModel public method has at least one test
- [ ] Every TemplateEngine edge case (empty, special chars, unicode, nested vars) is tested
- [ ] BlockCompositionSnapshot round-trip is tested for every property
- [ ] Clipboard copy works for: normal text, template variables, empty content, very long content
- [ ] App launches without crashing (XCUITest)
- [ ] App is navigable by keyboard (manual or XCUITest)
- [ ] No Instruments-detected memory leaks in a 10-minute usage session
- [ ] Launch time < 2 seconds (already measured)
- [ ] Zero accessibility errors in Accessibility Inspector audit

### Current State Assessment

Based on codebase analysis:
- **29 test files** across unit, integration, and UI test targets
- **26/29 using Swift Testing** (modern), 3 still on XCTest
- **Strong model/service coverage** -- PromptStudioModel, TemplateEngine, DiffEngine, BlockCompositionSnapshot all have dedicated tests
- **Weak areas:** UI tests are placeholder, no snapshot tests, no accessibility tests, no migration tests, GlobalHotkeyManager untested

### Migration Priority for 3 XCTest Files

These should be migrated to Swift Testing for consistency:
1. `KeychainServiceTests.swift` -- likely straightforward migration
2. `AIServiceTests.swift` -- may have async patterns that need Swift Testing's async support
3. `ProStatusManagerTests.swift` -- may depend on StoreKit test APIs (check if Swift Testing compatible)

---

## Sources & Confidence

| Finding | Source | Confidence |
|---------|--------|------------|
| In-memory ModelContainer pattern | Codebase analysis (already in use) | HIGH |
| Swift Testing framework features | Training data + codebase evidence | HIGH |
| swift-snapshot-testing for macOS | Training data | MEDIUM |
| ViewInspector not recommended | Training data (known fragility issues) | MEDIUM |
| macOS XCUITest window management | Training data | MEDIUM |
| SwiftData migration testing patterns | Training data | MEDIUM |
| Carbon hotkey API testability | Codebase analysis + training data | HIGH |
| Accessibility Inspector workflow | Training data (Apple tooling) | HIGH |
| Coverage targets | Industry standards + project analysis | MEDIUM |
| swift-snapshot-testing + Swift Testing compatibility | Training data only | LOW -- needs validation |
