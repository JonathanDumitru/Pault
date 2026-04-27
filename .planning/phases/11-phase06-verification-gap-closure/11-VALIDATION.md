---
phase: 11
slug: phase06-verification-gap-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest |
| **Config file** | Xcode scheme (no separate config file) |
| **Quick run command** | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests -only-testing:PaultTests/MarkdownFrontmatterParserTests -only-testing:PaultTests/ImportOrchestratorTests` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~45 seconds (quick), ~120 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (phase-specific tests)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | R9.1 | doc-edit | N/A (frontmatter fix) | N/A | ⬜ pending |
| 11-01-02 | 01 | 1 | R9.2, R9.3 | doc-edit | N/A (frontmatter fix) | N/A | ⬜ pending |
| 11-01-03 | 01 | 1 | R9.1 | code-verify | `xcodebuild test -scheme Pault -only-testing:PaultTests/ExportServiceTests` | ✅ | ⬜ pending |
| 11-01-04 | 01 | 1 | R9.2 | code-verify | `xcodebuild test -scheme Pault -only-testing:PaultTests/ImportOrchestratorTests` | ✅ | ⬜ pending |
| 11-01-05 | 01 | 1 | R9.3 | code-verify + manual | N/A (ShareLink needs live app) | N/A | ⬜ pending |
| 11-01-06 | 01 | 1 | R9.1, R9.2, R9.3 | doc-create | N/A (VERIFICATION.md authoring) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. 25 tests exist (16 Export + 9 Import). No new test stubs needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Share sheet presents system picker | R9.3 | ShareLink requires running macOS app + UI interaction | Open prompt detail → click share button → verify NSSharingServicePicker appears |
| Drag-drop import trigger | R9.2 | onDrop handler requires live window + file drag | Drag a .json file onto the main window → verify import preview sheet appears |
| Copy as Markdown to clipboard | R9.3 | NSPasteboard write needs running app context | Open prompt → click Copy as Markdown → paste in text editor → verify YAML frontmatter + body |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
