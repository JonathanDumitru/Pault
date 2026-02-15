# UX Sprint Design: Read-Only Preview, Inline Variables, Keyboard Navigation & Menu Bar

**Date:** 2026-02-15
**Status:** Approved
**Scope:** 4 phases, 16 tasks

## Problem

After hands-on testing of all 15 core features + polish pass, 7 UX issues were identified:

1. Prompts are editable on selection — need read-only preview + separate edit window
2. Template variables live only in a bottom panel — need inline fields in the preview
3. Tag picker popover too small (200x300 hardcoded, content overflows)
4. New Prompt window clips content (600x500 too small)
5. Variables panel needs UI redress
6. Menu bar lacks keyboard-driven usability
7. No comprehensive keyboard/accessibility navigation

## Design Decisions

**Read-only vs editable default:** Read-only preview on selection. Edit opens in a separate window (reusing PromptDetailView). Double-click on sidebar row also opens edit. In edit mode, raw `{{variable}}` syntax is visible so users can add/remove variables.

**Inline variables approach:** SwiftUI segmented flow. TemplateEngine splits content at `{{variable}}` boundaries into `[ContentSegment]` (`.text(String)` or `.variable(name:, value:)`). Each paragraph becomes an `HStack` of `Text` and `TextField` segments using existing `FlowLayout`. A compact summary panel sits below the inline content.

**Keyboard navigation model:** Mirrors HotkeyLauncherView pattern (selectedIndex + arrow key handlers). J/K for list navigation, `/` for search focus, `E` for edit, `Escape` for clear/deselect. Tab cycles through main window sections via `@FocusState` enum.

**Menu bar upgrade:** Full keyboard workflow (arrow keys, Enter to copy, 1-9 quick select), template variable quick-fill form in expanded rows, and additional actions (edit, tag management, favorite toggle, paste to frontmost app).

## Phase 1: Layout Fixes + Read-Only / Edit Window Foundation

### 1A: Tag picker popover size (S)
Change `.frame(width: 200, height: 300)` to `.frame(width: 260, height: 380)` in `NewPromptView.swift` and `InspectorView.swift`.

### 1B: New Prompt window size (S)
- PaultApp: `.defaultSize(width: 700, height: 620)`
- NewPromptView: `.frame(minWidth: 600, minHeight: 500)`

### 1C: Read-only PromptPreviewView (L)
New `PromptPreviewView.swift` — title as `Text`, content via `RichTextEditor` with `isEditable = false`, read-only tags, read-only attachments strip, Edit and Copy toolbar buttons. Replaces `PromptDetailView` in `ContentView` detail column.

### 1D: Edit window using existing PromptDetailView (M)
New `EditPromptView.swift` — thin wrapper receiving `Prompt.ID` via `openWindow(value:)`. New Window scene in PaultApp. Reuses PromptDetailView entirely.

### 1E: Double-click to edit from sidebar (S)
`.onTapGesture(count: 2)` on `PromptRowView` in SidebarView. Add Edit button to ContentView toolbar.

## Phase 2: Inline Template Variables + Variables Panel Redress

### 2A: TemplateEngine.splitContent() parser (S)
`ContentSegment` enum and `splitContent()` method. Tests in `TemplateEngineTests.swift`.

### 2B: InlineVariablePreview SwiftUI view (L)
New `InlineVariablePreview.swift` — renders `[ContentSegment]` as VStack of paragraphs, each an HStack of `Text`/`TextField` segments. Variable fields have rounded accent-tinted border, monospaced placeholder. Integrates into PromptPreviewView.

### 2C: Variables summary/reference panel (S)
Card-style container below inline content in PromptPreviewView. Header with count, name-value pairs, click-to-focus.

### 2D: Variables panel UI redress for edit window (M)
Restyle `TemplateVariablesView.swift` with card container, capsule badges, rounded bordered inputs, count header, code-block preview. Maintain Tab/Shift+Tab navigation.

## Phase 3: Keyboard Navigation + Accessibility

### 3A: Sidebar keyboard navigation (M)
J/K shortcuts, `/` for search focus, `E` for edit, `Escape` for clear/deselect. Guarded against text field focus.

### 3B: Tab through main window sections (M)
`FocusedSection` enum with `@FocusState`. Tab cycles sidebar, content, variables, inspector.

### 3C: VoiceOver compliance audit (M)
Systematic pass: MenuBarContentView, HotkeyLauncherView, TagPickerPopover, RichTextEditor, all new views.

### 3D: Power-user shortcuts (S)
`/`, `E`, `J`/`K`, `Escape`, `Cmd+Shift+C` (copy with resolved variables).

## Phase 4: Full Menu Bar Upgrade

### 4A: Keyboard-driven menu bar workflow (M)
selectedIndex state, arrow keys, Enter to copy, 1-9 quick select, `/` for search, Escape.

### 4B: Template variable quick-fill in menu bar (M)
Compact variable-filling form in expanded prompt rows. Uses shared `TemplateVariable.defaultValue`.

### 4C: Additional menu bar actions (S)
Edit action (activates main window), inline tag management, favorite star toggle, paste to frontmost app with resolved variables.

## Files Summary

| File | Action |
|------|--------|
| `Pault/NewPromptView.swift` | FIX tag picker size |
| `Pault/InspectorView.swift` | FIX tag picker size |
| `Pault/PaultApp.swift` | FIX window sizes, ADD edit-prompt Window scene |
| `Pault/PromptPreviewView.swift` | **CREATE** |
| `Pault/EditPromptView.swift` | **CREATE** |
| `Pault/ContentView.swift` | SWAP detail view, ADD toolbar, ADD focus management |
| `Pault/SidebarView.swift` | ADD double-click, keyboard nav |
| `Pault/TemplateEngine.swift` | ADD splitContent() |
| `Pault/InlineVariablePreview.swift` | **CREATE** |
| `Pault/TemplateVariablesView.swift` | RESTYLE |
| `Pault/MenuBarContentView.swift` | ADD keyboard nav, variable filling, actions |
| `Pault/AppDelegate.swift` | FIX popover key window |
| All view files | ADD accessibility labels |
| `PaultTests/TemplateEngineTests.swift` | ADD splitContent tests |

## Verification Criteria

1. Select prompt shows read-only preview. Edit/double-click opens edit window.
2. Inline variable fields at `{{variable}}` positions. Summary panel updates live.
3. Tab cycles sections. J/K navigates list. VoiceOver reads all elements.
4. Menu bar arrow keys navigate. Variable quick-fill works. Edit opens main window.
5. All 87+ tests pass. Release build zero warnings.
