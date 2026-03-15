# Domain Pitfalls: Testing macOS SwiftUI/SwiftData Apps

**Domain:** macOS app testing -- pre-App Store launch
**Researched:** 2026-03-14

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or App Store rejection.

### Pitfall 1: SwiftData Migration Not Tested Before Release
**What goes wrong:** Schema changes between versions (adding/removing @Model properties, changing relationships) silently corrupt or lose user data on update
**Why it happens:** In-memory test containers always use the latest schema. Developers never test the upgrade path from v1 schema to v2 schema
**Consequences:** Users update the app, existing prompts are lost or corrupted. 1-star reviews, support burden, potential need for emergency patch
**Prevention:**
- Create a versioned schema plan (`VersionedSchema` conformance) even for v1.0
- Write migration tests that: (1) create a store with the old schema, (2) insert test data, (3) migrate to new schema, (4) verify data integrity
- Keep a copy of your v1.0 `.store` file as a test fixture for future migration tests
**Detection:** Run the app with an existing data store after any @Model change. If the app crashes on launch or data is missing, migration is broken.

### Pitfall 2: @MainActor Test Isolation Failures
**What goes wrong:** Tests that create `@MainActor` objects (like PromptStudioModel) fail intermittently in CI because they run on background threads
**Why it happens:** Swift Testing runs tests concurrently by default. If a test struct is not `@MainActor`, the `@MainActor`-isolated init of the model under test may deadlock or fail
**Consequences:** Flaky CI. Tests pass locally but fail in CI (or vice versa)
**Prevention:**
- Always mark test structs `@MainActor` when testing `@MainActor` types (Pault already does this correctly)
- Never use `DispatchQueue.main.async` in tests -- use `@MainActor` annotation instead
- Understand that Swift Testing parallelism + MainActor can cause contention
**Detection:** Tests that fail only in CI or only when run as a full suite (not individually)

### Pitfall 3: Clipboard Tests Pollute System State
**What goes wrong:** Tests that write to `NSPasteboard.general` overwrite the user's clipboard content during test runs
**Why it happens:** `NSPasteboard.general` is the actual system clipboard. Unlike iOS, macOS tests run in the same pasteboard environment
**Consequences:** Developer frustration (lost clipboard), potential test interference when tests run in parallel
**Prevention:**
- Save and restore clipboard contents before/after clipboard tests
- Consider using a custom `NSPasteboard(name:)` for unit tests where possible (won't work for integration tests that go through PromptService)
- Accept that integration-level clipboard tests will touch the system clipboard
**Detection:** Running tests and noticing your clipboard contents changed

### Pitfall 4: GlobalHotkeyManager Cannot Be Tested Without Refactoring
**What goes wrong:** Attempting to test hotkey registration calls Carbon `RegisterEventHotKey` which requires a running event loop and may fail or cause side effects in test process
**Why it happens:** `GlobalHotkeyManager.shared` is a singleton that directly calls Carbon APIs. No seam for testing
**Consequences:** Either no test coverage for hotkey logic, or flaky tests that depend on system state
**Prevention:**
- Extract a `HotkeyManaging` protocol (see ARCHITECTURE.md Pattern 2)
- Inject the dependency instead of using `.shared` directly
- Test the callback routing logic with a mock. Test actual registration only in XCUITest (where the app is running normally)
**Detection:** Tests that call `GlobalHotkeyManager.shared.register(...)` and fail with obscure Carbon errors

## Moderate Pitfalls

### Pitfall 1: Snapshot Tests Break on macOS Version Updates
**What goes wrong:** Snapshot reference images generated on macOS 14 fail on macOS 15 due to font rendering, spacing, or theme changes
**Prevention:**
- Pin snapshot tests to a specific macOS version in CI
- Use `perceptualPrecision` parameter in snapshot assertions to allow small rendering differences (e.g., 0.98 instead of exact match)
- Regenerate snapshots after each macOS major version update
- Consider using `.dump` strategy (text representation) for layout tests instead of `.image` for less brittle assertions

### Pitfall 2: XCUITest Cannot Find Elements in Secondary Windows
**What goes wrong:** XCUIElement queries only search the main window by default. HotkeyLauncherWindow, preferences, and other secondary windows require explicit window targeting
**Prevention:**
- Use `app.windows["WindowIdentifier"]` to target specific windows
- Set `.accessibilityIdentifier()` on window content views
- Be aware that `.sheets()` and `.popovers()` have different query patterns on macOS vs iOS

### Pitfall 3: SwiftData Fetch Descriptors in Tests Miss Predicate Issues
**What goes wrong:** Tests use simple fetches (fetch all) but production code uses filtered FetchDescriptors with predicates. Predicate bugs are not caught
**Prevention:**
- Write tests that exercise the actual predicates used in production (e.g., filtering by `isFavorite`, `isArchived`, date ranges)
- Test predicate edge cases: empty results, special characters in search strings, nil optionals

### Pitfall 4: Testing @Published Property Changes Requires Async Awareness
**What goes wrong:** Test asserts a `@Published` property immediately after calling a method that triggers debounced compilation, but the value hasn't updated yet
**Prevention:**
- Use `compileNow()` in tests instead of `scheduleCompilation()` (already done correctly in existing tests)
- For properties that update via Combine pipelines, use `values` async sequence or `sink` with expectation
- Avoid `Thread.sleep` -- use proper async waiting mechanisms

### Pitfall 5: Test Target Does Not Include All Needed Source Files
**What goes wrong:** `@testable import Pault` cannot access certain types because they are in a different module or target
**Prevention:**
- Verify all @Model types and services are in the Pault target (not only in PaultCore or other modules)
- If using PaultCore as a separate module, it needs its own test target (which exists: PaultCoreTests)

## Minor Pitfalls

### Pitfall 1: Forgetting to Test Codable Round-Trips for BlockCompositionSnapshot
**What goes wrong:** A change to BlockCompositionSnapshot's stored properties silently breaks JSON deserialization of existing data
**Prevention:** Already have round-trip tests (BlockCompositionSnapshotTests). Ensure every property is covered and add a test with a known JSON fixture string.

### Pitfall 2: Test File Naming Inconsistency
**What goes wrong:** Tests for `Prompt` model are spread across PaultTests.swift, PromptServiceTests.swift, and IntegrationTests.swift with no clear organization
**Prevention:** Adopt naming convention: `[TypeUnderTest]Tests.swift`. Move prompt-related tests from PaultTests.swift to PromptTests.swift.

### Pitfall 3: Missing CopyEvent and PromptRun in Test Container
**What goes wrong:** In-memory container does not include CopyEvent or PromptRun, causing silent failures when code tries to insert these
**Prevention:** The shared TestModelContainer factory (ARCHITECTURE.md Pattern 1) should include ALL @Model types. Current tests include most but some files may miss a type.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Test infrastructure setup | swift-snapshot-testing may have breaking changes in latest version | Pin to specific version in Package.swift. Check release notes before adopting |
| SwiftData model testing | Missing models in container registration | Use shared factory that registers all 10 @Model types |
| PromptStudioModel testing | 948 lines means many state combinations to test | Prioritize by risk: canvas operations > compilation > UI state > library seeding |
| Clipboard integration testing | System pasteboard pollution | Save/restore pattern or accept the trade-off for integration tests |
| XCUITest for macOS | Window management, menu bar testing, sheet detection | Use explicit window queries. Test menu items via `app.menuBars` |
| Accessibility testing | Accessibility Inspector findings may require view changes | Budget time for fixing issues, not just finding them |
| Performance testing | Baselines vary by machine | Set generous thresholds. Use relative metrics (% regression) not absolute |
| GlobalHotkeyManager testing | Carbon API calls in test process | Protocol extraction + mock. Only test real registration in XCUITest |

## Sources

- Codebase analysis: existing test patterns, singleton usage, SwiftData model structure
- Training data: macOS testing gotchas, Swift Testing concurrency model, SwiftData migration patterns (MEDIUM confidence)
