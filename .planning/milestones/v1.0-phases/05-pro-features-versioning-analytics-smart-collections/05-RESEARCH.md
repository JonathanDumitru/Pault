# Phase 5: Pro Features — Versioning, Analytics & Smart Collections - Research

**Researched:** 2026-04-09
**Domain:** SwiftUI/SwiftData on macOS — version diffing, Swift Charts analytics, dynamic predicate filtering
**Confidence:** HIGH (all key patterns verified from codebase + official Apple documentation sources)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Version Capture Triggers**
- Versions created on explicit save (Cmd+S or navigate-away Save dialog) — not debounced or auto-timed
- AI auto-snapshots from Phase 4 continue unchanged (source-labeled: 'ai-improve', 'ai-variable-accept', etc.)
- Auto-generated change note labels: "Manual save", "Before AI Improve", "Restored from {date}" — no user prompt for notes
- Keep existing version limit: 50 per prompt (configurable 5-200 in Preferences via `versionHistoryLimit` AppStorage)
- Snapshots capture content + metadata only (title, content, tags, variables, favorite) — no block-level composition data

**Version History Presentation**
- Flat chronological list (newest first) with subtle date headers (Today, Yesterday, etc.) — not a timeline or grouped cards
- Lives in the inspector panel (right sidebar) as a collapsible section alongside tags and stats
- Colored source badges on each version row: AI = purple, Manual = blue, Restore = orange — small pill badges next to the date
- Search bar for filtering versions by change note or date (already implemented)
- Compare mode for selecting two versions (already implemented, now enhanced for V2V)
- No dedicated keyboard shortcut — use inspector toggle

**Version Diff UX**
- True version-to-version comparison: when user selects two versions in compare mode, diff those two versions directly (not just against current prompt)
- PromptDiffView accepts either (version, prompt) for version-vs-current or (version1, version2) for V2V
- Default to side-by-side mode (existing default preserved)
- Synchronized scrolling between the two panels in side-by-side mode
- Restore from V2V comparison: both sides show "Restore This Version" button; user picks which version to restore to current
- Restore flow unchanged: snapshot current state first ("Before restore"), apply version, snapshot restored state ("Restored from {date}")
- Granular restore with field selection (title, content, tags, variables, favorite) — already implemented

**Analytics Dashboard**
- Enhanced AnalyticsView: line chart (Swift Charts) for total usage over time + existing ranked prompt list + per-prompt drill-down
- Date range picker: 7 / 30 / 90 days segmented control
- Token consumption totals: aggregate inputTokens + outputTokens from PromptRun, display per-prompt and in overview summary
- No cost estimation (deferred per Phase 4 decision)
- Per-prompt drill-down: clicking a row shows the existing PromptStatsView bar chart with token breakdown
- Access: sheet from toolbar chart icon (existing pattern, just richer content)

**Analytics Event Tracking**
- Extend event tracking beyond CopyEvent: add prompt created, edited (version saved), and deleted events
- Claude decides implementation approach (extend CopyEvent into generic UsageEvent with type enum, or separate models)
- All data stored locally — no telemetry

**Smart Collection Filters**
- Extend SmartCollectionFilter with: qualityScoreMin/Max (Int?), model (String?), lastUsedWithin (Int? days), contentContains (String?)
- All filter criteria AND together — no OR/NOT logic builder
- Editor: simple form with pickers/toggles (extend existing SmartCollectionEditorView)
- Keep both creation paths: saved filter form + AI-curated clustering (existing)

**Smart Collection Behavior**
- Saved filter collections evaluate in real-time (SwiftData @Query with dynamic predicate) — always current
- AI-curated collections stay static until user clicks 'Refresh' — lastRefreshed timestamp shown
- Count badges on sidebar rows showing number of matching prompts
- 3 preset collections auto-created on first Pro unlock: "Most Used" (top 10 by usage), "Recently Created" (last 7 days), "Stale Prompts" (not used in 30+ days)
- All presets deletable/editable by user

### Claude's Discretion
- Analytics event model architecture (extend CopyEvent vs new model)
- Swift Charts implementation details (chart style, colors, animations)
- Synchronized scrolling implementation approach
- Date header grouping logic in version list
- Preset collection creation timing and migration
- Smart collection predicate construction from filter fields
- Inspector panel layout for version history section

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R3.1 | Version history view with diff summaries; browse and compare any two versions | PromptVersionHistoryView + PromptDiffView already built; add date grouping, source badges, V2V mode |
| R3.2 | Restore any previous version non-destructively (creates new version) | performRestore() in PromptDiffView already implemented; extend for V2V dual-restore buttons |
| R3.3 | Side-by-side or inline diff view; highlights additions/deletions | DiffEngine + PromptDiffView functional; add V2V init path and synchronized scrolling |
| R4.1 | Analytics dashboard with usage stats, visual charts, date range filter | AnalyticsView + AnalyticsService exist; add Swift Charts LineMark, date range segmented control |
| R4.2 | Track copy, creation, editing, deletion events locally | CopyEvent exists; new UsageEvent model with EventType enum recommended |
| R4.3 | Auto-generated + user-created smart collections that update dynamically | SmartCollection + SmartCollectionEditorView exist; add new filter fields, count badges, 3 presets |
</phase_requirements>

---

## Summary

Phase 5 is predominantly a **enhancement and extension phase**, not greenfield. Every major component exists — `PromptVersion`, `PromptVersionHistoryView`, `PromptDiffView`, `AnalyticsService`, `AnalyticsView`, `SmartCollection`, `SmartCollectionEditorView` — and the work is adding capabilities on top of proven foundations.

The three sub-systems are largely independent of each other and map cleanly to three plans: (1) complete versioning by adding `source` field to `PromptVersion`, enhancing the diff view for V2V mode with synchronized scrolling, and adding date headers + source badges to the history list; (2) extend analytics with a Swift Charts line chart and new event types; (3) add four new filter fields to `SmartCollectionFilter`, wire count badges in the sidebar, and create the three preset collections on first Pro unlock.

**Primary recommendation:** Treat each plan as self-contained SwiftData model extension + view enhancement. No new architectural patterns needed — all three plans follow established project conventions.

---

## Standard Stack

### Core (already in use — no new dependencies)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | macOS 14+ | Persistence layer, @Model types | Already used for all models; `@Query` + `ModelContext` pattern established |
| SwiftUI | macOS 14+ | All UI views | Every view in the project; established patterns throughout |
| Swift Charts | macOS 13+ | Line chart in AnalyticsView | Apple-native, zero-dependency, fits "native/clean" aesthetic requirement |
| Swift Testing | Xcode 16+ | Unit tests | Already in use (`@Test`, `#expect`, `@MainActor struct`) throughout PaultTests |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| OSLog (`Logger`) | macOS 12+ | Structured logging | Already used in all services; continue pattern for new code |
| Foundation Calendar | stdlib | Date grouping (Today/Yesterday), date arithmetic | Required for version date headers and analytics date range |

### No New Dependencies Required
All three plans use exclusively existing dependencies. Do not add any third-party libraries.

**No installation step needed** — all frameworks already linked.

---

## Architecture Patterns

### Recommended Project Structure (additions only)
```
Pault/
├── PromptVersion.swift          # Add `source: VersionSource` field
├── PromptVersionHistoryView.swift  # Add date grouping, source badges
├── PromptDiffView.swift         # Add V2V init, sync scroll, dual restore
├── CopyEvent.swift              # Replace with UsageEvent (or extend) — see Plan 02
├── AnalyticsService.swift       # Add token aggregation, new event queries
├── AnalyticsView.swift          # Add LineMark chart + date range picker
├── SmartCollection.swift        # Extend SmartCollectionFilter struct
├── SmartCollectionEditorView.swift  # Add new filter fields
└── SidebarView.swift            # Add count badges, preset seeding
```

### Pattern 1: SwiftData Model Extension with Migration Safety

**What:** Adding a new stored property to an existing `@Model` class requires adding a default value so SwiftData can handle existing rows without a migration plan.

**When to use:** Adding `source: VersionSource` to `PromptVersion`, new filter fields to `SmartCollectionFilter` (Codable struct — no migration needed), new event model.

**Rule:** `@Model` stored properties must have defaults. `Codable` structs (like `SmartCollectionFilter`) serialized to JSON can add `var field: Type?` with nil default — existing JSON decodes without error since `JSONDecoder` ignores unknown keys by default.

```swift
// Source: PromptVersion.swift — adding field with default
@Model final class PromptVersion {
    // existing fields...
    var source: String = "manual"  // raw-value-backed enum for SwiftData compatibility

    var versionSource: VersionSource {
        get { VersionSource(rawValue: source) ?? .manual }
        set { source = newValue.rawValue }
    }
}

enum VersionSource: String {
    case manual = "manual"
    case aiImprove = "ai-improve"
    case aiVariableAccept = "ai-variable-accept"
    case restore = "restore"
}
```

**Confidence:** HIGH — this is the established project pattern (see `editingModeRaw`/`editingMode` in `Prompt.swift`).

### Pattern 2: V2V Diff — Dual Init for PromptDiffView

**What:** `PromptDiffView` currently takes `(version: PromptVersion, prompt: Prompt)`. V2V comparison needs `(version1: PromptVersion, version2: PromptVersion)`.

**Approach:** Add a second initializer. Store the diff target as an enum internally.

```swift
// Source: PromptDiffView.swift pattern — new enum to model diff target
enum DiffTarget {
    case againstCurrent(PromptVersion, Prompt)
    case versionToVersion(older: PromptVersion, newer: PromptVersion)
}

struct PromptDiffView: View {
    let target: DiffTarget

    // Computed helpers
    private var leftTitle: String {
        switch target {
        case .againstCurrent(let v, _): return "Version \(v.savedAt.formatted(...))"
        case .versionToVersion(let older, _): return "Version A \(older.savedAt.formatted(...))"
        }
    }
    // ...
}
```

The `openComparison()` in `PromptVersionHistoryView` currently opens single-version diff against current. Extend it to pass both selected versions when in compare mode.

**Confidence:** HIGH — DiffEngine.diff(old:new:) is already stateless; it only needs two strings.

### Pattern 3: Synchronized Scrolling (macOS 15 / iOS 18+)

**What:** Two side-by-side `ScrollView` panels that scroll in lock-step.

**macOS 15 approach (recommended):** Use `scrollPosition(_:)` binding. Both scroll views bind to the same `@State var scrollPosition: ScrollPosition`. This is the native SwiftUI approach available on macOS 15+.

```swift
// Source: Apple Developer Forums + fatbobman.com (verified pattern)
@State private var scrollPosition = ScrollPosition(idType: Int.self)

HStack {
    ScrollView {
        // left content
    }
    .scrollPosition($scrollPosition)

    ScrollView {
        // right content
    }
    .scrollPosition($scrollPosition)
}
```

**Fallback if macOS 15 not available:** The project targets macOS 14+ based on existing code. For macOS 14, use `ScrollViewReader` with `onChangeOf` to programmatically scroll the other panel on offset change — more complex but functional. Given the project is on macOS 26 beta (per STATE.md), the macOS 15+ API is safe.

**Confidence:** MEDIUM — `scrollPosition` binding sharing for sync is a community-discovered pattern; verify it does not cause feedback loops on macOS 26.

### Pattern 4: Swift Charts Line Chart

**What:** Line chart showing daily usage totals over 7/30/90 days.

**Implementation:** `LineMark` + `AreaMark` (for fill under line) inside a `Chart`. Date axis auto-formatted by Swift Charts.

```swift
// Source: Apple Developer Documentation — Swift Charts / LineMark
import Charts

Chart(dailyData, id: \.date) { entry in
    LineMark(
        x: .value("Date", entry.date),
        y: .value("Uses", entry.count)
    )
    .interpolationMethod(.catmullRom)

    AreaMark(
        x: .value("Date", entry.date),
        y: .value("Uses", entry.count)
    )
    .foregroundStyle(.blue.opacity(0.1))
}
.chartXAxis {
    AxisMarks(values: .stride(by: .day, count: stride)) { value in
        AxisValueLabel(format: .dateTime.month().day())
    }
}
.frame(height: 120)
```

Where `stride` is computed: `days <= 7 ? 1 : days <= 30 ? 5 : 14`.

**Data source:** `AnalyticsService.dailyCopies(for:days:)` already returns `[(date: Date, count: Int)]`. Add an equivalent `dailyEvents(days:)` method that aggregates all event types.

**Confidence:** HIGH — LineMark is well-documented in Apple's official Swift Charts documentation.

### Pattern 5: Analytics Event Model (Claude's Discretion — Recommendation)

**Recommendation:** New `UsageEvent` model replacing `CopyEvent`.

**Rationale:** `CopyEvent` is 14 lines and only holds `promptID + timestamp`. Adding `eventType` as an enum and renaming it to `UsageEvent` is cleaner than keeping both models. Migration: the existing `CopyEvent` rows can be treated as `.copy` events — if we add a `UsageEvent` model and keep `CopyEvent` in the container schema, existing data is preserved. Eventually `CopyEvent` becomes read-only legacy data, or all AnalyticsService queries union both types.

**Simpler path:** Add `eventType: String` to `CopyEvent` with default `"copy"`, rename call sites. Keeps one model, zero data loss, backward-compatible.

```swift
// Recommended: Extend CopyEvent in-place
@Model final class CopyEvent {
    var promptID: UUID
    var timestamp: Date
    var eventType: String = "copy"   // "copy" | "created" | "edited" | "deleted"

    var type: UsageEventType {
        get { UsageEventType(rawValue: eventType) ?? .copy }
        set { eventType = newValue.rawValue }
    }
}

enum UsageEventType: String {
    case copy = "copy"
    case created = "created"
    case edited = "edited"
    case deleted = "deleted"
}
```

This follows the exact same pattern as `editingModeRaw`/`editingMode` in `Prompt.swift` — proven, SwiftData-safe, backward-compatible.

**Confidence:** HIGH — matches established project conventions.

### Pattern 6: Dynamic SmartCollection Predicate via Subview Injection

**What:** `SmartCollectionFilter` will gain new fields. Evaluation happens in `SidebarView.filteredPrompts` (computed property on `@Query` result). The existing implementation already filters in memory after `@Query` fetches all non-archived prompts.

**Current approach is correct** for the new fields too. `qualityScore` is a field on `Prompt` (added by Phase 4 AI quality scoring). `model` matches against `PromptRun.model`. `contentContains` is a string search on `prompt.content`. `lastUsedWithin` filters `prompt.lastUsedAt`.

**No dynamic `#Predicate` construction is needed** — the existing in-memory filter approach in `filterPrompts(_:collection:)` in `PromptService` is the right pattern. Just extend the `switch case .savedFilter:` block with the new fields.

```swift
// Source: Pault/PromptService.swift — extend existing pattern
case .savedFilter:
    guard let filter = collection.filter else { return [] }
    var result = prompts.filter { !$0.isArchived }
    if filter.onlyFavorites { result = result.filter(\.isFavorite) }
    if let days = filter.recentDays {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        result = result.filter { ($0.lastUsedAt ?? .distantPast) >= cutoff }
    }
    if !filter.tagIDs.isEmpty { /* existing */ }
    // New fields:
    if let minScore = filter.qualityScoreMin {
        result = result.filter { ($0.qualityScore ?? 0) >= minScore }
    }
    if let days = filter.lastUsedWithin {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        result = result.filter { ($0.lastUsedAt ?? .distantPast) >= cutoff }
    }
    if let content = filter.contentContains, !content.isEmpty {
        result = result.filter { $0.content.localizedCaseInsensitiveContains(content) }
    }
    if let model = filter.model, !model.isEmpty {
        // Requires cross-referencing PromptRun — check separately via AnalyticsService
    }
    return result
```

**Note on `model` filter:** Filtering by model requires knowing which prompts have been run with a given model. This cannot be done purely on `Prompt` — it needs a lookup via `PromptRun`. The filter should call `AnalyticsService.promptIDsRunWith(model:)` and intersect the result. This is a slightly heavier operation but still in-memory.

**Confidence:** HIGH — existing pattern in PromptService already handles complex filtering; extension is straightforward.

### Pattern 7: Smart Collection Count Badges

**What:** Show count of matching prompts on each sidebar collection row.

**Current state:** `FilterRow` in `SidebarView` already accepts `count: Int?`. Smart collection rows pass `count: nil`. Phase 5 adds a count.

**Implementation:** Add a computed dictionary `[UUID: Int]` to `SidebarView` that maps each collection's ID to its matching prompt count. Compute lazily from `filteredPrompts` logic applied to each collection.

```swift
// Source: SidebarView.swift — extend existing FilterRow usage
private var collectionCounts: [UUID: Int] {
    let service = PromptService(modelContext: modelContext)
    return Dictionary(uniqueKeysWithValues: collections.map { collection in
        (collection.id, service.filterPrompts(allPrompts, collection: collection).count)
    })
}
```

**Performance consideration:** This runs on every view update with `allPrompts` as the source. For typical prompt libraries (< 1000 prompts), this is negligible. With 10+ smart collections this could add up — but the project is scoped to normal usage and the in-memory filter is O(n) per collection.

**Confidence:** HIGH — pattern is already in place; just plumbing the count through.

### Anti-Patterns to Avoid
- **Dynamic `#Predicate` construction for new SmartCollectionFilter fields:** SwiftData `#Predicate` is compile-time only — constructing predicates at runtime is complex and unnecessary here since in-memory filtering already works.
- **New `@Model` fields without defaults:** Causes SwiftData migration failures. Always provide a default value.
- **Calling `AnalyticsService` outside `@MainActor`:** The service is `@MainActor final class`. Don't call from background Task without `await MainActor.run`.
- **Sharing `ScrollPosition` state without preventing feedback loops:** When setting one scroll view's position programmatically (in response to the other scrolling), guard with an `isScrolling` flag or use the `onScrollPhaseChange` callback to detect user-initiated vs programmatic scrolls.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Line/character diff | Custom LCS algorithm | `DiffEngine` (already in project) | Already implements LCS + character-level diff with coalescence |
| Analytics date bucketing | Manual date math | `AnalyticsService.dailyCopies(for:days:)` (already exists) | Handles calendar boundaries correctly |
| Smart collection filtering | New predicate system | Extend `PromptService.filterPrompts(_:collection:)` | In-memory filter already handles complex AND logic |
| Version limit enforcement | Manual count + prune | `PromptService.saveSnapshot(for:changeNote:limit:)` (already handles pruning) | Already prunes oldest versions to stay within limit |
| Diff visualization | Custom text view with spans | `DiffEngine.LineDiff` + existing `inlineDiffView`/`sideBySideDiffView` in `PromptDiffView` | 424-line view already handles all rendering cases |

**Key insight:** This phase is ~90% enhancement of existing code. The primary risk is breaking existing behavior by incorrectly extending model types or view initializers.

---

## Common Pitfalls

### Pitfall 1: V2V Diff Direction Confusion
**What goes wrong:** When comparing two historical versions (V2V), the "old" and "new" concepts flip depending on which direction the user wants to see changes. `DiffEngine.diff(old:new:)` treats the first argument as "was" and second as "is now."
**Why it happens:** Current diff always diffs `version.content` (old) against `prompt.content` (new). In V2V, the user selects two arbitrary versions.
**How to avoid:** Sort the two selected versions by `savedAt` ascending. Pass older version content as `old:`, newer as `new:`. Label left panel "Version A (older)" and right panel "Version B (newer)" per the CONTEXT.md spec.
**Warning signs:** Side-by-side shows additions on the left and removals on the right — reversed from expectation.

### Pitfall 2: SwiftData @Model New Field Without Default
**What goes wrong:** Adding `var source: VersionSource` (non-optional, no default) to `PromptVersion` causes a SwiftData migration error on launch for existing installs.
**Why it happens:** Existing rows have no value for the new column.
**How to avoid:** Always use `var source: String = "manual"` with a raw String backing (matching the `editingModeRaw` pattern already in `Prompt.swift`). The computed `versionSource` property provides typed access.
**Warning signs:** App crashes on launch with "NSPersistentStoreCoordinator" error referencing migration.

### Pitfall 3: Synchronized Scroll Feedback Loop
**What goes wrong:** Updating ScrollView B's position in response to ScrollView A's scroll triggers ScrollView A to update again, creating an infinite loop.
**Why it happens:** `scrollPosition` binding changes in both directions when shared naively.
**How to avoid:** Use `onScrollPhaseChange` to distinguish user-initiated scrolls from programmatic ones. Only propagate when the source is `.interacting`.
**Warning signs:** App freezes or scrolling becomes jerky/unusable in side-by-side diff view.

### Pitfall 4: CopyEvent Backward Compatibility
**What goes wrong:** If `CopyEvent` is deleted and replaced with a new `UsageEvent` model, existing `CopyEvent` rows are lost on the next app launch since the container schema no longer includes `CopyEvent`.
**Why it happens:** SwiftData removes tables for model types removed from the container schema.
**How to avoid:** Extend `CopyEvent` in place by adding `var eventType: String = "copy"`. Keep `CopyEvent` in the container schema. Existing data is preserved and interpreted as `.copy` events.
**Warning signs:** Analytics show 0 copy history after Phase 5 ships.

### Pitfall 5: Smart Collection Preset Seeding Race Condition
**What goes wrong:** Presets are seeded multiple times if the seeding logic runs before the first Pro status check completes.
**Why it happens:** ProStatusManager.refreshStatus is async; if seeding runs during app launch before status is confirmed, it may run before or after Pro is verified.
**How to avoid:** Seed presets only after `ProFeature.isUnlocked(.smartCollections)` returns true AND no collections with `isPreset == true` exist. Add an `isPreset: Bool = false` field to `SmartCollection` so presets are identifiable and not re-seeded.
**Warning signs:** Duplicate "Most Used", "Recently Created", "Stale Prompts" collections appear in sidebar.

### Pitfall 6: AnalyticsService Token Aggregation — Nil Handling
**What goes wrong:** `PromptRun.inputTokens` and `outputTokens` are `Int?`. Summing with `reduce` that ignores nil produces correct but potentially misleading totals (runs without token data skipped silently).
**Why it happens:** Not all runs have token data (e.g., Ollama or early runs before Phase 4).
**How to avoid:** Sum with `compactMap` + `reduce`. Display "N/A" or "~" prefix if any runs in the period had nil tokens. This is transparent to the user.

---

## Code Examples

Verified patterns from existing codebase and official sources:

### Version Source Badge (pill style — matches existing TagPillView pattern)
```swift
// Source: Pault/TagPillView.swift — reuse pill shape, parameterize color
struct VersionSourceBadge: View {
    let source: VersionSource

    private var label: String {
        switch source {
        case .manual: return "Manual"
        case .aiImprove, .aiVariableAccept, .aiAutoTag: return "AI"
        case .restore: return "Restore"
        }
    }

    private var color: Color {
        switch source {
        case .manual: return .blue
        case .aiImprove, .aiVariableAccept, .aiAutoTag: return .purple
        case .restore: return .orange
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
```

### Date Section Headers in Version List
```swift
// Source: Foundation Calendar — established pattern
private func sectionLabel(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
        return date.formatted(.dateTime.weekday(.wide))
    }
    return date.formatted(.dateTime.month().year())
}
```

### Token Total Formatting
```swift
// Source: CONTEXT.md spec — "23.4K input | 8.2K output"
func formatTokenCount(_ count: Int) -> String {
    if count >= 1000 {
        let k = Double(count) / 1000.0
        return String(format: "%.1fK", k)
    }
    return "\(count)"
}
```

### Extend SmartCollectionFilter (Codable — migration-safe)
```swift
// Source: Pault/SmartCollection.swift — extend existing Codable struct
struct SmartCollectionFilter: Codable {
    var tagIDs: [UUID]
    var onlyFavorites: Bool
    var recentDays: Int?
    // New fields (all optional — existing JSON decodes without error):
    var qualityScoreMin: Int?
    var qualityScoreMax: Int?
    var model: String?
    var lastUsedWithin: Int?   // days; nil = no filter
    var contentContains: String?
}
```

### Preset Collection Seeding
```swift
// Source: Pattern derived from TemplateSeedService.swift
func seedPresetCollections(in context: ModelContext) {
    // Guard: only seed if Pro and no presets exist yet
    guard ProFeature.isUnlocked(.smartCollections) else { return }
    let descriptor = FetchDescriptor<SmartCollection>(
        predicate: #Predicate { $0.isPreset == true }
    )
    guard (try? context.fetchCount(descriptor)) == 0 else { return }

    let presets: [(name: String, icon: String, SmartCollectionFilter)] = [
        ("Most Used", "flame", SmartCollectionFilter()),          // top 10 by usage — computed at display time
        ("Recently Created", "sparkles", SmartCollectionFilter(recentDays: 7)),
        ("Stale Prompts", "zzz", SmartCollectionFilter(lastUsedWithin: nil)) // custom stale logic
    ]
    // Insert each as SmartCollection with isPreset = true
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| V2V diff opens older version only vs current | V2V diffs two historical versions directly | Phase 5 | User can compare any two historical states without current prompt being the reference |
| CopyEvent only tracks copy actions | UsageEvent (extended CopyEvent) tracks all lifecycle events | Phase 5 | Analytics dashboard can show creation, edit, delete trends |
| SmartCollectionFilter: 3 fields (tags, favorites, recentDays) | +4 new fields (qualityScore, model, lastUsedWithin, contentContains) | Phase 5 | Much richer collection creation capability |
| AnalyticsView: ranked list only | + Swift Charts line chart + date range picker + drill-down | Phase 5 | Visual trend analysis, not just static ranking |
| No preset collections | 3 presets auto-created on first Pro unlock | Phase 5 | Immediate value on upgrade — no manual setup required |

**Deprecated/outdated approach to avoid:**
- `openComparison()` in `PromptVersionHistoryView` currently opens only the older version against current — this is the pre-Phase 5 behavior, replaced by true V2V.
- `count: nil` passed to smart collection sidebar rows — replaced with computed count badges.

---

## Open Questions

1. **`Prompt.qualityScore` field availability**
   - What we know: Phase 4 added AI quality scoring (R2.4); `SmartCollectionFilter.qualityScoreMin/Max` needs to filter on this
   - What's unclear: Whether `qualityScore: Int?` was actually added to the `Prompt` model in Phase 4 plans, or is still a stub
   - Recommendation: Planner should verify `Prompt.swift` contains `qualityScore` field before writing Plan 05-03; if absent, Plan 05-03 must add it or skip that filter

2. **Synchronized scrolling on macOS 15 vs macOS 14 target**
   - What we know: Project is on macOS 26 beta; `scrollPosition` binding API is macOS 15+
   - What's unclear: The project's `IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET` minimum — if set to macOS 14, `scrollPosition` sharing requires `@available` guard
   - Recommendation: Use `if #available(macOS 15, *)` guard around sync scrolling; fall back to independent scrolling on macOS 14 (still correct, just not synchronized)

3. **`model` filter in SmartCollectionFilter — performance path**
   - What we know: Filtering by model requires `PromptRun` lookup; `PromptRun.model` is a String field
   - What's unclear: Whether `AnalyticsService` should grow a `promptIDsRunWith(model:)` method, or if this is fetched ad-hoc in the filter
   - Recommendation: Add `func promptIDsRunWith(model: String) -> Set<UUID>` to `AnalyticsService` and call it in `PromptService.filterPrompts`. Keep it lazy (called only when filter has a model set).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) — already in use throughout PaultTests |
| Config file | None (Xcode scheme handles test target) |
| Quick run command | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/AnalyticsServiceTests` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R3.1 | Version list shows date group headers | unit | `xcodebuild test ... -only-testing:PaultTests/PromptVersionHistoryTests` | ❌ Wave 0 |
| R3.1 | Source badges label correct event types | unit | `xcodebuild test ... -only-testing:PaultTests/PromptVersionTests` | ✅ (extend) |
| R3.2 | V2V restore creates new snapshot correctly | unit | `xcodebuild test ... -only-testing:PaultTests/PromptVersionHistoryTests` | ❌ Wave 0 |
| R3.3 | DiffEngine.diff on two historical versions returns correct hunks | unit | `xcodebuild test ... -only-testing:PaultTests/DiffEngineTests` | ✅ (extend) |
| R4.1 | dailyEvents aggregates all event types | unit | `xcodebuild test ... -only-testing:PaultTests/AnalyticsServiceTests` | ✅ (extend) |
| R4.1 | Token totals aggregate inputTokens + outputTokens from PromptRun | unit | `xcodebuild test ... -only-testing:PaultTests/AnalyticsServiceTests` | ✅ (extend) |
| R4.2 | CopyEvent.eventType defaults to "copy" for existing rows | unit | `xcodebuild test ... -only-testing:PaultTests/Models/CopyEventTests` | ✅ (extend) |
| R4.2 | UsageEventType enum covers all 4 cases | unit | `xcodebuild test ... -only-testing:PaultTests/Models/CopyEventTests` | ✅ (extend) |
| R4.3 | SmartCollectionFilter encodes/decodes new fields with nil defaults | unit | `xcodebuild test ... -only-testing:PaultTests/SmartCollectionTests` | ✅ (extend) |
| R4.3 | filterPrompts applies qualityScoreMin/Max correctly | unit | `xcodebuild test ... -only-testing:PaultTests/SmartCollectionTests` | ✅ (extend) |
| R4.3 | seedPresetCollections creates exactly 3 presets once | unit | `xcodebuild test ... -only-testing:PaultTests/SmartCollectionTests` | ✅ (extend) |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/AnalyticsServiceTests -only-testing:PaultTests/SmartCollectionTests`
- **Per wave merge:** Full suite: `xcodebuild test -scheme Pault -destination 'platform=macOS'`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `PaultTests/PromptVersionHistoryTests.swift` — covers R3.1 (date grouping logic), R3.2 (V2V restore flow)
- [ ] No additional test infrastructure needed — `TestHelpers.makeTestModelContext()` covers all model types already

---

## Sources

### Primary (HIGH confidence)
- Pault codebase (read directly): `PromptVersion.swift`, `PromptVersionHistoryView.swift`, `PromptDiffView.swift`, `AnalyticsService.swift`, `AnalyticsView.swift`, `SmartCollection.swift`, `SmartCollectionEditorView.swift`, `SidebarView.swift`, `InspectorView.swift`, `DiffEngine.swift`, `PromptService.swift`, `Prompt.swift`, `CopyEvent.swift`, `PromptRun.swift`, `ProFeature.swift`, `TestHelpers.swift`
- Apple Developer Documentation — [Swift Charts / LineMark](https://developer.apple.com/documentation/charts)
- Apple Developer Documentation — [Customizing axes in Swift Charts](https://developer.apple.com/documentation/charts/customizing-axes-in-swift-charts)

### Secondary (MEDIUM confidence)
- [fatbobman.com — How to Dynamically Construct Complex Predicates for SwiftData](https://fatbobman.com/en/posts/how-to-dynamically-construct-complex-predicates-for-swiftdata/) — confirmed in-memory filtering is correct approach for complex AND predicates
- [fatbobman.com — The Evolution of SwiftUI Scroll Control APIs](https://fatbobman.com/en/posts/the-evolution-of-swiftui-scroll-control-apis/) — scrollPosition binding pattern for macOS 15+
- [Hacking with Swift — How to dynamically change a query's sort order or predicate](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-dynamically-change-a-querys-sort-order-or-predicate) — confirms subview injection is the established pattern

### Tertiary (LOW confidence — flagged for validation)
- Community pattern for `scrollPosition` binding sharing to sync two ScrollViews — needs validation on macOS 26 beta that feedback loop does not occur

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project, no new dependencies
- Architecture: HIGH — all patterns derived from existing codebase conventions
- Pitfalls: HIGH — migration pitfall and direction-confusion pitfall verified from actual code; feedback loop is community-observed
- V2V diff approach: HIGH — DiffEngine is stateless; dual-init pattern is standard Swift
- Synchronized scrolling: MEDIUM — API is official but sharing a single ScrollPosition across two views is less well-documented

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable Apple frameworks; 30-day window)
