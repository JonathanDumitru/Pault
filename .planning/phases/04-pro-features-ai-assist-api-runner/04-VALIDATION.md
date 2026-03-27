---
phase: 4
slug: pro-features-ai-assist-api-runner
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (AIServiceTests) + Swift Testing (PromptRunTests, ProFeatureTests) |
| **Config file** | Xcode scheme — no separate config file |
| **Quick run command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~45 seconds (quick) / ~120 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | tail -40`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | R2.5 | unit (mock) | `xcodebuild test ... -only-testing PaultTests/AIServiceTests` | ✅ (expand) | ⬜ pending |
| 04-01-02 | 01 | 1 | R2.5 | unit | `AIServiceTests/test_proxyUnreachable_showsInlineError` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | R2.5 | unit | `AIServiceTests/test_rateLimitResponse_parsesRetryAfter` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | R2.1 | unit (mock) | `AIServiceTests/test_streamImprove` | ✅ (expand) | ⬜ pending |
| 04-02-02 | 02 | 2 | R2.1 | unit | `AIAssistPanelTests/test_acceptCallsSaveSnapshot` | ❌ W0 | ⬜ pending |
| 04-02-03 | 02 | 2 | R2.2 | unit (mock) | `AIServiceTests/test_suggestVariablesRoutesProxy` | ✅ (expand) | ⬜ pending |
| 04-02-04 | 02 | 2 | R2.3 | unit | `AIServiceTests/test_autoTagRoutesProxy` | ✅ (expand) | ⬜ pending |
| 04-02-05 | 02 | 2 | R2.4 | unit | `AIServiceTests/test_qualityScoreReturnsTips` | ✅ (expand) | ⬜ pending |
| 04-03-01 | 03 | 2 | R5.1 | unit (mock) | `AIServiceTests/test_streamRunRoutesProxy` | ✅ (expand) | ⬜ pending |
| 04-03-02 | 03 | 2 | R5.2 | unit | `PromptRunTests/test_promptRunPersistsWithTokenMetadata` | ❌ W0 | ⬜ pending |
| 04-03-03 | 03 | 2 | R5.3 | unit | `RunTabViewTests/test_refinementAcceptCallsSaveSnapshot` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultTests/AIAssistPanelTests.swift` — stubs for snapshot-before-accept (R2.1), streaming state management
- [ ] `PaultTests/AIServiceTests.swift` (expand) — proxy routing tests, 429 handling, Ollama bypass verification (R2.5, R5.1)
- [ ] `PaultTests/PromptRunTests.swift` (expand) — token metadata persistence (R5.2)
- [ ] `PaultTests/RunTabViewTests.swift` — variable form pre-fill, Run Again behavior (R5.1, R5.3)

*Note: Proxy Worker tests are TypeScript unit tests in the proxy repo (outside Xcode). Recommend `vitest` for Worker logic tests (subscription verify, rate limit mock, routing). This is a Wave 0 gap in the proxy repo.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Streaming token-by-token display scrolls smoothly | R2.1, R5.1 | Visual smoothness not unit-testable | Run AI improve/execute, verify tokens appear incrementally with auto-scroll |
| AI panel shows "AI unavailable" when proxy unreachable | R2.5 | Requires network disconnection | Disconnect Wi-Fi, trigger AI action, verify inline error message |
| Cmd+Shift+I opens AI Improve tab | R2.1 | Keyboard shortcut requires UI test | Press Cmd+Shift+I with prompt open, verify AI panel focuses Improve tab |
| Star rating tappable in expanded RunHistoryRowView | R5.2 | UI interaction test | Expand a run history row, tap 1-5 stars, verify rating persists on reload |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
