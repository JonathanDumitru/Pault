# Phase 15: UX Polish - Research

**Researched:** 2026-04-27
**Domain:** SwiftUI macOS — error UX, AI curation refresh, screenshot Pro-override
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UX-01 | ProxyConfig.baseURL shows proper onboarding/error UI when no proxy URL is configured before first AI call | `ProxyConfig.isConfigured` already exists; need to intercept in `buildRequest` or at call-site views before the network call fires |
| UX-02 | AI-curated collection refresh button present in sidebar | `SidebarView` already shows `lastRefreshed` timestamp for `.aiCurated` collections; need a Refresh button that re-runs `AIService.clusterPrompts` and updates `promptIDs` + `lastRefreshed` |
| UX-03 | Screenshot capture can show Pro features via ProStatusManager override | `ProStatusManager.shared.isProUnlocked` is a `private(set)` property; need a seeding path (launch argument) that sets it to `true` without a real StoreKit transaction |
</phase_requirements>

---

## Summary

Phase 15 addresses three isolated UX gaps: a missing proxy-not-configured error surface (UX-01), a missing refresh trigger for AI-curated Smart Collections (UX-02), and the inability to capture Pro-gated UI in automated screenshots (UX-03).

**UX-01** is the most user-visible: when `ProxyConfig.isConfigured` is `false` (the default `PLACEHOLDER` URL), any AI call silently fails with an opaque HTTP error or network error. The fix is to check `isConfigured` at the call site before making the network request and surface a descriptive UI — either an inline message or a sheet directing the user to Preferences > AI > Proxy URL.

**UX-02** is a pure SwiftUI view addition. The `SmartCollectionEditorView` already has the full AI clustering logic (`AIService.shared.clusterPrompts`). The sidebar already shows the `lastRefreshed` timestamp. The only missing piece is a Refresh button in the sidebar that re-runs the same logic for an existing AI-curated collection and updates its `promptIDs` and `lastRefreshed`.

**UX-03** requires a lightweight Pro-status override that activates when `--screenshot-mode` is present. `ProStatusManager.isProUnlocked` is `private(set)`, so the seeder needs either a dedicated method (`setProStatusForScreenshots()`) or the property scope relaxed to `internal` for the test target. The launch-argument pattern already used by `ScreenshotDataSeeder` is the right model.

**Primary recommendation:** Implement all three as targeted, surgical changes — no new abstractions needed. Each change is 20-50 lines of Swift.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ | All view changes | Already used throughout app |
| SwiftData | macOS 14+ | `SmartCollection` model updates | Already used |
| StoreKit | macOS 14+ | `ProStatusManager` | Already used |

No new dependencies. All three requirements are pure Swift/SwiftUI modifications to existing files.

---

## Architecture Patterns

### UX-01: Proxy Not Configured — Error Surface

**What:** Guard `!ProxyConfig.isConfigured` before any AI network call and present a clear error UI.

**Where to intercept:** Two options — choose the view-layer approach for UX-01:

**Option A — View-layer guard (recommended for UX-01)**

Check `ProxyConfig.isConfigured` at the view level before invoking `AIService`. Shows a persistent contextual message with a link to Preferences.

Applicable call sites:
- `AIAssistPanel` — `runImprove()`, `VariablesTabContent`, `TagsTabContent`, `ScoreTabContent`
- `SmartCollectionEditorView` — `generateWithAI()`
- `RefinementLoopView`

The cleanest place is a shared computed property or `@ViewBuilder` helper used in `AIAssistPanel.body` (similar to the existing `noKeyStateView`):

```swift
// In AIAssistPanel
private var isProxyConfigured: Bool {
    ProxyConfig.isConfigured
}

private var noProxyStateView: some View {
    VStack(spacing: 12) {
        Image(systemName: "network.slash")
            .font(.title2)
            .foregroundStyle(.secondary)
        Text("Proxy URL not configured")
            .font(.subheadline).fontWeight(.medium)
        Text("Add your proxy URL in Preferences → AI → Proxy Infrastructure before using AI features.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 260)
        Button("Open Preferences") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        .buttonStyle(.bordered)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
}
```

Guard priority (first match wins):
1. `!isProxyConfigured` → `noProxyStateView`
2. `!hasAnyAPIKey` → existing `noKeyStateView`
3. Normal tab content

**Option B — Service-layer throw (alternative)**

Add `missingProxyURL` to `AIError` and throw from `buildRequest` when `!ProxyConfig.isConfigured`. Callers already catch and display `error.localizedDescription`, but the message is generic. Less targeted UX — not recommended for this requirement.

**SmartCollectionEditorView** — similarly, add a guard in `generateWithAI()` body or disable the "Generate with AI" button with a help text when `!ProxyConfig.isConfigured`.

### UX-02: AI-Curated Collection Refresh Button

**What:** A Refresh button in `SidebarView` for each `.aiCurated` collection that re-runs `clusterPrompts` for that collection's prompts and updates `promptIDs` + `lastRefreshed`.

**Where:** The collection row in `SidebarView`, inside the `ForEach(collections)` block, below the existing `lastRefreshed` timestamp label.

**State needed:** Per-collection refresh tracking — a `@State` dictionary keyed by collection `UUID`:

```swift
@State private var refreshingCollectionIDs: Set<UUID> = []
```

**Refresh logic** (mirrors `SmartCollectionEditorView.generateWithAI`):

```swift
private func refreshAICuratedCollection(_ collection: SmartCollection) {
    refreshingCollectionIDs.insert(collection.id)
    let config = AIConfig.defaults[.claude] ?? AIConfig(provider: .claude, model: "claude-opus-4-6")
    let titles = allPrompts.prefix(100).map(\.title)
    Task {
        do {
            let suggestions = try await AIService.shared.clusterPrompts(
                titles: Array(titles), config: config
            )
            await MainActor.run {
                // Match by collection name to update the right one
                if let match = suggestions.first(where: { $0.name == collection.name }) {
                    let ids = allPrompts
                        .filter { match.promptTitles.contains($0.title) }
                        .map(\.id)
                    collection.promptIDs = ids
                } else {
                    // Re-cluster produced different names — update with best match or first suggestion
                    // Fallback: keep existing promptIDs, still update lastRefreshed
                }
                collection.lastRefreshed = Date()
                try? modelContext.save()
                refreshingCollectionIDs.remove(collection.id)
            }
        } catch {
            await MainActor.run {
                refreshingCollectionIDs.remove(collection.id)
                // Error can be surfaced inline if desired (optional for this requirement)
            }
        }
    }
}
```

**Button placement** in the collection row (inside the existing `VStack` after `lastRefreshed`):

```swift
if collection.ruleType == .aiCurated {
    HStack(spacing: 4) {
        if let refreshed = collection.lastRefreshed {
            Text("Refreshed \(refreshed, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        Spacer()
        Button {
            refreshAICuratedCollection(collection)
        } label: {
            if refreshingCollectionIDs.contains(collection.id) {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .disabled(refreshingCollectionIDs.contains(collection.id) || !ProxyConfig.isConfigured)
        .help("Refresh AI-curated collection")
    }
    .padding(.leading, 36)
    .padding(.trailing, 8)
}
```

### UX-03: ProStatusManager Override for Screenshots

**What:** When `--screenshot-mode` is present, force `ProStatusManager.shared.isProUnlocked = true` so Pro-gated UI (Smart Collections section, AI Assist, Analytics, API Runner, etc.) renders in screenshots without a real StoreKit transaction.

**Mechanism:** Add a `setOverrideForScreenshots()` method to `ProStatusManager`:

```swift
// In ProStatusManager
#if DEBUG
func setOverrideForScreenshots() {
    isProUnlocked = true
}
#endif
```

Call it from `PaultApp.init()` inside the existing screenshot-mode guard:

```swift
if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
    ScreenshotDataSeeder.seed(context: seedContext)
    Task { @MainActor in
        ProStatusManager.shared.setOverrideForScreenshots()
    }
}
```

**Alternative — launch argument approach (no method needed):**
Read the launch argument directly in `ProStatusManager.refreshStatus()`:

```swift
func refreshStatus() async {
    // Screenshot mode override — no StoreKit needed
    if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
        isProUnlocked = true
        return
    }
    // ... normal StoreKit check
}
```

The second approach is slightly cleaner: no extra method, override is self-contained in `refreshStatus`. Use this one.

**Timing:** `ProStatusManager.init()` calls `Task { await refreshStatus() }`. By the time `PaultApp.init()` seeds data, the Task has not yet run. The `--screenshot-mode` guard in `refreshStatus()` fires when the Task executes — no race condition because `isProUnlocked = true` is set before any UI renders.

**`#if DEBUG` scoping:** The `refreshStatus` modification is behind no flag since it reads a launch argument — it cannot fire in App Store builds (no mechanism to inject launch arguments). No `#if DEBUG` guard is strictly necessary, but adding one is defensive.

### Anti-Patterns to Avoid

- **Adding new enum cases to `AIError`** for UX-01: unnecessary — the guard is purely at view level.
- **Global `@AppStorage` for "proxy configured" state:** `ProxyConfig.isConfigured` is already a static computed property — no need to duplicate.
- **Storing `isRefreshing` as `@State` on the collection model:** Keep refresh state in the parent `SidebarView`, not in `SmartCollection`.
- **Running `clusterPrompts` on the full prompt library for a single-collection refresh:** Limit to `allPrompts.prefix(100)` as the existing `generateWithAI` does.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AI clustering for refresh | New clustering service | `AIService.shared.clusterPrompts` | Already tested, handles markdown stripping, JSON decode |
| Pro status mocking | Separate mock `ProStatusManager` | Launch-arg guard in `refreshStatus()` | Simpler, no protocol indirection needed for 1 use case |
| Proxy URL validation | URL parsing + regex | `ProxyConfig.isConfigured` (already checks for PLACEHOLDER) | Already defined, single source of truth |

---

## Common Pitfalls

### Pitfall 1: ProStatusManager Async Init Race (UX-03)
**What goes wrong:** `ProStatusManager.shared` is created before `PaultApp.init()` completes. If `setOverrideForScreenshots()` is called before `refreshStatus()` runs, `refreshStatus` may overwrite `isProUnlocked = true` with `false`.
**Why it happens:** `init()` spawns `Task { await refreshStatus() }` which runs asynchronously.
**How to avoid:** Put the override check _inside_ `refreshStatus()` as the first guard — it runs after init and is the only write path for `isProUnlocked`.
**Warning signs:** Pro UI does not appear in screenshots even with `--screenshot-mode`.

### Pitfall 2: Refresh Button Visible for Non-AI Collections (UX-02)
**What goes wrong:** Refresh button appears on `.savedFilter` collections.
**Why it happens:** `collection.ruleType` check omitted or placed at wrong nesting level.
**How to avoid:** The entire refresh HStack must be inside `if collection.ruleType == .aiCurated`.

### Pitfall 3: `clusterPrompts` Returns Different Collection Names on Refresh (UX-02)
**What goes wrong:** Re-clustering the same prompts may produce collections with different names. Matching by name fails, leaving `promptIDs` stale.
**Why it happens:** LLM is non-deterministic.
**How to avoid:** For single-collection refresh, consider re-clustering all prompts and matching by name with a case-insensitive comparison. If no match, keep existing `promptIDs` and still update `lastRefreshed`. The requirement only mandates a refresh button that "triggers a new curation request" — it does not require guaranteed name-match fidelity.

### Pitfall 4: `noKeyStateView` vs `noProxyStateView` Priority (UX-01)
**What goes wrong:** Both guards fire but only one displays.
**Why it happens:** Wrong priority order in view body.
**How to avoid:** Check proxy first — a missing proxy URL is a stronger blocker than a missing API key (the proxy is required for Claude and OpenAI; no proxy = no AI regardless of keys).

### Pitfall 5: `SmartCollectionEditorView.generateWithAI` Not Gated (UX-01)
**What goes wrong:** The New Collection sheet's "Generate with AI" button fires even with no proxy configured, showing a confusing network error.
**How to avoid:** Disable the button or show inline text when `!ProxyConfig.isConfigured`.

---

## Code Examples

### Checking ProxyConfig.isConfigured (existing, confirmed)
```swift
// Source: Pault/Services/ProxyConfig.swift
static var isConfigured: Bool {
    !baseURL.contains("PLACEHOLDER")
}
```

### Existing pattern for "no key" guard in AIAssistPanel (confirmed)
```swift
// Source: Pault/AIAssistPanel.swift
var hasAnyAPIKey: Bool {
    for provider in AIConfig.Provider.allCases {
        if let key = try? KeychainService().load(key: "ai.apikey.\(provider.rawValue)"), !key.isEmpty {
            return true
        }
    }
    return false
}
// body: if !hasAnyAPIKey { noKeyStateView } else { ... }
```

### Existing lastRefreshed display in SidebarView (confirmed)
```swift
// Source: Pault/SidebarView.swift
if collection.ruleType == .aiCurated, let refreshed = collection.lastRefreshed {
    Text("Refreshed \(refreshed, style: .relative) ago")
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.leading, 36)
}
```

### Existing screenshot-mode guard in PaultApp.init (confirmed)
```swift
// Source: Pault/PaultApp.swift
if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
    ScreenshotDataSeeder.seed(context: seedContext)
}
```

### ProStatusManager.refreshStatus override point (insertion target)
```swift
// Source: Pault/Services/ProStatusManager.swift — func refreshStatus() line 64
// Insert at top of refreshStatus():
if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
    isProUnlocked = true
    return
}
```

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from `.planning/config.json` — treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (UITests: XCUITest) |
| Config file | Pault.xcodeproj (scheme targets) |
| Quick run command | `xcodebuild test -project Pault.xcodeproj -scheme PaultTests -destination 'platform=macOS' -only-testing:PaultTests` |
| Full suite command | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-01 | `noProxyStateView` appears when `ProxyConfig.isConfigured == false` | Unit (view state) | Manual verification — UI state gate | ❌ Wave 0 |
| UX-02 | Refresh button appears for `.aiCurated` collections in sidebar | Smoke (UITest) | `xcodebuild test ... -only-testing:PaultUITests/ScreenshotTests/testShot04_LibrarySplitView` (after seeding AI collection) | ✅ (existing, needs seed update) |
| UX-03 | `--screenshot-mode` causes `isProUnlocked == true` in screenshot run | UITest (screenshot capture) | `xcodebuild test ... -only-testing:PaultUITests/ScreenshotTests` | ✅ existing |

### Sampling Rate
- **Per task commit:** Build succeeds with no new warnings (`xcodebuild build`)
- **Per wave merge:** Full UITest screenshot suite passes
- **Phase gate:** All 6 screenshots capture Pro-gated UI correctly before marking phase complete

### Wave 0 Gaps
- [ ] No automated unit test for `noProxyStateView` visibility — manual verification sufficient for this requirement scope
- [ ] `ScreenshotDataSeeder.seed()` does not currently create any `.aiCurated` `SmartCollection` — if UX-02 screenshot verification is needed, seed must include one (optional, not required by the requirement text)

---

## Sources

### Primary (HIGH confidence)
- `Pault/Services/ProxyConfig.swift` — `isConfigured`, `baseURL`, `PLACEHOLDER` sentinel
- `Pault/Services/ProStatusManager.swift` — `isProUnlocked`, `refreshStatus()`, `init()` async pattern
- `Pault/Services/AIService.swift` — `clusterPrompts()`, `buildRequest()`, `AIError`
- `Pault/SidebarView.swift` — collection rendering, `lastRefreshed` display
- `Pault/SmartCollectionEditorView.swift` — `generateWithAI()` reference implementation
- `Pault/SmartCollection.swift` — `CollectionRuleType`, `promptIDs`, `lastRefreshed`
- `Pault/AIAssistPanel.swift` — `noKeyStateView` pattern, guard structure
- `Pault/PaultApp.swift` — `--screenshot-mode` handling, `ScreenshotDataSeeder.seed()` call
- `PaultUITests/ScreenshotTests.swift` — launch arguments, existing screenshot test structure
- `Pault/Models/ProFeature.swift` — `isUnlocked` delegates to `ProStatusManager.shared.isProUnlocked`

### Secondary (MEDIUM confidence)
- None needed — all findings are directly from source code

---

## Metadata

**Confidence breakdown:**
- UX-01 implementation path: HIGH — `ProxyConfig.isConfigured` exists, `noKeyStateView` pattern is a direct template
- UX-02 implementation path: HIGH — `generateWithAI` is the exact logic to reuse; sidebar render location confirmed
- UX-03 implementation path: HIGH — `refreshStatus()` is the single write path; launch-arg pattern confirmed in existing code
- Pitfalls: HIGH — derived from direct code inspection

**Research date:** 2026-04-27
**Valid until:** 2026-05-27 (stable codebase, no fast-moving dependencies)
