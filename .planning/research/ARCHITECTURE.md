# Architecture Patterns: Testing & QA

**Domain:** macOS SwiftUI/SwiftData app testing
**Researched:** 2026-03-14

## Recommended Test Architecture

### Layer Mapping

```
┌─────────────────────────────────────────────────┐
│  XCUITests (PaultUITests target)                │  Smoke tests only
│  - Launch flow, golden path, accessibility      │  ~5-10 tests
├─────────────────────────────────────────────────┤
│  Snapshot Tests (PaultTests target)             │  Visual regression
│  - Key views rendered to NSImage                │  ~15-20 snapshots
├─────────────────────────────────────────────────┤
│  Integration Tests (PaultTests target)          │  Service + model
│  - PromptService + clipboard                    │  ~20-30 tests
│  - TemplateEngine + variables + prompt          │
│  - ExportService + real data                    │
├─────────────────────────────────────────────────┤
│  Unit Tests (PaultTests target)                 │  Bulk of tests
│  - @Model types, PromptStudioModel              │  ~200+ tests
│  - TemplateEngine, DiffEngine, BlockSchema      │
│  - Pure logic, no side effects                  │
└─────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Test Strategy |
|-----------|---------------|---------------|
| SwiftData @Model types (10) | Data persistence, relationships, computed properties | Unit tests with in-memory ModelContainer. Test cascade deletes, relationship integrity, computed property correctness |
| PromptStudioModel | Block editor state machine -- canvas, compilation, sync | Exhaustive unit tests. Every public method, every state transition, every edge case |
| PromptService | CRUD operations, clipboard copy, prompt management | Integration tests with in-memory SwiftData + real pasteboard |
| TemplateEngine | Template variable parsing and resolution | Parameterized unit tests. Many input/output pairs |
| DiffEngine | Prompt version diffing | Unit tests with known diff inputs/outputs |
| GlobalHotkeyManager | System-level hotkey registration (Carbon API) | Extract protocol. Unit test the callback routing. Integration test registration in XCUITest |
| Views (SwiftUI) | UI rendering | Snapshot tests for key views. XCUITest for navigation flows |
| ExportService | File export/import | Integration tests with temp directories |

### Data Flow for Tests

```
Test Setup:
  ModelContainer(isStoredInMemoryOnly: true)
    -> ModelContext
      -> Insert test fixtures
        -> Create model/service under test
          -> Assert behavior

Teardown:
  (automatic -- in-memory container is discarded)
```

## Patterns to Follow

### Pattern 1: In-Memory SwiftData Container Factory

**What:** Shared helper to create test ModelContainers with all required model types
**When:** Every test that touches SwiftData (most tests)
**Why:** Current tests repeat the container creation. A shared factory reduces duplication and ensures all models are registered.

```swift
// TestHelpers/TestModelContainer.swift
import SwiftData
@testable import Pault

enum TestModelContainer {
    @MainActor
    static func make() throws -> ModelContainer {
        try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self,
                 Attachment.self, CopyEvent.self, PromptRun.self,
                 PromptVersion.self, SmartCollection.self,
                 PromptTemplate.self, CustomBlock.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    static func makeContext() throws -> ModelContext {
        ModelContext(try make())
    }
}
```

### Pattern 2: Protocol Extraction for Singletons

**What:** Extract a protocol from GlobalHotkeyManager to enable testing without Carbon APIs
**When:** Testing hotkey callback routing and registration logic

```swift
protocol HotkeyManaging {
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) -> Bool
    func unregister()
}

// Production
extension GlobalHotkeyManager: HotkeyManaging {}

// Test
class MockHotkeyManager: HotkeyManaging {
    var registerCalled = false
    var lastCallback: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) -> Bool {
        registerCalled = true
        lastCallback = callback
        return true
    }

    func unregister() {}
}
```

### Pattern 3: Parameterized Template Tests

**What:** Use Swift Testing `@Test(arguments:)` for template engine edge cases
**When:** Testing TemplateEngine with many input variations

```swift
@Test(arguments: [
    ("Hello {{name}}", ["name": "World"], "Hello World"),
    ("{{a}} and {{b}}", ["a": "X", "b": "Y"], "X and Y"),
    ("No vars here", [:], "No vars here"),
    ("{{missing}}", [:], "{{missing}}"),
    ("{{x}} {{x}}", ["x": "same"], "same same"),
])
func templateResolution(template: String, vars: [String: String], expected: String) {
    let result = TemplateEngine.resolve(template: template, variables: vars)
    #expect(result == expected)
}
```

### Pattern 4: Snapshot Testing for Views

**What:** Render SwiftUI views to NSImage and compare against reference
**When:** Verifying visual appearance of key views

```swift
import SnapshotTesting

@MainActor
@Test func promptDetailView_snapshot() throws {
    let context = try TestModelContainer.makeContext()
    let prompt = Prompt(title: "Test", content: "Hello world")
    context.insert(prompt)

    let view = PromptDetailView(prompt: prompt)
        .frame(width: 800, height: 600)

    assertSnapshot(of: NSHostingView(rootView: view), as: .image)
}
```

### Pattern 5: Clipboard Test Isolation

**What:** Save and restore pasteboard contents around clipboard tests
**When:** Integration tests that write to NSPasteboard

```swift
struct ClipboardTestScope {
    private let savedItems: [NSPasteboardItem]

    init() {
        savedItems = NSPasteboard.general.pasteboardItems?.compactMap { item in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        } ?? []
    }

    func restore() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(savedItems)
    }
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Testing SwiftUI View Body Composition
**What:** Using ViewInspector to assert that a `VStack` contains a `Text` with specific content
**Why bad:** Breaks on every UI refactor. Tests the "how" not the "what". macOS SwiftUI rendering differs from iOS
**Instead:** Snapshot test the rendered output. Test the view model that drives the view.

### Anti-Pattern 2: Shared Mutable Test State
**What:** Reusing a ModelContext or model instance across tests
**Why bad:** Tests become order-dependent. Flaky failures in CI
**Instead:** Each test creates its own in-memory container (already done correctly in existing tests)

### Anti-Pattern 3: Testing Async Debounce Timing
**What:** Testing that `compilationDebounceDelay` fires after exactly 0.3 seconds
**Why bad:** Timing tests are inherently flaky. CI machines have variable performance
**Instead:** Test `compileNow()` directly (synchronous). Test that `scheduleCompilation()` eventually compiles (use expectation with generous timeout). The debounce duration is an implementation detail.

### Anti-Pattern 4: Over-mocking ModelContext
**What:** Creating a mock ModelContext that returns pre-set data
**Why bad:** Hides real SwiftData behavior -- predicate evaluation, relationship loading, save semantics
**Instead:** Use real in-memory ModelContainers. They are fast and test real behavior.

## Scalability Considerations

| Concern | At 50 tests | At 200 tests | At 500+ tests |
|---------|-------------|--------------|---------------|
| Test execution time | < 5s, no concern | 10-20s, still fine | Parallelize with Swift Testing's built-in concurrency |
| Snapshot storage | ~5MB, trivial | ~20MB, watch git size | Consider snapshot pruning script, .gitattributes LFS |
| In-memory containers | Instant creation | Still instant | No concern -- in-memory is always fast |
| XCUITest suite | < 30s | Not applicable (keep XCUITests small) | Never let XCUITest grow this large |
| CI run time | < 1 min | 2-3 min | 5 min max. Parallelize unit and UI test targets |

## Sources

- Codebase analysis: existing test patterns, model architecture, singleton patterns
- Training data: Swift Testing framework patterns, snapshot testing patterns (MEDIUM confidence)
