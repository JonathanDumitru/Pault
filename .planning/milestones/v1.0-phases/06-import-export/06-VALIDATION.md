---
phase: 6
slug: import-export
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest |
| **Config file** | Xcode scheme — no separate config |
| **Quick run command** | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests -only-testing:PaultTests/MarkdownFrontmatterParserTests -only-testing:PaultTests/ImportOrchestratorTests` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds (quick), ~90 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (phase-specific tests)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | R8.1 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | R8.1 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | R8.1 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/MarkdownFrontmatterParserTests` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | R8.1 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 2 | R8.2 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ W0 | ⬜ pending |
| 06-02-02 | 02 | 2 | R8.2 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ W0 | ⬜ pending |
| 06-02-03 | 02 | 2 | R8.2 | unit | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ❌ W0 | ⬜ pending |
| 06-02-04 | 02 | 2 | R8.2 | manual | VoiceOver pass on ImportPreviewSheet | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultTests/ExportServiceTests.swift` — JSON v2 round-trip, v1 backward compat, Markdown export, filename slugification, Copy as Markdown
- [ ] `PaultTests/MarkdownFrontmatterParserTests.swift` — YAML serialize+parse round-trip, plain Markdown fallback, quoted strings with colons
- [ ] `PaultTests/ImportOrchestratorTests.swift` — conflict resolution (skip/overwrite/keepBoth), auto-snapshot before overwrite, variable auto-detection, partial import

*Existing `PaultTests/TestHelpers.swift` provides in-memory ModelContainer with all 10 @Model types.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Import preview sheet accessibility | R8.2 | VoiceOver navigation requires human verification | Enable VoiceOver, navigate import preview sheet, verify all controls are labeled and reachable |
| Drag-drop visual indicator | R8.1 | Visual feedback requires human observation | Drag .json/.md file over main window, verify drop target highlight appears |
| Share sheet integration | R8.1 | System share sheet requires macOS UI interaction | Click share button, verify system picker appears with compiled text |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
