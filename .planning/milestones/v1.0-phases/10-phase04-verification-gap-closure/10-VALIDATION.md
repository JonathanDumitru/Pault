---
phase: 10
slug: phase04-verification-gap-closure
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (AIServiceTests, AIAssistPanelTests) + Swift Testing (PromptRunTests, RunTabViewTests) |
| **Config file** | Xcode scheme — no separate config file |
| **Quick run command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | tail -40`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | R2.1-R2.5, R5.1-R5.3 | inspection | `grep -n` + file reads | ✅ | ⬜ pending |
| 10-01-02 | 01 | 1 | R5.3 | unit | `xcodebuild test ... -only-testing PaultTests/AIServiceTests` | ✅ | ⬜ pending |
| 10-01-03 | 01 | 1 | R2.5 | unit | `xcodebuild test ... -only-testing PaultTests/AIServiceTests` | ✅ | ⬜ pending |
| 10-01-04 | 01 | 1 | R2.1-R2.5, R5.1-R5.3 | doc | VERIFICATION.md written | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. All test files already exist from Phase 04 Plan 00.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AI streaming UI renders in panel | R2.1 | UI rendering requires Xcode Preview or simulator | Open AIAssistPanel, trigger Improve, observe streaming text |
| Proxy Worker deployment | R2.5 | External Cloudflare deployment | Deploy pault-proxy, paste URL in Preferences, verify AI call routes through Worker |
| Run tab execution with real API key | R5.1 | Requires live API key | Enter API key in Preferences, create prompt, execute via Run tab |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
