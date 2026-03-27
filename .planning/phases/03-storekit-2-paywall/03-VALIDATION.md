---
phase: 3
slug: storekit-2-paywall
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing throughout project) |
| **Config file** | PaultTests/ — standard Xcode test target |
| **Quick run command** | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests -destination 'platform=macOS' -quiet` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' -quiet` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests -destination 'platform=macOS' -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' -quiet`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | R6.4 | infrastructure | N/A — .storekit config + scheme setup | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | R6.4 | infrastructure | N/A — SKTestSession import + test stubs | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | R6.1 | unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_unverifiedTransaction_deniesAccess` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 1 | R6.1 | unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_purchase_grantsProAccess` | ❌ W0 | ⬜ pending |
| 03-01-05 | 01 | 1 | R6.1 | unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_restore_grantsProAccess` | ❌ W0 | ⬜ pending |
| 03-01-06 | 01 | 1 | R6.1 | unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_expiredSubscription_revokesProAccess` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | R6.3 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProFeatureTests` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | R6.3 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProFeatureTests/test_blockLimit_softGateAt6` | ❌ W0 | ⬜ pending |
| 03-02-03 | 02 | 2 | R6.2 | manual | See Manual-Only Verifications | N/A | ⬜ pending |
| 03-03-01 | 03 | 0 | R6.4 | unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_proProductID_isAnnualOnly` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Pault/Pault.storekit` — StoreKit configuration file with `com.pault.pro.annual`, 7-day trial, $59.99 price
- [ ] Xcode scheme configured to use `Pault.storekit` in Run options
- [ ] `PaultTests/ProStatusManagerTests.swift` — expanded with `SKTestSession`-based lifecycle tests (replace current 2 stubs)
- [ ] `PaultTests/ProFeatureTests.swift` — new file covering `ProFeature` enum correctness and `isUnlocked` logic
- [ ] `import StoreKitTest` in test target — verify framework is linked

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Paywall displays dynamic intro offer text | R6.2 | UI rendering + async eligibility check requires visual inspection | 1. Launch in sandbox with trial-eligible account 2. Open paywall → verify "7-day free trial" CTA 3. Complete trial → reopen paywall → verify price-only CTA |
| Paywall shows subscription terms, Privacy Policy and ToS links | R6.2 | Legal compliance text requires visual + tap verification | 1. Open paywall 2. Verify auto-renewal terms visible 3. Tap Privacy Policy link → verify navigation 4. Tap ToS link → verify navigation |
| Pro features unlock immediately after purchase | R6.1 | End-to-end purchase flow requires sandbox testing | 1. Purchase in sandbox 2. Verify block limit removed instantly 3. Verify Pro badge appears |
| Upgrade prompts appear for free users discovering Pro features | R6.3 | UX flow requires visual verification | 1. As free user, try to add 7th block 2. Verify graceful upgrade prompt appears 3. Verify prompt navigates to paywall |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
