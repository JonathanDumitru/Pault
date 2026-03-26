# Phase 2: Block Editor Polish — Context & Decisions

> Captured from /gsd:discuss-phase session on 2026-03-25
> 21 areas discussed, ~135 decisions

---

## 1. Drag-Drop & Reordering

- Full drag reordering within canvas (not just keyboard)
- Line indicator between blocks for drop position
- Library blocks droppable at specific canvas positions (not just append)
- Compact preview (title + category) while dragging
- Drag handle icon only (not entire header)
- Interrupt and snap for rapid reorder (no queued animations)
- Always draggable even when expanded (auto-collapse during drag, re-expand on drop)
- Illustrated drop zone for empty canvas with dashed border + guidance text
- Grab cursor on drag handle hover
- Dim drag handle when single block
- Both drag AND keyboard (Option+Arrow) reordering
- Auto-scroll canvas when dragging near top/bottom edges
- Lift effect (scale + shadow) when block picked up
- Animation only for drop confirmation (no toast/sound)

## 2. Undo/Redo

- Structural operations only (add, remove, reorder, duplicate, modifiers). Text inputs use standard macOS TextField undo
- Undo after save marks composition dirty again (standard document model)
- Menu + keyboard only (Cmd+Z / Shift+Cmd+Z) — no toolbar buttons
- Unlimited undo depth per session
- Removed block returns to exact original position on undo
- Full state restore on redo (block + inputs + modifiers)
- Clear redo stack on new action (standard linear undo)
- Shared undo stack across Build/Edit/Debug tabs
- Clear undo stack on navigation away from prompt
- Standard menu dimming when stacks are empty

## 3. VoiceOver & Accessibility

- Full navigation + custom actions (Move Up/Down, Delete via .accessibilityAction)
- Accessible actions menu for drag-drop (not drag gestures)
- Polite VoiceOver announcements for preview updates
- Full VO support for slash command palette (per-item announcements, selection tracking)
- Respect Reduce Motion (replace spring animations with cross-fades/instant)
- Visible focus ring on selected block (system accent color, 2pt border)
- Icons + color for placeholder status indicators (✖/⚠/✔ alongside red/yellow/green)
- Structured tab order: Library → Canvas (blocks → inputs) → Preview
- Announce category with each block ("Role block: System Prompt, position 1 of 5")
- Respect system text size (Dynamic Type)
- Announce block count changes ("Block added. 5 blocks on canvas.")
- Announce suggestion banner as polite alert
- Help rotor item with keyboard shortcut summary
- Support high contrast mode (@Environment(\.colorSchemeContrast))
- Support Differentiate Without Color (patterns/shapes alongside category colors)
- Disable auto-collapse when VoiceOver is active
- Keyboard shortcut guide via ? button / Cmd+?
- Validation errors announced on field exit (not live)
- Library blocks get 'Add to Canvas' accessibility action
- Token estimate and warnings as part of canvas summary
- Automatic from system settings (no in-app accessibility toggle)
- Panel expand/collapse state announced
- Modifier picker traps VoiceOver focus when open (modal)
- Block elements are separate navigable children (not combined)

## 4. Animation & Layout Polish

- Height animation for expand/collapse (slide, not fade)
- Invisible performance optimization (no visible loading indicators for 20+ blocks)
- Subtle shimmer/pulse on preview during compilation
- Slide from edge for panel transitions (existing pattern)
- Animated reflow for surrounding blocks on add/remove
- Refine auto-collapse warning timing (opacity + subtle blur)
- Fade + scale pop for slash command palette opening (<100ms)
- Fix compilation cache bug (include modifiers in cache key)
- Responsive panels with min widths (auto-collapse below threshold)
- Refine block hover effect (snappier transition + subtle category tint)
- Slide + fade for suggestion banner
- Polish ModeSwitchDialogView (backdrop blur, smooth scale-in)
- Underline slide for preview tab transitions
- Skeleton shimmer for initial load of 10+ block prompts
- Subtle gradient on block category color indicators
- Enforce minimum canvas width (~300px, panels auto-collapse first)
- Spacing + shadow sufficient for block separation (no dividers)
- Verify and fix dark mode across all block editor views
- Soft block count limit with warning at ~30 blocks

## 5. Scroll Behavior

- Auto-scroll to new block when added
- Scroll + focus to first error field on validation failure
- Keep selected block visible during keyboard navigation
- Preserve scroll position when toggling panels
- Cmd+Home/End for jump to first/last block
- Scroll to show full expanded block content
- Standard macOS momentum scrolling
- Standard rubber-band bouncing at edges
- Independent scroll per panel (library, canvas, preview)
- System default overlay scroll bars

## 6. Keyboard Shortcuts

- Option+Up/Down for block reordering
- Cmd+D for block duplication
- Enter/Return toggles expand/collapse on selected block
- Floating panel for shortcut help (Cmd+?)
- Layered Esc: palette → picker → help → deselect → collapse
- Context-dependent Tab (between blocks when collapsed, between inputs when expanded)
- Cmd+Shift+E toggles all blocks expanded/collapsed
- Cmd+Shift+C copies compiled prompt to clipboard
- Delete, Forward Delete, AND Cmd+Backspace all remove block
- Right-click context menu on blocks (Duplicate, Delete, Move Up/Down, Expand/Collapse, Copy)
- Only Cmd+/ opens palette (no bare / key)
- Cmd+1/2/3 for panel focus (Library/Canvas/Preview)

## 7. Focus Management

- Esc from text field → back to block header (not canvas)
- After block delete → focus next block (or previous if last)
- After slash palette insert → focus new block's first input (auto-expand)
- After library 'Add to Canvas' → focus jumps to canvas
- After undo remove → focus restored block
- After undo reorder → focus moved block

## 8. Testing Strategy

- Snapshot tests for key visual states (empty, single, multi, expanded, drag, error, dark mode)
- Both light and dark mode snapshots
- Programmatic accessibility audit tests
- Targeted performance benchmarks (20 blocks, palette open, preview update)
- Comprehensive undo/redo unit tests
- Model tests + 1-2 UI tests for drag-drop
- Integration tests for keyboard navigation flows
- Feature-based test files: DragDropTests, UndoRedoTests, AccessibilityTests, KeyboardNavigationTests, PerformanceBenchmarkTests, CanvasSnapshotTests
- Extend existing Phase 1 test files for model-level undo/redo/duplicate
- CI-ready (unit + a11y + perf in CI; UI + snapshot tests optional)

## 9. Edge Cases

- Long content: inputs grow with content (max ~500px then scroll)
- Rapid add: queue and process sequentially (abbreviated animations)
- Delete last block: allowed, shows empty canvas drop zone
- Long titles: truncate with ellipsis + hover tooltip
- Paste on canvas: ignored (text paste only in fields)
- Delete confirmation: none (trust undo system)
- Mode mismatch: show ModeSwitchDialogView for text-to-block conversion
- Data load failure: error state with "Try text mode" / "Reload" recovery
- Concurrent editing: detect and warn banner ("Modified elsewhere. Reload / Keep mine")
- Window resize/Split View: adaptive layout with auto-collapse
- No auto-save (explicit Cmd+S only)
- Warn on dirty navigation ("Unsaved changes. Save / Discard / Cancel")
- Duplicate block types: allowed with visual hint from suggestion engine
- Undo across sessions: no persistence (clear per session)

## 10. Block Library UX

- Filter as-you-type search
- Tooltip on hover (description, placeholders, category)
- Categories expanded by default
- Subtle badge on blocks already on canvas (count)
- Click adds to canvas (not drag-only)
- Highlight matching text in search results
- Persist category collapsed/expanded state across sessions
- Helpful "no results" state for empty search
- Shared filter logic between library and slash palette

## 11. Modifier UX

- Modifiers reorderable via drag within a block
- Indented subsection with 'Modifiers' label
- Mark applied modifiers in picker (checkmark, toggle to remove)
- Immediate removal with undo (no confirmation)
- Separate undo action for modifier add/remove
- Cmd+Shift+M to open modifier picker
- Highlight modifier-affected text in Diff preview mode
- Same validation (InputValidator) for modifier inputs

## 12. Preview Panel

- Cmd+F search within preview text
- Copy active mode (button label: "Copy Raw" / "Copy Filled" / "Copy Diff")
- Collapsible inspector section (collapsed by default)
- Color-coded inline diff (green additions, red deletions)
- Footer stats bar (word count, character count, token estimate)
- Placeholder highlighting in Raw mode ({{placeholders}} colored, code blocks tinted)
- Wrap by default with toggle for no-wrap

## 13. Copy/Paste Integration

- Cmd+C on selected block copies block's individual compiled output
- No block paste on canvas (text paste only in fields, Cmd+D for duplicate)
- Brief toast for Cmd+Shift+C confirmation ("Copied to clipboard")
- Plain text only on clipboard (no rich text)

## 14. Auto-collapse Refinement

- Fixed timing with tuned defaults (no user-configurable delay)
- Toggle in preferences: "Auto-hide panels while typing" (off by default)
- Warning phase: opacity + subtle Gaussian blur (2-3px)
- Hover cancels collapse entirely (full restore)
- Panels reappear via toolbar buttons / shortcuts only (no auto-reappear)
- Both panels collapse simultaneously ("focused mode" is all or nothing)

## 15. Toolbar Design

- Polish existing layout (consistent icons, spacing, tooltips)
- Tooltips show action + keyboard shortcut
- Dot indicator on save button when isDirty
- Save button shows brief checkmark on successful save
- Filled/outline SF Symbols for panel toggle state

## 16. Error Logging

- Structured logging for drag failures, compilation errors, data load, undo issues
- Performance metrics logging (compilation time, palette render time when exceeding thresholds)
- Export diagnostic logs from Preferences ("Diagnostic Logs" section)

## 17. Onboarding

- Subtle coach marks on first block editor open (2-3 floating tooltips)
- "Show Tips Again" button in ? help overlay
- Same coach marks for all users (no Pro-specific tips)

## 18. Theme/Appearance

- System font (SF Pro) for UI + monospace (SF Mono) for preview
- Subtle background difference between canvas and panels
- Solid backgrounds with rounded corners for block rows (no material vibrancy)
- Refine existing category color palette for WCAG contrast compliance
- 8pt grid spacing system (centralized in AppConstants)
- Standardized corner radii: .small (4pt), .medium (8pt), .large (12pt)

## 19. Shadow Standardization

- 3-level shadow scale: .subtle (rest), .medium (hover/selected), .elevated (overlays)
- Neutral gray shadows (no category color tinting)
- Reduced shadow opacity in dark mode
- Elevated shadow for overlays (palette, help, modifier picker)
- System accent color border for keyboard focus ring (not glow)

## 20. Debug Tab

- Compilation diagnostics (compilation order, placeholder resolution, modifier log, cache status, timing, token breakdown)
- Pro-only feature
- Live updates (same debounce as compilation)

## 21. Edit Tab (Minimal Polish)

- Fix glaring issues only, no new features
- Confirm with preview when switching Edit → Build (ModeSwitchDialogView)
- Clear sync state indicator in tab bar (green/orange dot)

---

## Claude's Discretion (Tune During Implementation)

- Exact auto-collapse timing values
- Specific shadow radius/opacity values for each level
- Compilation diagnostic format in Debug tab
- Coach mark positioning and exact copy
- Performance optimization techniques for 20+ blocks
- Exact skeleton shimmer implementation
- TextToBlocksService parsing improvements
