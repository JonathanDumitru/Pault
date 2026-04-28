---
phase: 1
slug: compliance-test-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (built-in, Xcode 16+) + XCTest (3 legacy files) |
| **Config file** | Xcode project scheme (no external config file) |
| **Quick run command** | `xcodebuild test -project Pault.xcodeproj -scheme Pault -only-testing PaultTests -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -project Pault.xcodeproj -scheme Pault -only-testing PaultTests -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | R7.1 | manual | Verify PrivacyInfo.xcprivacy exists in bundle after build | N/A (file creation) | ⬜ pending |
| 01-01-02 | 01 | 1 | R7.2 | manual | Build + run, check Console for sandbox violations | N/A (file edit) | ⬜ pending |
| 01-02-01 | 02 | 1 | R1.2-e | unit | `xcodebuild test -only-testing PaultTests` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | R1.2-a | unit | `xcodebuild test -only-testing PaultTests/PromptStudioModelTests` | ✅ needs expansion | ⬜ pending |
| 01-02-03 | 02 | 1 | R1.2-b | unit | `xcodebuild test -only-testing PaultTests/BlockSuggestionEngineTests` | ✅ needs major expansion | ⬜ pending |
| 01-02-04 | 02 | 1 | R1.2-c | unit | `xcodebuild test -only-testing PaultTests/SlashCommandStateTests` | ✅ needs gap filling | ⬜ pending |
| 01-02-05 | 02 | 1 | R1.2-d | integration | `xcodebuild test -only-testing PaultTests/IntegrationTests` | ✅ needs new test | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultTests/TestHelpers.swift` — shared ModelContainer factory (covers all 7 model types)
- [ ] Run full test suite to establish baseline — identify any already-broken tests before making changes

*Existing infrastructure covers framework requirements; Wave 0 focuses on shared factory and baseline.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| PrivacyInfo.xcprivacy exists with correct entries | R7.1 | File creation verified by build output, not unit-testable | Build project, verify PrivacyInfo.xcprivacy in app bundle |
| Apple-events entitlement removed | R7.2 | Entitlement changes verified by codesign, not unit-testable | Build project, run `codesign -d --entitlements - Pault.app`, verify no apple-events exception |
| Sandbox compatibility after changes | R7.2 | Runtime behavior only | Launch app, exercise file open/save, check Console for sandbox violations |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
