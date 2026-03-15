# Project Research Summary

**Project:** Pault -- Local Prompt Library for macOS
**Domain:** macOS-native productivity app with subscription monetization
**Researched:** 2026-03-14
**Confidence:** MEDIUM-HIGH

## Executive Summary

Pault is a macOS-native prompt library app that is feature-rich (block editor, global hotkey launcher, menu bar, template variables) and nearing App Store readiness. The core product experience is solid, but four critical gaps block submission: (1) a missing PrivacyInfo.xcprivacy manifest that will cause automatic rejection, (2) StoreKit 2 implementation deficiencies around transaction verification and subscription terms disclosure, (3) an unused Apple Events temporary-exception entitlement that will trigger reviewer scrutiny, and (4) insufficient test coverage for the most complex component (PromptStudioModel at 948 lines). The competitive landscape validates the approach -- no competitor occupies the local-first macOS-native prompt management space -- but also warns that AI platforms themselves (ChatGPT custom GPTs, Claude Projects) are the real long-term threat, making cross-tool portability the strategic moat.

The recommended approach is to ship v1.0 with a generous free tier and defer AI-powered Pro features to a fast-follow update. This dramatically simplifies the initial submission: no AI data collection disclosures, "Data Not Collected" privacy label, no need for the `network.client` entitlement justification, and a cleaner review surface. StoreKit 2 infrastructure should still ship in v1.0 so Pro gating is ready, but the paywall needs legal compliance fixes (dynamic trial text, subscription terms, Privacy Policy and Terms of Service links) before it faces App Store review.

The highest risks are: App Store rejection for missing privacy manifest or hardcoded trial language (both easily fixable with known patterns), SwiftData schema migration failures corrupting user data post-launch (preventable by establishing versioned schemas now, before any user has data), and the planned CGEvent paste simulation feature complicating review (defer to post-launch). Pricing should be set at $4.99-7.99/month to avoid competing against full AI subscriptions at the $9.99+ tier.

## Key Findings

### Recommended Stack

The app is built on SwiftUI + SwiftData targeting macOS 15+, which is correct and requires no changes. The testing infrastructure needs one addition: PointFree's swift-snapshot-testing (v1.17+) for visual regression testing of key views. The existing test suite (29 files, 26 using Swift Testing) is modern and well-structured but has coverage gaps.

**Core technologies (no changes needed):**
- Swift Testing (built-in): Primary test framework -- already adopted in 26/29 files
- XCUITest (built-in): UI smoke tests -- currently placeholder, needs real tests
- swift-snapshot-testing (1.17+): Visual regression for key views -- new dependency to add
- Instruments (built-in): Pre-launch performance profiling -- manual but essential

**Testing-specific tooling NOT recommended:** ViewInspector (fragile on macOS, breaks between OS versions), Quick/Nimble (legacy, Swift Testing is better), exhaustive XCUITest suites (slow, flaky, keep to 5-10 tests).

### Expected Features

**Must have (table stakes for App Store submission):**
- PrivacyInfo.xcprivacy manifest with UserDefaults declaration (CA92.1)
- Proper StoreKit 2 transaction verification (replace `try?` with explicit verified/unverified switch)
- Dynamic introductory offer text (remove hardcoded "7-Day Free Trial")
- Subscription terms disclosure (price, auto-renewal, cancellation info near purchase button)
- Privacy Policy and Terms of Service links in paywall and preferences
- Restore Purchases mechanism (already implemented)
- "Manage Subscription" button in preferences
- StoreKit Configuration file for development testing
- Import/Export (JSON at minimum) -- competitors all offer this, Pault lacks it
- Unit tests for all @Model cascade deletes
- XCUITest golden path: launch, create prompt, edit, copy, verify clipboard

**Should have (differentiators):**
- Centralized ProFeature enum for feature gating (replace scattered `isProUnlocked` checks)
- Subscription status checking via `Product.SubscriptionInfo.Status` (handle grace periods)
- Snapshot tests for revenue-critical views (PaywallView, ProBadge)
- Parameterized template engine tests
- Accessibility audit and fixes
- Performance baselines (launch < 2s, sidebar smooth with 500+ prompts)

**Defer (v2+):**
- AI Assist, API Runner, Prompt Chains (ship as fast-follow Pro update)
- CGEvent paste simulation (Accessibility permission adds review friction)
- Lifetime purchase option
- Family Sharing configuration
- Promotional/win-back offers
- Community sharing features

### Architecture Approach

The test architecture should follow a four-layer pyramid: bulk unit tests (200+) for models and services, integration tests (20-30) for service + model interactions, snapshot tests (15-20) for key views, and minimal XCUITests (5-10) for smoke testing. The critical architectural improvement is extracting a shared TestModelContainer factory that registers all 10 @Model types, replacing the duplicated container creation across 5+ test files. GlobalHotkeyManager needs a protocol extraction to enable testing without Carbon API side effects.

**Major components requiring test focus:**
1. PromptStudioModel (948 lines) -- block editor state machine; highest-risk, needs exhaustive edge case coverage
2. SwiftData @Model types (10) -- cascade deletes, relationship integrity, Codable round-trips
3. ProStatusManager + PaywallView -- revenue path; must handle verification, grace periods, and display legal compliance text
4. TemplateEngine -- string interpolation with many edge cases; ideal for parameterized tests
5. GlobalHotkeyManager -- protocol extraction needed for testability

### Critical Pitfalls

Cross-referencing all research files, these are the highest-risk items:

1. **SwiftData migration not tested before first release** -- Once users have data, schema changes become dangerous. Establish `VersionedSchema` conformances NOW, save a v1.0 `.store` fixture, and write migration tests before any post-launch model changes. This is the only pitfall that cannot be fixed after the fact.

2. **App Store rejection for hardcoded trial language** -- PaywallView says "Start 7-Day Free Trial" but does not check `product.subscription?.introductoryOffer` or `isEligibleForIntroOffer`. Users who already used their trial see misleading text. This is a well-known rejection reason.

3. **Missing PrivacyInfo.xcprivacy** -- Automatic rejection since Spring 2024. The fix is straightforward (declare UserDefaults CA92.1) but must not be forgotten.

4. **Unused Apple Events temporary-exception entitlement** -- The entitlement exists in Pault.entitlements but no code uses it. Reviewers will ask pointed questions. Remove it before submission.

5. **Transaction verification swallows failures** -- `try? result.payloadValue` silently ignores unverified transactions. On macOS, where users have filesystem access, this is a real receipt-tampering vector. Switch to explicit `.verified`/`.unverified` handling.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Compliance and Test Infrastructure
**Rationale:** These are hard blockers. Without them, the app cannot be submitted or safely maintained. Must come first because everything else builds on a clean compliance and testing foundation.
**Delivers:** Submission-ready compliance posture, shared test infrastructure, CI-ready test suite
**Addresses:**
- Create PrivacyInfo.xcprivacy
- Remove unused Apple Events temporary-exception entitlement
- Publish Privacy Policy and Terms of Service URLs
- Create shared TestModelContainer factory
- Add PromptStudioModel exhaustive edge case tests
- Add SwiftData cascade delete tests
- Establish VersionedSchema for v1.0 schema
- Add swift-snapshot-testing dependency
- XCUITest golden path (launch, create, edit, copy)
- Accessibility audit with Accessibility Inspector
**Avoids:** Pitfalls 1, 3, 4 (migration, privacy manifest, entitlements)

### Phase 2: StoreKit 2 Hardening
**Rationale:** Revenue infrastructure must be correct before any Pro features ship. The existing StoreKit 2 code has the right shape but needs critical fixes for App Store compliance.
**Delivers:** Bulletproof purchase flow, compliant paywall, testable monetization
**Addresses:**
- Fix transaction verification (explicit verified/unverified switch)
- Dynamic introductory offer text (query eligibility, remove hardcoded trial)
- Add subscription terms disclosure below CTA
- Add Privacy Policy and Terms of Service links to paywall
- Subscription status via `Product.SubscriptionInfo.Status` (grace periods)
- Create StoreKit Configuration file (Pault.storekit)
- Centralized ProFeature enum for feature gating
- "Manage Subscription" button in preferences
- ProStatusManager and PaywallView snapshot tests
**Avoids:** Pitfalls 2 and 5 (hardcoded trial, transaction verification)
**Research flag:** Standard patterns, well-documented by Apple. No additional research needed.

### Phase 3: Import/Export and Feature Completion
**Rationale:** Import/Export is table stakes that every competitor offers and Pault lacks. The block editor at ~95% must hit 100%. All incomplete features must be hidden or finished before review.
**Delivers:** Data portability, complete core product, no unfinished UI
**Addresses:**
- JSON import/export with round-trip tests
- Block editor remaining 5% completion
- Hide incomplete Pro features behind feature flags
- Performance profiling (Instruments: Time Profiler, Allocations, Leaks)
- Performance test: sidebar with 500+ prompts
**Avoids:** App Store rejection for incomplete features (Guideline 2.1)

### Phase 4: App Store Submission
**Rationale:** With compliance, monetization, and feature completion done, this phase is pure submission mechanics and polish.
**Delivers:** App live on the Mac App Store
**Addresses:**
- Capture screenshots at Mac Retina resolutions (3456x2234 or 2880x1800)
- Complete App Store Connect metadata (age rating, copyright, URLs)
- Set version 1.0, build 1
- Archive and upload via Xcode
- Review notes explaining Carbon hotkey usage and how to test IAP
- Coordinate launch marketing (Product Hunt, Twitter/X, Hacker News)
**Avoids:** Metadata rejection (faster to fix but wastes review cycles)

### Phase 5: Pro Features (Post-Launch Fast-Follow)
**Rationale:** Ship AI Assist and API Runner together so the Pro upgrade pitch is compelling. These share AIService infrastructure and together transform Pault from prompt storage to prompt execution. Defer to post-launch to simplify initial review surface.
**Delivers:** Compelling Pro tier, recurring revenue, updated privacy labels for AI data collection
**Addresses:**
- AI Assist (prompt improvement, quality scoring)
- API Runner (direct LLM execution with streaming)
- Updated privacy labels ("Other User Content" for prompts sent to AI)
- Usage Analytics (which prompts are used most)
**Research flag:** Needs phase research on current Claude/OpenAI API pricing, streaming patterns for macOS, error handling for API failures.

### Phase 6: Advanced Pro Features
**Rationale:** These features deepen engagement for existing Pro users. Prompt Chains depends on a stable API Runner. Shortcuts integration opens automation workflows.
**Delivers:** Power-user features that increase retention and reduce churn
**Addresses:**
- Prompt Versioning (history, diff, restore)
- Prompt Chains (depends on API Runner)
- Apple Shortcuts integration
- Smart Collections (dynamic filters)
- CGEvent paste simulation (with proper Accessibility permission flow)
**Research flag:** Needs phase research on Shortcuts integration patterns, CGEvent + App Sandbox interaction details, and chain execution architecture.

### Phase Ordering Rationale

- Compliance before monetization: Cannot submit without privacy manifest and clean entitlements
- Monetization before features: Cannot gate features that are not gated
- Import/Export before Pro: Reduces lock-in fear, which is a barrier to adoption and positive reviews
- Free-only v1.0 then Pro fast-follow: Simplifies privacy labels ("Data Not Collected"), avoids AI data disclosure complexity, gives cleaner first review
- AI features together: AI Assist + API Runner share infrastructure and make a compelling joint Pro pitch
- Chains last: Highest complexity, lowest launch urgency, depends on stable API Runner

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5 (Pro Features):** AI API pricing, streaming best practices for macOS SwiftUI, error/retry patterns for network calls
- **Phase 6 (Advanced Pro):** Shortcuts integration API surface, CGEvent paste simulation + Accessibility permission UX, chain execution state machine design

Phases with standard patterns (skip research-phase):
- **Phase 1 (Compliance):** PrivacyInfo.xcprivacy format is well-documented; entitlement cleanup is straightforward
- **Phase 2 (StoreKit 2):** Apple provides extensive documentation; rejection patterns are well-known
- **Phase 4 (Submission):** Standard Xcode archive/upload workflow

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Built-in Apple frameworks + one well-known third-party testing library. No exotic dependencies |
| Features (table stakes) | HIGH | Based on Apple Review Guidelines, direct codebase audit, and known rejection patterns |
| Features (market/pricing) | MEDIUM | Competitor data from training data (early 2025); pricing benchmarks may have shifted |
| Architecture | HIGH | Testing patterns are well-established; codebase already follows most recommended patterns |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls are well-documented; phase-specific warnings based on training data patterns |
| App Store submission | HIGH | Guidelines read directly; entitlements audited against codebase |
| Competitive landscape | MEDIUM | Based on training data through early 2025; new competitors may have emerged |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Competitor pricing verification:** All competitor pricing data is from early 2025 training data. Verify current pricing before finalizing Pault's price points. Use live web research.
- **SubscriptionStoreView macOS availability:** Training data says unavailable on macOS as of macOS 15. Check WWDC 2025/2026 announcements -- if Apple added macOS support, the custom PaywallView could be replaced.
- **swift-snapshot-testing + Swift Testing compatibility:** The library was built for XCTest. Verify the latest version supports `@Test` macro natively or determine if an XCTest wrapper is needed.
- **Privacy manifest reason codes:** Apple's exact required-reason API list may have updated. Verify CA92.1 and check if SwiftData triggers additional declarations.
- **Mac App Store keyword volume:** No data on actual search volume for AI/prompt-related terms in MAS. Needs live ASO research.
- **App Store Connect product setup:** StoreKit Configuration file is for development only. Actual subscription products must be created in App Store Connect (manual step, not automatable).

## Sources

### Primary (HIGH confidence)
- Apple App Store Review Guidelines Section 3 (fetched 2026-03-14) -- IAP requirements, subscription rules
- Apple Privacy Manifest Documentation -- required-reason API categories
- Apple App Sandbox Documentation -- entitlement requirements
- Direct codebase audit -- 97 Swift source files, 29 test files, entitlements, Info.plist
- Existing project documentation -- PROJECT.md, pro-features-design.md, app-store-connect.md

### Secondary (MEDIUM confidence)
- StoreKit 2 API patterns (stable since WWDC 2021, training data through WWDC 2024)
- swift-snapshot-testing library (PointFree, community standard)
- Swift Testing framework patterns
- Competitor analysis (training data through early 2025)
- Indie macOS app pricing benchmarks

### Tertiary (LOW confidence)
- Mac App Store keyword search volume and ASO effectiveness
- SubscriptionStoreView macOS availability post-WWDC 2025
- swift-snapshot-testing + Swift Testing `@Test` macro compatibility

---
*Research completed: 2026-03-14*
*Ready for roadmap: yes*
