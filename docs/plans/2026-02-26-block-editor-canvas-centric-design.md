# Block Editor UX Redesign: Canvas-Centric Approach

**Date:** 2026-02-26
**Status:** Approved
**Scope:** Block-based prompt building UX improvements

---

## Problem Statement

The current block editor has friction across four areas:

1. **Discovery** — Hard to find blocks in 20+ categories
2. **Composition flow** — Drag-drop workflow fragments attention
3. **Placeholder editing** — Tedious, hidden, no guidance
4. **Preview feedback** — Separate panel, not always visible

## Solution: Canvas-Centric Design

Make the canvas the primary interface. Panels become optional assistants. Users build prompts through inline interactions rather than panel switching.

---

## Design Sections

### 1. Slash Command Palette

**Trigger:** Type `/` in canvas or press `⌘K`

**Behavior:**
- Floating palette appears near cursor
- Fuzzy search across all block titles and snippets
- Results grouped by category with icons
- Keyboard navigation: ↑/↓ select, Enter insert, Esc dismiss

**Layout:**
```
┌─────────────────────────────────┐
│ 🔍 /role                        │
├─────────────────────────────────┤
│ ⭐ Recent                        │
│   • Expert Advisor (Role)       │
│   • Step-by-Step (Format)       │
├─────────────────────────────────┤
│ 👤 Role                          │
│   • Expert Advisor              │
│   • Persona                     │
│   • Devil's Advocate            │
├─────────────────────────────────┤
│ 📋 Templates                     │
│   • Code Review                 │
│   • Writing Assistant           │
└─────────────────────────────────┘
```

**Keyboard shortcuts:**
- `/` — Open palette (when canvas focused)
- `⌘K` — Open palette (global within editor)
- `↑/↓` — Navigate results
- `Enter` — Insert selected block
- `Esc` — Dismiss palette

---

### 2. Inline Block Editing

**Block States:**

| State | Indicator | Description |
|-------|-----------|-------------|
| Unfilled | 🔴 Red dot | Has unfilled required placeholders |
| Editing | 🟡 Yellow dot | Currently expanded for editing |
| Complete | 🟢 Green dot | All placeholders filled |

**Collapsed view:**
```
┌─────────────────────────────────────────────┐
│ 🔴 Expert Advisor          [Role]    ✕     │
└─────────────────────────────────────────────┘
```

**Expanded view (click to expand):**
```
┌─────────────────────────────────────────────┐
│ 🟡 Expert Advisor          [Role]    ✕     │
├─────────────────────────────────────────────┤
│ domain                                      │
│ ┌─────────────────────────────────────────┐ │
│ │ TypeScript and React                    │ │
│ └─────────────────────────────────────────┘ │
│ 💡 e.g., "machine learning", "legal"       │
├─────────────────────────────────────────────┤
│ years_experience                            │
│ ┌─────────────────────────────────────────┐ │
│ │ 10                                      │ │
│ └─────────────────────────────────────────┘ │
│ 💡 Number of years of expertise            │
└─────────────────────────────────────────────┘
```

**Interactions:**
- Click block → expand/collapse
- Tab → move between placeholder fields
- Enter on last field → collapse, move to next block
- Placeholder hints shown below each field

**Placeholder value reuse:**
- Auto-suggest from previously used values
- Dropdown appears as you type with matches

---

### 3. Consolidated Block Library

**Category reduction:** 20+ categories → 7 top-level categories

| New Category | Icon | Consolidated From |
|--------------|------|-------------------|
| Role | 👤 | Role, Persona, Perspective |
| Context | 📖 | Context, Background, Domain, Knowledge |
| Task | ✅ | Task, Goal, Action, Request, Question |
| Format | 📋 | Format, Output, Structure, Style, Markdown |
| Constraints | 🚫 | Constraints, Rules, Boundaries, Limits, Tone |
| Examples | 📝 | Examples, Few-shot, Patterns |
| Meta | ⚙️ | Meta, Chain-of-thought, Reasoning, Self-check |

**Library panel layout:**
```
┌─ Block Library ─────────────────────────────┐
│ 🔍 Search blocks...                         │
├─────────────────────────────────────────────┤
│ ⭐ RECENT                                    │
│   Expert Advisor • Step-by-Step • Markdown  │
├─────────────────────────────────────────────┤
│ 💡 SUGGESTED                                 │
│   Based on: Expert Advisor                  │
│   → Context Block  → Task Block             │
├─────────────────────────────────────────────┤
│ ▼ 👤 Role (12)                              │
│ ▶ 📖 Context (8)                            │
│ ▶ ✅ Task (15)                               │
│ ▶ 📋 Format (10)                            │
│ ▶ 🚫 Constraints (6)                        │
│ ▶ 📝 Examples (4)                           │
│ ▶ ⚙️ Meta (5)                               │
├─────────────────────────────────────────────┤
│ 📦 TEMPLATES                                 │
└─────────────────────────────────────────────┘
```

**Features:**
- Search bar with fuzzy matching
- Recent blocks section (last 5 used)
- Suggested blocks based on canvas state
- Collapsible category sections with counts
- Double-click to add, drag-drop for positioning

---

### 4. Smart Preview Strip

**Always-visible strip below canvas:**
```
┌───────────────────────────────────────────────────┐
│  Preview Strip                               ⌘P ▲ │
├───────────────────────────────────────────────────┤
│ You are an expert in TypeScript and React with   │
│ 10 years of experience. [Task placeholder]...    │
├───────────────────────────────────────────────────┤
│ ~127 tokens • 2/3 placeholders filled  [Expand ▲]│
└───────────────────────────────────────────────────┘
```

**Features:**
- 2-3 lines of live compiled output
- Token counter with color coding:
  - 🟢 Green: < 1000 tokens
  - 🟡 Yellow: 1000-3000 tokens
  - 🔴 Red: > 3000 tokens
- Placeholder fill status: "2/3 filled"
- Expand button or `⌘P` for full preview

**Expanded preview (overlay):**
```
┌─ Full Preview ──────────────────────────── ✕ ─┐
│  Raw │ Filled │ Diff                          │
├───────────────────────────────────────────────┤
│ You are an expert in TypeScript and React    │
│ with 10 years of experience.                 │
│                                               │
│ {{task_description}}  ← highlighted unfilled │
│                                               │
│ Please provide your response in markdown.    │
├───────────────────────────────────────────────┤
│ ~127 tokens                        [Copy 📋] │
└───────────────────────────────────────────────┘
```

**Highlight mapping:**
- Click block in canvas → highlights in preview
- Click text in preview → highlights corresponding block

---

### 5. Block Templates

**Pre-built block combinations for common patterns.**

**Built-in templates:**

| Template | Blocks | Use Case |
|----------|--------|----------|
| Code Review | 5 | Review code for bugs, style, improvements |
| Writing Assistant | 4 | Help with drafting and editing text |
| Data Analysis | 5 | Analyze datasets and extract insights |
| Brainstorming | 4 | Generate ideas with structured output |
| Explanation | 4 | Explain concepts at adjustable levels |
| Step-by-Step Guide | 5 | Create tutorials or instructions |

**Template card:**
```
┌─ Template: Code Review ─────────────────────┐
│ 📦 5 blocks • ~200 tokens base              │
│                                             │
│ Includes:                                   │
│ • Expert Advisor (Role) - "code review"     │
│ • Code Context (Context) - {{language}}     │
│ • Review Task (Task) - {{focus_areas}}      │
│ • Structured Feedback (Format)              │
│ • Constructive Tone (Constraints)           │
│                                             │
│ [Preview] [Insert All] [Customize]          │
└─────────────────────────────────────────────┘
```

**Actions:**
- **Preview** — Show compiled template with placeholders
- **Insert All** — Add all blocks to canvas
- **Customize** — Select which blocks to insert

**Access:**
- `/template code review` or `/temp` with fuzzy match
- Templates section in library panel
- Custom templates: save current canvas as template

---

### 6. AI Suggestions

**Contextual suggestions based on canvas state.**

**Suggestion triggers:**

| Canvas State | Suggestion |
|--------------|------------|
| Empty | "Start with a Role or Template" |
| Role only | "Add Context or Task next" |
| Role + Task | "Consider Format or Constraints" |
| No Format block | "Add output format for consistency" |
| >2000 tokens | "Consider Constraints to focus" |

**UI placement (inline in canvas):**
```
┌─ 💡 Suggested ──────────────────────────┐
│ Add a Task block to define what the    │
│ expert should do                        │
│                                         │
│ [+ Task Block]  [+ Context Block]       │
│                        [Dismiss ✕]      │
└─────────────────────────────────────────┘
```

**Behavior:**
- Appears inline after adding a block (2s delay)
- Max 1 suggestion at a time
- Dismiss with ✕ or Esc — won't repeat this session
- User preference to disable entirely

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `/` | Open slash command palette |
| `⌘K` | Open slash command palette (global) |
| `⌘P` | Toggle full preview |
| `⌘[` | Toggle block library panel |
| `↑/↓` | Navigate blocks or palette |
| `Enter` | Expand block / insert from palette |
| `Tab` | Next placeholder field |
| `Esc` | Collapse block / dismiss palette |
| `Delete` | Remove selected block |

---

## Layout Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Block Library (collapsible)  │  Canvas (primary)           │
│                               │                             │
│  🔍 Search...                 │  / Add block...             │
│                               │                             │
│  ⭐ Recent                    │  ┌─────────────────────────┐│
│  💡 Suggested                 │  │ 🟢 Expert Advisor [Role]││
│                               │  └─────────────────────────┘│
│  ▼ Role                       │  ┌─────────────────────────┐│
│  ▶ Context                    │  │ 🔴 Task Block    [Task] ││
│  ...                          │  └─────────────────────────┘│
│                               │                             │
│                               │  💡 Suggested: Add Format   │
│                               │                             │
│                               │  / Add block...             │
├───────────────────────────────┴─────────────────────────────┤
│  Preview Strip                                         ⌘P ▲ │
│  You are an expert... ~127 tokens • 2/3 filled    [Expand] │
└─────────────────────────────────────────────────────────────┘
```

---

## Success Criteria

1. **Discovery:** Users can find any block in <5 seconds via slash command
2. **Composition:** Building a 5-block prompt takes <60 seconds
3. **Placeholders:** All unfilled placeholders visible at a glance
4. **Preview:** Token count and output always visible without panel switching

---

## Out of Scope

- Collaborative editing
- Version history for templates
- Block marketplace / sharing
- Natural language to blocks ("make me a code review prompt")

These may be considered for future iterations.
