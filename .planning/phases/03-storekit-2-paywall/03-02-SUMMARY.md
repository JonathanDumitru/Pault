---
phase: 03-storekit-2-paywall
plan: 02
subsystem: payments
tags: [storekit, paywall, subscription, apple-compliance, swiftui]

# Dependency graph
requires:
  - phase: 03-01
    provides: ProFeature enum with allCases, displayName, sfSymbol; ProStatusManager with single annual product and introductoryOffer-capable Product
provides:
  - Fully compliant PaywallView with dynamic CTA, comparison grid, and Apple Schedule 2 disclosures
affects: [app-store-review, paywall-callers, 03-03, 03-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Dynamic CTA text computed from Product.subscription.isEligibleForIntroOffer + introductoryOffer.paymentMode at load time
    - Apple Schedule 2 auto-renewal disclosure with dynamic displayPrice injected at runtime
    - ProFeature.allCases drives feature list — paywall stays in sync with feature enum automatically

key-files:
  created: []
  modified:
    - Pault/PaywallView.swift

key-decisions:
  - "PaywallView uses @State private var ctaText + isEligibleForTrial computed in .task after loadProducts() — not computed inline to avoid async in ViewBuilder"
  - "paymentMode switch uses default: (not @unknown default:) to satisfy Swift exhaustiveness — StoreKit paymentMode enum is non-frozen"
  - "Free vs Pro comparison grid is hardcoded (not enum-driven) — free-tier features are not modeled in ProFeature (Pro-only enum)"
  - "disclosureSection conditionally shows dynamic displayPrice only when product is loaded — falls back to generic text if products unavailable"

patterns-established:
  - "Auto-renewal disclosure: display dynamic price from product.displayPrice, not hardcoded values"
  - "Legal links: use SwiftUI Link() with .font(.caption).foregroundStyle(.secondary) styling"

requirements-completed: [R6.2]

# Metrics
duration: 15min
completed: 2026-03-26
---

# Phase 3 Plan 02: PaywallView Compliance Rebuild Summary

**Apple-compliant PaywallView with dynamic StoreKit CTA text, Free vs Pro comparison grid, Schedule 2 auto-renewal disclosure, and Privacy/Terms links**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-26T21:15:00Z
- **Completed:** 2026-03-26T21:30:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Rebuilt PaywallView from scratch while preserving `(featureName:featureDescription:featureIcon:)` init signature — all call sites compile unchanged
- Dynamic CTA text derived from `product.subscription?.isEligibleForIntroOffer` and `introductoryOffer.paymentMode` — free trial, pay-as-you-go, or standard subscribe
- ProFeature.allCases drives contextual Pro features list — paywall automatically stays in sync with the feature enum
- Apple Schedule 2 Section 3.8(b) auto-renewal disclosure with runtime-injected `product.displayPrice/year`
- Privacy Policy (`pault.app/privacy`) and Terms of Service (`pault.app/terms`) as SwiftUI Link views
- Segmented Picker and `selectedProductID` state removed (annual-only product model)
- Free vs Pro 10-row comparison grid with gradient checkmarks for Pro column

## Task Commits

1. **Task 1: Rebuild PaywallView with compliance and dynamic content** - `cca5458` (feat)

**Plan metadata:** (to be added after final commit)

## Files Created/Modified
- `Pault/PaywallView.swift` - Full rewrite: dynamic CTA, compliance grid, disclosure, legal links, ScrollView layout

## Decisions Made
- `paymentMode` switch uses `default:` instead of `@unknown default:` — Swift compiler requires exhaustive switch and `@unknown default:` triggers an error indicating unhandled known cases exist
- CTA text is computed in `loadProducts()` async function (not a computed property) to use `await subscription.isEligibleForIntroOffer`
- Free vs Pro grid hardcoded rows (not enum-driven) since free-tier features like "Prompt CRUD" and "Templates & Tags" aren't modeled in `ProFeature` (which is Pro-only)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Swift exhaustiveness error on paymentMode switch**
- **Found during:** Task 1 (build verification)
- **Issue:** `@unknown default:` in paymentMode switch caused compiler error "switch must be exhaustive" — StoreKit PaymentMode is not an open enum that warrants `@unknown`
- **Fix:** Changed `@unknown default:` to `default:` to satisfy Swift exhaustiveness requirement
- **Files modified:** Pault/PaywallView.swift
- **Verification:** Build succeeded with 0 errors
- **Committed in:** cca5458 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor fix required for compilation. No scope creep.

## Issues Encountered
- StoreKit `Product.SubscriptionOffer.PaymentMode` switch requires `default:` not `@unknown default:` — fixed inline during build verification

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PaywallView fully compliant and ready for App Store review
- All call sites using `(featureName:featureDescription:featureIcon:)` unchanged
- Dynamic CTA functional — will show real offer text when StoreKit sandbox/production returns introductory offer data
- Ready for Plan 03 (paywall trigger wiring) and Plan 04 (entitlement verification)

## Self-Check: PASSED

- Pault/PaywallView.swift: FOUND
- .planning/phases/03-storekit-2-paywall/03-02-SUMMARY.md: FOUND
- Commit cca5458: FOUND in git log

---
*Phase: 03-storekit-2-paywall*
*Completed: 2026-03-26*
