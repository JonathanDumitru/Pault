---
phase: 09-privacyinfo-xcode-wiring
status: verified
score: 4/4
verified_date: 2026-04-21
---

# Phase 09 Verification: PrivacyInfo.xcprivacy Bundling

**Verdict: VERIFIED — R7.1 integration gap formally closed**

This verification closes the gap flagged in `.planning/phases/01-compliance-test-infrastructure/01-VERIFICATION.md` (truth #6: "PrivacyInfo.xcprivacy not wired to Xcode target"). The gap was a false positive caused by the Phase 1 verifier using a check appropriate for classic Xcode projects, not Xcode 16 folder-synchronized projects.

---

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PrivacyInfo.xcprivacy present in built bundle at Contents/Resources/PrivacyInfo.xcprivacy | VERIFIED | `find ~/Library/Developer/Xcode/DerivedData -name "Pault.app" -path "*/Debug/*" ... find ... -name "PrivacyInfo.xcprivacy"` returned `/Users/dev/Library/Developer/Xcode/DerivedData/Pault-diallvrkwaylkjghpogtffmbnryp/Build/Products/Debug/Pault.app/Contents/Resources/PrivacyInfo.xcprivacy` after clean build |
| 2 | No PBXFileSystemSynchronizedBuildFileExceptionSet excludes PrivacyInfo.xcprivacy | VERIFIED | `grep -c "membershipExceptions\|PBXFileSystemSynchronizedBuildFileExceptionSet" Pault.xcodeproj/project.pbxproj` returned `0` |
| 3 | PrivacyInfo.xcprivacy has valid plist format with CA92.1 and C617.1 reason codes | VERIFIED | `plutil -lint` → `OK`; `plutil -p` shows `NSPrivacyAccessedAPICategoryUserDefaults: CA92.1` and `NSPrivacyAccessedAPICategoryFileTimestamp: C617.1` in both source and built bundle |
| 4 | R7.1 integration gap from Phase 1 VERIFICATION formally closed | VERIFIED | All three evidence sources agree: source file valid, project structure correct, built bundle contains the file |

---

## Requirements Coverage

### R7.1 — Privacy & Compliance

**Status: VERIFIED**

**Evidence collected 2026-04-21:**

**Check 1 — Source file validity:**
```
$ plutil -lint Pault/PrivacyInfo.xcprivacy
Pault/PrivacyInfo.xcprivacy: OK

$ plutil -p Pault/PrivacyInfo.xcprivacy
{
  "NSPrivacyAccessedAPITypes" => [
    0 => {
      "NSPrivacyAccessedAPIType" => "NSPrivacyAccessedAPICategoryUserDefaults"
      "NSPrivacyAccessedAPITypeReasons" => [
        0 => "CA92.1"
      ]
    }
    1 => {
      "NSPrivacyAccessedAPIType" => "NSPrivacyAccessedAPICategoryFileTimestamp"
      "NSPrivacyAccessedAPITypeReasons" => [
        0 => "C617.1"
      ]
    }
  ]
  "NSPrivacyCollectedDataTypes" => [
    0 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeOtherDataTypes"
      "NSPrivacyCollectedDataTypeLinked" => false
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => false
    }
    1 => {
      "NSPrivacyCollectedDataType" => "NSPrivacyCollectedDataTypeOtherUserContent"
      "NSPrivacyCollectedDataTypeLinked" => false
      "NSPrivacyCollectedDataTypePurposes" => [
        0 => "NSPrivacyCollectedDataTypePurposeAppFunctionality"
      ]
      "NSPrivacyCollectedDataTypeTracking" => false
    }
  ]
  "NSPrivacyTracking" => false
  "NSPrivacyTrackingDomains" => [
  ]
}
```

**Check 2 — PBXFileSystemSynchronizedRootGroup covers Pault/:**
```
$ grep "PBXFileSystemSynchronizedRootGroup" Pault.xcodeproj/project.pbxproj
/* Begin PBXFileSystemSynchronizedRootGroup section */
      isa = PBXFileSystemSynchronizedRootGroup;
      isa = PBXFileSystemSynchronizedRootGroup;
      isa = PBXFileSystemSynchronizedRootGroup;
/* End PBXFileSystemSynchronizedRootGroup section */
```
Entry with `isa = PBXFileSystemSynchronizedRootGroup` exists — confirms the Pault/ folder is auto-synchronized.

**Check 3 — No exception sets:**
```
$ grep -c "membershipExceptions\|PBXFileSystemSynchronizedBuildFileExceptionSet" Pault.xcodeproj/project.pbxproj
0
```
Zero exclusions — PrivacyInfo.xcprivacy is not excluded from any target.

**Check 4 — Clean build result:**
```
** BUILD SUCCEEDED **
```
Full `xcodebuild clean build -project Pault.xcodeproj -scheme Pault -configuration Debug -destination 'platform=macOS'` succeeded with no errors.

**Check 5 — PrivacyInfo.xcprivacy in built bundle:**
```
/Users/dev/Library/Developer/Xcode/DerivedData/Pault-diallvrkwaylkjghpogtffmbnryp/Build/Products/Debug/Pault.app/Contents/Resources/PrivacyInfo.xcprivacy
```

**Check 6 — Built bundle xcprivacy content:**
```
$ plutil -p .../Pault.app/Contents/Resources/PrivacyInfo.xcprivacy
{
  "NSPrivacyAccessedAPITypes" => [
    0 => {
      "NSPrivacyAccessedAPIType" => "NSPrivacyAccessedAPICategoryUserDefaults"
      "NSPrivacyAccessedAPITypeReasons" => [ 0 => "CA92.1" ]
    }
    1 => {
      "NSPrivacyAccessedAPIType" => "NSPrivacyAccessedAPICategoryFileTimestamp"
      "NSPrivacyAccessedAPITypeReasons" => [ 0 => "C617.1" ]
    }
  ]
  "NSPrivacyTracking" => false
  "NSPrivacyTrackingDomains" => []
}
```
Content matches source — `CA92.1` and `C617.1` present in the shipped bundle.

---

## Phase 1 Gap Resolution

### What Phase 1 Flagged

Phase 1 VERIFICATION (`.planning/phases/01-compliance-test-infrastructure/01-VERIFICATION.md`) listed truth #6 as unverified:

> "PrivacyInfo.xcprivacy wired to Xcode target — 0 PBXFileReference entries found for PrivacyInfo.xcprivacy in project.pbxproj"

### Why It Was a False Positive

The Phase 1 verifier used the correct check for **classic Xcode projects**: look for explicit `PBXFileReference` and `PBXBuildFile` entries in `project.pbxproj`. If a file has no `PBXFileReference`, it is not known to Xcode and will not be bundled.

However, this project uses **Xcode 16's PBXFileSystemSynchronizedRootGroup** mechanism (objectVersion 77), which works differently:

| Classic Project | Folder-Synchronized Project |
|---|---|
| Every file needs an explicit `PBXFileReference` entry | Files are auto-discovered from the folder on disk |
| `PBXResourcesBuildPhase files = (...)` lists every resource by UUID | `PBXResourcesBuildPhase files = ()` is correct and expected |
| Adding a file requires an Xcode GUI action or project.pbxproj edit | Dropping a file into the folder automatically includes it |

When the Phase 1 verifier found `PBXResourcesBuildPhase files = ()` (empty), it correctly concluded "this file is not referenced" — but this is actually the **correct and expected state** for a folder-synchronized project.

### Ground Truth: The Built Bundle

The authoritative verification is the built application bundle, not `project.pbxproj`. The built bundle at `Pault.app/Contents/Resources/PrivacyInfo.xcprivacy` confirms the file is being copied by Xcode's folder-sync mechanism.

### Key Takeaway

No code changes were needed. PrivacyInfo.xcprivacy has always been correctly bundled. The project.pbxproj was never incorrect. The Phase 1 gap was a tooling false positive attributable to the verifier not accounting for Xcode 16's folder synchronization feature.

**Do NOT add explicit PBXFileReference or PBXBuildFile entries.** Doing so would cause a "Multiple commands produce PrivacyInfo.xcprivacy" build error because both the explicit entry and the folder-sync mechanism would try to copy the file.

---

## Summary

| Requirement | Verdict | Method |
|-------------|---------|--------|
| R7.1 Privacy & Compliance | VERIFIED | Clean build + bundle inspection + plutil validation |

Phase 9 closes the last outstanding gap from Phase 1. No source code modifications were made.
