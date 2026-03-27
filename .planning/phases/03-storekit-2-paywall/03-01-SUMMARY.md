---
phase: 03-storekit-2-paywall
plan: 01
subsystem: payments
tags: [storekit, pro, feature-gating, paywall, storekit2]

# Dependency graph
requires:
  - phase: 02-block-editor-polish
    provides: CompositionCanvasView with addToCanvas/insertOnCanvas insertion paths
provides:
  - ProFeature enum as single source of truth for all feature gating
  - Hardened ProStatusManager with explicit VerificationResult handling and os.Logger
  - Centralized ProFeature.isUnlocked() gate pattern used by all views
  - 5-block limit gate on all canvas insertion paths for free users
affects:
  - 03-02 (PaywallView UI — needs ProFeature enum for feature metadata)
  - 03-03 (StoreKit purchase flow — needs hardened ProStatusManager)
  - 03-04 (Testing — needs centralized gate for test scenarios)

# Tech tracking
tech-stack:
  added: [os.Logger for StoreKit events]
  patterns: [ProFeature.isUnlocked(.case) gate pattern, paywallFeature state + dynamic PaywallView metadata]

key-files:
  created:
    - Pault/Models/ProFeature.swift
  modified:
    - Pault/Services/ProStatusManager.swift
    - Pault/PromptDetailView.swift
    - Pault/SidebarView.swift
    - Pault/ContentView.swift
    - Pault/AnalyticsView.swift
    - Pault/InspectorView.swift
    - Pault/PromptLaunchpadView.swift
    - Pault/BlockEditor/Views/CompositionCanvasView.swift

key-decisions:
  - "ProFeature.isUnlocked delegates to ProStatusManager.shared.isProUnlocked — single delegation point, views never call manager directly"
  - "5-block limit gated on ALL canvas insertion paths (slash palette, empty canvas drop, block list drop, per-row positional drop)"
  - "PromptDetailView uses paywallFeature state + dynamic PaywallView metadata instead of hardcoded feature strings"
  - "activateABMode (A/B testing) mapped to .versioning feature case, not .analytics"
  - "Run button in PromptDetailView toolbar maps to .apiRunner feature case"

patterns-established:
  - "Feature gate pattern: guard ProFeature.isUnlocked(.case) else { paywallFeature = .case; showPaywall = true; return }"
  - "PaywallView presented with ProFeature metadata: displayName, description, sfSymbol — no hardcoded strings"
  - "StoreKit VerificationResult: always explicit switch, never try? payloadValue — .verified proceeds, .unverified logs via Self.logger"

requirements-completed: [R6.1, R6.3]

# Metrics
duration: 25min
completed: 2026-03-27
---

# Phase 03 Plan 01: ProFeature Centralized Gating Summary

**ProFeature enum with 6 cases as single source of truth; hardened StoreKit transaction verification; all 10+ scattered isProUnlocked checks centralized; 5-block limit gate on all canvas insertion paths**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-03-27T01:17:41Z
- **Completed:** 2026-03-27T01:43:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Created ProFeature enum (6 cases) with displayName/description/sfSymbol metadata and static isUnlocked() gate
- Hardened ProStatusManager: single annual product ID, explicit VerificationResult switch in all 3 sites (purchase, refreshStatus, listenForTransactions), os.Logger structured logging
- Replaced all 10+ scattered ProStatusManager.shared.isProUnlocked calls in 7 view files with ProFeature.isUnlocked(.specificCase)
- Added 5-block limit gate on all 4 canvas insertion paths in CompositionCanvasView with dynamic paywall presentation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ProFeature enum and harden ProStatusManager** - `158ea13` (feat)
2. **Task 2: Replace scattered isProUnlocked checks and add block limit gate** - `a36fa03` (feat)

## Files Created/Modified
- `Pault/Models/ProFeature.swift` - New: ProFeature enum with 6 cases, metadata properties, isUnlocked() gate, freeBlockLimit = 5
- `Pault/Services/ProStatusManager.swift` - Hardened: single proProductID, explicit VerificationResult switches, os.Logger
- `Pault/ContentView.swift` - Analytics button gate: ProFeature.isUnlocked(.analytics)
- `Pault/SidebarView.swift` - Collections section + New Collection button: ProFeature.isUnlocked(.smartCollections)
- `Pault/PromptDetailView.swift` - AI Assist (.aiAssist), Run (.apiRunner), A/B Mode (.versioning) gates; paywallFeature state; dynamic PaywallView metadata
- `Pault/InspectorView.swift` - Stats section: ProFeature.isUnlocked(.analytics)
- `Pault/AnalyticsView.swift` - Full view gate: ProFeature.isUnlocked(.analytics)
- `Pault/PromptLaunchpadView.swift` - AI Generate features: ProFeature.isUnlocked(.aiAssist)
- `Pault/BlockEditor/Views/CompositionCanvasView.swift` - 5-block limit gate on 4 insertion paths + paywall sheet

## Decisions Made
- ProFeature.isUnlocked delegates entirely to ProStatusManager — views have zero direct dependency on manager
- A/B testing feature mapped to .versioning (not .analytics) based on actual code semantics (version branching)
- Run button mapped to .apiRunner to match the feature's actual capability
- All 4 canvas insertion paths gated (not just slash palette) so drag-and-drop also respects the block limit
- paywallFeature state pattern added to PromptDetailView so a single .sheet presenter serves all feature gates

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added paywallFeature state to PromptDetailView for dynamic PaywallView metadata**
- **Found during:** Task 2 (replacing scattered checks in PromptDetailView)
- **Issue:** PromptDetailView had multiple feature gates (aiAssist, apiRunner, versioning) all using a single `showPaywall = true` with a hardcoded "API Runner" PaywallView — users triggered the wrong paywall context for some features
- **Fix:** Added `@State private var paywallFeature: ProFeature = .aiAssist`, each guard sets paywallFeature before showPaywall = true, PaywallView uses paywallFeature metadata
- **Files modified:** Pault/PromptDetailView.swift
- **Verification:** Project compiles cleanly
- **Committed in:** a36fa03 (Task 2 commit)

**2. [Rule 2 - Missing Critical] Gated all 4 canvas insertion paths, not just slash palette**
- **Found during:** Task 2 (block limit gate implementation in CompositionCanvasView)
- **Issue:** Plan only specified the slash palette onInsert closure, but drag-and-drop (empty canvas drop, block list drop, per-row positional drop) bypassed the block limit
- **Fix:** Added ProFeature.isUnlocked(.unlimitedBlocks) guard to all 3 dropDestination handlers in addition to the slash palette
- **Files modified:** Pault/BlockEditor/Views/CompositionCanvasView.swift
- **Verification:** Project compiles cleanly; all insertion paths check limit before addToCanvas/insertOnCanvas
- **Committed in:** a36fa03 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 2 - missing critical)
**Impact on plan:** Both fixes necessary for correctness — the paywall showed wrong feature context, and drag-and-drop would bypass the block limit gate. No scope creep.

## Issues Encountered
- Previous agent had created ProFeature.swift and refactored ProStatusManager.swift without committing. Files were verified correct and committed as Task 1 without re-implementation. Xcode project uses PBXFileSystemSynchronizedRootGroup so the new Models/ directory was auto-discovered without pbxproj edits.

## Next Phase Readiness
- ProFeature enum ready for PaywallView UI to use feature metadata (displayName, description, sfSymbol)
- ProStatusManager hardened and ready for full StoreKit purchase flow implementation
- All gate points established — adding new gates anywhere just requires ProFeature.isUnlocked(.case)
- Block limit tested at compile time; runtime behavior needs manual verification during paywall UI phase

---
*Phase: 03-storekit-2-paywall*
*Completed: 2026-03-27*
