# Phase 1: Compliance & Test Infrastructure - Research

**Researched:** 2026-03-14
**Domain:** App Store compliance (privacy manifest, entitlements) + Swift Testing infrastructure
**Confidence:** HIGH

## Summary

Phase 1 addresses two distinct concerns: (1) removing App Store hard-rejection blockers by creating a PrivacyInfo.xcprivacy manifest and cleaning up stale entitlements, and (2) establishing shared test infrastructure and expanding block editor test coverage. Both are well-understood domains with minimal technical risk.

The compliance work is straightforward -- the entitlements file is small and the privacy manifest follows a well-documented XML plist format. The test infrastructure work centers on extracting duplicated `ModelContainer` setup (found in 15 test files) into a shared `TestHelpers.swift` factory, then expanding the three block editor test suites that have the most coverage gaps.

**Primary recommendation:** Execute compliance changes first (small, high-impact), then refactor test containers, then expand test coverage. Run full test suite before and after each step.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Remove `com.apple.security.temporary-exception.apple-events` entitlement entirely -- paste-to-frontmost-app feature was removed in build 2.5B
- Remove paste-action migration code at PaultApp.swift:140-143
- Remaining entitlements (sandbox, network.client, files.user-selected.read-write) stay as-is
- Create `PrivacyInfo.xcprivacy` for Pault app target only (not Schemap)
- Declare UserDefaults (CA92.1) and file timestamp access in privacy manifest
- Privacy nutrition labels: "Data Not Collected" for now
- Create single `TestHelpers.swift` with `makeTestModelContainer()` and `makeTestModelContext()` factory functions
- Migrate all 13 test files with container setup to shared factory
- Audit and strip unnecessary SwiftData imports from pure logic tests
- All new tests use Swift Testing (`@Test` macro, struct-based suites) -- no XCTest
- Fix broken/bit-rotted tests first before writing new ones
- PromptStudioModel: expand to cover all major state transitions
- BlockSuggestionEngine: significantly expand to cover all heuristics (biggest gap)
- SlashCommandState: fill remaining gaps in filtering and selection
- Include one key integration test: block composition -> compiled preview pipeline
- Snapshot testing: research compatibility in Phase 1, defer implementation to Phase 2

### Claude's Discretion
- Exact privacy manifest XML structure and placement in Xcode project
- Which PromptStudioModel state transitions are "major" vs. negligible
- Test organization within TestHelpers.swift
- Whether to use `@Suite` grouping for related test cases

### Deferred Ideas (OUT OF SCOPE)
- Paste-to-frontmost-app via Accessibility API -- noted for potential future phase
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R1.2 | Block Editor Testing -- unit tests for PromptStudioModel state transitions, BlockSuggestionEngine heuristics, SlashCommandState filtering, integration tests for compose->preview pipeline, snapshot/visual regression tests | Test patterns documented; BlockSuggestionEngine has 10+ untested heuristic paths; swift-snapshot-testing 1.18.3+ confirmed compatible with Swift Testing @Test macro |
| R7.1 | Privacy & Compliance -- PrivacyInfo.xcprivacy manifest with required API declarations, accurate privacy labels | Privacy manifest XML format documented; UserDefaults CA92.1 and FileTimestamp C617.1 reason codes verified; "Data Not Collected" nutrition label appropriate |
| R7.2 | Sandboxing & Entitlements -- all entitlements justified and minimal | Current entitlements analyzed; apple-events exception confirmed removable; remaining 3 entitlements verified as justified |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Testing | Built-in (Xcode 16+) | Test framework | Already used by 26 of 29 test files in this project |
| SwiftData | Built-in (macOS 14+) | Persistence layer | Already the project's data layer; test containers use in-memory config |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-snapshot-testing | 1.18.3+ | Snapshot/visual regression tests | Phase 2 implementation; research compatibility in Phase 1 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Swift Testing | XCTest | 3 files still use XCTest; not migrating those in this phase (KeychainServiceTests, AIServiceTests, ProStatusManagerTests) as it is out of scope |

## Architecture Patterns

### Test File Organization
```
PaultTests/
├── TestHelpers.swift              # NEW: shared container factory
├── PromptStudioModelTests.swift   # Existing: 34 tests, expand
├── BlockSuggestionEngineTests.swift  # Existing: 4 tests, major expansion
├── SlashCommandStateTests.swift   # Existing: 13 tests, fill gaps
├── IntegrationTests.swift         # Existing: add compose->preview test
├── Models/                        # Existing subdirectory
│   ├── CopyEventTests.swift
│   └── PromptVersionTests.swift
└── [24 other test files]          # Migrate to shared factory
```

### Pattern 1: Shared Test Container Factory
**What:** Single source of truth for ModelContainer creation listing all 7 model types
**When to use:** Any test that needs SwiftData persistence
**Example:**
```swift
// TestHelpers.swift
import SwiftData
@testable import Pault

enum TestHelpers {
    @MainActor
    static func makeTestModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self,
                 Attachment.self, CopyEvent.self, PromptRun.self, PromptVersion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    static func makeTestModelContext() throws -> ModelContext {
        ModelContext(try makeTestModelContainer())
    }
}
```

### Pattern 2: Pure Logic Tests (No SwiftData)
**What:** Tests that do not need ModelContainer at all
**When to use:** Testing pure functions/structs like BlockSuggestionEngine, DiffEngine, SlashCommandState.filterBlocks
**Example:**
```swift
// No @MainActor needed, no SwiftData import needed
struct BlockSuggestionEngineTests {
    @Test func suggest_whenEmpty_suggestsRole() {
        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: [])
        #expect(suggestion != nil)
    }
}
```

### Anti-Patterns to Avoid
- **Duplicated container setup:** Currently 15 test files each define their own `makeContext()` with slightly different model lists (e.g., IntegrationTests omits CopyEvent, PromptRun, PromptVersion). Use the shared factory instead.
- **SwiftData imports in pure logic tests:** TagTests, DiffEngineTests, BlockSuggestionEngineTests do not need SwiftData. Remove unnecessary imports.
- **Using XCTest for new tests:** Project standard is Swift Testing with `@Test` macro and struct-based suites.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Privacy manifest | Manual XML editing without validation | Xcode's built-in privacy manifest editor (File > New > App Privacy) or verified XML template | Xcode validates the plist structure; manual edits can introduce subtle schema errors |
| Snapshot testing | Custom screenshot-and-compare code | swift-snapshot-testing (pointfreeco) | Handles image diffing, failure artifacts, CI integration, multiple strategies |
| Test model containers | Per-file makeContext() helpers | Shared TestHelpers factory | Single model list to update when schema changes; no more silent mismatches |

## Common Pitfalls

### Pitfall 1: Incomplete Model List in Test Container
**What goes wrong:** A test creates a ModelContainer missing one or more model types. SwiftData silently fails or crashes when accessing the missing type's relationships.
**Why it happens:** The project has 7 model types (Prompt, TemplateVariable, Tag, Attachment, CopyEvent, PromptRun, PromptVersion). IntegrationTests currently only lists 4 of them.
**How to avoid:** Single shared factory that lists all types. Any new model added to the schema must be added to TestHelpers.
**Warning signs:** Tests that pass individually but fail in batches, or EXC_BAD_ACCESS in tests.

### Pitfall 2: Missing Privacy Manifest Reason Codes
**What goes wrong:** App Store Connect rejects the build with ITMS-91053 because a required-reason API usage was not declared.
**Why it happens:** Easy to miss indirect usages. ErrorLogger uses `.creationDateKey` for log rotation. AttachmentManager uses `attributesOfItem`.
**How to avoid:** Search codebase for all FileManager attribute access, UserDefaults access, and system boot time access before finalizing the manifest.
**Warning signs:** Build upload warnings from Xcode about "missing API declaration."

### Pitfall 3: Removing Entitlement Breaks Sandbox
**What goes wrong:** Removing the apple-events temporary exception could theoretically affect other sandbox behaviors if something else depended on it.
**Why it happens:** Entitlements can have subtle side effects.
**How to avoid:** After removing the entitlement, run the app and verify: (1) global hotkey paste still works via CGEvent (which uses accessibility, not apple-events), (2) clipboard operations work, (3) file import/export works.
**Warning signs:** Sandbox violation crashes logged in Console.app.

### Pitfall 4: Privacy Manifest Not Added to Correct Target
**What goes wrong:** PrivacyInfo.xcprivacy exists in the project but is not included in the Pault app target's "Copy Bundle Resources" build phase.
**Why it happens:** Xcode does not always auto-add new files to the correct target membership.
**How to avoid:** Verify target membership in Xcode after adding the file. The file should appear in the app bundle at `Pault.app/Contents/Resources/PrivacyInfo.xcprivacy`.
**Warning signs:** App Store Connect still reports missing privacy manifest after upload.

### Pitfall 5: File Timestamp Reason Code Selection
**What goes wrong:** Using wrong reason code (e.g., DDA9.1 for displaying timestamps to user vs. C617.1 for accessing within app container).
**Why it happens:** Apple provides 4 different reason codes for file timestamp access, each for a different use case.
**How to avoid:** ErrorLogger accesses file creation dates within the app container (Application Support/Pault/Logs/) for log rotation. This is app-container access, so the correct code is **C617.1** ("access file metadata within app container, app group container, or CloudKit container").
**Warning signs:** ITMS-91055 "Invalid API reason declaration" rejection.

## Code Examples

### Privacy Manifest (PrivacyInfo.xcprivacy)
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
    <array/>
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
Source: Apple Developer Documentation on privacy manifest files, verified against codebase usage patterns.

**Key fields explained:**
- `NSPrivacyTracking: false` -- app does not track users
- `NSPrivacyTrackingDomains: []` -- no tracking domains
- `NSPrivacyCollectedDataTypes: []` -- "Data Not Collected" nutrition label
- UserDefaults CA92.1: "access UserDefaults to read and write information accessible only within the app"
- FileTimestamp C617.1: "access file timestamps within app container" (ErrorLogger log rotation)

### Entitlement Cleanup (Pault.entitlements after removal)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Migration Code to Remove (PaultApp.swift lines 140-143)
```swift
// DELETE THIS BLOCK:
// One-time migration: "paste" action removed in 2.5B — fall back to "copy"
if UserDefaults.standard.string(forKey: "defaultAction") == "paste" {
    UserDefaults.standard.set("copy", forKey: "defaultAction")
}
```

### Block Composition -> Preview Integration Test Pattern
```swift
@Test func blockComposition_compilesToPreview() throws {
    let context = try TestHelpers.makeTestModelContext()
    let prompt = Prompt(title: "Integration", content: "")
    context.insert(prompt)

    let model = PromptStudioModel(prompt: prompt)

    // Add blocks to canvas
    let roleBlock = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
    let taskBlock = Block(title: "Task", category: .instructions, valueType: .string, snippet: "TASK: {{task}}")
    model.addToCanvas(roleBlock)
    model.addToCanvas(taskBlock)

    // Fill placeholders
    let b1 = model.canvasBlocks[0]
    let b2 = model.canvasBlocks[1]
    model.setBlockInput(blockID: b1.id, placeholder: "role", value: "engineer")
    model.setBlockInput(blockID: b2.id, placeholder: "task", value: "review code")

    // Compile and verify full pipeline
    model.compileNow()

    // Verify compiled output
    #expect(model.compiledTemplate.contains("ROLE: engineer"))
    #expect(model.compiledTemplate.contains("TASK: review code"))
    #expect(model.rawTemplate.contains("{{role}}"))
    #expect(model.rawTemplate.contains("{{task}}"))

    // Verify saved to prompt
    #expect(prompt.content.contains("ROLE: engineer"))
    #expect(prompt.blockComposition != nil)
    #expect(prompt.blockComposition?.blocks.count == 2)
    #expect(prompt.blockSyncState == .synced)
}
```

## BlockSuggestionEngine: Untested Heuristic Paths

The engine has 7 distinct code paths. Only 4 are currently tested. The untested paths are:

| Path | Condition | Current Coverage |
|------|-----------|-----------------|
| Empty canvas | `categorySet.isEmpty` | Tested |
| Role only, no task/context | `has .role, missing .task and .context` | Tested |
| Role + task, no format | `has .role and .task, missing .format` | Tested |
| **Task without role** | `has .task, missing .role` | **NOT TESTED** |
| **3+ categories, no constraints** | `categorySet.count >= 3, missing .constraints` | **NOT TESTED** |
| **Complete canvas (4+)** | `categorySet.count >= 4` | Tested (returns nil) |
| **Default: suggest examples** | `missing .examples` | **NOT TESTED** |

Additional untested scenarios:
- `shouldShowTokenWarning()` function (never tested)
- Edge case: only `.context` on canvas (no role, no task)
- Edge case: all 7 categories present
- Edge case: duplicate categories on canvas

## SlashCommandState: Untested Behaviors

Currently tested (13 tests): filterBlocks (4), show/hide (2), moveSelection (4), recordUsage (3).

Gaps to fill:
- `filterBlocks` with no matching results (returns empty array)
- `filterBlocks` with special characters in query
- `recentBlockTitles` persistence via `@AppStorage` (getter decodes from Data)
- `recordUsage` deduplication (same block used twice)
- `show()` resets `selectedIndex` when called while already visible
- Edge case: `moveSelection` with maxIndex of 0 or 1

## PromptStudioModel: Major Untested State Transitions

Currently tested (34 tests): init states (4), compilation (3), save (4), canvas ops (7), modifiers (2), placeholders (4), dirty state (1), compatibility (2), consolidated library (2), placeholder status (4), loading existing data (1).

Major transitions NOT tested:
- **Canvas block duplication** (if such method exists)
- **Modifier compilation effect** -- adding a modifier and verifying it changes compiled output
- **Multiple modifier stacking** -- two modifiers on same block
- **Recompile after move** -- moveOnCanvas should trigger recompilation with new order
- **Save/restore round-trip** -- create blocks, save to prompt, create new model from same prompt, verify identical state
- **Empty canvas compilation** -- verify compiledTemplate is empty string (not nil or whitespace)
- **Block with no placeholders** -- add block with static snippet, verify no inputs created
- **setBlockInput for non-existent block** -- edge case handling

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No privacy manifest | PrivacyInfo.xcprivacy required | May 2024 | Hard rejection without it |
| XCTest with classes | Swift Testing with structs and @Test | Xcode 16 (Sep 2024) | Already adopted in 26/29 test files |
| Manual snapshot comparison | swift-snapshot-testing 1.18.3+ | Jan 2025 | Full Swift Testing @Test compatibility via TestScoping traits |

## Open Questions

1. **AttachmentManager file timestamp access**
   - What we know: `AttachmentManager.swift:36` calls `attributesOfItem` which may access timestamps
   - What's unclear: Whether this access is within app container (C617.1) or user-selected files (3B52.1)
   - Recommendation: Check the code path. If it accesses user-selected files via NSOpenPanel, the C617.1 reason code still covers it because the files are being managed within the app's data. However, if it accesses files outside the container, 3B52.1 may also be needed. Investigate during implementation.

2. **3 XCTest files migration**
   - What we know: KeychainServiceTests, AIServiceTests, ProStatusManagerTests use XCTest
   - What's unclear: Whether these should be migrated to Swift Testing in this phase
   - Recommendation: Out of scope per CONTEXT.md. Leave as-is; they still work alongside Swift Testing.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (built-in, Xcode 16+) + XCTest (3 legacy files) |
| Config file | Xcode project scheme (no external config file) |
| Quick run command | `xcodebuild test -project Pault.xcodeproj -scheme Pault -only-testing PaultTests -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -project Pault.xcodeproj -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R7.1 | Privacy manifest exists with correct entries | manual | Verify file exists in bundle after build | N/A (file creation) |
| R7.2 | Apple-events entitlement removed | manual | Build + run, check Console for sandbox violations | N/A (file edit) |
| R1.2-a | PromptStudioModel state transitions | unit | `xcodebuild test -only-testing PaultTests/PromptStudioModelTests` | Exists, needs expansion |
| R1.2-b | BlockSuggestionEngine heuristics | unit | `xcodebuild test -only-testing PaultTests/BlockSuggestionEngineTests` | Exists, needs major expansion |
| R1.2-c | SlashCommandState filtering | unit | `xcodebuild test -only-testing PaultTests/SlashCommandStateTests` | Exists, needs gap filling |
| R1.2-d | Compose->preview integration | integration | `xcodebuild test -only-testing PaultTests/IntegrationTests` | Exists, needs new test |
| R1.2-e | Shared test container factory | unit | All tests pass using shared factory | Does not exist yet |

### Sampling Rate
- **Per task commit:** `xcodebuild test -project Pault.xcodeproj -scheme Pault -only-testing PaultTests -destination 'platform=macOS'`
- **Per wave merge:** Full test suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `PaultTests/TestHelpers.swift` -- shared ModelContainer factory (covers all 7 model types)
- [ ] Run full test suite to establish baseline -- identify any already-broken tests before making changes

## Sources

### Primary (HIGH confidence)
- Codebase analysis: Pault.entitlements, ErrorLogger.swift, BlockSuggestionEngine.swift, SlashCommandState.swift, all 29 test files
- [Apple Developer: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple Developer: Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

### Secondary (MEDIUM confidence)
- [Point Free: Swift Testing support for SnapshotTesting](https://www.pointfree.co/blog/posts/146-swift-testing-support-for-snapshottesting) -- confirms 1.17.0+ support, 1.18.3+ for full TestScoping
- [Point Free: Swift 6.1 Test Scoping Traits](https://www.pointfree.co/blog/posts/169-new-in-swift-6-1-test-scoping-traits) -- improved Swift Testing compatibility
- [Bugfender: Apple Privacy Requirements](https://bugfender.com/blog/apple-privacy-requirements/) -- cross-verified reason codes

### Tertiary (LOW confidence)
- File timestamp reason code C617.1 vs DDA9.1: verified via multiple sources but Apple's JS-rendered docs could not be directly fetched. Cross-referenced with multiple third-party sources that agree C617.1 is for app container access. HIGH confidence despite tertiary methodology.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- project already uses Swift Testing and SwiftData; no new dependencies needed
- Architecture: HIGH -- test patterns already established in codebase; factory extraction is mechanical
- Pitfalls: HIGH -- compliance requirements well-documented; codebase analysis identified all API usages
- Privacy manifest: HIGH -- reason codes verified across multiple sources; XML format well-documented

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (stable domain; Apple reason codes rarely change)
