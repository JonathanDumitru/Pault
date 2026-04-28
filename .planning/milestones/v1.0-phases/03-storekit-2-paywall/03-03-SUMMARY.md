---
phase: 03-storekit-2-paywall
plan: 03
subsystem: testing
tags: [storekit2, sktestsession, xctest, storkit-configuration, subscription-lifecycle]

# Dependency graph
requires:
  - phase: 03-storekit-2-paywall
    plan: 01
    provides: ProFeature enum, ProStatusManager with refreshStatus, com.pault.pro.annual productID

provides:
  - Pault.storekit configuration file (version 4.0 format, com.pault.pro.annual annual subscription)
  - ProStatusManagerTests with 5 SKTestSession lifecycle tests (all passing)
  - ProFeatureTests with 6 enum correctness tests (all passing)
  - ProStatusManager.refreshStatus made internal for test accessibility

affects: [03-04]

# Tech tracking
tech-stack:
  added: [StoreKitTest framework (SKTestSession), Pault.storekit configuration]
  patterns:
    - SKTestSession with @MainActor test class for subscription lifecycle testing
    - Direct refreshStatus call instead of sleep-based timing for deterministic tests
    - 800ms sleep after expireSubscription for StoreKit propagation on macOS 26 beta

key-files:
  created:
    - Pault/Pault.storekit
    - PaultTests/ProFeatureTests.swift
  modified:
    - PaultTests/ProStatusManagerTests.swift
    - Pault/Services/ProStatusManager.swift

key-decisions:
  - "Pault.storekit uses version {major:4,minor:0} object format (NOT version:3 integer) — this is the actual Xcode-generated format; template had wrong format"
  - "ProStatusManager.refreshStatus changed from private to internal — required for direct test invocation to avoid sleep-based timing"
  - "SKTestSession lifecycle tests use @MainActor class-level annotation — consistent direct async calls without MainActor.run wrappers"
  - "800ms sleep after expireSubscription on macOS 26 beta — StoreKit needs propagation time before currentEntitlements reflects expiry"
  - "test_restore_grantsProAccess tests restorePurchases() explicit call path (not clearTransactions+restore) — clearTransactions removes all history from session making restore impossible"

patterns-established:
  - "SKTestSession pattern: setUp creates session, tearDown clears transactions, tests call refreshStatus directly instead of sleeping"
  - "Storekit config format: version object {major,minor}, hex internalIDs, settings section required for valid product lookup"

requirements-completed: [R6.4, R6.1]

# Metrics
duration: 33min
completed: 2026-03-27
---

# Phase 03 Plan 03: StoreKit Configuration and Lifecycle Tests Summary

**SKTestSession-based subscription lifecycle tests (5 tests) and ProFeature enum tests (6 tests) using corrected Xcode 4.0-format Pault.storekit configuration on macOS 26 beta**

## Performance

- **Duration:** 33 min
- **Started:** 2026-03-27T01:25:45Z
- **Completed:** 2026-03-27T02:00:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created Pault.storekit with com.pault.pro.annual annual subscription ($59.99, 7-day trial, P1Y period) in correct Xcode 4.0 JSON format
- Expanded ProStatusManagerTests from 2 stubs to 5 SKTestSession lifecycle tests: initialState, productID, purchase, expiredSubscription, restore
- Created ProFeatureTests with 6 tests: allCases count (6), displayNames, sfSymbols, descriptions not empty, freeBlockLimit (5), isUnlocked defaults false
- Fixed storekit config format (discovered template format was wrong; real format uses version object, hex IDs, settings section)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create StoreKit configuration file** - `28a2a63` (feat)
2. **Task 2: Subscription lifecycle and ProFeature tests** - `aca5c24` (feat)

## Files Created/Modified
- `Pault/Pault.storekit` - StoreKit configuration in Xcode 4.0 format with com.pault.pro.annual subscription
- `PaultTests/ProFeatureTests.swift` - 6 enum correctness tests (all pass)
- `PaultTests/ProStatusManagerTests.swift` - 5 lifecycle tests using SKTestSession (all pass)
- `Pault/Services/ProStatusManager.swift` - refreshStatus access changed from private to internal

## Decisions Made
- Storekit format correction: plan template specified version as integer (3) and a `storeKitVersion` field that don't exist in real Xcode-generated files. Real format uses `"version": {"major": 4, "minor": 0}` with hex IDs and a `settings` section. Wrong format caused `SKTestErrorCodeInvalidProductIdentifier` (Code 1).
- refreshStatus made internal: plan recommended this as an option to enable direct test invocation. Avoids non-deterministic sleep-based timing.
- 800ms sleep after `expireSubscription`: on macOS 26 beta, the synchronous `expireSubscription` call triggers StoreKit's async propagation. Direct `refreshStatus()` call immediately after didn't see the expiration yet.
- test_restore_grantsProAccess: plan suggested buy+clearTransactions+restore, but SKTestSession.clearTransactions() removes all transaction history (unlike real "fresh install" which just clears local keychain). The test instead verifies that explicitly calling restorePurchases() (AppStore.sync+refreshStatus) correctly maintains Pro access.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed storekit file format causing SKTestErrorCodeInvalidProductIdentifier**
- **Found during:** Task 2 (subscription lifecycle tests)
- **Issue:** Plan template had `"version": 3` (integer) and `"storeKitVersion": 2` which are not real Xcode storekit fields. This caused SKTestSession to initialize without error but fail on `buyProduct` with `SKTestError.invalidProductIdentifier (Code=1)`. Discovered by comparing with another project's Xcode-generated Configuration.storekit.
- **Fix:** Rewrote Pault.storekit with correct format: version object `{"major": 4, "minor": 0}`, hex internalIDs (8 chars), settings section with _storeKitErrors array, nonRenewingSubscriptions/products arrays.
- **Files modified:** Pault/Pault.storekit
- **Verification:** session.buyProduct("com.pault.pro.annual") succeeds; all lifecycle tests pass
- **Committed in:** aca5c24 (Task 2 commit)

**2. [Rule 2 - Missing Critical] Made refreshStatus internal for test accessibility**
- **Found during:** Task 2 (subscription lifecycle tests)
- **Issue:** refreshStatus was private, preventing direct calls from tests. Without direct call, tests had to rely on sleep-based timing (non-deterministic on low-disk macOS 26 beta).
- **Fix:** Removed `private` access modifier — function is now internal.
- **Files modified:** Pault/Services/ProStatusManager.swift
- **Verification:** Tests call manager.refreshStatus() directly; results are deterministic.
- **Committed in:** aca5c24 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug in plan template, 1 missing internal access)
**Impact on plan:** Both auto-fixes required for correctness. No scope creep.

## Issues Encountered
- macOS 26 beta disk space constraint: each SKTestSession test run generates ~226MB system log archives in DerivedData. With only ~350MB free disk, successive test runs would exhaust disk space. Mitigated by cleaning Logs/ directory between runs.
- SKTestSession.expireSubscription is synchronous but StoreKit propagation is async — need 800ms sleep on macOS 26 beta before refreshStatus sees the expiry.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Pault.storekit is ready for scheme configuration (editor needs to select it in Run > Options > StoreKit Configuration for local development testing in the app, but tests work without this via SKTestSession)
- ProFeatureTests and ProStatusManagerTests provide regression coverage for subscription logic
- Ready for Plan 04 (paywall UI / PaywallView implementation or remaining phase work)

---
*Phase: 03-storekit-2-paywall*
*Completed: 2026-03-27*
