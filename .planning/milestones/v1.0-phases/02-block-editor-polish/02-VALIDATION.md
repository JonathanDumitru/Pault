---
phase: 2
slug: block-editor-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-25
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, ~30 test files) + Swift Testing @Test macro |
| **Config file** | None — Xcode scheme based |
| **Quick run command** | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Pault -only-testing PaultTests/{RelevantTestFile}`
- **After every plan wave:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | R1.1 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | R1.1 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | R1.1 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/UndoRedoTests` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | R1.1 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/DragDropTests` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | R1.1 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/KeyboardNavigationTests` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | R1.3 | unit (a11y) | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 1 | R1.3 | unit (a11y) | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 1 | R1.3 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/AccessibilityTests` | ❌ W0 | ⬜ pending |
| 02-02-04 | 02 | 2 | R1.4 | performance | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ❌ W0 | ⬜ pending |
| 02-02-05 | 02 | 2 | R1.4 | performance | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ❌ W0 | ⬜ pending |
| 02-02-06 | 02 | 2 | R1.4 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/PerformanceBenchmarkTests` | ❌ W0 | ⬜ pending |
| 02-snapshot | 02 | 2 | R1.1 | snapshot | Snapshot optional / local only | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultTests/UndoRedoTests.swift` — stubs for R1.1 undo/redo structural operations
- [ ] `PaultTests/DragDropTests.swift` — stubs for R1.1 drag-drop model operations
- [ ] `PaultTests/KeyboardNavigationTests.swift` — stubs for R1.1 keyboard navigation
- [ ] `PaultTests/AccessibilityTests.swift` — stubs for R1.3 a11y labels, actions, reduceMotion
- [ ] `PaultTests/PerformanceBenchmarkTests.swift` — stubs for R1.4 compilation + palette benchmarks
- [ ] `PaultTests/CanvasSnapshotTests.swift` — snapshot stubs (optional CI)
- [ ] SPM dependency: `swift-snapshot-testing` 1.17.x — add to Xcode project

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| VoiceOver full canvas navigation | R1.3 | Requires real VoiceOver runtime | Enable VoiceOver, navigate Library → Canvas → Preview using Tab/Arrow keys. Verify announcements include category, title, position |
| Drag-drop visual feedback (lift effect, line indicator) | R1.1 | Visual rendering requires manual inspection | Drag a block, verify scale+shadow lift effect. Drop between blocks, verify line indicator appears |
| Auto-scroll during drag near edges | R1.1 | Requires real scroll container | Add 10+ blocks, drag block near top/bottom edge, verify canvas auto-scrolls |
| Slash command palette <100ms open time | R1.4 | Requires real rendering pipeline | Press Cmd+/ repeatedly, verify palette appears instantly with no perceptible delay |
| Dark mode across all views | R1.1 | Visual appearance | Toggle system dark mode, verify all block editor views render correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
