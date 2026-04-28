# Phase 6: Import/Export - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can move their data in and out of Pault with standard formats. Export full library, individual collections, or individual prompts as JSON or Markdown. Import from JSON bundles or Markdown files/folders with duplicate detection and user-controlled conflict resolution. Free tier feature — not Pro-gated.

</domain>

<decisions>
## Implementation Decisions

### Export Data Scope
- Bump JSON bundle format from v1 to v2 to accommodate new fields; import handles both v1 (legacy) and v2 gracefully with missing fields defaulting
- Include block composition data (blockCompositionData) in JSON export — restores full block editor state on Pault import
- Include all metadata fields: qualityScore, lastUsedAt, editingMode, variantB, attributedContent
- Do NOT include version history (PromptVersion records) — export current state only
- Do NOT include run history (PromptRun records) — tied to user's sessions and API keys
- Do NOT embed attachments — note them as references in export but don't embed binary data
- Collection-scoped export: export all prompts in a collection (regular or smart collection's current matching set) with collection name in bundle metadata

### Markdown Format
- YAML frontmatter + Markdown body — standard pattern (compatible with Jekyll, Obsidian, etc.)
- Frontmatter includes: title, tags, favorite, archived, created, updated, variables (name + default), qualityScore
- Body: H1 title heading followed by compiled prompt text (block compositions export as flattened compiled text, not structured blocks)
- Multi-prompt Markdown export: one .md file per prompt in a user-chosen folder, filenames slugified from title
- Markdown import parses YAML frontmatter back into structured metadata — full round-trip for Pault exports
- Importing plain Markdown (no Pault frontmatter): title from first H1, fallback to filename (minus .md extension)
- Auto-detect {{variable}} patterns in imported Markdown content and create TemplateVariable records; merge with frontmatter-defined variables if both exist
- Folder batch import: NSOpenPanel allows selecting a folder — all .md files inside are parsed and imported

### Conflict Resolution
- Duplicate detection: UUID match only — different prompts with the same title are NOT duplicates
- Import preview sheet: lists all prompts to import, highlights duplicates with per-prompt Skip/Overwrite/Keep Both dropdown
- "Apply to all duplicates" dropdown sets global default; individual prompts can override
- User confirms import from preview sheet before any writes happen
- Expandable diff row on duplicate entries: mini diff between existing prompt and incoming version (reuses DiffEngine)
- Overwrite behavior: auto-snapshot existing prompt state as PromptVersion labeled "Before import overwrite" before applying incoming data
- Keep Both behavior: import as new prompt with fresh UUID + " (Imported)" suffix appended to title
- Flat prompt list in preview (same presentation for JSON and Markdown imports — not a file tree)
- Partial import: skip malformed entries, import valid ones; report count of skipped entries in summary
- Post-import feedback: inline summary banner with counts ("8 imported, 2 overwritten, 1 skipped") — dismissible, non-blocking

### Access Points & Triggers
- File menu: Export Library (JSON), Export as Markdown, Import Prompts — standard macOS pattern
- Context menu on collections: "Export ▸" submenu with "As JSON" / "As Markdown"
- Context menu on prompts: "Export ▸" submenu with "As JSON" / "As Markdown"
- Keep existing Preferences > Data section with Export/Import buttons alongside new access points
- Drag-drop import: drop .json or .md files onto main window to trigger import flow (same preview sheet); visual drop indicator for compatible file types
- macOS Share sheet: share button on prompt detail view → system share sheet with compiled prompt as plain text
- "Copy as Markdown" clipboard action: copies prompt with YAML frontmatter to clipboard — available from context menu
- Export submenu pattern (JSON / Markdown) used consistently across all access points
- Indeterminate spinner overlay during export for large libraries

### Feature Tier
- Import/export is free tier — not Pro-gated
- Data portability is a user right, not a premium differentiator

### Claude's Discretion
- Exact keyboard shortcuts for File menu import/export items (Cmd+Shift+I is taken by AI panel)
- NSSavePanel/NSOpenPanel configuration details
- Markdown filename slugification algorithm
- Share sheet SwiftUI/AppKit bridging approach
- Spinner timing threshold (whether to show for small exports)
- Import preview sheet layout details beyond the described behavior
- YAML serialization library choice (if any — vs hand-rolled)

</decisions>

<specifics>
## Specific Ideas

- Import preview sheet should feel like a native macOS import dialog — clean, informative, not overwhelming
- Expandable diff rows in import preview reuse the existing DiffEngine (not a new diff implementation)
- Auto-snapshot before overwrite follows the same PromptVersion pattern established in Phase 4 (AI auto-snapshots) and Phase 5 (version history)
- Phase 4 deferred "Markdown export for run responses" — this phase covers prompt export, not run response export specifically
- Copy as Markdown should include frontmatter (unlike share sheet which is plain text) — the two serve different audiences (developers vs general sharing)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ExportService.swift` (198 lines): Working JSON export/import with NSSavePanel/NSOpenPanel, PromptExportBundle/PromptExportRecord DTOs, tag resolution, duplicate skip by UUID — needs extension to v2 format with new fields and Markdown support
- `DiffEngine`: Line and character-level diff — reuse for import preview expandable diff rows
- `PromptService.saveSnapshot(for:changeNote:limit:)`: Version snapshot creation — reuse for auto-snapshot before overwrite
- `PromptExportRecord`: Existing Codable DTO — extend with blockCompositionData, qualityScore, lastUsedAt, editingMode, variantB
- `PromptExportBundle`: Existing bundle wrapper with version field — bump to version 2
- `BlockCompositionSnapshot`: Already Codable — can be included in export records directly
- `TemplateEngine`: Existing variable detection — reuse for auto-detecting {{variables}} in imported Markdown

### Established Patterns
- `NSSavePanel`/`NSOpenPanel` for sandboxed file access (ExportService, AttachmentManager)
- `NSPasteboard` for clipboard operations (PromptService.copyToClipboard, CompiledPreviewView)
- `CommandGroup` in PaultApp.swift for File menu items
- `@discardableResult` static methods on service enums (ExportService pattern)
- `Logger(subsystem:category:)` for structured logging
- SwiftData `ModelContext` passed to service methods for persistence

### Integration Points
- `PaultApp.swift`: Add File menu CommandGroup items for Import/Export
- `ContentView.swift`: Add drop target for drag-drop import (.onDrop)
- `SidebarView.swift`: Add context menu "Export ▸" on collection rows
- `PromptDetailView.swift`: Add share button + "Copy as Markdown" to context menu
- `PreferencesView.swift` (line ~399): Existing Export/Import buttons — update to use enhanced ExportService
- `ExportService.swift`: Primary file to extend — add Markdown export/import, v2 format, import preview logic

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-import-export*
*Context gathered: 2026-04-09*
