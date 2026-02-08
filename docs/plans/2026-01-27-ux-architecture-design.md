# Pault UX Architecture Design

> **Status: COMPLETED** — Menu bar-first architecture implemented. See `2026-01-27-menu-bar-implementation.md` for the task-level plan.

## Overview

Transform Pault from a dock-based app into a menu bar-first AI prompt library. Quick access handles 90% of usage; the main app becomes a management console for setup and bulk operations.

---

## Core Concept

Pault becomes a menu bar-first application with two quick access methods:

1. **Menu bar popover** — Full mini-browser with search, filters, prompt list, and inline editing
2. **Global hotkey launcher** — Spotlight-style quick search with instant actions

### Mental Model

```
┌─────────────────────────────────────────────────────────┐
│                    Quick Access Layer                    │
│  ┌─────────────────┐      ┌─────────────────────────┐  │
│  │  Menu Bar Icon  │      │  Global Hotkey Launcher │  │
│  │  (full browser) │      │  (search → action)      │  │
│  └─────────────────┘      └─────────────────────────┘  │
│                              │                          │
│         90% of usage ────────┘                          │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼ (rare)
┌─────────────────────────────────────────────────────────┐
│                     Main App (Dock)                      │
│           Setup, bulk operations, preferences            │
└─────────────────────────────────────────────────────────┘
```

### App Lifecycle

- Pault runs as a menu bar app (no dock icon by default)
- Main window can be opened from menu bar or ⌘+, for preferences
- Stays running in background for instant access

---

## Menu Bar Popover

### Appearance

A popover window (roughly 320×480pt) anchored to the menu bar icon. Feels native, like macOS's Wi-Fi or Bluetooth popovers but larger.

### Layout

```
┌──────────────────────────────────┐
│ 🔍 Search...                     │
├──────────────────────────────────┤
│ ★ Favorites    All    Archived   │  ← Filter tabs
├──────────────────────────────────┤
│ ┌──────────────────────────────┐ │
│ │ Email Tone Adjuster     #work│ │
│ │ Code Review Prompt   #coding │ │
│ │ Meeting Summary         ★    │ │
│ │ ...                          │ │
│ └──────────────────────────────┘ │
│         (scrollable list)        │
├──────────────────────────────────┤
│ [+ New]              [⚙ Settings]│
└──────────────────────────────────┘
```

### Interactions

- **Click prompt** → Expands inline to show full content + action buttons (Copy / Paste / Edit / Open in App)
- **Right-click prompt** → Context menu (Favorite, Archive, Delete)
- **Click tag pill** → Filters list to that tag
- **+ New** → Inline creation form (title, content, tags)
- **Edit mode** → Fields become editable inline, auto-saves on blur

### Keyboard Navigation

- Arrow keys navigate list
- Enter on selected prompt → shows options
- ⌘+C copies immediately
- ⌘+V pastes to frontmost app
- Escape closes popover

---

## Global Hotkey Launcher

### Appearance

A floating panel centered on screen (similar to Spotlight or Raycast). Minimal chrome, appears instantly on hotkey press.

```
┌────────────────────────────────────────────────┐
│  🔍 Search prompts...                          │
├────────────────────────────────────────────────┤
│  ▶ Email Tone Adjuster              #work      │
│    Code Review Prompt               #coding    │
│    Meeting Summary                  ★          │
│    Bug Report Template              #coding    │
└────────────────────────────────────────────────┘
         ↑ results update as you type
```

### Behavior

- **Default hotkey**: ⌘+Shift+P (customizable in preferences)
- **Instant fuzzy search** across title, content, and tags
- **Results ranked by**: exact match → favorites → recent use → alphabetical

### Selection Flow

When you press Enter (or click) on a prompt:

```
┌────────────────────────────────────────────────┐
│  Email Tone Adjuster                           │
├────────────────────────────────────────────────┤
│  [⌘C Copy]   [⌘V Paste]   [⌘E Edit]   [⌘O Open]│
└────────────────────────────────────────────────┘
```

- **⌘+C** → Copy to clipboard, dismiss
- **⌘+V** → Copy + paste into frontmost app, dismiss
- **⌘+E** → Open in menu bar popover for editing
- **⌘+O** → Open in main app
- **Escape** → Go back to search

### Speed Shortcuts

From the search results (without selecting first):
- **⌘+1 through ⌘+9** → Instantly copy the Nth result

---

## Main App Changes

### Role Shift

The main app becomes a "management console" rather than the primary interface. Opens when you need to:
- Bulk edit or reorganize prompts
- Manage tags (rename, merge, delete)
- Import/export library
- Configure preferences

### Behavior Changes

- **No dock icon by default** — Pault runs as menu bar agent
- **Open via**: Menu bar → Settings → "Open Main Window", or ⌘+, from anywhere
- **Closing main window** doesn't quit — app stays in menu bar

### Preferences

| Setting | Options |
|---------|---------|
| Global hotkey | Customizable (default ⌘+Shift+P) |
| Launch at login | On/Off |
| Show dock icon | On/Off |
| Default action | Copy / Paste / Show options |
| Paste delay | 0-500ms (for apps that need it) |

### Main Window Focus

Since quick access handles browsing/editing, the main app focuses on:
- **Library view** — Table/grid of all prompts with bulk selection
- **Tag manager** — Dedicated view for organizing tags
- **Import/Export** — Backup and restore
- **Preferences** — All settings in one place

---

## Implementation Summary

### New Components to Build

| Component | Description |
|-----------|-------------|
| `PaultMenuBarApp` | Menu bar agent with NSPopover |
| `MenuBarPopover` | Full browser view (search, filters, list, inline editing) |
| `HotkeyLauncher` | Floating panel with fuzzy search |
| `GlobalHotkeyManager` | Registers and handles system-wide hotkey |
| `PasteService` | Simulates paste into frontmost app |
| `PreferencesView` | Settings for hotkey, launch at login, etc. |

### Technical Considerations

- **Menu bar app**: Use `NSStatusItem` + `NSPopover` for native feel
- **Global hotkey**: Use `CGEvent` tap or a library like HotKey
- **Paste simulation**: `CGEvent` to send ⌘+V to frontmost app
- **App lifecycle**: `LSUIElement = YES` in Info.plist to hide dock icon

### Migration Path

1. Keep current main app working
2. Add menu bar agent alongside
3. Add global hotkey launcher
4. Add preferences to control behavior
5. Default to menu bar-first for new users

### Data Model Changes

No changes to existing `Prompt` and `Tag` models. Additions:
- `lastUsedAt: Date` on Prompt for "recent" sorting in launcher
- User preferences stored in `UserDefaults` or a `Settings` model

---

## Summary

| Layer | Purpose | Access |
|-------|---------|--------|
| Menu bar popover | Full browser, inline editing | Click menu bar icon |
| Hotkey launcher | Fast search → action | ⌘+Shift+P |
| Main app | Management, settings, bulk ops | Rarely opened |
