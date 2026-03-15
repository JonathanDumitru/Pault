# Feature Landscape: Testing & QA for App Store Launch

**Domain:** macOS SwiftUI/SwiftData app -- pre-launch quality assurance
**Researched:** 2026-03-14

## Table Stakes

Features/practices required for a high-quality App Store submission.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Unit tests for all @Model types | SwiftData models are the persistence layer; bugs here cause data loss | Low | Most already covered. Verify cascade deletes, relationship integrity |
| State machine edge case coverage | PromptStudioModel (948 lines) drives the core UX | Med | Add tests for: empty canvas edge cases, rapid add/remove, concurrent compilation |
| Integration tests for copy-to-clipboard | Core product action. Clipboard bugs are immediately visible | Low | Already started in IntegrationTests.swift. Expand edge cases |
| XCUITest for critical launch flow | App must launch, display content, and navigate without crashing | Med | Current PaultUITests.swift is placeholder. Need real smoke tests |
| Performance baseline: launch time | App Store reviewers notice slow launches. Users notice sub-2s | Low | Already measuring via XCTApplicationLaunchMetric. Set a baseline assertion |
| Accessibility labels on interactive elements | App Store review checks basic accessibility. VoiceOver users exist | Med | Audit all buttons, text fields, custom controls for accessibility labels |
| Memory leak testing | macOS apps run for hours/days. Leaks compound | Med | Test with Instruments Allocations. Focus on view model retain cycles |
| SwiftData migration testing | Schema changes between versions must not lose user data | High | Critical if any @Model has changed since last release. Test with staged migrations |

## Differentiators

Practices that elevate quality beyond minimum viable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Snapshot testing for key views | Catches visual regressions automatically. Prevents "it looks wrong" bugs | Med | Focus on: PromptDetailView, BlockEditor canvas, SidebarView, HotkeyLauncherView |
| Parameterized tests for template engine | TemplateEngine handles complex string interpolation; parameterized tests cover many inputs cheaply | Low | Swift Testing `@Test(arguments:)` is perfect for this |
| Performance tests for large prompt collections | Users with 100+ prompts should not see UI lag | Med | Test sidebar rendering, search, and SwiftData fetch performance with seeded data |
| Keyboard shortcut coverage | Power users rely on keyboard shortcuts. Broken shortcuts cause frustration | Low | Verify all *.commands() and keyboard shortcuts trigger expected actions in XCUITest |
| Export/import round-trip tests | Data integrity for export features | Low | Test JSON/file export and re-import preserves all data |
| Concurrency safety verification | @MainActor isolation is used but Sendable compliance should be verified | Med | Swift 6 strict concurrency mode can catch issues at compile time |

## Anti-Features

Testing practices to explicitly NOT pursue.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| 100% code coverage target | Chasing coverage numbers leads to brittle tests that test implementation, not behavior | Target 80%+ on model/service layer, 60%+ overall. Focus on meaningful assertions |
| ViewInspector for every SwiftUI view | Fragile, breaks on SwiftUI updates, poor macOS support | Snapshot test key views. Unit test view models. XCUITest for smoke |
| Mocking SwiftData ModelContext | Over-mocking hides real SwiftData behavior and bugs | Use in-memory ModelContainers (already doing this correctly) |
| Testing private methods directly | Couples tests to implementation. Breaks on refactor | Test through public API. If a private method needs direct testing, it should be extracted to its own type |
| Exhaustive XCUITest for every screen | Slow, flaky, expensive to maintain | XCUITest only for: launch, critical navigation, copy action, hotkey launcher |
| Testing Apple framework behavior | Do not test that SwiftUI `@Published` works or that SwiftData saves | Test YOUR logic. Assume frameworks work correctly |

## Feature Dependencies

```
In-memory ModelContainer helper -> All SwiftData tests
Protocol extraction for GlobalHotkeyManager -> Hotkey testing
Snapshot testing dependency (SPM) -> All snapshot tests
Accessibility identifiers on views -> XCUITest element queries
Shared test fixtures/factories -> Consistent test data across files
```

## MVP Test Suite Recommendation

Prioritize before App Store submission:

1. **PromptStudioModel exhaustive edge cases** -- the highest-risk code path
2. **SwiftData cascade delete tests** -- verify deleting a Prompt cleans up TemplateVariables, Attachments, Versions
3. **XCUITest: launch -> create prompt -> edit -> copy -> verify clipboard** -- the golden path
4. **Accessibility audit** -- one pass with Accessibility Inspector, fix critical issues
5. **Launch performance baseline** -- assert < 2 seconds

Defer:
- Snapshot testing: valuable but not blocking for launch
- Performance tests for large datasets: important for v1.1
- Export/import round-trip: can be post-launch if export feature is not in v1.0

## Sources

- Direct codebase analysis of 29 test files, 10 @Model types, 97 Swift source files
- Existing test patterns in PromptStudioModelTests.swift, IntegrationTests.swift, BlockCompositionSnapshotTests.swift
