# Phase 7: App Store Readiness - Research

**Researched:** 2026-04-18
**Domain:** macOS App Store submission, distribution signing, screenshot automation, privacy compliance
**Confidence:** HIGH (core signing/sandbox verified; MEDIUM on XCUITest screenshot automation patterns)

## Summary

Phase 7 takes an app that is already technically compliant (sandbox, Hardened Runtime, PrivacyInfo.xcprivacy base set up in Phase 1) and produces the remaining submission artifacts: verified distribution archive, notarized DMG, automated screenshots at 2560×1600, updated metadata copy, updated legal documents, and a verified privacy manifest with AI proxy disclosure added.

The project has strong existing scaffolding: `scripts/create_dmg.sh` already builds a styled DMG with a background, `docs/app-store/app-store-connect.md` has the metadata draft to update (not rewrite), `docs/legal/privacy-policy.md` has the base privacy policy, and `Pault/PrivacyInfo.xcprivacy` has the base manifest. All signing configuration is confirmed correct in the Xcode project: CODE_SIGN_STYLE=Automatic, DEVELOPMENT_TEAM=93QQU293YD, ENABLE_HARDENED_RUNTIME=YES, ENABLE_APP_SANDBOX=YES.

The two biggest tasks are (1) implementing the XCUITest screenshot suite with realistic seed data and (2) writing `scripts/build-release.sh` with `--appstore` and `--dmg` flags. Both plans must also ensure the PrivacyInfo.xcprivacy is updated with `NSPrivacyCollectedDataTypeOtherUserContent` for prompts sent to the AI proxy, and that legal docs are finalized with subscription and BYOK terms.

**Primary recommendation:** Use XCUITest with `launchArguments` to inject seed data, capture via `app.windows.firstMatch.screenshot()`, attach via `XCTAttachment(lifetime: .keepAlways)`. For the build script, use `xcodebuild archive` + `xcodebuild -exportArchive` (method: app-store-connect, destination: export) for App Store path, and archive + exportArchive (method: developer-id) + notarytool + stapler + create_dmg.sh for the DMG path.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Screenshot strategy**
- Lead with Pro features: 1. AI Assist (streaming rewrite), 2. Block editor canvas, 3. API Runner, 4. Library split view, 5. Menu bar popover with desktop context, 6. Analytics dashboard
- Clean app-only screenshots — no device frames, no text overlays
- Light mode only
- Target resolution: 2560×1600
- Automated capture via XCUITest with realistic seed data (8-10 prompts, tags, versions, analytics events)
- No App Preview video for v1.0
- AI Assist hero shot shows the Improve tab mid-stream
- Library shot shows full split view (sidebar + list + detail)
- Menu bar shot shows popover floating above visible desktop

**Website & legal content**
- Site built in Framer (outside codebase scope) — Phase 7 produces content only
- Legal docs live in docs/legal/ as source-of-truth Markdown
- Updated privacy policy: make AI proxy data handling explicit (prompts sent to external APIs via proxy, not stored server-side)
- New Terms of Service: subscription terms, AI acceptable use clause, BYOK API key liability clause
- Support page: mailto: link to support@pault.app
- Separate email addresses: privacy@pault.app (legal), support@pault.app (support), hello@pault.app (about/general)
- Domain registration (pault.app) handled separately by user before submission
- Privacy nutrition labels pre-documented for ASC copy-paste
- Fixed effective date on legal docs (set to actual launch date)

**Privacy & compliance updates**
- Update PrivacyInfo.xcprivacy to add NSPrivacyCollectedDataTypeOtherUserContent for prompts sent to AI proxy
- Verify and update in-app links in AboutView.swift and PaywallView (URLs, emails match final site structure)
- Copyright string kept as-is: © 2025–2026

**Metadata & keywords**
- Subtitle changed to: "AI Prompt Studio" (from "Local Prompt Library for macOS")
- Description rewritten to lead with Pro features (AI Assist, API Runner, versioning, analytics)
- Keywords optimized to fill 100 chars — add: llm, chatgpt, prompt engineering, workflow, developer, automation; drop: notes
- Promotional text highlights 7-day free trial: "Try Pault Pro free for 7 days — AI rewrites, prompt execution, version history, and analytics. Your prompts stay local."
- Primary category: Productivity; Secondary: Developer Tools
- Age rating: 4+
- Bundle identifier kept: Jonathan-Hines-Dumitru.Pault
- What's New text prepared for v1.0 release
- ASC questionnaire answers pre-documented (encryption: yes/HTTPS, IDFA: no, third-party content: no, content rights: yes)

**Distribution & signing**
- Verify archive-ready only — do not upload to ASC
- Also prepare notarized DMG for direct distribution
- Branded DMG with custom background image + arrow to Applications
- Same sandbox entitlements for both App Store and DMG builds
- Single scripts/build-release.sh with --appstore and --dmg flags
- Notarization via xcrun notarytool with Apple ID + app-specific password (Keychain profile)
- Test suite runs as safety gate before archive step

### Claude's Discretion
- Exact XCUITest navigation and seed data implementation
- DMG background image design
- Keyword order and exact 100-char optimization
- Description copy and What's New text wording
- ASC questionnaire answer formatting
- Build script implementation details (error handling, logging, cleanup)

### Deferred Ideas (OUT OF SCOPE)
- Marketing landing page on pault.app — post-launch effort, not needed for ASC submission
- App Preview video — revisit post-launch based on conversion data
- Dark mode screenshot set — add later if conversion warrants
- Fastlane automation — evaluate if build frequency justifies the setup cost
- ASC API key for notarytool — switch from Apple ID auth if CI is set up later
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R7.1 | Privacy & Compliance — PrivacyInfo.xcprivacy with all required API declarations; App Store privacy labels accurate; no data leaves device except proxy API calls | NSPrivacyCollectedDataTypeOtherUserContent is the correct type for AI prompt content sent to proxy; existing UserDefaults (CA92.1) and FileTimestamp (C617.1) reason codes must be preserved; privacy label classification: "Other User Content" → "Data Not Linked to You" → "App Functionality" |
| R7.2 | Sandboxing & Entitlements — minimal entitlements, clipboard entitled, accessibility graceful fallback, Carbon global hotkey compatible with sandbox | Current entitlements confirmed minimal (app-sandbox, network.client, files.user-selected.read-write); Carbon RegisterEventHotKey works in sandbox without temporary exceptions; NSPasteboard write does not require extra entitlement beyond app-sandbox |
| R7.3 | App Store Metadata — name/subtitle/description/keywords optimized, 6+ screenshots at required resolutions, icon finalized, category/age-rating set | 2560×1600 confirmed as one of 4 valid macOS screenshot resolutions; icon set at Assets.xcassets confirmed complete; metadata source-of-truth is docs/app-store/app-store-connect.md |
| R7.4 | Signing & Distribution — Apple Distribution certificate/provisioning, Hardened Runtime, notarization passing, DMG installer | ENABLE_HARDENED_RUNTIME=YES and CODE_SIGN_STYLE=Automatic confirmed in project; xcodebuild exportArchive with method:app-store-connect (export only, not upload); notarytool store-credentials + submit --wait + stapler for DMG path |
</phase_requirements>

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| xcodebuild | Xcode bundled | Archive and export distributable app bundles | Only official command-line build tool for Xcode projects |
| xcrun notarytool | Xcode 13+ bundled | Submit app/DMG to Apple notarization service | Required; altool deprecated since Xcode 14 and removed |
| xcrun stapler | macOS bundled | Staple notarization ticket to DMG/app | Required for offline Gatekeeper verification |
| hdiutil | macOS bundled | Create and convert DMG disk images | Standard macOS tool; already used in create_dmg.sh |
| XCUITest | Xcode bundled | Automated screenshot capture with seed data | Native; captures at native display resolution; no third-party dependency |
| codesign | macOS bundled | Sign app bundle and verify entitlements | Required for all macOS distribution; verify command diagnoses signing issues |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| spctl | macOS bundled | Test Gatekeeper assessment locally | Run after notarization/stapling to confirm DMG passes Gatekeeper before shipping |
| ditto | macOS bundled | Copy .app bundle preserving xattrs/resource forks | Use instead of `cp -R` when staging app bundle for notarization zip |
| sips | macOS bundled | Read pixel dimensions from PNG files | Quick verification that screenshot PNGs are exactly 2560×1600 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual xcodebuild script | Fastlane | Deferred by user — adds Ruby dependency; justified only at higher release frequency |
| Apple ID auth for notarytool | ASC API key | Deferred by user — API key is better for CI but not needed for manual release |
| XCUITest screenshots | Manual screencapture | Manual is sufficient for one-shot but not reproducible; XCUITest is repeatable |

**Installation:** All tools are Xcode and macOS built-ins — no additional installation required.

---

## Architecture Patterns

### Recommended File Structure

```
scripts/
├── build-release.sh               # New: --appstore and --dmg flags
├── ExportOptions-AppStore.plist   # New: method app-store-connect
├── ExportOptions-DeveloperID.plist # New: method developer-id
├── create_dmg.sh                  # Existing: keep as-is
└── dmg/
    └── dmg-background.png         # Existing: update if needed

docs/
├── app-store/
│   ├── app-store-connect.md       # Update: subtitle, keywords, description, promo, screenshots list
│   └── screenshot-capture.md     # Update: new 6-shot lineup + XCUITest instructions
└── legal/
    ├── privacy-policy.md          # Update: add AI proxy data handling section
    └── terms-of-service.md       # New: subscription, acceptable use, BYOK liability

Pault/
└── PrivacyInfo.xcprivacy          # Update: add OtherUserContent entry

PaultUITests/
└── ScreenshotTests.swift          # New: 6-shot automated capture
```

### Pattern 1: XCUITest Screenshot Automation with Seed Data

**What:** Launch the app with `launchArguments` to inject a known seed state, navigate each screen, capture `app.windows.firstMatch.screenshot()`, and attach as `XCTAttachment(lifetime: .keepAlways)`.

**When to use:** Generating reproducible App Store screenshots on any Mac at any time.

```swift
// Source: Jesse Squires (2025-03-24) + XCUIScreenshot Apple docs
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()
    }

    func testShot01_AIAssist() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        // Navigate to AI Assist / Improve tab...
        let screenshot = window.screenshot()
        let attachment = XCTAttachment(
            uniformTypeIdentifier: "public.png",
            name: "01-ai-assist",
            payload: screenshot.pngRepresentation,
            userInfo: nil
        )
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
```

**Seed data pattern in app (reads launch arg at startup):**
```swift
// In App struct or AppDelegate
if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
    ScreenshotDataSeeder.seed(context: modelContext)
}
```

**AI Assist mid-stream mock (Claude's discretion — one approach):**
```swift
// Add --screenshot-mode-ai-streaming arg to put AIAssistView
// into a hardcoded visual state with partial text visible,
// bypassing the real AIService entirely.
if ProcessInfo.processInfo.arguments.contains("--screenshot-mode-ai-streaming") {
    aiAssistViewModel.mockStreamingState(chunks: ["Rewrite the", " following prompt", " to be clearer..."])
}
```

### Pattern 2: build-release.sh with --appstore and --dmg Flags

**What:** Single script producing either an App Store export or a notarized DMG.

```bash
#!/usr/bin/env bash
# Source: Apple xcodebuild + notarytool documentation
# One-time setup (run manually, not in CI):
#   xcrun notarytool store-credentials "pault-notarytool" \
#       --apple-id "YOUR_APPLE_ID" --team-id 93QQU293YD
set -euo pipefail

SCHEME="Pault"
PROJECT="Pault.xcodeproj"
ARCHIVE_PATH="build/Pault.xcarchive"
EXPORT_PATH="build/export"
VERSION="1.0"

archive() {
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH"
}

build_appstore() {
    archive
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist scripts/ExportOptions-AppStore.plist \
        -exportPath "$EXPORT_PATH"
    echo "Archive ready: open $ARCHIVE_PATH in Xcode Organizer to validate/upload"
}

build_dmg() {
    archive
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist scripts/ExportOptions-DeveloperID.plist \
        -exportPath "$EXPORT_PATH"

    # Notarize
    ditto -c -k --keepParent "$EXPORT_PATH/Pault.app" "$EXPORT_PATH/Pault-notarize.zip"
    xcrun notarytool submit "$EXPORT_PATH/Pault-notarize.zip" \
        --keychain-profile "pault-notarytool" \
        --wait
    xcrun stapler staple "$EXPORT_PATH/Pault.app"

    # Verify
    spctl -a -v "$EXPORT_PATH/Pault.app"

    # Package
    mkdir -p dist
    scripts/create_dmg.sh "$EXPORT_PATH/Pault.app" "dist/Pault-${VERSION}.dmg" "Pault"
    xcrun stapler staple "dist/Pault-${VERSION}.dmg"
    echo "DMG ready: dist/Pault-${VERSION}.dmg"
}

case "${1:-}" in
    --appstore) build_appstore ;;
    --dmg)      build_dmg ;;
    *) echo "Usage: $0 --appstore | --dmg"; exit 1 ;;
esac
```

### Pattern 3: ExportOptions Plist Files

**App Store export (destination=export, not upload — user wants verify-only):**
```xml
<!-- scripts/ExportOptions-AppStore.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>93QQU293YD</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
```

```xml
<!-- scripts/ExportOptions-DeveloperID.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>93QQU293YD</string>
</dict>
</plist>
```

### Anti-Patterns to Avoid

- **destination=upload in ExportOptions:** This triggers an interactive credential prompt and hangs in scripts. Use `destination=export` and upload manually via Xcode Organizer or Transporter.
- **Notarizing without stapling:** After notarytool returns success, always run `xcrun stapler staple`. Without it, Gatekeeper cannot verify offline.
- **Using `cp -R` to copy .app bundle:** Use `ditto` to preserve extended attributes needed for codesign verification.
- **Capturing screenshots with display sleep enabled:** Screenshots will be black. Set display sleep to "Never" or use `caffeinate -d` during screenshot test runs.
- **Removing existing NSPrivacyAccessedAPITypes entries when updating xcprivacy:** The UserDefaults (CA92.1) and FileTimestamp (C617.1) entries must remain — treat NSPrivacyAccessedAPITypes as append-only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notarization submission | Custom HTTP to Apple notary API | `xcrun notarytool` | Apple changes the API; notarytool handles auth, polling, error codes automatically |
| DMG creation with styled window | Custom hdiutil pipeline | Existing `scripts/create_dmg.sh` | Already implemented and tested; handles background image, Applications symlink, Finder layout |
| Screenshot extraction from test logs | Custom xcresult parser | `XCTAttachment(lifetime: .keepAlways)` | Xcode writes attachments to test results automatically; accessible via Xcode UI or `xcresulttool` |
| Keyword character counting | Custom counter | Manual count in text editor | 100 ASCII characters; trivial; no tooling needed |
| Privacy policy legal prose | Legal boilerplate generators | Update existing `docs/legal/privacy-policy.md` | Already complete; just needs AI proxy section appended |

**Key insight:** Phase 7 is primarily document and artifact production over existing scaffolding. The signing infrastructure (code signing style, team ID, hardened runtime) is already correct in the Xcode project. The main code deliverable is the XCUITest screenshot suite and the build-release.sh script.

---

## Common Pitfalls

### Pitfall 1: Screenshot Resolution Mismatch
**What goes wrong:** App Store Connect rejects screenshots that don't match one of the four accepted macOS resolutions.
**Why it happens:** XCUITest captures at the physical display resolution. On a 5K iMac or Retina MacBook, the logical window size times scale factor may not produce 2560×1600.
**How to avoid:** Resize the app window to exactly 1280×800 logical pixels before capturing on a 2x Retina display — this produces 2560×1600 physical pixels. Verify with `sips -g pixelWidth,pixelHeight screenshot.png` after capture.
**Warning signs:** ASC upload rejects with "Screenshot dimensions are not correct for Mac".

### Pitfall 2: Notarytool Keychain Profile Not Set Up on Build Machine
**What goes wrong:** `xcrun notarytool submit` fails with "Error: No credentials found".
**Why it happens:** The keychain profile must be created on the machine before first use; it is not stored in the repo.
**How to avoid:** Document the one-time setup command prominently in build-release.sh header comments. Do not embed credentials in the script.
**Warning signs:** notarytool exits non-zero on first run on a new machine.

### Pitfall 3: PrivacyInfo.xcprivacy Missing Existing API Reason Codes
**What goes wrong:** App Store submission fails with "ITMS-91053: Missing API declaration".
**Why it happens:** When adding the OtherUserContent data type to xcprivacy, an accidental edit removes the NSPrivacyAccessedAPITypes entries.
**How to avoid:** Treat the NSPrivacyAccessedAPITypes array as append-only; verify both CA92.1 (UserDefaults) and C617.1 (FileTimestamp) remain after editing.
**Warning signs:** Any edit to xcprivacy should be followed by a diff check against the original.

### Pitfall 4: exportArchive with destination=upload Hangs
**What goes wrong:** `xcodebuild -exportArchive` with `destination=upload` prompts interactively for Apple ID credentials and hangs in a script.
**Why it happens:** App Store Connect upload requires two-factor authentication flow that cannot complete non-interactively via Apple ID.
**How to avoid:** Use `destination=export` in ExportOptions-AppStore.plist. Upload via Xcode Organizer or Transporter manually.
**Warning signs:** build-release.sh blocks indefinitely with no output after exportArchive.

### Pitfall 5: XCUITest Captures Wrong Window or Black Image
**What goes wrong:** Screenshot attachment is empty/black or shows a sheet instead of the target view.
**Why it happens:** `windows.firstMatch` may not be the main content window; display sleep may have triggered.
**How to avoid:** Use `waitForExistence(timeout:)` before every capture. If unreliable, add `.accessibilityIdentifier("main-window")` to the SwiftUI WindowGroup and query by that ID. Run with `caffeinate -d`.
**Warning signs:** PNG attachment in test results is black or shows wrong UI.

### Pitfall 6: ASC Questionnaire Answers Not Filled In Before Validation
**What goes wrong:** Xcode Organizer "Validate App" passes, but ASC flags missing questionnaire answers (encryption export, IDFA, content rights) before upload.
**Why it happens:** Documenting answers in app-store-connect.md is a reference; ASC requires them to be entered in the web interface directly.
**How to avoid:** Fill in the ASC questionnaire (App Privacy → questionnaire, and the export compliance/IDFA questions) in the App Store Connect web interface before running validation.

---

## Code Examples

### PrivacyInfo.xcprivacy — Complete Updated File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeOtherDataTypes</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeOtherUserContent</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Notarytool one-time keychain profile setup
```bash
# Source: Apple notarytool man page
# Run once manually on the build machine — NOT in build-release.sh
xcrun notarytool store-credentials "pault-notarytool" \
    --apple-id "YOUR_APPLE_ID" \
    --team-id 93QQU293YD
# Prompts for app-specific password from appleid.apple.com
```

### Verify codesigning and entitlements after export
```bash
# Source: Apple codesign + spctl man pages
codesign --verify --deep --strict --verbose=4 build/export/Pault.app
codesign --display --entitlements :- build/export/Pault.app
spctl -a -v build/export/Pault.app
```

### Verify screenshot dimensions
```bash
# After running ScreenshotTests, extract PNG attachments and check:
sips -g pixelWidth,pixelHeight docs/app-store/screenshots/01-ai-assist.png
# Expected: pixelWidth: 2560  pixelHeight: 1600
```

### ASC Privacy Nutrition Label for AI Proxy Use Case
```
Category: User Content
Data type: Other User Content
  Linked to user: No
  Used for tracking: No
  Purposes: App Functionality
  Description: Prompt text is transmitted to an AI proxy service when the
               user explicitly invokes AI Assist or API Runner features.
               Prompts are not stored server-side.
```

### Keywords draft (100-char target, Claude's discretion for final order)
```
prompts,ai,llm,chatgpt,prompt engineering,workflow,developer,automation,productivity,templates
```
Check character count (comma-separated, no trailing comma): verify this fills close to 100 chars before finalizing.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| altool for notarization | notarytool | Xcode 13 (2021); deprecated Xcode 14 | notarytool required now; faster and provides real-time status |
| Manual screencapture | XCUITest + XCTAttachment | Stable since Xcode 9 | Reproducible; no third-party tool |
| app-store method in exportOptions | app-store-connect method | Xcode 13+ | Both may work; app-store-connect is the current documented value |

**Deprecated/outdated in this project:**
- `altool`: Removed. Do not reference.
- `docs/app-store/screenshot-capture.md` currently describes manual `screencapture -i`. This file will be updated to reflect the new XCUITest-based lineup and workflow.
- `app-store-connect.md` metadata (subtitle "Local Prompt Library for macOS", keywords including "notes") will be replaced per locked decisions.

---

## Open Questions

1. **Main window accessibility identifier**
   - What we know: `app.windows.firstMatch` is fragile if sheets are open
   - What's unclear: Whether the main SwiftUI WindowGroup window currently has an accessibility identifier set
   - Recommendation: During Plan 02 implementation, check `NSApp.keyWindow.accessibilityIdentifier()`; if absent, add `.accessibilityIdentifier("main-window")` to the WindowGroup body

2. **AI Assist mid-stream screenshot**
   - What we know: AI Assist calls the real proxy; a UI test cannot reliably trigger live streaming
   - What's unclear: Best mock strategy — view model state injection vs. launch arg vs. preview-only fake
   - Recommendation: Add `--screenshot-mode-ai-streaming` launch arg; in AIAssistViewModel or equivalent, check for this arg and load a hardcoded array of "streamed" text chunks displayed as if streaming is in progress

3. **Menu bar popover screenshot with visible desktop**
   - What we know: XCUITest can click status bar items; the shot requires the popover floating above a real desktop
   - What's unclear: Whether XCUITest reliably captures the popover window on all Mac configurations in a test run
   - Recommendation: Implement via XCUITest first; if the popover window is not queryable via `app.windows`, fall back to `XCUIScreen.main.screenshot()` which captures full screen including desktop

4. **DMG background image**
   - What we know: `scripts/dmg/dmg-background.png` already exists
   - What's unclear: Whether the current design matches Phase 7's branding expectations
   - Recommendation: Review the existing file during Plan 02 task; update if the design doesn't reflect the current app aesthetic

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | Pault.xcodeproj (target: PaultUITests) |
| Quick run command | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS' -only-testing:PaultUITests/ScreenshotTests` |
| Full suite command | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R7.1 | PrivacyInfo.xcprivacy contains OtherUserContent entry | Manual inspection | `grep -c OtherUserContent Pault/PrivacyInfo.xcprivacy` | ✅ (file exists; entry added in this phase) |
| R7.1 | Privacy policy contains AI proxy disclosure section | Manual review | Human review of docs/legal/privacy-policy.md | ✅ file exists |
| R7.2 | Entitlements minimal — only 3 keys present | Manual inspection | `codesign --display --entitlements :- build/export/Pault.app` | ✅ entitlements file exists |
| R7.3 | 6 screenshots exist at 2560×1600 | Manual inspection | `sips -g pixelWidth,pixelHeight docs/app-store/screenshots/*.png` | ❌ Wave 0 — ScreenshotTests.swift needed |
| R7.3 | app-store-connect.md updated with new metadata | Manual diff | human review | ✅ file exists |
| R7.4 | Archive validates cleanly | Manual | Xcode Organizer → Validate App | N/A until archive built |
| R7.4 | DMG passes Gatekeeper spctl | Manual | `spctl -a -v dist/Pault-1.0.dmg` | ❌ Wave 0 — build-release.sh needed |

### Wave 0 Gaps
- [ ] `PaultUITests/ScreenshotTests.swift` — 6-shot automated capture suite (covers R7.3)
- [ ] `scripts/build-release.sh` — archive, export, notarize workflow (covers R7.4)
- [ ] `scripts/ExportOptions-AppStore.plist` — required by build-release.sh
- [ ] `scripts/ExportOptions-DeveloperID.plist` — required by build-release.sh
- [ ] `docs/legal/terms-of-service.md` — subscription terms, BYOK liability, acceptable use clause

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: Screenshot Specifications — https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ — confirmed 4 valid macOS resolutions including 2560×1600
- Apple Developer Documentation: App Privacy Details — https://developer.apple.com/app-store/app-privacy-details/ — User Content data types; OtherUserContent is the correct category for AI prompt text
- Apple notarytool man page — https://keith.github.io/xcode-man-pages/notarytool.1.html — keychain-profile flag, store-credentials command syntax
- Jesse Squires blog (2025-03-24) — https://www.jessesquires.com/blog/2025/03/24/automate-perfect-mac-screenshots/ — XCUITest screenshot automation pattern for macOS App Store

### Secondary (MEDIUM confidence)
- Apple Developer Forums: xcodebuild -exportArchive developer-id — method values verified against Xcode archive export docs
- Scripting Notarization for macOS — https://oozou.com/blog/scripting-notarization-for-macos-app-distribution-38 — xcodebuild archive + notarytool workflow; cross-verified with Apple notarytool docs
- Apple: Custom EULA Requirements — https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/ — custom EULA clauses (subscription apps may use standard Apple EULA or provide custom)

### Tertiary (LOW confidence)
- Carbon RegisterEventHotKey sandbox compatibility — confirmed via multiple Apple Developer Forum posts; no single definitive Apple doc; flag as LOW for verification during Plan 01
- XCUITest menu bar status item interaction for popover screenshot — documented in general XCUITest docs but Mac-specific menu bar item querying has limited official examples; flagged in Open Questions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are Xcode/macOS built-ins; verified against official docs
- Architecture: HIGH — signing/notarization pattern confirmed via Apple documentation and current (2025) guides
- Pitfalls: MEDIUM — based on Apple Developer Forum patterns and documentation; resolution mismatch and stapler-omission pitfalls are well-documented across multiple sources

**Research date:** 2026-04-18
**Valid until:** 2026-07-18 (stable Apple toolchain; macOS screenshot specs rarely change mid-year)
