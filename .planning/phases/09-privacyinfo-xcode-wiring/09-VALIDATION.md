---
phase: 9
slug: privacyinfo-xcode-wiring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xcodebuild + shell inspection (no XCTest unit tests — verification-only phase) |
| **Config file** | Pault.xcodeproj |
| **Quick run command** | `plutil -lint Pault/PrivacyInfo.xcprivacy && grep "PBXFileSystemSynchronizedRootGroup" Pault.xcodeproj/project.pbxproj` |
| **Full suite command** | `xcodebuild build -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS' && find ~/Library/Developer/Xcode/DerivedData -name "Pault.app" -path "*/Debug/*" -maxdepth 12 \| head -1 \| xargs -I{} find {} -name "PrivacyInfo.xcprivacy"` |
| **Estimated runtime** | ~60 seconds (full build) |

---

## Sampling Rate

- **After every task commit:** Run `plutil -lint Pault/PrivacyInfo.xcprivacy && grep "PBXFileSystemSynchronizedRootGroup" Pault.xcodeproj/project.pbxproj`
- **After every plan wave:** Run full build + bundle inspection
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | R7.1 | smoke | `grep "membershipExceptions" Pault.xcodeproj/project.pbxproj` | ✅ | ⬜ pending |
| 09-01-02 | 01 | 1 | R7.1 | smoke | `plutil -lint Pault/PrivacyInfo.xcprivacy` | ✅ | ⬜ pending |
| 09-01-03 | 01 | 1 | R7.1 | build | `xcodebuild build ... && find DerivedData -name PrivacyInfo.xcprivacy` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework or stubs needed — verification is shell-based bundle inspection.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App Store Connect accepts the bundle | R7.1 | Requires actual submission to Apple | Upload via Xcode Organizer or `xcrun altool` and check for privacy manifest warnings |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
