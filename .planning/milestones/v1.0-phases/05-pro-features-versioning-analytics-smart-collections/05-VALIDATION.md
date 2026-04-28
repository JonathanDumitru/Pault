---
phase: 5
slug: pro-features-versioning-analytics-smart-collections
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) — already in use throughout PaultTests |
| **Config file** | None (Xcode scheme handles test target) |
| **Quick run command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/AnalyticsServiceTests -only-testing:PaultTests/SmartCollectionTests` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/AnalyticsServiceTests -only-testing:PaultTests/SmartCollectionTests`
- **After every plan wave:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 45 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | R3.1 | unit | `xcodebuild test ... -only-testing:PaultTests/PromptVersionHistoryTests` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | R3.1 | unit | `xcodebuild test ... -only-testing:PaultTests/PromptVersionTests` | ✅ extend | ⬜ pending |
| 05-01-03 | 01 | 1 | R3.2 | unit | `xcodebuild test ... -only-testing:PaultTests/PromptVersionHistoryTests` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 1 | R3.3 | unit | `xcodebuild test ... -only-testing:PaultTests/DiffEngineTests` | ✅ extend | ⬜ pending |
| 05-02-01 | 02 | 1 | R4.1 | unit | `xcodebuild test ... -only-testing:PaultTests/AnalyticsServiceTests` | ✅ extend | ⬜ pending |
| 05-02-02 | 02 | 1 | R4.1 | unit | `xcodebuild test ... -only-testing:PaultTests/AnalyticsServiceTests` | ✅ extend | ⬜ pending |
| 05-02-03 | 02 | 1 | R4.2 | unit | `xcodebuild test ... -only-testing:PaultTests/Models/CopyEventTests` | ✅ extend | ⬜ pending |
| 05-02-04 | 02 | 1 | R4.2 | unit | `xcodebuild test ... -only-testing:PaultTests/Models/CopyEventTests` | ✅ extend | ⬜ pending |
| 05-03-01 | 03 | 2 | R4.3 | unit | `xcodebuild test ... -only-testing:PaultTests/SmartCollectionTests` | ✅ extend | ⬜ pending |
| 05-03-02 | 03 | 2 | R4.3 | unit | `xcodebuild test ... -only-testing:PaultTests/SmartCollectionTests` | ✅ extend | ⬜ pending |
| 05-03-03 | 03 | 2 | R4.3 | unit | `xcodebuild test ... -only-testing:PaultTests/SmartCollectionTests` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultTests/PromptVersionHistoryTests.swift` — stubs for R3.1 (date grouping logic), R3.2 (V2V restore flow)
- [ ] No additional test infrastructure needed — `TestHelpers.makeTestModelContext()` covers all model types already

*Existing infrastructure covers most phase requirements; only one new test file needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Synchronized scrolling in V2V diff | R3.3 | Visual scroll behavior not testable in unit tests | Open V2V diff, scroll one pane, verify other follows |
| Swift Charts line chart renders correctly | R4.1 | Visual rendering not testable in unit tests | Open Analytics, verify line chart shows daily usage over 7/30/90 days |
| Smart collection count badges update in real-time | R4.3 | Sidebar visual behavior | Add/remove prompts matching filter, verify badge count changes |
| Preset collection emoji icons display correctly | R4.3 | Visual rendering | Unlock Pro, verify 3 preset collections with correct emoji |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 45s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
