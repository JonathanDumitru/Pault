# Phase 5: Pro Features — Versioning, Analytics & Smart Collections - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete the remaining Pro tier features: full prompt version history with diff, usage analytics with visual dashboards, and dynamic smart collections with complex filtering. All three features are Pro-gated via existing ProFeature enum. Main window only — no versioning, analytics, or smart collection management in menu bar popover or hotkey launcher.

</domain>

<decisions>
## Implementation Decisions

### Version Capture Triggers
- Versions created on explicit save (Cmd+S or navigate-away Save dialog) — not debounced or auto-timed
- AI auto-snapshots from Phase 4 continue unchanged (source-labeled: 'ai-improve', 'ai-variable-accept', etc.)
- Auto-generated change note labels: "Manual save", "Before AI Improve", "Restored from {date}" — no user prompt for notes
- Keep existing version limit: 50 per prompt (configurable 5-200 in Preferences via `versionHistoryLimit` AppStorage)
- Snapshots capture content + metadata only (title, content, tags, variables, favorite) — no block-level composition data

### Version History Presentation
- Flat chronological list (newest first) with subtle date headers (Today, Yesterday, etc.) — not a timeline or grouped cards
- Lives in the inspector panel (right sidebar) as a collapsible section alongside tags and stats
- Colored source badges on each version row: AI = purple, Manual = blue, Restore = orange — small pill badges next to the date
- Search bar for filtering versions by change note or date (already implemented)
- Compare mode for selecting two versions (already implemented, now enhanced for V2V)
- No dedicated keyboard shortcut — use inspector toggle

### Version Diff UX
- True version-to-version comparison: when user selects two versions in compare mode, diff those two versions directly (not just against current prompt)
- PromptDiffView accepts either (version, prompt) for version-vs-current or (version1, version2) for V2V
- Default to side-by-side mode (existing default preserved)
- Synchronized scrolling between the two panels in side-by-side mode
- Restore from V2V comparison: both sides show "Restore This Version" button; user picks which version to restore to current
- Restore flow unchanged: snapshot current state first ("Before restore"), apply version, snapshot restored state ("Restored from {date}")
- Granular restore with field selection (title, content, tags, variables, favorite) — already implemented

### Analytics Dashboard
- Enhanced AnalyticsView: line chart (Swift Charts) for total usage over time + existing ranked prompt list + per-prompt drill-down
- Date range picker: 7 / 30 / 90 days segmented control
- Token consumption totals: aggregate inputTokens + outputTokens from PromptRun, display per-prompt and in overview summary
- No cost estimation (deferred per Phase 4 decision)
- Per-prompt drill-down: clicking a row shows the existing PromptStatsView bar chart with token breakdown
- Access: sheet from toolbar chart icon (existing pattern, just richer content)

### Analytics Event Tracking
- Extend event tracking beyond CopyEvent: add prompt created, edited (version saved), and deleted events
- Claude decides implementation approach (extend CopyEvent into generic UsageEvent with type enum, or separate models)
- All data stored locally — no telemetry

### Smart Collection Filters
- Extend SmartCollectionFilter with: qualityScoreMin/Max (Int?), model (String?), lastUsedWithin (Int? days), contentContains (String?)
- All filter criteria AND together — no OR/NOT logic builder
- Editor: simple form with pickers/toggles (extend existing SmartCollectionEditorView)
- Keep both creation paths: saved filter form + AI-curated clustering (existing)

### Smart Collection Behavior
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

</decisions>

<specifics>
## Specific Ideas

- Version source badges should use the same pill/tag component style used elsewhere in the app
- The 3 preset smart collections use emoji icons in sidebar: fire for Most Used, sparkles for Recently Created, zzz for Stale
- Analytics line chart should feel native/clean — Swift Charts with minimal styling, not a complex dashboard
- V2V comparison labels should clearly show which is older vs newer: "Version A (Apr 7)" vs "Version B (Apr 9)"
- Token totals formatted with K suffix for readability (e.g., "23.4K input | 8.2K output")

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PromptVersion` model (62 lines): SwiftData model with id, prompt relationship, title, content, savedAt, changeNote, isFavorite, snapshotData — complete, needs source field added
- `VersionSnapshot`: Codable struct with tags + variables snapshots — extend for new metadata if needed
- `PromptVersionHistoryView` (191 lines): Full version list with search, compare mode, context menu delete — enhance with date headers and source badges
- `PromptDiffView` (424 lines): Inline + side-by-side diff modes, metadata change detection, granular restore with field selection — extend for V2V and sync scrolling
- `DiffEngine`: Line and character-level diff with LineDiff/CharDiff types — ready to use for any two strings
- `AnalyticsService` (108 lines): copyCount, lastCopied, runCount, allRunCounts, topPromptIDsByUsage, dailyCopies — extend with token aggregation and new event types
- `AnalyticsView` (167 lines): Ranked list with Pro gating and upgrade prompt — enhance with chart and date filter
- `PromptStatsView` (78 lines): Per-prompt stats with mini bar chart — reuse as drill-down view
- `CopyEvent` model (14 lines): Simple promptID + timestamp — extend or replace with generic event model
- `SmartCollection` model (68 lines): Supports .savedFilter and .aiCurated types with JSON-encoded filter
- `SmartCollectionFilter`: Codable struct with tagIDs, onlyFavorites, recentDays — extend with new fields
- `SmartCollectionEditorView` (123 lines): Form for filter creation + AI clustering — extend with new filter fields
- `ProFeature` enum: `.analytics`, `.smartCollections`, `.promptVersioning` cases for gating
- `InspectorView`: Right sidebar panel — add version history section

### Established Patterns
- `@AppStorage("versionHistoryLimit")` for version limit (Preferences + diff view)
- `PromptService.saveSnapshot(for:changeNote:limit:)` for version creation
- `ProFeature.isUnlocked(.feature)` for Pro gating in views
- Sheet presentation for analytics (NavigationStack + .frame)
- Sidebar `@Query` + ForEach for smart collection listing
- `AnalyticsService(modelContext:)` instantiation pattern in views

### Integration Points
- `InspectorView.swift`: Add collapsible version history section
- `PromptDetailView.swift`: Wire version creation on save (line 534 already calls saveSnapshot)
- `AnalyticsView.swift`: Enhance with Swift Charts and date range picker
- `AnalyticsService.swift`: Add token aggregation methods and new event tracking
- `SidebarView.swift`: Add count badges to smart collection rows, wire preset creation
- `SmartCollectionEditorView.swift`: Add new filter fields (quality score, model, lastUsed, content)
- `SmartCollection.swift`: Extend SmartCollectionFilter with new fields
- `PromptDiffView.swift`: Add V2V mode, sync scrolling, dual restore buttons

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-pro-features-versioning-analytics-smart-collections*
*Context gathered: 2026-04-09*
