# Pault UI Overhaul Design

## Overview

A full visual overhaul to give Pault a native macOS feel with modern patterns: auto-hiding sidebar, tag-based organization, always-editable content, and a collapsible inspector panel.

---

## Architecture & Layout

### Overall Structure

Use `NavigationSplitView` with a two-column layout:
- **Sidebar** (left): Smart filters + flat prompt list with tag pills
- **Detail** (right): Prompt editor with collapsible inspector

### Sidebar Behavior

- Auto-hides when a prompt is selected
- Reappears on hover near left edge (20pt trigger zone)
- Manual toggle via toolbar button or `⌘+0`
- Uses native translucent sidebar material

### Window

- Resizable (no longer fixed size)
- Minimum size: 700×500
- Remembers last size/position

### Layout Diagram

```
┌─────────────────────────────────────────────────┐
│ [Toggle Sidebar]        [Copy]    [New Prompt]  │  ← Toolbar
├────────────┬────────────────────────────────────┤
│ 🔍 Search  │                                    │
│            │   Title (editable)                 │
│ Recently   │   ─────────────────────────────    │
│ All Prompts│                                    │
│ Archived   │   Content area                     │
│ ─────────  │   (large, always editable)         │
│            │                              [ℹ︎]  │  ← Inspector toggle
│ • Prompt A │                                    │
│   #tag     │   ┌─────────────────────────────┐  │
│ • Prompt B │   │ Tags: #work #email          │  │  ← Inspector panel
│ • Prompt C │   │ Favorite: ★                 │  │     (collapsible)
│            │   │ Created: Jan 15, 2026       │  │
│            │   │ Modified: Jan 27, 2026      │  │
│            │   └─────────────────────────────┘  │
└────────────┴────────────────────────────────────┘
```

---

## Sidebar Details

### Smart Filters (top section)

Fixed items that filter the prompt list:
- **Search field** — filters by title, content, or tag name as you type
- **Recently Used** — last 10 prompts accessed (based on `updatedAt`)
- **All Prompts** — shows everything except archived
- **Archived** — shows only archived prompts

Selected filter is highlighted. Only one active at a time (search overrides others while typing).

### Prompt List (below filters)

- Flat list, no section headers
- Each row shows:
  - Title (or first ~30 chars of content if untitled)
  - Tag pills inline (small, colored, max 2 visible + "+N" overflow)
  - Subtle favorite star if favorited
- Single-click selects and opens in detail view
- Right-click context menu: Copy, Favorite/Unfavorite, Archive/Unarchive, Delete

### Tags

- Displayed as small rounded pills (e.g., `#work`, `#email`)
- Clicking a tag in the list filters to show only prompts with that tag
- Tag colors auto-assigned from a preset palette (or user-customizable later)

### Empty States

- No prompts: "No prompts yet. Click + to create one."
- No search results: "No prompts match your search."
- No archived: "No archived prompts."

---

## Detail View & Editor

### Layout

The detail area has two parts:
- **Editor** (main area) — title and content, always editable
- **Inspector panel** (right side) — collapsible metadata panel

### Editor

- **Title field** at top: Large font (`.title2`), placeholder "Untitled", no visible border until focused
- **Content area** below: Full-height `TextEditor`, clean appearance, subtle background on focus
- Auto-saves on every change (debounced ~500ms to avoid excessive writes)
- No Save button needed—changes persist automatically

### Inspector Panel

- Toggle visibility with `ℹ︎` button in bottom-right corner (or `⌘+I`)
- Slides in/out from the right edge
- Width: ~220pt fixed
- Contains:
  - **Tags** — editable tag pills with inline "+" to add new tags
  - **Favorite toggle** — star button
  - **Created date** — read-only
  - **Modified date** — read-only
  - **Archive button** — moves prompt to/from archive

### No Selection State

When no prompt is selected (and sidebar is hidden), show a minimal welcome view:
- "Select a prompt or press ⌘+N to create one"
- Keyboard shortcut hint

---

## Data Model Changes

### Current Model

- `Prompt`: title, content, isFavorite, isArchived, createdAt, updatedAt, category (single `Category`)
- `Category`: name, prompts (inverse relationship)

### New Model

Replace `Category` with `Tag`:

- `Prompt`: title, content, isFavorite, isArchived, createdAt, updatedAt, **tags** (many-to-many with `Tag`)
- `Tag`: name, color (optional), prompts (inverse relationship)

### Migration

- Existing categories become tags automatically
- Each prompt's single category converts to a one-item tag array
- No data loss

### Color Palette for Tags

Preset colors (user picks when creating, or auto-assigned):
- Blue, Purple, Pink, Red, Orange, Yellow, Green, Teal, Gray

---

## Toolbar & Keyboard Shortcuts

### Toolbar (unified, no duplicates)

Three items, left to right:
- **Toggle Sidebar** (leading) — `sidebar.left` icon, `⌘+0`
- **Copy** (trailing) — `doc.on.doc` icon, `⌘+C` when prompt selected, disabled otherwise
- **New Prompt** (trailing) — `plus` icon, `⌘+N`

No Save button (auto-save handles it). No Edit button (always editable).

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘+N` | New prompt |
| `⌘+C` | Copy prompt content (when detail view focused) |
| `⌘+0` | Toggle sidebar |
| `⌘+I` | Toggle inspector panel |
| `⌘+F` | Focus search field |
| `⌘+Delete` | Archive selected prompt |
| `Delete` | Delete prompt (with confirmation) |
| `Escape` | Deselect prompt / close inspector |

---

## Summary of Changes

| Area | Current | New |
|------|---------|-----|
| Layout | Manual `HStack` | `NavigationSplitView` |
| Sidebar | Always visible, fixed width | Auto-hide + hover reveal + manual toggle |
| Organization | Category sections | Smart filters + flat list with tags |
| Data model | Single category per prompt | Multiple tags per prompt |
| Editing | Edit mode toggle | Always editable, auto-save |
| Metadata | Inline in form | Collapsible inspector panel |
| Toolbar | Duplicated across views | Single unified toolbar |

---

## Files to Create/Modify

### New Files
- `Pault/Tag.swift` — new Tag model
- `Pault/SidebarView.swift` — extracted sidebar with filters and list
- `Pault/InspectorView.swift` — collapsible metadata panel
- `Pault/TagPillView.swift` — reusable tag pill component
- `Pault/SearchField.swift` — search filter component

### Modified Files
- `Pault/Prompt.swift` — replace category with tags relationship
- `Pault/ContentView.swift` — refactor to NavigationSplitView, unified toolbar
- `Pault/PromptDetailView.swift` — simplify to editor + inspector toggle
- `Pault/PaultApp.swift` — update schema, remove fixed window size

### Deleted Files
- `Pault/Category.swift` — replaced by Tag
- `Pault/WindowSizeConstraints.swift` — no longer needed (window is resizable)
