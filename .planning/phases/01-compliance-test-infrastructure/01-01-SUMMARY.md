---
phase: 01-compliance-test-infrastructure
plan: 01
subsystem: infra
tags: [privacy-manifest, entitlements, sandbox, xcprivacy, app-store-compliance]

# Dependency graph
requires: []
provides:
  - "PrivacyInfo.xcprivacy with UserDefaults CA92.1 and FileTimestamp C617.1 declarations"
  - "Cleaned entitlements (3 justified entries, no stale exceptions)"
  - "PaultApp.swift without stale paste migration code"
affects: [07-app-store-readiness]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Privacy manifest declares all required-reason APIs per Apple guidelines"
    - "Entitlements kept minimal -- only sandbox, network.client, files.user-selected.read-write"

key-files:
  created:
    - Pault/PrivacyInfo.xcprivacy
  modified:
    - Pault/Pault.entitlements
    - Pault/PaultApp.swift

key-decisions:
  - "C617.1 reason code sufficient for FileTimestamp API (app-container file access only)"
  - "Removed apple-events temporary exception -- CGEvent-based paste does not require it"
  - "Removed stale paste-action migration code from PaultApp.swift init()"

patterns-established:
  - "Privacy manifest pattern: declare required-reason APIs with specific reason codes"

requirements-completed: [R7.1, R7.2]

# Metrics
duration: 8min
completed: 2026-03-14
---

# Phase 1 Plan 1: Privacy Manifest and Entitlement Cleanup Summary

**PrivacyInfo.xcprivacy with UserDefaults/FileTimestamp declarations, entitlements reduced to 3 justified entries, stale migration code removed**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-14
- **Completed:** 2026-03-14
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 3

## Accomplishments
- Created PrivacyInfo.xcprivacy declaring UserDefaults (CA92.1) and FileTimestamp (C617.1) required-reason APIs
- Removed stale apple-events temporary-exception entitlement, leaving only 3 justified entries
- Removed obsolete paste-action migration code from PaultApp.swift
- User verified sandbox compatibility -- hotkey paste, clipboard, and file access all work without violations

## Task Commits

Each task was committed atomically:

1. **Task 1: Create privacy manifest and clean entitlements** - `a7981f5` (feat)
2. **Task 2: Verify sandbox compatibility** - checkpoint:human-verify (approved by user, no commit needed)

## Files Created/Modified
- `Pault/PrivacyInfo.xcprivacy` - Privacy manifest declaring required-reason APIs (UserDefaults CA92.1, FileTimestamp C617.1)
- `Pault/Pault.entitlements` - Cleaned to 3 justified entries (sandbox, network.client, files.user-selected.read-write)
- `Pault/PaultApp.swift` - Removed stale paste-action migration block from init()

## Decisions Made
- C617.1 reason code is sufficient for FileTimestamp API usage (only accessing files within app container for log rotation)
- Apple-events temporary exception safely removed since paste functionality uses CGEvent, not Apple Events
- Paste migration code removed as it was a one-time migration from v2.5B that has long since served its purpose

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Privacy manifest and entitlements are App Store compliant
- Ready for Phase 1 Plan 2 (test infrastructure) and subsequent phases
- No blockers identified

## Self-Check: PASSED

- FOUND: Pault/PrivacyInfo.xcprivacy
- FOUND: Pault/Pault.entitlements
- FOUND: Pault/PaultApp.swift
- FOUND: commit a7981f5

---
*Phase: 01-compliance-test-infrastructure*
*Completed: 2026-03-14*
