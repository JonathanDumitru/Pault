# Phase 6: Import/Export - Research

**Researched:** 2026-04-09
**Domain:** macOS file I/O, YAML frontmatter, drag-and-drop, NSSharingService, SwiftData persistence
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Export Data Scope**
- Bump JSON bundle format from v1 to v2 to accommodate new fields; import handles both v1 (legacy) and v2 gracefully with missing fields defaulting
- Include block composition data (blockCompositionData) in JSON export — restores full block editor state on Pault import
- Include all metadata fields: qualityScore, lastUsedAt, editingMode, variantB, attributedContent
- Do NOT include version history (PromptVersion records) — export current state only
- Do NOT include run history (PromptRun records) — tied to user's sessions and API keys
- Do NOT embed attachments — note them as references in export but don't embed binary data
- Collection-scoped export: export all prompts in a collection (regular or smart collection's current matching set) with collection name in bundle metadata

**Markdown Format**
- YAML frontmatter + Markdown body — standard pattern (compatible with Jekyll, Obsidian, etc.)
- Frontmatter includes: title, tags, favorite, archived, created, updated, variables (name + default), qualityScore
- Body: H1 title heading followed by compiled prompt text (block compositions export as flattened compiled text, not structured blocks)
- Multi-prompt Markdown export: one .md file per prompt in a user-chosen folder, filenames slugified from title
- Markdown import parses YAML frontmatter back into structured metadata — full round-trip for Pault exports
- Importing plain Markdown (no Pault frontmatter): title from first H1, fallback to filename (minus .md extension)
- Auto-detect {{variable}} patterns in imported Markdown content and create TemplateVariable records; merge with frontmatter-defined variables if both exist
- Folder batch import: NSOpenPanel allows selecting a folder — all .md files inside are parsed and imported

**Conflict Resolution**
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

**Access Points & Triggers**
- File menu: Export Library (JSON), Export as Markdown, Import Prompts — standard macOS pattern
- Context menu on collections: "Export ▸" submenu with "As JSON" / "As Markdown"
- Context menu on prompts: "Export ▸" submenu with "As JSON" / "As Markdown"
- Keep existing Preferences > Data section with Export/Import buttons alongside new access points
- Drag-drop import: drop .json or .md files onto main window to trigger import flow (same preview sheet); visual drop indicator for compatible file types
- macOS Share sheet: share button on prompt detail view → system share sheet with compiled prompt as plain text
- "Copy as Markdown" clipboard action: copies prompt with YAML frontmatter to clipboard — available from context menu
- Export submenu pattern (JSON / Markdown) used consistently across all access points
- Indeterminate spinner overlay during export for large libraries

**Feature Tier**
- Import/export is free tier — not Pro-gated

### Claude's Discretion
- Exact keyboard shortcuts for File menu import/export items (Cmd+Shift+I is taken by AI panel)
- NSSavePanel/NSOpenPanel configuration details
- Markdown filename slugification algorithm
- Share sheet SwiftUI/AppKit bridging approach
- Spinner timing threshold (whether to show for small exports)
- Import preview sheet layout details beyond the described behavior
- YAML serialization library choice (if any — vs hand-rolled)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R8.1 | Comprehensive Testing — all existing tests pass; new tests for phase features (unit + integration) | Test patterns for ExportService, YAML parsing, import conflict logic; existing TestHelpers infrastructure covers all @Model types |
| R8.2 | Accessibility Audit — VoiceOver, keyboard navigation, accessibility labels on all interactive elements | Import preview sheet requires accessibility labels; file menu items/context menus get VoiceOver for free; drop target needs accessibilityDropPoint |
| R9.1 | Export — individual prompts as JSON or Markdown; entire library as archive; includes template variables, tags, block compositions | ExportService v2 extension; BlockCompositionSnapshot is already Codable; NSSavePanel for folder selection |
| R9.2 | Import — from JSON or Markdown; conflict resolution (skip/overwrite/duplicate); drag-drop support | NSOpenPanel for file and folder picking; onDrop in ContentView; ImportPreviewSheet with DiffEngine integration |
| R9.3 | Interoperability — Copy as Markdown to clipboard; Share sheet integration | NSPasteboard for clipboard; NSSharingServicePicker for share sheet |
</phase_requirements>

---

## Summary

Phase 6 extends the existing `ExportService.swift` (198 lines, v1 JSON only) into a full bidirectional data portability layer. The core work is three-pronged: (1) bump the JSON bundle to v2 with new fields, (2) add a Markdown provider using hand-rolled YAML frontmatter (no external library needed), and (3) build an import preview sheet with per-prompt conflict resolution using the already-established `DiffEngine` and `PromptService.saveSnapshot` patterns.

The existing codebase gives excellent scaffolding. `PromptExportRecord` and `PromptExportBundle` are already `Codable`, `BlockCompositionSnapshot` is `Codable` and can be directly embedded in export records, `resolveTag` and tag creation patterns exist, and `TemplateEngine` handles `{{variable}}` detection. No new Swift Package Manager dependencies are required for this phase.

The most complex new component is the import preview sheet — a `List`-based SwiftUI sheet with expandable `DiffEngine`-powered rows, per-row conflict selectors, and a global "apply to all" control. All file I/O follows the established `NSSavePanel`/`NSOpenPanel` sandbox pattern. Drag-and-drop uses SwiftUI's `.onDrop(of:isTargeted:perform:)` on `ContentView`. The macOS Share sheet bridges via `NSSharingServicePicker` (AppKit) wrapped in a SwiftUI button action.

**Primary recommendation:** Extend `ExportService.swift` with a provider-pattern design (JSONExportProvider, MarkdownExportProvider) and extract `ImportPreviewSheet` as a separate view file. Keep all file-panel logic in `ExportService` static methods to match existing architecture.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation | System | JSON encoding/decoding, Data, URL, FileManager | Built-in; JSONEncoder/JSONDecoder already used |
| SwiftUI | System | Import preview sheet, drop target, spinner overlay | Established project UI layer |
| AppKit | System | NSSavePanel, NSOpenPanel, NSSharingServicePicker, NSPasteboard | Required for sandboxed file access and share sheet |
| SwiftData | System | ModelContext for import insertion, FetchDescriptor for duplicate detection | Project persistence layer |
| UniformTypeIdentifiers | System | UTType.json, UTType.plainText / custom .markdown type | Already imported in ExportService.swift |
| os (Logger) | System | Structured logging in ExportService | Already used — Logger(subsystem:category:) pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DiffEngine (in-project) | — | Line and character-level diff for import preview expandable rows | Reuse directly — already tested |
| TemplateEngine (in-project) | — | {{variable}} detection in imported Markdown content | Reuse `detectVariables` / `resolve` methods |
| PromptService.saveSnapshot | — | Auto-snapshot before overwrite during import | Reuse directly — established Phase 4/5 pattern |

### No External Dependencies Needed
| Problem | Hand-rolled approach | Why no library |
|---------|---------------------|----------------|
| YAML frontmatter serialization | String interpolation with ISO8601 dates | Pault's YAML subset is small and predictable — title, tags, booleans, dates, variables list |
| YAML frontmatter parsing | Regex/line scanning to extract frontmatter block, then line-by-line parsing | Subset is well-defined; adding Yams SPM dependency for ~15 YAML keys is not warranted |
| Filename slugification | `lowercased().replacingOccurrences` + regex stripping non-alphanumeric | Simple enough to hand-roll in a String extension |

**Installation:** No new packages. All dependencies are system frameworks already in the project.

---

## Architecture Patterns

### Recommended Project Structure (additions only)
```
Pault/
├── ExportService.swift           # Extend existing — add v2 DTOs, Markdown providers, collection-scoped export
├── ImportPreviewSheet.swift      # New — SwiftUI sheet for conflict resolution preview
├── ImportOrchestrator.swift      # New — import logic (parse → classify → apply) separated from UI
├── MarkdownFrontmatterParser.swift  # New — YAML frontmatter read/write utility
└── ContentView.swift             # Add .onDrop(of:) for drag-drop entry point
```

### Pattern 1: Provider-Based Export (within ExportService)

**What:** Two static methods `exportAsJSON(prompts:scope:)` and `exportAsMarkdown(prompts:)` that each call their own encoding logic and their own NSSavePanel/NSOpenPanel presentation.

**When to use:** Consistent with the existing `@discardableResult static func` enum pattern already established in ExportService.

```swift
// Extension of ExportService enum — same pattern as existing exportAll/importPrompts
enum ExportService {
    // Existing:  static func exportAll(prompts:) -> Bool
    // New v2:    static func exportLibraryJSON(prompts:scope:) -> Bool
    //            static func exportMarkdown(prompts:) -> Bool
    //            static func importFromFiles(into:) -> ImportResult?
    //            static func buildMarkdownString(for:compiledText:) -> String
    //            static func parseMarkdownFile(at:) -> MarkdownImportRecord?
}
```

### Pattern 2: v2 PromptExportRecord (backward-compatible)

All new fields are `Optional` or provide defaults. Import reads v1 bundles gracefully because a `JSONDecoder` with `keyNotFound` strategy set to use defaults (or all new fields are Optional in the struct) handles missing keys without throwing.

```swift
// In ExportService.swift — replaces existing v1 DTOs
struct PromptExportBundle: Codable {
    let version: Int          // 2
    let exportedAt: Double
    let collectionName: String?  // new: nil for library-wide export
    let prompts: [PromptExportRecord]
}

struct PromptExportRecord: Codable {
    // Existing v1 fields (unchanged):
    let id: String
    let title: String
    let content: String
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: Double
    let updatedAt: Double
    let tags: [String]
    let templateVariables: [VariableExportRecord]
    // New v2 fields (all Optional for backward compat):
    let blockCompositionData: Data?
    let qualityScore: Int?
    let lastUsedAt: Double?
    let editingModeRaw: String?
    let variantB: String?
    let attachmentFileNames: [String]?  // references only, not embedded
}
```

**v1 import decode strategy:** Use `JSONDecoder` — all v2-only fields are `Optional` so v1 JSON simply leaves them nil. No explicit version branching needed at the decoder level.

### Pattern 3: Markdown Frontmatter Format

```markdown
---
title: "My Prompt Title"
tags: [engineering, code-review]
favorite: true
archived: false
created: 2025-12-16T10:30:00Z
updated: 2026-01-02T14:22:00Z
quality_score: 82
variables:
  - name: language
    default: Swift
  - name: tone
    default: professional
---

# My Prompt Title

Write a {{tone}} code review for the following {{language}} code...
```

**Serialization:** String interpolation. ISO8601 dates via `ISO8601DateFormatter`. Tags as YAML inline sequence `[tag1, tag2]`. Variables as YAML block sequence.

**Parsing algorithm:**
1. Detect `---` delimiters at start of file (lines 0 and N)
2. Extract frontmatter block as string
3. Parse line by line: `key: value` pairs, handle quoted strings, array literals `[a, b]`, and block sequences (indent-detected `- name: / - default:` pairs)
4. Everything after the closing `---` is the body
5. Strip leading `# Heading\n\n` if present to get raw content

### Pattern 4: Import Preview Sheet

**What:** A `.sheet` presented from `ContentView` (or triggered from any import entry point via a shared `@State var importSession: ImportSession?`). Shows a flat list of all parsed prompts with conflict status.

**Struct design:**
```swift
struct ImportSession {
    let records: [ImportCandidate]
    // ... resolved after user confirms
}

struct ImportCandidate: Identifiable {
    let id = UUID()
    let incoming: PromptExportRecord   // or MarkdownImportRecord
    let existing: Prompt?              // non-nil = duplicate
    var resolution: ConflictResolution = .skip
    var isExpanded: Bool = false
}

enum ConflictResolution: String, CaseIterable {
    case skip = "Skip"
    case overwrite = "Overwrite"
    case keepBoth = "Keep Both"
}
```

**Sheet structure:**
- Header: title, count summary, "Apply to all duplicates" picker (only shown if any duplicates exist)
- List: `ForEach(session.records)` — each row shows title, conflict badge if duplicate, resolution picker
- Expandable diff section (when `isExpanded`): calls `DiffEngine.diff(old: existing.content, new: incoming.content)`
- Footer: Cancel / Import N Prompts buttons
- Post-import: dismiss sheet, show summary banner (inline, non-modal)

### Pattern 5: Drag-Drop Import

```swift
// In ContentView.swift — add to root view
.onDrop(of: [UTType.json, UTType.plainText], isTargeted: $isDropTargeted) { providers in
    Task { await handleDroppedFiles(providers) }
    return true
}
.overlay(alignment: .center) {
    if isDropTargeted {
        DropIndicatorOverlay()
    }
}
```

**Provider loading:** Use `NSItemProvider.loadItem(forTypeIdentifier:options:)` or `loadFileRepresentation(forTypeIdentifier:)`. For `.json` and `.md` files, load as `URL` via `loadItem(forTypeIdentifier: UTType.fileURL.identifier)`.

**UTType for Markdown:** Use `UTType.plainText` or register `UTType("net.daringfireball.markdown")`. Filter by file extension after URL is resolved (`.json` → JSON flow, `.md` → Markdown flow).

### Pattern 6: Share Sheet (NSSharingServicePicker)

SwiftUI does not expose `NSSharingServicePicker` natively on macOS (as of the project's macOS target). Bridge via AppKit:

```swift
// In PromptDetailView or a helper
Button(action: { showShareSheet(for: prompt) }) {
    Label("Share", systemImage: "square.and.arrow.up")
}

func showShareSheet(for prompt: Prompt) {
    let text = TemplateEngine.resolve(content: prompt.content, variables: prompt.templateVariables)
    let picker = NSSharingServicePicker(items: [text as NSString])
    // Anchor to the button's NSView
    if let button = NSApp.keyWindow?.contentView?.hitTest(buttonPoint) {
        picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
```

**Simpler alternative (HIGH confidence):** Wrap `NSSharingServicePicker` in a `NSViewRepresentable` shim or use a `@State var shareAnchor: NSView?` passed via preference key. The project already bridges AppKit elsewhere (UndoManager injection pattern from Phase 02 decisions).

**macOS 13+ approach:** `ShareLink` in SwiftUI works for simple text sharing and is fully native. Since the share sheet only needs to share plain text (compiled prompt), `ShareLink(item: compiledText)` is the cleanest path. Verify project's minimum macOS target before choosing.

### Anti-Patterns to Avoid

- **Embedding NSSavePanel inside a Task with wrong actor context:** NSSavePanel and NSOpenPanel must run on the main thread. `ExportService` static methods are called from SwiftUI button actions (already on MainActor). Do not dispatch to background queue before showing panels.
- **Parsing all Markdown imports before showing preview:** Parse eagerly when files are picked, but do not write to SwiftData until user confirms. Keep `ImportCandidate` array in a view-model `@State`, not in ModelContext.
- **Using `try? JSONDecoder().decode` for user-facing import errors:** Surface decode errors — the user needs to know when a file is malformed. Return `Result<PromptExportBundle, ImportError>` from parsing methods.
- **Tag deduplication via in-memory Set only:** The existing `resolveTag(named:in:)` already does a `FetchDescriptor` lookup — reuse it. Do not re-implement with a Set that misses tags created mid-import-loop.
- **Overwriting without snapshot:** Always call `PromptService.saveSnapshot(for:changeNote:source:)` before applying overwrite data. Use `source: .manual` with `changeNote: "Before import overwrite"` per the CONTEXT decision.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Diff for import preview | Custom line differ | `DiffEngine.diff(old:new:)` (in-project) | Already unit-tested, handles character-level refinement |
| {{variable}} detection in Markdown | Regex from scratch | `TemplateEngine` (in-project) | Already handles detection + dedup patterns |
| Version snapshot before overwrite | Ad-hoc PromptVersion creation | `PromptService.saveSnapshot(for:changeNote:source:)` | Handles dedup guard, version limit pruning, analytics event |
| Tag resolution/creation | Plain `context.insert(Tag)` | `ExportService.resolveTag(named:in:)` (already in ExportService) | Handles fetch-or-create, lowercased normalization |
| JSON encode/decode | Manual serialization | `JSONEncoder` / `JSONDecoder` with `Codable` structs | All DTOs already Codable |

**Key insight:** The in-project services (`DiffEngine`, `TemplateEngine`, `PromptService.saveSnapshot`) eliminate the hardest parts of this phase. The work is wiring, not inventing.

---

## Common Pitfalls

### Pitfall 1: YAML Frontmatter Parser Fragility
**What goes wrong:** Hand-rolled YAML line parser breaks on prompts containing colons (e.g., `title: "URL: https://example.com"`), unquoted special characters, or multiline default values.
**Why it happens:** YAML is not line-by-line parseable without a full state machine.
**How to avoid:** Restrict Pault's YAML output to a well-defined safe subset: always quote string values (`"..."`) in output; in parsing, handle only quoted and unquoted scalars for known keys, bail gracefully on unexpected structure.
**Warning signs:** Round-trip test failures when title or variable defaults contain `:`, `#`, `[`, `]`.

### Pitfall 2: NSSavePanel for Folder (Markdown Multi-Export)
**What goes wrong:** Calling `NSSavePanel` for folder selection — NSSavePanel saves a single file. For multi-file export, you need `NSOpenPanel` configured with `canChooseDirectories = true, canChooseFiles = false, canCreateDirectories = true, allowsMultipleSelection = false`.
**Why it happens:** Confusing save vs open panels.
**How to avoid:** Use `NSOpenPanel` (not `NSSavePanel`) as a folder picker for multi-file Markdown export. The user picks/creates a destination folder, then the service writes N `.md` files programmatically.

### Pitfall 3: Filename Collisions in Markdown Export
**What goes wrong:** Two prompts with similar titles slug to the same filename (e.g., "Fix Bug" and "Fix Bug!"). Last write wins and silently overwrites.
**Why it happens:** Slugification strips special chars, leaving identical basenames.
**How to avoid:** After slugification, check for filename collisions in the export set and append `-2`, `-3` suffixes.

### Pitfall 4: SwiftData Insertion Order for Tags During Import
**What goes wrong:** `resolveTag` is called per-prompt, and within one import batch the same tag name appears across multiple records. First call creates the tag; second call re-fetches. But if `context.save()` is deferred, the FetchDescriptor may not see the newly-inserted-but-not-saved tag.
**Why it happens:** SwiftData's `context.fetch` returns in-memory unsaved objects only if they were registered in the same context. The existing `resolveTag` pattern already handles this correctly — but only within the same import pass. If the import loops in separate context passes this breaks.
**How to avoid:** Keep all import insertions in one ModelContext pass and call `context.save()` once at the end (existing pattern). Also maintain an in-memory `[String: Tag]` cache within the import loop to avoid redundant fetches.

### Pitfall 5: Drag-Drop UTType Matching
**What goes wrong:** `.onDrop(of: [UTType.json])` does not trigger for `.json` files dropped from Finder because the item provider advertises `public.file-url` not `public.json`.
**Why it happens:** NSItemProvider type hierarchy; files dropped from Finder provide `public.file-url` regardless of content type.
**How to avoid:** Accept `[UTType.fileURL]` in the `onDrop` handler (or `[UTType.item]`), then inspect the URL's `pathExtension` to decide JSON vs Markdown. Alternatively accept `[UTType.json, UTType.plainText, UTType.fileURL]`.

### Pitfall 6: Import Preview Sheet Import Ordering
**What goes wrong:** User clicks "Import" on the preview sheet; the import runs on a background context and completes after the sheet dismisses — but the main view has not refreshed.
**Why it happens:** SwiftData main context needs the write to trigger a `@Query` refresh, which only happens if writes happen on (or are saved through) the main ModelContext.
**How to avoid:** Perform all import writes on `@MainActor` using the same `modelContext` already provided by the SwiftUI environment (consistent with how `ExportService.importPrompts(into:)` works today).

---

## Code Examples

### v2 Bundle Encode with Optional Fields
```swift
// ExportService.swift — buildRecord helper
static func buildRecord(from prompt: Prompt) -> PromptExportRecord {
    PromptExportRecord(
        id: prompt.id.uuidString,
        title: prompt.title,
        content: prompt.content,
        isFavorite: prompt.isFavorite,
        isArchived: prompt.isArchived,
        createdAt: prompt.createdAt.timeIntervalSince1970,
        updatedAt: prompt.updatedAt.timeIntervalSince1970,
        tags: prompt.tags.map(\.name),
        templateVariables: prompt.templateVariables
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { VariableExportRecord(name: $0.name, defaultValue: $0.defaultValue, sortOrder: $0.sortOrder) },
        blockCompositionData: prompt.blockCompositionData,
        qualityScore: prompt.qualityScore,
        lastUsedAt: prompt.lastUsedAt?.timeIntervalSince1970,
        editingModeRaw: prompt.editingModeRaw,
        variantB: prompt.variantB,
        attachmentFileNames: prompt.attachments.isEmpty ? nil : prompt.attachments.map(\.fileName)
    )
}
```

### Markdown Frontmatter Output
```swift
// MarkdownFrontmatterParser.swift
static func serialize(record: PromptExportRecord) -> String {
    let iso = ISO8601DateFormatter()
    let created = iso.string(from: Date(timeIntervalSince1970: record.createdAt))
    let updated = iso.string(from: Date(timeIntervalSince1970: record.updatedAt))
    let tagsLine = record.tags.isEmpty ? "[]" : "[" + record.tags.joined(separator: ", ") + "]"

    var fm = """
    ---
    title: "\(record.title.replacingOccurrences(of: "\"", with: "\\\""))"
    tags: \(tagsLine)
    favorite: \(record.isFavorite)
    archived: \(record.isArchived)
    created: \(created)
    updated: \(updated)
    """
    if let qs = record.qualityScore { fm += "\nquality_score: \(qs)" }
    if !record.templateVariables.isEmpty {
        fm += "\nvariables:"
        for v in record.templateVariables {
            fm += "\n  - name: \(v.name)\n    default: \"\(v.defaultValue)\""
        }
    }
    fm += "\n---\n\n# \(record.title)\n\n\(record.content)\n"
    return fm
}
```

### Frontmatter Parser (Read Path)
```swift
// MarkdownFrontmatterParser.swift
struct MarkdownImportRecord {
    var title: String
    var content: String
    var tags: [String] = []
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var createdAt: Date? = nil
    var updatedAt: Date? = nil
    var qualityScore: Int? = nil
    var variables: [(name: String, defaultValue: String)] = []
}

static func parse(markdown: String, filename: String) -> MarkdownImportRecord {
    let lines = markdown.components(separatedBy: "\n")
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
        return parsePlain(markdown: markdown, filename: filename)
    }
    // find closing ---
    let fmEnd = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
    guard let fmEndIdx = fmEnd else {
        return parsePlain(markdown: markdown, filename: filename)
    }
    let fmLines = Array(lines[1..<(fmEndIdx + 1)])
    let body = lines[(fmEndIdx + 2)...].joined(separator: "\n")
    return buildRecord(frontmatterLines: fmLines, body: body, filename: filename)
}
```

### NSOpenPanel as Folder Picker (Multi-file Markdown Export)
```swift
// ExportService.swift — exportMarkdown
static func exportMarkdown(prompts: [Prompt]) -> Bool {
    let panel = NSOpenPanel()
    panel.title = "Choose Export Folder"
    panel.prompt = "Export Here"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let folder = panel.url else { return false }

    var written = 0
    var usedFilenames = Set<String>()
    for prompt in prompts {
        let slug = slugify(prompt.title, existing: usedFilenames)
        usedFilenames.insert(slug)
        let url = folder.appendingPathComponent("\(slug).md")
        let markdown = MarkdownFrontmatterParser.serialize(record: buildRecord(from: prompt))
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
        written += 1
    }
    exportLogger.info("exportMarkdown: wrote \(written) files to \(folder.lastPathComponent)")
    return written > 0
}
```

### Drag-Drop in ContentView
```swift
// ContentView.swift — add to root container view
.onDrop(of: [UTType.fileURL, UTType.json, UTType.plainText], isTargeted: $isDropTargeted) { providers in
    Task { @MainActor in
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                urls.append(url)
            }
        }
        let jsonURLs = urls.filter { $0.pathExtension.lowercased() == "json" }
        let mdURLs   = urls.filter { $0.pathExtension.lowercased() == "md" }
        if !jsonURLs.isEmpty || !mdURLs.isEmpty {
            importSession = ImportOrchestrator.prepare(jsonURLs: jsonURLs, markdownURLs: mdURLs, context: modelContext)
        }
    }
    return true
}
```

### File Menu CommandGroup (PaultApp.swift)
```swift
// After the existing CommandGroup(replacing: .newItem)
CommandGroup(after: .newItem) {
    Divider()
    Button("Export Library as JSON…") {
        NotificationCenter.default.post(name: .exportLibraryJSON, object: nil)
    }
    Button("Export Library as Markdown…") {
        NotificationCenter.default.post(name: .exportLibraryMarkdown, object: nil)
    }
    Divider()
    Button("Import Prompts…") {
        NotificationCenter.default.post(name: .importPrompts, object: nil)
    }
    .keyboardShortcut("i", modifiers: [.command, .option])  // Cmd+Opt+I — Cmd+Shift+I taken by AI panel
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| ExportService v1: JSON only, skip duplicates silently | v2: JSON + Markdown, interactive preview sheet with per-prompt conflict control | Phase 6 replaces v1 behavior entirely |
| Import: silent skip of all duplicates | Import: Skip / Overwrite / Keep Both per prompt with diff preview | Much better user control |
| No drag-drop | `.onDrop` on ContentView for .json and .md files | Standard macOS data portability pattern |
| Share via clipboard only | NSSharingServicePicker / ShareLink for native share sheet | Reaches AirDrop, Messages, Mail, etc. |

**Deprecated in this phase:**
- `ExportService.exportAll(prompts:)` v1 signature — keep for PreferencesView backward compatibility but have it call through to v2 internally, or update call sites
- `ExportService.importPrompts(into:)` v1 — replace with new preview-based import flow; update PreferencesView call site

---

## Open Questions

1. **Minimum macOS target for ShareLink**
   - What we know: `ShareLink` was introduced in macOS 13 (Ventura). The project's minimum deployment target is not confirmed in this research.
   - What's unclear: Whether `ShareLink` is available or `NSSharingServicePicker` bridge is required.
   - Recommendation: Check `IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET` in Xcode project settings. If macOS 13+, use `ShareLink(item: compiledText)` — simpler. If macOS 12, use `NSSharingServicePicker` AppKit bridge.

2. **Keyboard shortcut for Import (File menu)**
   - What we know: Cmd+Shift+I is taken by the AI Assist panel. Cmd+Option+I is unassigned.
   - Recommendation: Use `Cmd+Option+I` for Import. No shortcut for Export items (they're less frequent).

3. **TemplateEngine API for variable detection from string**
   - What we know: `TemplateEngine` has `resolve(content:variables:)` and detects `{{var}}` patterns. The specific method for detection-only (returning variable names without a default value set) needs to be confirmed in `TemplateEngine.swift`.
   - Recommendation: Planner should read `TemplateEngine.swift` to confirm the detection API before writing the Markdown import task. If no detection-only method exists, it needs to be added or the import task must implement a simple regex.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Testing not confirmed as default for this project) |
| Config file | Xcode scheme — no separate pytest/jest config |
| Quick run command | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R9.1 | JSON v2 round-trip export (all fields) | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ Wave 0 |
| R9.1 | v1 bundle imports cleanly (missing optional fields default) | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ Wave 0 |
| R9.1 | Markdown serialize → parse round-trip | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/MarkdownFrontmatterParserTests` | ❌ Wave 0 |
| R9.1 | Plain Markdown (no frontmatter) parses title from H1 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/MarkdownFrontmatterParserTests` | ❌ Wave 0 |
| R9.1 | Filename slugification + collision dedup | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ Wave 0 |
| R9.2 | Duplicate detection (UUID match only) | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ Wave 0 |
| R9.2 | Overwrite creates auto-snapshot before applying | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ Wave 0 |
| R9.2 | Keep Both creates new prompt with fresh UUID + "(Imported)" title | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ Wave 0 |
| R9.2 | Malformed records skipped, valid ones imported (partial import) | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ Wave 0 |
| R9.2 | {{variable}} auto-detection in Markdown body creates TemplateVariable records | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ Wave 0 |
| R9.3 | Copy as Markdown writes YAML frontmatter to NSPasteboard | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ Wave 0 |
| R8.1 | All existing PaultTests pass after phase | integration | `xcodebuild test -scheme Pault -destination 'platform=macOS'` | ✅ existing |
| R8.2 | Import preview sheet accessibility labels | manual | VoiceOver pass on ImportPreviewSheet | manual-only |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests -only-testing:PaultTests/MarkdownFrontmatterParserTests -only-testing:PaultTests/ImportOrchestratorTests 2>&1 | tail -5`
- **Per wave merge:** `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | tail -20`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `PaultTests/ExportServiceTests.swift` — covers R9.1 JSON v2 round-trip, v1 backward compat, Markdown export, filename slugification, Copy as Markdown
- [ ] `PaultTests/MarkdownFrontmatterParserTests.swift` — covers R9.1 YAML serialize+parse round-trip, plain Markdown fallback, quoted strings with colons
- [ ] `PaultTests/ImportOrchestratorTests.swift` — covers R9.2 conflict resolution (skip/overwrite/keepBoth), auto-snapshot before overwrite, variable auto-detection, partial import error handling

---

## Sources

### Primary (HIGH confidence)
- Direct reading of `/Pault/ExportService.swift` — existing implementation, DTO types, NSSavePanel/NSOpenPanel pattern
- Direct reading of `/Pault/Prompt.swift` — all model fields, blockCompositionData, qualityScore, lastUsedAt, editingModeRaw, variantB
- Direct reading of `/Pault/BlockEditor/Models/BlockCompositionSnapshot.swift` — Codable conformance, field structure
- Direct reading of `/Pault/PromptService.swift` — saveSnapshot signature, VersionSource enum, AnalyticsService recording pattern
- Direct reading of `/Pault/PaultApp.swift` — CommandGroup pattern, Notification.Name extension pattern
- Direct reading of `/Pault/SidebarView.swift` — contextMenu pattern on list rows
- Direct reading of `/Pault/PreferencesView.swift` — existing ExportService call sites (lines 399, 423)
- Direct reading of `/PaultTests/TestHelpers.swift` — in-memory ModelContainer with all 10 @Model types
- Direct reading of `/Pault/DiffEngine.swift` — DiffEngine.diff(old:new:) signature

### Secondary (MEDIUM confidence)
- Apple documentation knowledge (within training cutoff): `NSSavePanel`, `NSOpenPanel`, `NSItemProvider`, `UTType`, `NSSharingServicePicker`, `ShareLink` (macOS 13+)
- SwiftUI `.onDrop(of:isTargeted:perform:)` documentation pattern
- YAML frontmatter specification (Jekyll/Obsidian community standard)

### Tertiary (LOW confidence — flag for validation)
- ShareLink macOS 13+ availability — verify against project's actual deployment target in Xcode settings
- `TemplateEngine` variable detection API — confirm exact method name/signature before planning import task

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — confirmed from existing codebase; no new dependencies
- Architecture patterns: HIGH — directly derived from existing code patterns (ExportService, NSSavePanel, contextMenu, CommandGroup)
- Pitfalls: HIGH for YAML fragility, NSOpenPanel-as-folder-picker, UTType drag-drop; MEDIUM for SwiftData import ordering
- Validation: MEDIUM — test file names are proposed, XCTest infrastructure confirmed; specific test commands unverified against actual Xcode scheme names

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable domain — AppKit/SwiftUI patterns change slowly)
