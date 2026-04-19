---
phase: 8
slug: final-quality-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (unit) + Swift Testing + XCUITest (UI) |
| **Config file** | Xcode scheme; no separate test config file |
| **Quick run command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests 2>&1 \| xcpretty` |
| **Full suite command** | `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 \| xcpretty` |
| **Estimated runtime** | ~45 seconds (unit), ~120 seconds (full with UI) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
- **Before `/gsd:verify-work`:** Full suite must be green + Instruments Leaks session clean + manual VoiceOver pass
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | R8.1 | unit | Full suite command | ✅ ~40 test files | ⬜ pending |
| 08-02-01 | 02 | 2 | R8.3 | unit | `xcodebuild test -only-testing PaultTests/PerformanceBenchmarkTests` | ✅ | ⬜ pending |
| 08-02-02 | 02 | 2 | R8.3 | UI | `xcodebuild test -only-testing PaultUITests/PaultUITests/testLaunchPerformance` | ✅ | ⬜ pending |
| 08-02-03 | 02 | 2 | R8.3 | manual | Instruments → Leaks template | manual-only | ⬜ pending |
| 08-03-01 | 03 | 3 | R8.2 | UI (XCUITest) | `xcodebuild test -only-testing PaultUITests/AccessibilityAuditUITests` | ❌ W0 | ⬜ pending |
| 08-03-02 | 03 | 3 | R1.3 | unit | `xcodebuild test -only-testing PaultTests/AccessibilityTests` | ✅ | ⬜ pending |
| 08-04-01 | 04 | 4 | R8.4 | UI (XCUITest) | `xcodebuild test -only-testing PaultUITests/ReduceMotionUITests` | ❌ W0 | ⬜ pending |
| 08-04-02 | 04 | 4 | R8.4 | unit | Visual inspection + screenshot tests | ✅ ScreenshotTests | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultUITests/AccessibilityAuditUITests.swift` — stubs for R8.2 (automated accessibility audit across 3 surfaces)
- [ ] `PaultUITests/ReduceMotionUITests.swift` — stubs for R8.4 (verifies animations disabled when reduceMotion=true)
- [ ] Framework install: none needed — XCUITest already in project

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| VoiceOver full walkthrough | R8.2 | Cannot automate VoiceOver content clarity or navigation flow quality | Enable VoiceOver (Cmd+F5), navigate all 3 surfaces: main window, block editor, menu bar. Verify all elements announced, logical tab order, no unlabelled buttons |
| Instruments Leaks session | R8.3 | Cannot automate Instruments GUI profiling | Product → Profile → Leaks. 5-min editing session: add 20+ blocks, switch views, trigger AI assist. Zero leaks in final pass |
| Instruments App Launch | R8.3 | Cannot automate Instruments GUI profiling | Product → Profile → App Launch template. Verify pre-main + main() < 1s in Release config |
| Instruments SwiftUI template | R8.3 | Cannot automate Instruments GUI profiling | Instruments 26 SwiftUI template. No view body > 50ms |
| Liquid Glass visual check | R8.4 | Visual judgment on macOS 26 | Run on macOS 26 device/simulator. Verify materials/vibrancy consistent with system |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
