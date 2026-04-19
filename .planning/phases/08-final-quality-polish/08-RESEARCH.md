# Phase 8: Final Quality & Polish - Research

**Researched:** 2026-04-19
**Domain:** macOS SwiftUI quality engineering — crash scrub, performance profiling, accessibility audit, visual polish
**Confidence:** HIGH (core tooling), MEDIUM (specific targets)

---

## Summary

Phase 8 is a cross-cutting quality pass that must verify the entire app before App Store submission. The four plans address distinct concerns: (1) crash scrub and stability, (2) Instruments-based performance profiling against hard targets (<1s launch, <100ms canvas sync), (3) a full accessibility audit using Xcode 15+ `performAccessibilityAudit()` supplemented by VoiceOver manual pass, and (4) a visual polish/micro-interactions sweep.

The project already has a strong test foundation — ~40 unit test files, dedicated `PerformanceBenchmarkTests`, `AccessibilityTests`, and `KeyboardNavigationTests`. Phase 8 extends this with UI-level automated accessibility audits (XCUIApplication), Instruments profiling sessions for launch time and memory, and targeted SwiftUI animation polish that respects `accessibilityReduceMotion`. This is the final gate before distribution; every plan has a zero-regression bar.

The project runs on macOS 15+ / Xcode 26 / macOS 26. Instruments 26 adds a dedicated SwiftUI instrument template and an App Launch instrument. The `performAccessibilityAudit()` API (introduced Xcode 15) is the correct automated tool for the accessibility plan. Animation micro-interactions must use spring parameters calibrated for "delightful but subtle" and must always guard on `@Environment(\.accessibilityReduceMotion)`.

**Primary recommendation:** Run all four plans sequentially — bugs before performance before accessibility before polish — because bug fixes can invalidate perf benchmarks and accessibility attributes.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R8.1 | Comprehensive testing — all tests pass, new tests for Pro features, UI tests for critical flows, edge case testing | Existing ~40 test files; Phase 8 adds UI-level `performAccessibilityAudit()` tests and any missing Pro feature integration tests |
| R8.2 | Accessibility audit — VoiceOver pass, keyboard navigation, accessibility labels on all interactive elements, Reduce Motion | `performAccessibilityAudit(for:)` in XCUITest + manual VoiceOver walkthrough across all 3 surfaces |
| R8.3 | Performance profiling — Instruments for memory leaks, CPU profiling, launch time <2s (phase target <1s), SwiftData query perf | Instruments 26 (SwiftUI template, Leaks, Time Profiler, App Launch); existing `PerformanceBenchmarkTests` baselines |
| R8.4 | UX consistency pass — consistent spacing/typography/color, system-convention animations, clear error states, helpful empty states | SwiftUI `.spring()` parameters, `accessibilityReduceMotion` guard, HIG spacing/typography checklist |
| R1.3 | Block editor accessibility — VoiceOver canvas navigation, keyboard-only workflow, Dynamic Type, color contrast | Already partially covered by `AccessibilityTests.swift`; Phase 8 extends with live UI audit |
| R1.4 | Block editor performance — canvas responsive with 20+ blocks, compiled preview <300ms, slash palette <100ms, stable memory | `PerformanceBenchmarkTests` covers these; Phase 8 validates with Instruments in distribution build |
</phase_requirements>

---

## Standard Stack

### Core
| Tool/Library | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| Xcode Instruments | Xcode 26 | Memory leaks, CPU, launch time, SwiftUI perf | Apple's official profiling toolchain; no alternative on macOS |
| XCUIApplication.performAccessibilityAudit | Xcode 15+ | Automated accessibility audit in UI tests | Apple-native, runs in CI, catches labels/contrast/element-size issues automatically |
| XCTApplicationLaunchMetric | Xcode 15+ | Measures launch time in `measure()` blocks | Already used in `PaultUITests.testLaunchPerformance()` |
| VoiceOver (manual) | macOS 15 | Human review of screen reader UX | Cannot be fully automated; required for 5-star experience |
| Accessibility Inspector | Xcode 26 | Interactive element tree inspection | Companion to automated audit; good for diagnosing failures |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Instruments — Leaks | Xcode 26 | Detect retain cycles and memory leaks | Run manually after each feature area; not automatable in CI |
| Instruments — SwiftUI template | Xcode 26 / Instruments 26 | Identify long view body updates, hitch-causing redraws | New in 2025; first-class tool for SwiftUI perf, replaces ad-hoc Time Profiler usage |
| Instruments — App Launch | Xcode 26 | Visualize dyld, runtime, main() phases | Use for launch time breakdown; targets the <1s hard requirement |
| Instruments — Time Profiler | Xcode 26 | CPU hotspot detection | Canvas operations, SwiftData queries |
| Instruments — Allocations | Xcode 26 | Memory growth during long editing sessions | Validate R1.4 stable memory |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `performAccessibilityAudit()` | A11yUITests (GitHub) | Apple-native is simpler; A11yUITests adds rules but requires SPM dependency |
| Manual Instruments | MetricKit | MetricKit is post-launch production data; Instruments is pre-ship dev tool — use both |

**Installation:** No new packages required. All tooling is built into Xcode 26.

---

## Architecture Patterns

### Recommended Plan Structure

```
08-01-PLAN.md  Final bug scrub + stability
  - Run full test suite, fix any regressions
  - Address deferred issues from STATE.md
  - Validate distribution build (archive + notarize dry-run)

08-02-PLAN.md  Performance profiling + optimization
  - Instruments sessions: App Launch, SwiftUI template, Leaks
  - Validate existing PerformanceBenchmarkTests pass in release config
  - Fix any SwiftData fetch bottlenecks or view body hotspots

08-03-PLAN.md  Accessibility audit + fixes
  - Run performAccessibilityAudit() across all 3 surfaces
  - Manual VoiceOver walkthrough checklist
  - Fix all audit failures + add accessibilityLabel/hint where missing

08-04-PLAN.md  Visual polish + micro-interactions
  - Audit animation consistency: spring params, Reduce Motion guard
  - Empty state / error state review across all views
  - Typography/spacing consistency sweep
```

### Pattern 1: Automated Accessibility Audit in XCUITest

**What:** `XCUIApplication.performAccessibilityAudit(for:)` runs the same checks as Accessibility Inspector programmatically.
**When to use:** Per-view in the UI test target; one test per major surface.

```swift
// Source: https://developer.apple.com/videos/play/wwdc2023/10035/
// Source: https://www.polpiella.dev/xcode-15-automated-accessibility-audits/

@MainActor
func testMainWindowAccessibilityAudit() throws {
    let app = XCUIApplication()
    app.launch()
    // Audit all categories; suppress specific known-acceptable issues
    try app.performAccessibilityAudit { issue in
        // Return true to ignore, false to fail
        // Example: ignore dynamicType on fixed-size badges
        if issue.auditType == .dynamicType,
           issue.element.identifier == "ProBadge" {
            return true
        }
        return false
    }
}

// Surface-specific: navigate to menu bar, then audit
@MainActor
func testMenuBarAccessibilityAudit() throws {
    let app = XCUIApplication()
    app.launch()
    // Navigate to menu bar surface via test launch argument
    app.launchArguments = ["--ui-test-menu-bar"]
    app.launch()
    try app.performAccessibilityAudit()
}
```

**Available audit types** (pass to `for:` parameter using set syntax):
- `.contrast` — color contrast ratios
- `.dynamicType` — text scaling support
- `.sufficientElementDescription` — accessibilityLabel present and non-empty
- `.hitRegion` — tap/click target size
- `.textClipping` — text not truncated where full visibility required
- Pass nothing (default) to run all types.

### Pattern 2: Reduce Motion Guard for Micro-Interactions

**What:** All animations must check `accessibilityReduceMotion` and degrade gracefully.
**When to use:** Every view that applies `withAnimation`, `.animation()`, or custom transitions.

```swift
// Source: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
// Source: https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-the-reduce-motion-accessibility-setting

struct AnimatedView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Preferred: pass nil animation when reduceMotion is true
    var body: some View {
        someContent
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: someState)
    }
}

// For withAnimation call sites — create a helper:
func withOptionalAnimation<Result>(_ animation: Animation = .default, _ body: () throws -> Result) rethrows -> Result {
    if UIAccessibility.isReduceMotionEnabled {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}
// Note: On macOS use NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
// SwiftUI @Environment(\.accessibilityReduceMotion) is preferred — reads correctly on macOS too
```

### Pattern 3: Spring Animation Parameters for "Delightful" Micro-Interactions

**What:** Calibrated spring parameters for common UI events.
**When to use:** Button presses, list item selection, panel expansion, toast appearance.

```swift
// Source: https://dev.to/sebastienlato/micro-interactions-in-swiftui-subtle-animations-that-make-apps-feel-premium-2ldn
// Source: https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)

// Button press / tap confirmation
.animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)

// Panel slide-in / sheet appear
.animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPanelVisible)

// Copy toast pop-in
.animation(.spring(response: 0.3, dampingFraction: 0.65), value: showToast)

// List row hover/select highlight
.animation(.easeOut(duration: 0.12), value: isSelected)

// Block expansion/collapse (canvas)
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
```

**Parameter guidelines:**
- `response`: How fast — 0.18 (snappy tap) → 0.55 (default) → 0.9 (deliberate modal)
- `dampingFraction`: How bouncy — 0.5 (bouncy) → 0.75 (balanced) → 0.95 (subtle)
- Never use `dampingFraction < 0.6` on macOS — macOS HIG favors subtle motion over bounce

### Pattern 4: Instruments Profiling Workflow

**What:** Sequential Instruments sessions to profile before shipping.
**When to use:** 08-02 plan; run against the release-scheme build (Product → Scheme → Edit Scheme → Release).

```
Session order:
1. App Launch instrument → target: pre-main + main() combined < 1s
   - Product → Profile → App Launch template
   - Look for dyld loading bottlenecks, slow static initializers

2. SwiftUI instrument (Instruments 26) → target: no view body > 50ms
   - Filter by "Long View Body Updates" lane
   - Fix: move computations out of body; use lazy/computed caching

3. Leaks instrument → 5-minute editing session
   - Add 20+ blocks, switch views, trigger AI assist, run prompt
   - Zero leaks in final pass

4. Allocations instrument → extended session
   - Grow/shrink canvas, navigate surfaces
   - Look for unbounded growth (R1.4: stable memory)

5. Time Profiler → SwiftData fetch under load
   - Import 100+ prompt library, then navigate/search
   - Identify hot fetch descriptors; add predicates or fetchLimit
```

### Pattern 5: SwiftData Query Optimization

**What:** Reduce fetch cost by adding predicates, fetch limits, and prefetching.
**When to use:** Whenever Instruments Time Profiler shows SwiftData fetch in hot path.

```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-optimize-the-performance-of-your-swiftdata-apps

// GOOD: predicate pushes filter to store layer
var descriptor = FetchDescriptor<Prompt>(
    predicate: #Predicate { $0.isArchived == false },
    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
)
descriptor.fetchLimit = 200

// GOOD: prefetch known-needed relationships in one pass
descriptor.relationshipKeyPathsForPrefetching = [\.tags, \.templateVariables]

// BAD: fetch all, filter in Swift
let all = try context.fetch(FetchDescriptor<Prompt>())
let filtered = all.filter { !$0.isArchived }  // N objects loaded unnecessarily
```

### Pattern 6: XCTApplicationLaunchMetric for CI Launch Gate

**What:** Assert launch time in automated test.
**When to use:** `PaultUITests` — already has `testLaunchPerformance()`, extend to assert baseline.

```swift
// Source: existing PaultUITests.swift testLaunchPerformance()
// Extend to add baseline assertion:
@MainActor
func testLaunchPerformance() throws {
    let metric = XCTApplicationLaunchMetric()
    measure(metrics: [metric]) {
        XCUIApplication().launch()
    }
    // After measuring, check metric.averageMeasurement is reasonable
    // Note: XCTApplicationLaunchMetric does not surface a direct assertion API;
    // use Xcode test result baselines to enforce regression prevention.
    // Set baseline in Xcode after first passing run.
}
```

### Anti-Patterns to Avoid

- **Profiling in Debug config:** Always profile with Release scheme — Debug build performance is not representative of ship build.
- **Skipping manual VoiceOver review:** `performAccessibilityAudit()` catches structural issues but cannot validate content clarity or navigation flow. Manual pass is mandatory.
- **Animating without Reduce Motion guard:** Every `withAnimation` call site must check `accessibilityReduceMotion`. Missing guards are accessibility bugs.
- **Fixing accessibility labels in views instead of models:** Prefer computing labels in the model (as `AccessibilityTests.swift` already tests) so unit tests can verify them without UI hosting.
- **Over-engineering micro-interactions:** macOS HIG favors subtlety. Prefer `dampingFraction > 0.7` and `response < 0.5` for most interactions. Exaggerated bounce reads as cheap.
- **Importing 100-object test data in unit tests:** Performance profiling under realistic load requires manual Instruments sessions or dedicated XCUITest helpers like `ScreenshotDataSeeder`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Accessibility violations check | Custom element tree walker | `app.performAccessibilityAudit()` | Apple's audit covers 10+ rule categories automatically |
| Memory leak detection | Reference counting tracker | Instruments Leaks | Instruments handles ARC graph traversal, generations, backtrace capture |
| Launch time measurement | `Date()` delta in AppDelegate | `XCTApplicationLaunchMetric` + Instruments App Launch | Covers dyld phase that `Date()` cannot measure |
| Animation disable for Reduce Motion | `UserDefaults` flag | `@Environment(\.accessibilityReduceMotion)` | System-provided; automatically syncs with System Preferences |
| Visual regression for polish | Manual screenshot compare | `XCTAttachment` screenshots in UI tests OR existing `ScreenshotTests.swift` | Systematic, CI-friendly |

**Key insight:** Phase 8 is almost entirely about operating existing Apple tooling correctly in the right order against the right build configuration. The primary risk is running Instruments in Debug mode and getting non-representative numbers.

---

## Common Pitfalls

### Pitfall 1: Profiling the Debug Build
**What goes wrong:** Instruments shows 3–5x slower performance than ship build; dev spends hours on phantom bottlenecks.
**Why it happens:** Debug build has extra assertions, no optimization, ASAN overhead.
**How to avoid:** Always switch to Release scheme before profiling: Product → Scheme → Edit Scheme → Run → Build Configuration → Release. Or archive and profile the .app directly.
**Warning signs:** Launch time > 5s in Debug; compilation > 1s in benchmarks.

### Pitfall 2: performAccessibilityAudit() False Positives on Custom Views
**What goes wrong:** Audit fails on `BlockRowView` or `CompositionCanvasView` due to missing labels on internal sub-elements that are intentionally inaccessible.
**Why it happens:** Nested views that are decorative/container get flagged for `sufficientElementDescription`.
**How to avoid:** Use `.accessibilityHidden(true)` on purely decorative elements. Use the audit closure to suppress known-acceptable issues with comments explaining why.
**Warning signs:** Audit fails on SF Symbol icons that are adjacent to labelled buttons.

### Pitfall 3: Reduce Motion Not Tested
**What goes wrong:** `withAnimation` wrapper is added but `accessibilityReduceMotion` path is never exercised; VoiceOver users see animations.
**Why it happens:** Reduce Motion requires enabling in System Preferences → Accessibility → Display → Reduce Motion; developers forget to test this path.
**How to avoid:** Add a UI test that sets `app.launchArguments = ["-UIAccessibilityIsReduceMotionEnabled", "1"]` to force-enable the setting.
**Warning signs:** No test exercises the `reduceMotion == true` branch.

### Pitfall 4: XCTApplicationLaunchMetric Baseline Not Set
**What goes wrong:** `testLaunchPerformance()` runs but Xcode has no baseline to compare against; regressions go undetected.
**Why it happens:** Metric tests require a one-time "set baseline" step in Xcode's test result viewer.
**How to avoid:** After Phase 8's first passing run, right-click the metric result in Xcode → Set Baseline. Commit the `.xctestplan` or baseline file.
**Warning signs:** `testLaunchPerformance` shows yellow warning about missing baseline.

### Pitfall 5: SwiftData Fetch in View Body
**What goes wrong:** `@Query` or manual fetch inside a computed property fires on every view update, causing hitches with large libraries.
**Why it happens:** SwiftUI view bodies re-evaluate on any `@State`/`@Observable` change; if fetch is inside body it re-runs.
**How to avoid:** Fetch once, cache result. Use `@Query` with a predicate (not filter-in-Swift). The Instruments SwiftUI template will highlight the view body as "Long Update" if this is happening.
**Warning signs:** Instruments shows orange/red for a view body correlated with keystrokes in search.

### Pitfall 6: UndoManager / MainActor Crash in UI Tests
**What goes wrong:** UI tests that trigger undo operations crash on macOS 26 with Swift Concurrency + ObjC `UndoManager` interaction.
**Why it happens:** Known project issue from Phase 02 decisions — see STATE.md.
**How to avoid:** UI tests that touch undo must use `@MainActor` class + direct async calls (not `MainActor.run{}` wrappers). Document this in test comments.
**Warning signs:** Crash in `UndoManager` during XCUITest run.

---

## Code Examples

### Accessibility Audit — Three Surfaces

```swift
// Source: https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)

// 08-03 plan: one test class, one test per surface
final class AccessibilityAuditUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMainWindowAudit() throws {
        let app = XCUIApplication()
        app.launch()
        try app.performAccessibilityAudit { issue in
            // Suppress dynamicType on ProBadge (fixed size by design)
            if issue.auditType == .dynamicType,
               issue.element.identifier == "proBadge" {
                return true
            }
            return false
        }
    }

    @MainActor
    func testBlockEditorAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-open-block-editor"]
        app.launch()
        try app.performAccessibilityAudit()
    }
}
```

### Reduce Motion in withAnimation Call Sites

```swift
// Pattern for macOS SwiftUI — add as extension in a shared file
extension View {
    func animateIfAllowed<V: Equatable>(
        _ animation: Animation,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? nil : animation, value: value)
    }
}

// Usage in BlockRowView:
struct BlockRowView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        content
            .animateIfAllowed(
                .spring(response: 0.4, dampingFraction: 0.8),
                value: isExpanded,
                reduceMotion: reduceMotion
            )
    }
}
```

### SwiftData Optimized Fetch

```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-optimize-the-performance-of-your-swiftdata-apps

// In PromptService or a dedicated query helper:
func fetchActivePrompts(limit: Int = 500) throws -> [Prompt] {
    var descriptor = FetchDescriptor<Prompt>(
        predicate: #Predicate<Prompt> { !$0.isArchived },
        sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    descriptor.relationshipKeyPathsForPrefetching = [\.tags]
    return try modelContext.fetch(descriptor)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual Time Profiler for SwiftUI | Instruments SwiftUI template (Xcode 26) | WWDC25 | Direct SwiftUI body update timeline; replaces indirect profiling |
| Ad-hoc VoiceOver testing | `performAccessibilityAudit()` automated in XCUITest | Xcode 15 | Systematic, CI-runnable, catches regressions automatically |
| `UIAccessibility.isReduceMotionEnabled` (UIKit) | `@Environment(\.accessibilityReduceMotion)` (SwiftUI) | SwiftUI 1.0 | Declarative, testable, works cross-platform |
| `spring(response:dampingFraction:blendDuration:)` | `.snappy`, `.bouncy`, `.smooth` convenience APIs (SwiftUI 5) | iOS 17 / macOS 14 | Simpler call sites; also: `spring(duration:bounce:)` new form |

**Deprecated / avoid:**
- `withAnimation(.default)` at call sites with no explicit type — use `.spring()` or `.easeOut()` explicitly for reviewability.
- `UIAccessibility.isReduceMotionEnabled` — use `@Environment(\.accessibilityReduceMotion)` in SwiftUI.
- Profiling with `DYLD_PRINT_STATISTICS` env var — Instruments App Launch template supersedes this.

---

## Open Questions

1. **Liquid Glass / macOS 26 visual changes**
   - What we know: macOS 26 introduces Liquid Glass translucency system (2025 WWDC). Pault targets macOS 15+.
   - What's unclear: Whether Pault's custom `BlockRowView` and `CompositionCanvasView` need any Liquid Glass adaptation for macOS 26 users.
   - Recommendation: In 08-04, visually verify the app on macOS 26 simulator/device. If vibrancy/material usage looks inconsistent with system apps, file a follow-up. Do not block shipping.

2. **ScreenshotDataSeeder reuse for performance testing**
   - What we know: `ScreenshotDataSeeder.swift` exists and populates realistic data for UI tests.
   - What's unclear: Whether the seeder creates large enough dataset (100+ prompts) for meaningful SwiftData performance testing.
   - Recommendation: In 08-02, extend `ScreenshotDataSeeder` to accept a count parameter (e.g., 200 prompts) for the Instruments session; don't block on this.

3. **Carbon global hotkey memory impact**
   - What we know: `GlobalHotkeyManager` uses Carbon (legacy framework) for global hotkeys.
   - What's unclear: Whether Carbon event handler registration creates any background thread memory pressure during Instruments session.
   - Recommendation: Check Leaks for Carbon-related objects specifically; should be negligible but worth verifying.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (unit) + Swift Testing (some files) + XCUITest (UI) |
| Config file | Xcode scheme; no separate test config file |
| Quick run command | `xcodebuild test -scheme Pault -destination 'platform=macOS' -testPlan PaultTests 2>&1 | xcpretty` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R8.1 | All tests pass, Pro feature coverage | unit | Full suite command above | ✅ ~40 test files |
| R8.2 | Automated accessibility audit — main window | UI (XCUITest) | `xcodebuild test -scheme Pault -only-testing PaultUITests/AccessibilityAuditUITests` | ❌ Wave 0 |
| R8.2 | Automated accessibility audit — block editor | UI (XCUITest) | same class, different test | ❌ Wave 0 |
| R8.2 | Automated accessibility audit — menu bar | UI (XCUITest) | same class, different test | ❌ Wave 0 |
| R8.3 | Launch time measurement with baseline | UI (XCUITest) | `xcodebuild test -scheme Pault -only-testing PaultUITests/PaultUITests/testLaunchPerformance` | ✅ PaultUITests.swift |
| R8.3 | Canvas perf 20+ blocks < 300ms | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ✅ PerformanceBenchmarkTests.swift |
| R8.3 | Instruments leak/memory session | manual | Instruments → Leaks template | manual-only (cannot automate Instruments GUI) |
| R8.4 | Reduce Motion: animation disabled | UI (XCUITest) | `xcodebuild test -scheme Pault -only-testing PaultUITests/ReduceMotionUITests` | ❌ Wave 0 |
| R1.3 | Accessibility label format, icons | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ✅ AccessibilityTests.swift |
| R1.4 | Palette filter < 10ms, compile < 300ms | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ✅ PerformanceBenchmarkTests.swift |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests 2>&1 | tail -20`
- **Per wave merge:** Full suite (unit + UI)
- **Phase gate:** Full suite green + Instruments Leaks session clean + manual VoiceOver pass before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `PaultUITests/AccessibilityAuditUITests.swift` — covers R8.2 (automated accessibility audit, all 3 surfaces)
- [ ] `PaultUITests/ReduceMotionUITests.swift` — covers R8.4 (verifies animations disabled when `reduceMotion=true`)
- [ ] Framework install: none needed — XCUITest already in project

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `performAccessibilityAudit(for:_:)` — https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)
- WWDC23 "Perform accessibility audits for your app" — https://developer.apple.com/videos/play/wwdc2023/10035/
- Apple Developer Documentation: `accessibilityReduceMotion` — https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
- Apple Developer Documentation: `spring(response:dampingFraction:blendDuration:)` — https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)
- Apple Developer Documentation: SwiftData performance — https://www.hackingwithswift.com/quick-start/swiftdata/how-to-optimize-the-performance-of-your-swiftdata-apps
- WWDC25 "Optimize SwiftUI performance with Instruments" — https://developer.apple.com/videos/play/wwdc2025/306/

### Secondary (MEDIUM confidence)
- Polpiella.dev "Xcode 15: Automated accessibility audits" (verified against Apple docs) — https://www.polpiella.dev/xcode-15-automated-accessibility-audits/
- HackingWithSwift "How to detect the Reduce Motion accessibility setting" — https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-the-reduce-motion-accessibility-setting
- SwiftUI micro-interactions spring parameters — https://dev.to/sebastienlato/micro-interactions-in-swiftui-subtle-animations-that-make-apps-feel-premium-2ldn
- SwiftData performance blog (Jacob Bartlett) — https://blog.jacobstechtavern.com/p/high-performance-swiftdata

### Tertiary (LOW confidence)
- Instruments 26 App Launch AI-powered bottleneck detection claim — from web search only, not verified against official Xcode 26 release notes; flag if Instruments behavior differs.

---

## Metadata

**Confidence breakdown:**
- Standard stack (Instruments, XCUITest, accessibilityReduceMotion): HIGH — Apple first-party tooling, stable APIs
- Architecture/patterns (spring params, audit types, SwiftData optimization): HIGH — verified with official docs and WWDC
- Pitfalls (Debug config profiling, Reduce Motion not tested, baseline not set): MEDIUM — derived from known project decisions (STATE.md) and common community patterns
- Liquid Glass / macOS 26 visual impact: LOW — WWDC25 reference, project targets macOS 15+ so impact is forward-looking only

**Research date:** 2026-04-19
**Valid until:** 2026-06-01 (stable Apple APIs; Spring parameter guidance is stable indefinitely; Instruments 26 features stable post-WWDC25)
