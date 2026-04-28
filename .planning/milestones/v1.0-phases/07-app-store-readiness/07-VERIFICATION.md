---
phase: 07-app-store-readiness
verified: 2026-04-19T04:30:00Z
status: passed
score: 12/12 must-haves verified
re_verification: false
---

# Phase 7: App Store Readiness Verification Report

**Phase Goal:** Pault is fully prepared for submission with all required metadata, assets, and legal compliance
**Verified:** 2026-04-19T04:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PrivacyInfo.xcprivacy declares OtherUserContent alongside existing OtherDataTypes, UserDefaults CA92.1, and FileTimestamp C617.1 | VERIFIED | All four entries confirmed in `Pault/PrivacyInfo.xcprivacy` lines 12–54 |
| 2 | Privacy policy explicitly discloses AI proxy data handling including BYOK model | VERIFIED | `docs/legal/privacy-policy.md` line 35: "AI Proxy Service" section; line 41: "Bring Your Own Key (BYOK)" subsection |
| 3 | Terms of Service covers subscription terms, AI acceptable use, and BYOK API key liability | VERIFIED | `docs/legal/terms-of-service.md` 93 lines; subscription §3, acceptable use §4, BYOK §5 confirmed |
| 4 | build-release.sh passes syntax check, is executable, and supports --appstore and --dmg flags | VERIFIED | `bash -n` passes, `-rwxr-xr-x`, 162 lines; case statement at line 152 dispatches both flags |
| 5 | build-release.sh --appstore reads ExportOptions-AppStore.plist via xcodebuild -exportArchive | VERIFIED | Line 86: `-exportOptionsPlist "${SCRIPT_DIR}/ExportOptions-AppStore.plist"` |
| 6 | build-release.sh --dmg calls create_dmg.sh after notarization and stapling | VERIFIED | Line 131: `"${SCRIPT_DIR}/create_dmg.sh" "${app_path}" "${dmg_path}" "Pault"` |
| 7 | ExportOptions plists use correct method values and team ID 93QQU293YD | VERIFIED | AppStore plist: `app-store-connect` + `93QQU293YD`; DeveloperID plist: `developer-id` + `93QQU293YD`; both pass `plutil -lint` |
| 8 | App Store Connect metadata has subtitle "AI Prompt Studio", optimized keywords, Pro-led description, and promo text | VERIFIED | `docs/app-store/app-store-connect.md` line 8: subtitle confirmed; line 16: keywords (93 chars); lines 30–50: Pro-led description |
| 9 | ScreenshotDataSeeder creates 8-10 realistic prompts with tags, versions, analytics events, and AI assist state | VERIFIED | `Pault/ScreenshotDataSeeder.swift` 554 lines; 10 prompts, 8 tags, PromptVersion, CopyEvent, PromptRun entries confirmed |
| 10 | App launches in screenshot mode when --screenshot-mode launch argument is present | VERIFIED | `Pault/PaultApp.swift` lines 164–165: `ProcessInfo.processInfo.arguments.contains("--screenshot-mode")` calls `ScreenshotDataSeeder.seed(context:)` |
| 11 | 6 XCUITest screenshot tests capture PNG attachments covering the locked 6-shot lineup | VERIFIED | `PaultUITests/ScreenshotTests.swift` 321 lines; testShot01_AIAssist through testShot06_AnalyticsDashboard; all use `XCTAttachment` with `.keepAlways` lifetime |
| 12 | Screenshot capture documentation updated with XCUITest-based workflow | VERIFIED | `docs/app-store/screenshot-capture.md` line 1: "XCUITest Workflow"; run command at line 53 confirmed |

**Score:** 12/12 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Pault/PrivacyInfo.xcprivacy` | Privacy manifest with OtherUserContent + OtherDataTypes + CA92.1 + C617.1 | VERIFIED | All four entries present; 56 lines |
| `scripts/build-release.sh` | Distribution script with --appstore and --dmg; min 60 lines | VERIFIED | 162 lines, executable (-rwxr-xr-x), bash syntax valid |
| `scripts/ExportOptions-AppStore.plist` | method=app-store-connect, destination=export | VERIFIED | Contains `app-store-connect`; plutil lint passes |
| `scripts/ExportOptions-DeveloperID.plist` | method=developer-id | VERIFIED | Contains `developer-id`; plutil lint passes |
| `docs/legal/privacy-policy.md` | Updated with AI proxy disclosure section | VERIFIED | "AI proxy" appears at line 35, 37, 43, 51 |
| `docs/legal/terms-of-service.md` | Subscription, acceptable use, BYOK liability; min 60 lines | VERIFIED | 93 lines; all three sections present |
| `docs/app-store/app-store-connect.md` | Contains "AI Prompt Studio" subtitle | VERIFIED | Subtitle confirmed at line 8 |
| `Pault/ScreenshotDataSeeder.swift` | Seed factory with 8-10 prompts; min 80 lines | VERIFIED | 554 lines |
| `PaultUITests/ScreenshotTests.swift` | 6 XCUITest screenshot tests; min 100 lines | VERIFIED | 321 lines; 6 test methods confirmed |
| `docs/app-store/screenshot-capture.md` | XCUITest workflow documentation | VERIFIED | Contains "XCUITest" at line 1 and line 5 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/build-release.sh` | `scripts/ExportOptions-AppStore.plist` | `--appstore` flag reads plist for xcodebuild -exportArchive | WIRED | Line 86: `-exportOptionsPlist "${SCRIPT_DIR}/ExportOptions-AppStore.plist"` |
| `scripts/build-release.sh` | `scripts/create_dmg.sh` | `--dmg` flag calls create_dmg.sh after notarization | WIRED | Line 131: `"${SCRIPT_DIR}/create_dmg.sh"` called inside `build_dmg()` |
| `Pault/PaultApp.swift` | `Pault/ScreenshotDataSeeder.swift` | `--screenshot-mode` launch argument triggers `ScreenshotDataSeeder.seed(context:)` | WIRED | PaultApp.swift lines 164–165 confirmed |
| `PaultUITests/ScreenshotTests.swift` | `Pault/PaultApp.swift` | `app.launchArguments = ["--screenshot-mode"]` triggers seed data path | WIRED | ScreenshotTests.swift line 45 confirmed |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| R7.1: Privacy & Compliance | Plan 01 | PrivacyInfo.xcprivacy manifest with all required API declarations; privacy labels accurate | SATISFIED | PrivacyInfo.xcprivacy has OtherUserContent + OtherDataTypes + CA92.1 + C617.1; privacy policy and ASC nutrition labels updated |
| R7.2: Sandboxing & Entitlements | Plan 01 | App-sandbox enabled; hardened runtime enabled; clipboard access entitled; Carbon hotkey sandbox-compatible | SATISFIED | `Pault.entitlements`: `com.apple.security.app-sandbox=true`, `network.client=true`, `files.user-selected.read-write=true`; `ENABLE_HARDENED_RUNTIME=YES` in both Release and Debug build settings; AppDelegate.swift uses Carbon for global hotkey with fallback UX on failure |
| R7.3: App Store Metadata | Plan 02 | App name/subtitle/description/keywords; 6+ screenshots; icon; category; age rating | SATISFIED | ASC metadata finalized with subtitle, keywords (93 chars), Pro-led description; 6 XCUITest screenshot tests targeting locked lineup; category Productivity/Developer Tools; age rating 4+ |
| R7.4: Signing & Distribution | Plan 01 | Distribution certificate/provisioning; hardened runtime; notarization; DMG installer | SATISFIED | `ENABLE_HARDENED_RUNTIME=YES` confirmed; build-release.sh implements full notarize-staple-DMG pipeline via `xcrun notarytool`; ExportOptions plists cover both App Store and Developer ID paths |

**Note on R7.3 and R7.4:** The ROADMAP Phase 7 requirements field lists only `R7.1, R7.2`, but both the REQUIREMENTS.md tracking table and plan frontmatter assign R7.3 and R7.4 to Phase 7. Both requirements are fully satisfied by the delivered artifacts. The ROADMAP requirements field appears to be a documentation artifact from an earlier planning pass before the phase scope was finalized.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `docs/legal/privacy-policy.md` | 3 | `[Launch Date]` placeholder | Info | Expected — user fills actual date before app launch; not a code defect |
| `docs/legal/terms-of-service.md` | 3 | `[Launch Date]` placeholder | Info | Expected — user fills actual date before app launch; not a code defect |
| `PaultUITests/ScreenshotTests.swift` | multiple | Best-guess accessibility identifiers with fallback branches | Warning | Navigation queries (e.g., button/outline queries) may need adjustment based on live accessibility tree; SUMMARY documents this explicitly and instructs use of `po app.debugDescription` |

No blockers found. The `[Launch Date]` placeholders are intentional per plan design. The accessibility identifier warning is pre-documented and expected.

---

### Human Verification Required

The following items require a human developer to confirm before App Store submission. They cannot be verified programmatically.

#### 1. Screenshot Test Navigation Accuracy

**Test:** Run `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS' -only-testing:PaultUITests/ScreenshotTests` on a 2x Retina display
**Expected:** 6 PNG attachments in test results; each attachment shows the correct target screen (AI Assist streaming state, block editor canvas, API Runner results, library split view, menu bar popover, analytics dashboard)
**Why human:** XCUITest navigation queries use best-guess accessibility identifiers that may not match the live accessibility tree. The seeded AI streaming state (Shot 01) depends on `AIAssistViewModel` reading `UserDefaults["screenshot_ai_streaming_active"]`, which cannot be verified without running the app.

#### 2. In-App URL Match

**Test:** Launch the app and open About (AboutView) and Paywall (PaywallView). Click "Privacy Policy" and "Terms of Service" links.
**Expected:** Privacy Policy opens `https://pault.app/privacy`; Terms of Service opens `https://pault.app/terms`. Both URLs must be live and serve the correct document before submission.
**Why human:** URL liveness and correct deployment of legal docs to pault.app cannot be verified from the codebase alone.

#### 3. Build-Release.sh End-to-End Signing

**Test:** Run `scripts/build-release.sh --appstore` on the developer machine with valid Apple Distribution certificate
**Expected:** Archive created at `build/Pault.xcarchive`; export passes `codesign --verify --deep --strict`; Xcode Organizer can open the archive and validate it
**Why human:** Requires valid signing identity, provisioning profile, and Apple Developer account. Cannot be verified without the actual certificate and connected developer account.

#### 4. Legal Document Accuracy

**Test:** Read `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md` with legal review
**Expected:** Documents accurately describe the actual data handling architecture; BYOK liability clause is legally appropriate; governing law clause is acceptable to developer
**Why human:** Legal document accuracy requires human judgment; automated checks only confirm presence of required sections, not their legal sufficiency.

---

### Gaps Summary

No gaps. All 12 truths are verified. All 10 artifacts exist, are substantive, and are wired. All 4 key links are confirmed in the codebase. All 4 requirements (R7.1, R7.2, R7.3, R7.4) are satisfied by delivered artifacts.

Four items are flagged for human verification before actual App Store submission — these are operational/runtime items that cannot be confirmed from static analysis: screenshot test accuracy against the live accessibility tree, legal URL liveness, distribution signing end-to-end, and legal document review.

---

_Verified: 2026-04-19T04:30:00Z_
_Verifier: Claude (gsd-verifier)_
