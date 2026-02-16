# Phase 2.5 Brainstorms — Design Notes for Future Phases

These are design-only brainstorms from user testing feedback. No code changes — just ideas for future implementation.

---

## 2.5C: Settings Page Expansion

Current settings after paste removal: 2 tabs, ~3 items total. Feels sparse.

### Top Candidates to Add

1. **Appearance tab** — Font size slider, compact mode toggle, accent color override
2. **Data Management tab** — Export/Import prompts (JSON), clear all data, storage path info, prompt count
3. **About section in General tab** — Version display, reset all settings button

### Deferred (Complex)

4. Keyboard Shortcuts customization (requires Carbon/HotKey framework integration)

---

## 2.5D: File Menu Bar Expansion

Current: only "New Prompt" (⌘N).

### Top Candidates to Add

1. **Edit menu** — Copy Prompt (⌘C), Duplicate Prompt (⌘D)
2. **View menu** — Toggle Inspector (⌘I), Toggle Sidebar (⌘⌥S)
3. **Help menu** — Keyboard Shortcuts Reference, Report a Bug link

### Deferred (Depends on Data Management)

4. Prompt menu — Import/Export Prompts

---

## 2.5E: About Screen

No custom About screen exists currently.

### Recommended: Branded About with Links

- App icon centered at top
- "Pault" in large font + tagline
- Version/build from `Bundle.main`
- Clickable links: website, GitHub, feedback email
- Copyright line
- Override default About via `CommandGroup(replacing: .appInfo)`
