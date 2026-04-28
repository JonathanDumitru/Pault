---
phase: 07
slug: app-store-readiness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | Pault.xcodeproj (targets: PaultTests, PaultUITests) |
| **Quick run command** | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS' -only-testing:PaultUITests/ScreenshotTests` |
| **Full suite command** | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` |
| **Estimated runtime** | ~45 seconds |

---

## Sampling Rate

- **After every task commit:** Run `grep` / `plutil` / `bash -n` quick checks per task
- **After every plan wave:** Run `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | R7.1 | grep | `grep -c OtherUserContent Pault/PrivacyInfo.xcprivacy` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | R7.4 | plutil | `plutil -lint scripts/ExportOptions-AppStore.plist && plutil -lint scripts/ExportOptions-DeveloperID.plist` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | R7.4 | bash -n | `bash -n scripts/build-release.sh` | ❌ W0 | ⬜ pending |
| 07-01-04 | 01 | 1 | R7.1 | manual | Human review of docs/legal/privacy-policy.md | ✅ | ⬜ pending |
| 07-01-05 | 01 | 1 | R7.1 | manual | Human review of docs/legal/terms-of-service.md | ❌ W0 | ⬜ pending |
| 07-01-06 | 01 | 1 | R7.2, R7.4 | manual | `codesign --verify --deep --strict` + `codesign --display --entitlements :-` | N/A | ⬜ pending |
| 07-02-01 | 02 | 1 | R7.3 | build | `xcodebuild build -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 07-02-02 | 02 | 1 | R7.3 | build | compile check (same as above) | ✅ | ⬜ pending |
| 07-02-03 | 02 | 1 | R7.3 | xctest | `xcodebuild test -only-testing:PaultUITests/ScreenshotTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 07-02-04 | 02 | 1 | R7.3 | manual | Human review of metadata copy quality | ✅ | ⬜ pending |
| 07-02-05 | 02 | 1 | R7.3 | manual | Verify docs consistent with ScreenshotTests | ✅ | ⬜ pending |
| 07-02-06 | 02 | 1 | R7.3 | manual | Visual QA on screenshots + in-app link check | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `PaultUITests/ScreenshotTests.swift` — 6-shot automated capture suite (R7.3)
- [ ] `Pault/ScreenshotDataSeeder.swift` — seed data factory for screenshot mode (R7.3)
- [ ] `scripts/build-release.sh` — archive, export, notarize workflow (R7.4)
- [ ] `scripts/ExportOptions-AppStore.plist` — required by build-release.sh (R7.4)
- [ ] `scripts/ExportOptions-DeveloperID.plist` — required by build-release.sh (R7.4)
- [ ] `docs/legal/terms-of-service.md` — subscription terms, BYOK liability (R7.1)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Archive validates in Xcode Organizer | R7.4 | Requires Apple Distribution cert + interactive validation | Build archive, open in Organizer, click Validate App |
| DMG passes Gatekeeper | R7.4 | Requires notarization with Apple credentials | Run `spctl -a -v dist/Pault-1.0.dmg` after notarizing |
| Screenshots look visually correct | R7.3 | Aesthetic judgment | Open each PNG, verify UI shows correct view with seed data |
| Legal docs are legally accurate | R7.1 | Legal review | Human reads privacy policy AI proxy section and ToS |
| In-app links match deployed URLs | R7.3 | Requires live site | Click links in AboutView/PaywallView, verify they resolve |
| ASC questionnaire answers are correct | R7.3 | Web-only interface | Enter answers in App Store Connect, verify no warnings |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
