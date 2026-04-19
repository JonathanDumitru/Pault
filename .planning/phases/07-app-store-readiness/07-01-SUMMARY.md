---
phase: 07-app-store-readiness
plan: 01
subsystem: infra
tags: [xcprivacy, privacy-manifest, legal, app-store, distribution, notarization, bash, plist]

requires:
  - phase: 01-compliance-test-infrastructure
    provides: "Base PrivacyInfo.xcprivacy with OtherDataTypes, CA92.1, C617.1 entries"
provides:
  - "Updated PrivacyInfo.xcprivacy with OtherUserContent for AI proxy prompts"
  - "Privacy policy with AI proxy disclosure and BYOK section"
  - "Terms of Service covering subscriptions, acceptable use, and BYOK liability"
  - "Updated ASC metadata with subtitle 'AI Prompt Studio', optimized keywords, Pro-led description"
  - "build-release.sh with --appstore and --dmg distribution flows"
  - "ExportOptions-AppStore.plist and ExportOptions-DeveloperID.plist"
affects: [07-02-screenshot-automation]

tech-stack:
  added: [xcrun notarytool, xcodebuild archive, xcodebuild -exportArchive, codesign, spctl, xcrun stapler]
  patterns: [test-gate-before-archive, notarize-then-staple-app-then-dmg, destination=export-not-upload]

key-files:
  created:
    - docs/legal/terms-of-service.md
    - scripts/build-release.sh
    - scripts/ExportOptions-AppStore.plist
    - scripts/ExportOptions-DeveloperID.plist
  modified:
    - Pault/PrivacyInfo.xcprivacy
    - docs/legal/privacy-policy.md
    - docs/app-store/app-store-connect.md

key-decisions:
  - "ExportOptions-AppStore.plist uses destination=export (not upload) — user uploads manually via Xcode Organizer"
  - "KEEP_BUILD=1 env var skips build/ cleanup in build-release.sh for debugging"
  - "build-release.sh runs test suite as safety gate before archive step in both --appstore and --dmg paths"
  - "DMG path: notarize app bundle, staple app, package DMG via create_dmg.sh, then staple DMG"

patterns-established:
  - "ExportOptions plists live in scripts/ alongside build-release.sh for colocation"
  - "Legal documents are Markdown source-of-truth in docs/legal/ published separately to pault.app"

requirements-completed: [R7.1, R7.2, R7.4]

duration: 15min
completed: 2026-04-19
---

# Phase 7 Plan 01: App Store Compliance and Distribution Artifacts Summary

**Privacy manifest updated with OtherUserContent for AI proxy, legal docs created (privacy policy AI proxy + BYOK disclosure, full Terms of Service), ASC metadata rewritten with "AI Prompt Studio" subtitle and Pro-led copy, and build-release.sh created for App Store archive export and notarized DMG distribution.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-19T03:47:52Z
- **Completed:** 2026-04-19T03:55:00Z
- **Tasks:** 2 of 3 (Task 3 is a human-verify checkpoint — awaiting user review)
- **Files modified:** 7

## Accomplishments

- Updated PrivacyInfo.xcprivacy to add NSPrivacyCollectedDataTypeOtherUserContent alongside all preserved existing entries (OtherDataTypes, CA92.1 UserDefaults, C617.1 FileTimestamp)
- Updated privacy policy with AI Proxy Service section, BYOK subsection, and App Store Privacy Labels table; added all three contact emails
- Created Terms of Service covering subscription auto-renewal, 7-day trial, acceptable use, BYOK API key liability, intellectual property, disclaimers, and governing law
- Rewrote app-store-connect.md with subtitle "AI Prompt Studio", 93-char optimized keywords, Pro-led description with bullet sections, 7-day trial promo text, What's New v1.0, questionnaire answers, and nutrition label table
- Created ExportOptions-AppStore.plist (method: app-store-connect, destination: export) and ExportOptions-DeveloperID.plist (method: developer-id), both passing plutil lint
- Created build-release.sh (162 lines, executable) with --appstore and --dmg flags; test suite runs as safety gate before archive in both paths; DMG path covers notarize, staple app, create_dmg.sh, staple DMG

## Task Commits

Each task was committed atomically:

1. **Task 1: Privacy manifest, legal documents, and metadata updates** - `72948d7` (feat)
2. **Task 2: Build release script and ExportOptions plists** - `e75a76e` (feat)

## Files Created/Modified

- `Pault/PrivacyInfo.xcprivacy` - Added NSPrivacyCollectedDataTypeOtherUserContent entry, preserved all existing entries
- `docs/legal/privacy-policy.md` - Added AI Proxy Service section, BYOK subsection, App Store Privacy Labels table, updated contact section
- `docs/legal/terms-of-service.md` - New file: subscription terms, acceptable use, BYOK liability, IP, disclaimers, governing law
- `docs/app-store/app-store-connect.md` - Rewrote with new subtitle, keywords, Pro-led description, promo, What's New, questionnaire answers, nutrition labels, updated screenshot lineup
- `scripts/build-release.sh` - New file: distribution build script with --appstore and --dmg flags
- `scripts/ExportOptions-AppStore.plist` - New file: App Store export options (method: app-store-connect, destination: export)
- `scripts/ExportOptions-DeveloperID.plist` - New file: Developer ID export options for notarized DMG

## Decisions Made

- ExportOptions-AppStore.plist uses `destination=export` (not `upload`) per locked decision — user uploads via Xcode Organizer manually
- `KEEP_BUILD=1` environment variable added to skip `build/` cleanup in build-release.sh for debugging convenience
- Test suite safety gate runs before archive in both `--appstore` and `--dmg` paths to prevent archiving broken code
- DMG notarization sequence: zip app → notarytool submit --wait → staple app → create_dmg.sh → staple DMG

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

One-time notarytool credential setup required before running `--dmg` on a new machine:

```bash
xcrun notarytool store-credentials "pault-notarytool" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id 93QQU293YD
```

This is documented in the header comment of `scripts/build-release.sh`.

## Self-Check: PASSED

All 7 files created/modified verified present on disk. Both task commits (72948d7, e75a76e) confirmed in git log.

## Next Phase Readiness

- All compliance and distribution artifacts are ready for Task 3 human review
- After review approval, Phase 7 Plan 02 (screenshot automation) can begin
- In-app links (AboutView.swift pault.app/privacy, PaywallView.swift pault.app/terms) are verified to match documented URLs

---
*Phase: 07-app-store-readiness*
*Completed: 2026-04-19*
