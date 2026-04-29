---
phase: 15
slug: ux-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-27
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest / XCUITest |
| **Config file** | Pault.xcodeproj (scheme targets) |
| **Quick run command** | `xcodebuild test -project Pault.xcodeproj -scheme PaultTests -destination 'platform=macOS' -only-testing:PaultTests` |
| **Full suite command** | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | UX-01 | Manual (view state) | Build succeeds + manual proxy-unset check | ❌ W0 | ⬜ pending |
| 15-01-02 | 01 | 1 | UX-01 | Manual (view state) | Build succeeds + manual check in SmartCollectionEditor | ❌ W0 | ⬜ pending |
| 15-02-01 | 02 | 1 | UX-02 | Smoke (UITest) | `xcodebuild test ... -only-testing:PaultUITests/ScreenshotTests` | ✅ existing (needs seed update) | ⬜ pending |
| 15-03-01 | 03 | 1 | UX-03 | UITest (screenshot) | `xcodebuild test ... -only-testing:PaultUITests/ScreenshotTests` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] No automated unit test for `noProxyStateView` visibility — manual verification sufficient for this requirement scope
- [ ] `ScreenshotDataSeeder.seed()` does not currently create `.aiCurated` SmartCollection — if UX-02 screenshot verification is needed, seed must include one

*Existing infrastructure covers most phase requirements. UX-01 is primarily a view-layer guard verified by build success and manual check.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `noProxyStateView` appears when proxy URL not configured | UX-01 | View state guard — no automated UI test for empty-state rendering | 1. Remove proxy URL from Preferences. 2. Open AI Assist panel. 3. Verify "Proxy URL not configured" message appears. |
| Refresh button triggers new curation request | UX-02 | Requires AI service call with live proxy | 1. Create an AI-curated collection. 2. Click refresh button in sidebar. 3. Verify spinner appears, then `lastRefreshed` updates. |
| Pro features visible in screenshot mode | UX-03 | Visual verification of screenshot output | 1. Run screenshot tests with `--screenshot-mode`. 2. Verify Pro-gated UI (Smart Collections, AI Assist) is visible in captures. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
