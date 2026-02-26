# Smoother Prompt Creation Journey — Design

## Context

Pault has excellent post-creation tools (AI refinement, quality scoring, versioning) but zero pre-creation scaffolding. Users face a blank page when creating prompts — no templates, no starters, no guidance. The `{{variable}}` syntax, AI Assist panel, and tag system exist but are invisible to users who don't already know about them. This redesign introduces a **Launchpad modal** for choosing a starting point and **contextual coaching** in the editor for progressive feature discovery.

**Approach:** Mix of "Launchpad" (clear starting-point cards) + "Contextual Coaching" (lightweight tips in the editor).

---

## Section 1: Launchpad Modal

Replace the current `NewPromptView` (separate window) with a **modal sheet** over the main window.

**Layout:** A centered card grid with 4 starting-point cards:

| Card | Icon | Label | Behavior |
|------|------|-------|----------|
| Blank Prompt | `doc.text` | "Start from scratch" | Creates empty prompt, opens PromptDetailView |
| From Template | `rectangle.stack` | "Use a template" | Shows template browser within sheet |
| Generate with AI | `sparkles` | "Describe & generate" (Pro badge) | Text field → AI generates content |
| Paste from Clipboard | `doc.on.clipboard` | "Paste existing prompt" | Creates prompt from clipboard text |

**Below the grid:** "Recent Templates" horizontal scroll row (top 5 by usage count, hidden if none used yet).

**Keyboard shortcuts:**
- `Return` → Blank Prompt
- Typing → search templates
- `Escape` → dismiss

**All paths end with:** `PromptService.createPrompt()` → post `.promptCreated` → user lands in `PromptDetailView`.

---

## Section 2: Template System

**`PromptTemplate` — new SwiftData model:**
- `id: UUID`, `name: String`, `content: String`, `category: String` ("Writing", "Coding", "Analysis")
- `isBuiltIn: Bool` — bundled vs. user-created
- `iconName: String` — SF Symbol for Launchpad display
- `usageCount: Int` — tracks popularity for "Recent Templates" row
- `createdAt: Date`, `updatedAt: Date`

**Bundled templates** (~6-8 starters, seeded on first launch):
- `TemplateSeedService` checks `@AppStorage("hasSeededTemplates")` flag, bulk-inserts
- Examples: "Meeting Notes Extractor", "Code Review Checklist", "Email Drafter", "Bug Report", "Creative Writing Starter"
- Each has pre-filled content with `{{variables}}` already placed
- `isBuiltIn = true` — users can duplicate-and-edit but not delete

**Save as Template** (from PromptDetailView action menu):
- Creates `PromptTemplate` from current prompt's content
- User names it, picks category
- `isBuiltIn = false` — fully editable and deletable

**"From Template" card flow:**
1. Tap card → grid/list of templates grouped by category (within modal)
2. Pick one → `PromptService.createPrompt()` pre-fills from template
3. Template's `usageCount` incremented
4. Lands in `PromptDetailView` with content ready to customize

---

## Section 3: AI Generation Path

**"Generate with AI" card** (Pro-gated via `ProStatusManager.shared.isProUnlocked`):

1. Tap card → text field: "Describe what you want your prompt to do..."
2. Type description (e.g., "A prompt that helps me write better commit messages")
3. Tap "Generate" → calls existing `AIService` with system prompt to create a reusable prompt template with `{{variables}}`
4. Result → `PromptService.createPrompt()` with generated content
5. Lands in `PromptDetailView` to refine (full AI Assist panel available)

**Design decisions:**
- Reuses existing `AIService` and API key infrastructure — no new AI plumbing
- Single-step generation (no multi-turn wizard) — lightweight as "one of several paths"
- If no API key configured, show nudge to set one up in Preferences

---

## Section 4: Contextual Coaching

**Where:** In `PromptDetailView` — the editor users land in after any Launchpad path.

**Empty-state tips** (shown when content is empty/short):
- Subtle, dismissible tip area below title field
- Contextual based on what's missing:
  - No content → "Tip: Use {{variable_name}} to create reusable placeholders"
  - Content but no variables → "Tip: Add {{variables}} to make this prompt reusable"
  - Variables but no tags → "Tip: Add tags to organize your prompts"
- Each tip has "x" to dismiss + "Don't show again" via `@AppStorage`
- Tips auto-disappear when user performs the suggested action

**Power-feature discovery:**
- First few uses: small blue dot badge on AI Assist panel button
- Clears after user opens the panel once
- `@AppStorage("hasDiscoveredAIAssist")`

---

## Files to Create

| File | Purpose |
|------|---------|
| `Pault/PromptTemplate.swift` | SwiftData model for templates |
| `Pault/TemplateSeedService.swift` | Seeds bundled templates on first launch |
| `Pault/PromptLaunchpadView.swift` | Launchpad modal sheet with card grid |

## Files to Modify

| File | Changes |
|------|---------|
| `Pault/PaultApp.swift` | Add `PromptTemplate.self` to schema; remove `Window("New Prompt")`; call seed in `init()` |
| `Pault/ContentView.swift` | Replace `openWindow(id: "new-prompt")` with `@State var showCreationSheet` + `.sheet()` |
| `Pault/PromptDetailView.swift` | Add contextual coaching tips in empty state |
| `Pault/PromptService.swift` | Add `createPromptFromTemplate(_:)` method |
| `Pault/AIService.swift` | Add `generatePrompt(from description:)` method |

## Existing Code to Reuse

| Code | Location | Purpose |
|------|----------|---------|
| `PromptService.createPrompt()` | `Pault/PromptService.swift` | Single creation entry point — all paths use this |
| `TemplateEngine.syncVariables()` | `Pault/TemplateEngine.swift` | Auto-detect `{{variables}}` after template/AI fill |
| `ProStatusManager.shared.isProUnlocked` | Throughout views | Gate AI generation card |
| `AIService` infrastructure | `Pault/AIService.swift` | Reuse for prompt generation |
| `FlowLayout` | `Pault/FlowLayout.swift` | Template category chips in Launchpad |
| `TagPickerPopover` pattern | `Pault/NewPromptView.swift` | Category picker UX pattern |
