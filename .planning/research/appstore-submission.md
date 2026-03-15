# macOS App Store Submission Readiness Research

**Project:** Pault -- Local Prompt Library for macOS
**Domain:** App Store review compliance, sandboxing, privacy manifests, entitlements
**Researched:** 2026-03-14
**Overall confidence:** HIGH (based on Apple Review Guidelines, codebase audit, existing project docs)

---

## Executive Summary

Pault is well-positioned for App Store submission. The app is already sandboxed, uses standard macOS APIs, and has existing App Store Connect metadata prepared. However, there are several concrete issues that must be addressed before submission:

1. **Privacy Manifest (PrivacyInfo.xcprivacy) is missing entirely** -- Apple requires this as of Spring 2024 and will reject submissions without it.
2. **The temporary-exception entitlement for Apple Events is a red flag** -- this entitlement requires justification and may delay review or cause rejection.
3. **CGEvent paste simulation (planned but not yet built)** requires Accessibility permission, which is incompatible with the App Sandbox in a meaningful way -- the app cannot programmatically grant itself Accessibility access, and Apple scrutinizes apps that request it.
4. **No StoreKit 2 integration yet** -- required for the planned Free/Pro tier model.
5. **Screenshot assets not yet captured** -- needed for all required macOS display sizes.

The core app (prompt CRUD, clipboard copy, menu bar, global hotkey via Carbon) is App Store compatible. The biggest risk is the planned CGEvent paste simulation feature, which should be carefully scoped or made optional.

---

## 1. App Store Review Guidelines -- Common Rejection Risks

### Pault-Specific Risk Assessment

| Guideline | Risk Level | Pault Status | Action Needed |
|-----------|-----------|-------------|---------------|
| 2.1 -- App completeness | LOW | Core features complete, block editor ~95% | Finish remaining 5%, remove placeholder UI |
| 2.4.5(i) -- Sandboxing | LOW | Already sandboxed | Audit entitlements (see section 3) |
| 2.4.5(ii) -- Packaging | LOW | Standard Xcode project | Verify no embedded frameworks issues |
| 2.4.5(iii) -- Auto-launch | LOW | No auto-launch behavior observed | Confirm no Login Items without consent |
| 2.5.1 -- Private APIs | MEDIUM | Carbon is deprecated but still public | Document justification for Carbon usage |
| 3.1.1 -- In-app purchase | HIGH | StoreKit 2 not yet implemented | Must implement before submission if Pro tier ships |
| 4.2 -- Minimum functionality | LOW | Rich feature set | No risk here |
| 5.1.1 -- Privacy policy | MEDIUM | Privacy policy drafted, URL placeholder | Must publish to pault.app/privacy before submission |
| 5.1.2 -- Data use | LOW | Local-first, no telemetry | Clean position |

### Top Rejection Reasons for macOS Utility Apps (and Pault's Exposure)

**1. Missing or incomplete privacy declarations**
- Pault has NO PrivacyInfo.xcprivacy file. This will cause automatic rejection.
- Action: Create the file (see section 2).

**2. Temporary exception entitlements without justification**
- Pault requests `com.apple.security.temporary-exception.apple-events` for System Events.
- Apple treats temporary exceptions as technical debt. Reviewers will ask why.
- Action: Determine if this is actually needed. The current codebase does NOT use Apple Events or CGEvent -- the paste simulation is planned but not implemented.

**3. Insufficient purpose strings for permissions**
- If the app prompts for Accessibility permission, it needs a clear, user-facing explanation.
- Action: Add purpose strings in Info.plist or in-app UI before the permission prompt.

**4. Crashes or incomplete features during review**
- The block editor is ~95% complete. Any unfinished UI elements will be flagged.
- Action: Hide or remove unfinished features behind feature flags before submission.

**5. Network calls without disclosure**
- AI API calls (Claude, OpenAI, Ollama) send data to external servers.
- Action: Privacy labels must declare "Data Linked to You" for any prompt content sent to AI APIs.

---

## 2. Privacy Manifest (PrivacyInfo.xcprivacy)

### Status: MISSING -- Must Create

Apple requires a privacy manifest for all App Store submissions as of May 2024. Pault does not have one.

### Required API Declarations for Pault

Based on the codebase audit, Pault uses these "required reason" API categories:

| API Category | Pault's Usage | Required Reason Code | Notes |
|-------------|--------------|---------------------|-------|
| **NSPrivacyAccessedAPICategoryUserDefaults** | `@AppStorage` throughout (accent color, default action, onboarding flag, dock visibility) | `CA92.1` -- "Access info from same app" | Standard usage, straightforward declaration |
| **NSPrivacyAccessedAPICategoryFileTimestamp** | SwiftData stores files with timestamps; `Prompt.updatedAt`, `Prompt.createdAt` | `C617.1` -- "Access file timestamps within app container" | If using `FileManager` for timestamps. May not apply if only SwiftData dates. |
| **NSPrivacyAccessedAPICategorySystemBootTime** | Possibly used by os.Logger or system frameworks | `35F9.1` -- "Measure time elapsed" | Check if any dependency uses `ProcessInfo.processInfo.systemUptime` |
| **NSPrivacyAccessedAPICategoryDiskSpace** | Not used directly | N/A | Likely not needed unless SwiftData checks this |

### Privacy Manifest Template for Pault

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <!-- If AI features send prompt content to external APIs -->
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
    </array>
</dict>
</plist>
```

### Important Notes

- **NSPasteboard is NOT in Apple's required-reason API list.** Clipboard read/write does not require a privacy manifest declaration (it requires App Store privacy label declarations instead -- see section 8).
- **Keychain (SecItem) is NOT in Apple's required-reason API list.** Standard keychain usage is expected for credential storage.
- If using only `@AppStorage` / `UserDefaults` for the app's own preferences, `CA92.1` is the correct reason.
- If AI features are gated behind Pro and not in v1.0 free tier, the collected data types array can be empty for initial submission.

---

## 3. Sandboxing and Entitlements

### Current Entitlements (from Pault.entitlements)

```
com.apple.security.app-sandbox = true
com.apple.security.network.client = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.temporary-exception.apple-events = ["com.apple.systemevents"]
```

### Entitlement Audit

| Entitlement | Justified? | Risk | Recommendation |
|------------|-----------|------|----------------|
| `app-sandbox` | YES | None | Required for App Store |
| `network.client` | YES | None | Needed for AI API calls (Claude, OpenAI, Ollama) |
| `files.user-selected.read-write` | YES | None | Standard for import/export via NSOpenPanel/NSSavePanel |
| `temporary-exception.apple-events` | QUESTIONABLE | HIGH | See analysis below |

### The Apple Events Temporary Exception Problem

**Current state:** The entitlement is declared but the codebase does NOT use Apple Events or AppleScript to control System Events. The `AccessibilityHelper.swift` file referenced in docs does not exist yet.

**The issue:** Temporary exception entitlements are flagged during App Store review. Apple will ask:
1. What specific Apple Events does your app send?
2. Why can't you achieve this without the exception?
3. What is your plan to remove this exception?

**Recommendation:** REMOVE this entitlement before submission. It is not used by any current code. If paste simulation is added later, it should use a different approach (see section 6).

### Entitlements NOT Needed

- `com.apple.security.personal-information.calendars` -- not used
- `com.apple.security.personal-information.addressbook` -- not used
- `com.apple.security.device.camera` -- not used
- `com.apple.security.device.microphone` -- not used
- `com.apple.security.device.audio-input` -- not used

---

## 4. App Store Connect Metadata

### Status: Partially Prepared

The project has `docs/app-store/app-store-connect.md` with good metadata. Gaps:

| Requirement | Status | Action |
|------------|--------|--------|
| App Name | DONE | "Pault" |
| Subtitle | DONE | "Local Prompt Library for macOS" |
| Primary Category | DONE | Productivity |
| Secondary Category | DONE | Developer Tools |
| Keywords | DONE | prompts,writing,productivity,clipboard,templates,notes,ai |
| Promotional Text | DONE | 96 chars, under 170 limit |
| Description | DONE | Well-written, covers features |
| Privacy URL | PLACEHOLDER | Must publish pault.app/privacy before submission |
| Support URL | PLACEHOLDER | Must publish pault.app/support before submission |
| Marketing URL | PLACEHOLDER | Must publish pault.app |
| Screenshots | NOT DONE | Need 6 screenshots for each macOS display size |
| App Preview Video | NOT DONE | Optional but recommended |
| Age Rating | NOT SET | Needs questionnaire completion in ASC |
| Copyright | NOT SET | "2026 [Your Name/Company]" |
| Build Upload | NOT DONE | Requires archive + upload via Xcode |

### Screenshot Requirements for macOS

Apple requires screenshots at these resolutions (at least one set):

| Display Size | Resolution | Required? |
|-------------|-----------|-----------|
| Mac with 16-inch Retina display | 3456 x 2234 or 2880 x 1800 | At least one Mac size required |
| Mac with 13-inch Retina display | 2560 x 1600 or 2880 x 1800 | Optional |

- Minimum 1 screenshot, maximum 10
- Acceptable formats: PNG, JPEG
- No alpha channel allowed (no transparency)
- Screenshots must show the app running, not just marketing images (though marketing overlays are common)

The project already has a `docs/app-store/screenshots/` directory and a `docs/app-store/screenshot-capture.md` plan. These need to be executed.

---

## 5. Signing and Notarization

### For App Store Distribution

| Requirement | Details |
|------------|---------|
| **Apple Developer Program** | Must have active membership ($99/year) |
| **Code signing** | Automatic signing in Xcode with App Store distribution profile |
| **Hardened Runtime** | Automatically enabled for App Store builds |
| **Notarization** | NOT required for App Store distribution (Apple handles it). Only needed for direct distribution outside the store. |
| **Provisioning Profile** | App Store type, managed by Xcode |
| **Team ID / Bundle ID** | Must match App Store Connect record |

### Build Submission Process

1. Set version number and build number in Xcode
2. Select "Any Mac" as destination
3. Product > Archive
4. In Organizer, select archive > Distribute App > App Store Connect
5. Upload (Xcode validates entitlements, signing, and basic compliance)
6. In App Store Connect, select the build for the app version
7. Submit for review

### Potential Signing Issues

- **Carbon framework:** Carbon is a system framework and does not cause signing issues. It is linked automatically.
- **No third-party frameworks** appear to be used that would require embedded framework signing.
- **SwiftData** is a system framework, no issues.

---

## 6. CGEvent/Carbon Hotkey and Sandbox Interaction

### Carbon Global Hotkeys (RegisterEventHotKey)

**Confidence: HIGH**

Carbon's `RegisterEventHotKey` works within the App Sandbox. Many shipped App Store apps use this exact API (Raycast, Rocket, Magnet, etc.). Apple has not deprecated the hotkey registration portion of Carbon, and there is no SwiftUI/AppKit replacement.

**Key facts:**
- `RegisterEventHotKey` does NOT require Accessibility permission
- It works within the sandbox without any special entitlements
- It registers hotkeys at the application event target level, not system-wide event tap
- The current `GlobalHotkeyManager.swift` implementation is correct and App Store safe

### CGEvent Paste Simulation (Planned Feature)

**Confidence: HIGH -- this is the highest-risk feature for App Store submission**

The planned `AccessibilityHelper.swift` would use `CGEvent` to simulate Cmd+V in the frontmost app. This is fundamentally at odds with the App Sandbox:

**How it works:**
1. Copy text to NSPasteboard (safe, no permission needed)
2. Create a CGEvent for key-down of Cmd+V
3. Post the event to the system (requires Accessibility permission)

**App Store compatibility issues:**
- `CGEvent.init(keyboardEventSource:virtualKey:keyDown:)` and `CGEvent.post(tap:)` require the app to be in the Accessibility allowed list in System Settings > Privacy & Security > Accessibility
- Sandboxed apps CAN check for Accessibility trust via `AXIsProcessTrusted()` and prompt with `AXIsProcessTrustedWithOptions`
- Sandboxed apps CAN use CGEvent IF the user grants Accessibility permission manually
- Apple DOES allow this for App Store apps -- apps like Raycast, TextExpander, Rocket, Paste, and PopClip all do it
- However, the app MUST handle the case where the user denies permission gracefully

**Recommendations for paste simulation:**
1. Make it optional -- the default action should be "copy to clipboard" (which is already the case)
2. When the user first tries to paste, check `AXIsProcessTrusted()` and show an in-app explanation before triggering the system prompt
3. Provide a clear settings toggle: "Enable paste into active app (requires Accessibility permission)"
4. If permission is denied, fall back to copy-only with a helpful message
5. Do NOT use the `temporary-exception.apple-events` entitlement -- it is not needed for CGEvent and sends the wrong signal to reviewers

### Recommendation for v1.0

Ship v1.0 with copy-to-clipboard only. The paste simulation can be added in a post-launch update once the app is established in the store. This avoids the Accessibility permission friction during first review and reduces rejection risk.

If paste simulation MUST ship in v1.0:
- Remove the Apple Events temporary exception entitlement
- Implement `AccessibilityHelper.swift` with proper permission flow
- Add a clear user-facing explanation for why Accessibility permission is needed
- Make the feature discoverable but not required for core functionality

---

## 7. Accessibility Permission Handling

### Permission Flow Design

If/when CGEvent paste simulation is implemented:

```
User taps "Paste into App" button
  |
  v
Check AXIsProcessTrusted()
  |
  +--> TRUE: Execute CGEvent paste
  |
  +--> FALSE: Show in-app sheet explaining:
         "Pault needs Accessibility access to paste
          prompts directly into your active app.

          This allows Pault to simulate Cmd+V
          after copying your prompt to the clipboard.

          [Open System Settings]  [Just Copy Instead]"
         |
         v
       AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])
         |
         v
       System dialog appears
         |
         +--> User enables: Feature works on next attempt
         +--> User denies: Fall back to copy-only, remember preference
```

### Key Implementation Rules

1. **Never block app launch on Accessibility permission.** The permission is only relevant for paste simulation.
2. **Check permission lazily** -- only when the user tries to use the paste feature, not at startup.
3. **Provide a fallback.** Copy-to-clipboard must always work without any permissions.
4. **Remember user choice.** If user dismisses the permission dialog, do not nag on every paste attempt. Show a subtle "Enable paste" option in settings instead.
5. **App restart required.** After granting Accessibility permission in System Settings, the app must be restarted for macOS to recognize the new trust status. Inform the user of this.

### Important Caveat

`AXIsProcessTrustedWithOptions` with the prompt option will show the system's "App would like to control this computer" dialog. This is expected behavior and Apple approves it for apps that genuinely need Accessibility (text expanders, clipboard managers, launcher tools). Pault fits this category.

---

## 8. App Store Privacy Labels (Data Handling Declarations)

### Required Declarations in App Store Connect

When submitting, you must answer Apple's privacy questionnaire. Here is what Pault should declare:

### If v1.0 Ships WITHOUT AI Features (Free Tier Only)

**Data Not Collected.** Select "Data Not Collected" in App Store Connect.

Justification:
- Prompts are stored locally in SwiftData
- No analytics, no telemetry, no network requests in free tier
- Keychain stores API keys locally on device
- Clipboard writes are ephemeral and not collected
- No account system, no user identifiers

### If v1.0 Ships WITH AI Features (Pro Tier)

You must declare data collection for the AI API calls:

| Data Type | Collected? | Linked to User? | Used for Tracking? | Purpose |
|-----------|-----------|-----------------|-------------------|---------|
| Other User Content (prompts sent to AI) | YES | NO | NO | App Functionality |
| Identifiers (API keys in Keychain) | NO (stored locally, sent to third-party API) | N/A | N/A | N/A |

**Important:** API keys stored in Keychain are not "collected" by your app -- they are stored locally and sent directly to third-party APIs. However, the prompt content IS sent to external servers (OpenAI, Anthropic, Ollama). If Ollama is local-only, that specific provider does not count as data collection.

### Privacy Label Recommendation

Ship v1.0 free tier as "Data Not Collected." Add AI features in a subsequent update and update privacy labels at that time. This simplifies the initial review process significantly.

---

## 9. Pre-Submission Checklist

### Must-Do Before First Submission

- [ ] **Create PrivacyInfo.xcprivacy** with UserDefaults declaration (CA92.1)
- [ ] **Remove `temporary-exception.apple-events`** from entitlements (not used by current code)
- [ ] **Publish privacy policy** at pault.app/privacy
- [ ] **Publish support page** at pault.app/support (can be a simple contact form or email)
- [ ] **Capture screenshots** at required Mac Retina resolutions
- [ ] **Set version to 1.0** (build number 1)
- [ ] **Complete age rating questionnaire** in App Store Connect
- [ ] **Set copyright** in App Store Connect
- [ ] **Hide or finish incomplete features** -- all Pro features behind a paywall or feature flag
- [ ] **Test on clean macOS install** -- ensure first-run experience works without crashes
- [ ] **Review all os.Logger messages** -- ensure no sensitive data (API keys, prompt content) is logged
- [ ] **Verify network.client entitlement justification** -- if no network calls in v1.0 free tier, consider removing until AI features ship
- [ ] **Add `NSHumanReadableCopyright`** to Info.plist

### Should-Do for Smooth Review

- [ ] **Add accessibility labels** throughout the app (partially done, good coverage in existing code)
- [ ] **Support system Dark Mode** properly (verify all views)
- [ ] **Handle edge cases** -- empty states, error states, long prompt content
- [ ] **Performance test** -- ensure app launches quickly, no memory leaks
- [ ] **Test with VoiceOver** -- Apple sometimes tests accessibility
- [ ] **Add App Transport Security** -- if making HTTPS calls, ensure ATS compliance (HTTPS-only is fine)

### Post-Submission Expectations

- **Review time:** Typically 24-48 hours for new macOS apps
- **Common back-and-forth:** Reviewer may ask about entitlement justifications, especially if temporary exceptions are present
- **Binary rejection vs. metadata rejection:** Metadata issues (screenshots, description) are faster to fix than binary issues (code changes requiring new upload)

---

## 10. Phase Ordering Recommendation

Based on this research, the recommended order for App Store readiness work:

### Phase 1: Compliance Foundation
1. Create PrivacyInfo.xcprivacy
2. Remove unused Apple Events temporary exception entitlement
3. Audit and finalize entitlements
4. Publish privacy policy and support URLs

### Phase 2: Feature Completion Gate
1. Finish block editor remaining 5%
2. Hide or feature-flag all incomplete Pro features
3. Decide: ship v1.0 as free-only or with StoreKit 2 paywall

### Phase 3: Store Assets
1. Capture screenshots at required resolutions
2. Complete App Store Connect metadata
3. Set version, copyright, age rating

### Phase 4: Quality Gate
1. Test on clean macOS 15 install
2. VoiceOver and accessibility audit
3. Performance profiling
4. Edge case testing

### Phase 5: Submission
1. Archive and upload via Xcode
2. Configure build in App Store Connect
3. Submit for review
4. Prepare for reviewer questions about Carbon usage and hotkey behavior

---

## Sources

- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Privacy Manifest Documentation: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Apple App Sandbox Documentation: https://developer.apple.com/documentation/security/app-sandbox
- Codebase audit: Pault.entitlements, GlobalHotkeyManager.swift, PromptService.swift, KeychainService.swift
- Project docs: docs/PERMISSIONS.md, docs/app-store/app-store-connect.md, docs/enterprise/SECURITY_PRIVACY.md
- Community knowledge: Carbon RegisterEventHotKey usage in shipped App Store apps (Raycast, Magnet, Rocket, PopClip)

## Confidence Assessment

| Area | Confidence | Notes |
|------|-----------|-------|
| Review Guidelines | HIGH | Read directly from Apple's guidelines page |
| Privacy Manifest | MEDIUM | Apple docs require JS rendering; API category list based on training data + known requirements. Verify exact reason codes against current Apple documentation before implementation. |
| Sandboxing/Entitlements | HIGH | Entitlements file audited directly; Carbon hotkey compatibility confirmed by shipped apps |
| App Store Connect Metadata | HIGH | Requirements are stable and well-documented |
| Signing/Notarization | HIGH | Standard Xcode workflow, no special requirements |
| CGEvent/Accessibility | HIGH | Well-understood pattern used by many macOS productivity apps |
| Privacy Labels | HIGH | Local-first architecture makes this straightforward |
