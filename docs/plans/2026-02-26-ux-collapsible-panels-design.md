# UX Redesign: Collapsible Panel System

**Date:** 2026-02-26
**Status:** Approved
**Scope:** Main window layout, block editor, animations

---

## Problem Statement

The current 3-column NavigationSplitView (Sidebar | Detail | Inspector) causes UX friction:
- **Too crowded** — elements compete for attention
- **Poor hierarchy** — unclear what's primary vs secondary
- **Awkward navigation** — moving between columns feels clunky
- **Wasted space** — screen real estate not used efficiently

**User goal:** Focus on editing — prompt content should dominate; everything else should get out of the way.

---

## Solution: Hybrid Collapsible Panel System

Slide-out panels that auto-collapse when editing begins. Combines manual control with intelligent auto-hide behavior.

### Core Layout Architecture

Replace NavigationSplitView with single-column editor and collapsible side panels:

```
Default (panels collapsed):
┌─────────────────────────────────────────────────────────┐
│  [≡]              Prompt Title                    [i]   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│                    EDITOR CONTENT                       │
│                  (Full width, focused)                  │
│                                                         │
└─────────────────────────────────────────────────────────┘

With sidebar (⌘1):
┌──────────┬──────────────────────────────────────────────┐
│ Sidebar  │              EDITOR CONTENT                  │
│ (slide)  │            (pushes right)                    │
└──────────┴──────────────────────────────────────────────┘

With inspector (⌘I):
┌─────────────────────────────────────────────┬───────────┐
│              EDITOR CONTENT                 │ Inspector │
│              (pushes left)                  │  (slide)  │
└─────────────────────────────────────────────┴───────────┘
```

**Key behaviors:**
- Default: Editor only (panels collapsed)
- Toggle shortcuts: ⌘1 for sidebar, ⌘I for inspector
- Auto-collapse: Panels slide away 2-3s after user starts typing
- Hover reveal: Cursor at edge shows panel peek indicator
- Animations: Spring-based slide (200-300ms)

---

## Sidebar Redesign

**Collapsed state:**
- Hidden entirely
- Toolbar shows [≡] hamburger icon
- Keyboard: ⌘1 to toggle

**Expanded state:**
- Width: 220-260px
- Compact prompt list (smaller rows, more prompts visible)
- Sticky search field at top
- Horizontal filter chips (All | Recent | Archived | Tags)
- Floating "+" button at bottom

**Auto-collapse triggers:**
- User starts typing in editor → collapse after 2s
- User presses Escape → collapse immediately
- User clicks prompt → stays open (browsing mode)

---

## Inspector Redesign

**Collapsed state:**
- Hidden entirely
- Toolbar shows [i] info icon
- Keyboard: ⌘I to toggle

**Expanded state:**
- Width: 200-240px
- Single scrollable view (no tabs):
  - Top: Title, Tags (editable), Favorite toggle
  - Middle: Quick stats (created, modified, used count)
  - Bottom: Version history (collapsible section)
- Stats tab only for Pro users

**Auto-collapse triggers:**
- Same as sidebar
- Exception: stays open while editing tags

---

## Editor Area Enhancements

**Minimal toolbar:**
- Left: [≡] sidebar toggle + breadcrumb
- Center: Mode toggle (Text | Blocks)
- Right: [Copy] [Run▾] [i] inspector toggle

**Full-width editor:**
- Content-width constraint (~700px) centered for readability
- Or full width with user preference toggle

**Fixed bottom toolbar (text mode):**
- Variable summary
- A/B variant picker
- AI Assist button
- More stable than current floating toolbar

**Keyboard focus:**
- ⌘Enter to run prompt
- Escape to collapse all panels
- Tab through variables

---

## Block Editor Consistency

Apply same collapsible philosophy:

```
Default:
┌─────────────────────────────────────────────────────────┐
│ [≡ Library]     Block Canvas Title            [Preview] │
├─────────────────────────────────────────────────────────┤
│                   BLOCK CANVAS                          │
│               (full width, focused)                     │
└─────────────────────────────────────────────────────────┘
```

**Library (left):** ⌘[ to toggle, auto-collapses after drag-drop
**Preview (right):** ⌘] to toggle, shows Raw/Filled/Diff modes
**Canvas:** Full width when panels collapsed, keyboard nav works regardless

---

## Animations & Transitions

**Panel animations:**
- Slide in/out (200ms spring)
- Content pushes (no overlay)

**Auto-collapse sequence:**
- Panel dims (0.5s) as warning
- Then slides out
- Moving cursor to panel cancels collapse

**Focus transitions:**
- Editor content fades (100ms) on prompt switch
- Cursor moves to editor start

**State persistence:**
- Remember panel states per session
- User preference: "Always collapsed" vs "Remember last state"

---

## Keyboard Shortcuts Summary

| Shortcut | Action |
|----------|--------|
| ⌘1 | Toggle sidebar |
| ⌘I | Toggle inspector |
| ⌘[ | Toggle block library |
| ⌘] | Toggle block preview |
| ⌘Enter | Run prompt |
| Escape | Collapse all panels, focus editor |
| Tab | Next variable (in editor) |

---

## Files to Modify

**Main window:**
- `ContentView.swift` — Replace NavigationSplitView with collapsible architecture
- `SidebarView.swift` — Compact layout, horizontal filters
- `InspectorView.swift` — Single-scroll layout, remove tabs
- `PromptDetailView.swift` — Full-width editor, bottom toolbar

**Block editor:**
- `BlockEditorView.swift` — Replace HSplitView with collapsible panels
- `BlockLibraryView.swift` — Slide-out behavior
- `CompiledPreviewView.swift` — Slide-out behavior

**New components:**
- `CollapsiblePanelContainer.swift` — Reusable panel container
- `PanelToggleButton.swift` — Consistent toggle buttons
- `AutoCollapseManager.swift` — Centralized auto-collapse logic

**Supporting:**
- `Constants.swift` — Panel widths, animation timings
- `Preferences` — Panel state persistence

---

## Success Criteria

1. Editor takes full width by default (no visible panels)
2. Panels slide in/out smoothly with spring animation
3. Auto-collapse works reliably (typing triggers collapse)
4. Keyboard shortcuts work consistently (⌘1, ⌘I, etc.)
5. Block editor follows same pattern
6. Panel states persist across sessions
7. No loss of existing functionality
