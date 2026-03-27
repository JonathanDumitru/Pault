# Phase 3: StoreKit 2 Paywall - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Harden the existing StoreKit 2 implementation for App Store compliance. Users can purchase, restore, and manage an annual Pro subscription with a compliant, polished paywall experience. Feature gating uses a centralized ProFeature enum with graceful upgrade prompts. No new Pro features are built in this phase — only the subscription infrastructure and gating.

</domain>

<decisions>
## Implementation Decisions

### Subscription tiers & pricing
- Annual-only subscription at $59.99/yr — remove monthly product ID (`com.pault.pro.monthly`)
- Single product ID: `com.pault.pro.annual`
- 7-day free trial configured as introductory offer in App Store Connect
- CTA button text pulled dynamically from `product.subscription?.introductoryOffer` — no hardcoded trial language
- Price locked at $59.99/yr for launch (StoreKit displays dynamically regardless)

### Paywall presentation
- Sheet overlay (.sheet modal) — current behavior, keep it
- Contextual header: highlight the triggering feature (name + icon) at top
- Below header: full Pro features bullet list showing everything Pro unlocks
- Feature comparison grid: Free vs Pro checkmark matrix
- Dynamic offer text from StoreKit (trial eligibility, price, renewal terms)
- Legal links: Privacy Policy and Terms of Service as web URLs (pault.app/privacy, pault.app/terms) — must be hosted before submission
- Apple-required subscription terms text (auto-renewal info, cancellation instructions)
- Restore Purchases button remains (current behavior)

### Feature gating behavior
- Centralized `ProFeature` enum with cases: `aiAssist`, `versioning`, `analytics`, `apiRunner`, `smartCollections`, `unlimitedBlocks`
- Each case carries paywall metadata: `displayName`, `description`, `sfSymbol` — self-describing for PaywallView
- Visible-but-locked pattern: Pro features appear in UI with ProBadge, tappable, trigger paywall on tap
- Free tier block limit: 5 blocks per prompt composition
- Soft block on 6th block: slash palette / library shows paywall prompt instead of adding block; existing 5 blocks remain fully functional
- Replace all ~10 scattered `ProStatusManager.shared.isProUnlocked` checks with `ProFeature.isUnlocked(_:)` or equivalent centralized check

### Transaction handling
- Explicit `VerificationResult` handling: switch on `.verified` vs `.unverified` — no `try?` swallowing
- Unverified transactions: deny Pro access + log failure for diagnostics
- Purchase errors: inline error text below purchase button in paywall (current behavior, keep it)
- Subscription expiry: immediate downgrade — Pro features lock as soon as `Transaction.currentEntitlements` no longer includes the product
- Expiry UI: subtle — remove Pro badges, lock features silently. No aggressive popup. Users discover via normal gating (paywall on Pro feature tap)
- Transaction listener continues monitoring `Transaction.updates` for real-time status changes
- Restore purchases: `AppStore.sync()` + refresh status (current behavior, keep it)

### Claude's Discretion
- Exact StoreKit Configuration file (.storekit) structure for testing
- Internal caching strategy for subscription status (how often to re-check `currentEntitlements`)
- Error log format and storage for unverified transactions
- Exact paywall layout spacing, typography, and animation
- Test structure for subscription lifecycle tests

</decisions>

<specifics>
## Specific Ideas

- Remove the segmented Picker from PaywallView (was for monthly/annual selection) — with annual-only, just show the single plan with price
- ProFeature enum should be the single source of truth for what's gated — if a feature isn't in the enum, it's free
- Legal URLs (pault.app/privacy, pault.app/terms) need to be live web pages before App Store submission — can be simple static pages

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ProStatusManager.swift` (74 lines): Working purchase/restore/listener flow — needs verification fix and monthly product removal
- `PaywallView.swift` (137 lines): Functional paywall with header, product picker, CTA, restore — needs content expansion and dynamic text
- `ProBadge.swift`: Reusable badge component for Pro feature indicators — keep as-is
- `ProStatusManagerTests.swift` (19 lines): Basic tests — needs significant expansion for lifecycle testing

### Established Patterns
- `@Observable` + `@MainActor` for ProStatusManager (matches app's observation pattern)
- `.sheet(isPresented:)` for paywall presentation (used in PromptDetailView)
- `ProStatusManager.shared` singleton pattern (refactor checks to go through ProFeature enum)

### Integration Points
- `PromptDetailView.swift`: 3 paywall trigger points (AI Assist, versioning, analytics) — refactor to use ProFeature enum
- `SidebarView.swift`: 2 checks for smart collections and analytics sections
- `ContentView.swift`: 1 check for Pro status
- `AnalyticsView.swift`: 1 check + ProBadge usage
- `InspectorView.swift`: 1 check for version history
- `PromptLaunchpadView.swift`: 2 checks for hotkey launcher Pro features
- `ModeSwitchDialogView.swift`: 1 ProBadge usage
- Block editor canvas: needs new integration point for 5-block limit gate

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-storekit-2-paywall*
*Context gathered: 2026-03-26*
