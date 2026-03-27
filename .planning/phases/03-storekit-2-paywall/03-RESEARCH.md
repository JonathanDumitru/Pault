# Phase 3: StoreKit 2 Paywall - Research

**Researched:** 2026-03-26
**Domain:** StoreKit 2 / In-App Subscriptions / macOS SwiftUI
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Annual-only subscription at $59.99/yr — remove monthly product ID (`com.pault.pro.monthly`)
- Single product ID: `com.pault.pro.annual`
- 7-day free trial configured as introductory offer in App Store Connect
- CTA button text pulled dynamically from `product.subscription?.introductoryOffer` — no hardcoded trial language
- Paywall presented as `.sheet` modal — keep current behavior
- Contextual header: highlight triggering feature (name + icon) at top
- Full Pro features bullet list + Free vs Pro checkmark matrix below header
- Legal links: Privacy Policy (`pault.app/privacy`) and Terms of Service (`pault.app/terms`) as web URLs — must be hosted before submission
- Apple-required subscription terms text (auto-renewal info, cancellation instructions)
- Restore Purchases button remains
- `ProFeature` enum with cases: `aiAssist`, `versioning`, `analytics`, `apiRunner`, `smartCollections`, `unlimitedBlocks`
- Each case carries `displayName`, `description`, `sfSymbol` — self-describing for PaywallView
- Visible-but-locked pattern: Pro features appear with ProBadge, trigger paywall on tap
- Free tier block limit: 5 blocks per prompt composition
- Soft block on 6th block: slash palette / library shows paywall prompt instead of adding block
- Replace all ~10 scattered `ProStatusManager.shared.isProUnlocked` checks with `ProFeature.isUnlocked(_:)` or equivalent
- Explicit `VerificationResult` switch on `.verified` vs `.unverified` — no `try?` swallowing
- Unverified transactions: deny Pro access + log failure for diagnostics
- Purchase errors: inline error text below purchase button
- Subscription expiry: immediate downgrade when `Transaction.currentEntitlements` no longer includes the product
- Expiry UI: silent — remove Pro badges, lock features; no aggressive popup
- `Transaction.updates` listener continues for real-time status changes
- Restore: `AppStore.sync()` + refresh status

### Claude's Discretion

- Exact `.storekit` configuration file structure for testing
- Internal caching strategy for subscription status (how often to re-check `currentEntitlements`)
- Error log format and storage for unverified transactions
- Exact paywall layout spacing, typography, and animation
- Test structure for subscription lifecycle tests

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R6.1 | Subscription Management: Annual subscription purchase, restore, persisted status on launch | `Transaction.currentEntitlements` async sequence, `AppStore.sync()` for restore, `Transaction.updates` listener started at init, no custom caching needed — StoreKit 2 handles offline |
| R6.2 | Paywall UI: Feature comparison, contextual trigger, Apple-compliant terms and legal links | Apple Schedule 2 disclosure requirements, dynamic offer text from `introductoryOffer`, SwiftUI `.sheet` modal pattern, `ProFeature` enum as self-describing data source |
| R6.3 | Feature Gating: Centralized ProFeature enum, visible-but-locked pattern, graceful upgrade prompts, 5-block limit | `ProFeature` enum pattern replaces 10 scattered `isProUnlocked` checks; block limit gate at slash palette / library insertion point |
| R6.4 | StoreKit 2 Testing: .storekit config file, sandbox testing, lifecycle tests | `SKTestSession` from StoreKitTest framework — `buyProduct`, `expireSubscription`, `refundTransaction`; `.storekit` file added to project and scheme; no existing config found in repo |
</phase_requirements>

---

## Summary

This phase hardens an existing StoreKit 2 stub into a fully App Store-compliant subscription implementation. The existing `ProStatusManager.swift` and `PaywallView.swift` are functional scaffolding — they need: (1) security hardening via explicit `VerificationResult` switch instead of `try?`, (2) product simplification from two products to one, (3) a `ProFeature` enum to replace ~10 scattered `isProUnlocked` direct checks, and (4) a paywall redesign meeting Apple's required UI disclosures.

The most critical compliance risk is Apple's Schedule 2 / Section 3.8(b) requirement: auto-renewal terms, renewal price, trial duration, and cancellation instructions must appear clearly in the paywall UI itself — not just in the StoreKit payment sheet. Missing this is a common App Review rejection reason. Dynamic CTA text derived from `product.subscription?.introductoryOffer` eliminates hardcoded trial language and handles edge cases where users are no longer eligible for an intro offer.

StoreKit 2's `Transaction.currentEntitlements` is an async sequence that returns locally cached data with automatic sync — no custom polling or caching logic is needed. The `SKTestSession` from `StoreKitTest` framework enables fully automated lifecycle tests (`purchase`, `expire`, `refund`, `restore`) without App Store sandbox interactions.

**Primary recommendation:** Wire `ProFeature` enum first (it unblocks all other work), then fix `VerificationResult` handling, then rebuild PaywallView with compliant disclosures. Test infrastructure (`.storekit` config + `SKTestSession`) is a Wave 0 gap.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| StoreKit | iOS 15+ / macOS 12+ | Purchase, restore, entitlements | Apple-native; StoreKit 2 is the required modern API |
| StoreKitTest | Same availability | Automated purchase lifecycle tests | Apple-provided; only way to test without sandbox |
| SwiftUI | macOS 14+ (project target) | Paywall sheet UI | App already uses SwiftUI throughout |
| Observation (`@Observable`) | Swift 5.9+ | `ProStatusManager` reactive state | Already established pattern in codebase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| os.Logger | macOS 11+ | Structured logging of unverified transactions | Use for diagnostic logs on verification failure |
| Foundation.URL | — | Opening Privacy Policy / Terms links | `NSWorkspace.shared.open(url)` on macOS |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native StoreKit 2 | RevenueCat / Adapty | Third-party adds SDK dependency, ongoing cost, but provides receipt validation server and analytics. Not needed for a single annual subscription — native is simpler and sufficient. |
| Manual polling loop | `Transaction.updates` async sequence | Polling wastes CPU; `Transaction.updates` is push-based and handles all edge cases including renewals pushed by App Store. |

**Installation:** No new packages required. StoreKit and StoreKitTest are system frameworks.

---

## Architecture Patterns

### Recommended Project Structure
```
Pault/
├── Models/
│   └── ProFeature.swift          # NEW: centralized enum, replaces scattered isProUnlocked checks
├── Services/
│   └── ProStatusManager.swift    # REFACTOR: fix VerificationResult, remove monthly product
├── Views/
│   ├── PaywallView.swift          # REFACTOR: expanded layout, compliant disclosures, dynamic offer text
│   └── ProBadge.swift            # KEEP as-is
PaultTests/
├── ProStatusManagerTests.swift   # EXPAND: lifecycle tests with SKTestSession
└── ProFeatureTests.swift         # NEW: enum correctness, isUnlocked logic
Pault.xcodeproj/ (scheme)         # CONFIGURE: add StoreKit configuration file to Run scheme
Pault/
└── Pault.storekit                # NEW: local test configuration file
```

### Pattern 1: Explicit VerificationResult Switch
**What:** Switch on `VerificationResult` with `.verified` and `.unverified` cases; never use `try?` which silently grants access on verification failure.
**When to use:** Every place a `VerificationResult` is unwrapped — purchase flow, `currentEntitlements` iteration, `Transaction.updates` listener.
**Example:**
```swift
// Source: Apple WWDC 2021 / wwdcbysundell.com StoreKit 2 guide
// Verified: deliver content. Unverified: deny and log.
private func handle(_ result: VerificationResult<Transaction>) async {
    switch result {
    case .verified(let transaction):
        await transaction.finish()
        await refreshStatus()
    case .unverified(let transaction, let error):
        // Deny Pro access — do NOT finish the transaction
        Logger.storeKit.error("Unverified transaction \(transaction.id): \(error.localizedDescription)")
        isProUnlocked = false
    }
}
```

### Pattern 2: Transaction.currentEntitlements for Status Refresh
**What:** Iterate `Transaction.currentEntitlements` to check active subscriptions. No server call needed — StoreKit 2 caches locally and syncs automatically.
**When to use:** On app launch, after purchase, after restore, whenever `refreshStatus()` is called.
**Example:**
```swift
// Source: swiftwithmajid.com Mastering StoreKit 2
// Use guard case to skip unverified cleanly
private func refreshStatus() async {
    var hasPro = false
    for await result in Transaction.currentEntitlements {
        guard case .verified(let transaction) = result else { continue }
        if transaction.productID == Self.proProductID {
            hasPro = true
        }
    }
    isProUnlocked = hasPro
}
```

### Pattern 3: ProFeature Enum as Single Source of Truth
**What:** Enum carrying all paywall metadata. Views ask `ProFeature.isUnlocked(_:)` instead of accessing `ProStatusManager.shared.isProUnlocked` directly.
**When to use:** Every feature gate in the app routes through this enum.
**Example:**
```swift
// Recommended pattern — Claude's design
enum ProFeature: CaseIterable {
    case aiAssist, versioning, analytics, apiRunner, smartCollections, unlimitedBlocks

    var displayName: String {
        switch self {
        case .aiAssist: return "AI Assist"
        case .versioning: return "Prompt Versioning"
        case .analytics: return "Usage Analytics"
        case .apiRunner: return "API Runner"
        case .smartCollections: return "Smart Collections"
        case .unlimitedBlocks: return "Unlimited Blocks"
        }
    }

    var description: String { /* per-case marketing copy */ }
    var sfSymbol: String { /* per-case SF Symbol name */ }

    static func isUnlocked(_ feature: ProFeature) -> Bool {
        ProStatusManager.shared.isProUnlocked
    }
}
```

### Pattern 4: Dynamic CTA Button Text from introductoryOffer
**What:** Read `product.subscription?.introductoryOffer` to determine trial eligibility and build CTA text. Fall back to price-only text when no offer available.
**When to use:** CTA button label in PaywallView.
**Example:**
```swift
// Source: tanaschita.com StoreKit 2 introductory offers guide
func ctaButtonText(for product: Product) async -> String {
    guard let subscription = product.subscription else {
        return "Subscribe for \(product.displayPrice)/year"
    }
    let eligible = await subscription.isEligibleForIntroOffer
    guard eligible, let offer = subscription.introductoryOffer else {
        return "Subscribe for \(product.displayPrice)/year"
    }
    switch offer.paymentMode {
    case .freeTrial:
        return "Start \(offer.period.debugDescription) Free Trial"
    case .payAsYouGo:
        return "Start for \(offer.displayPrice)/\(offer.period.debugDescription)"
    case .payUpFront:
        return "Start for \(offer.displayPrice)"
    default:
        return "Subscribe for \(product.displayPrice)/year"
    }
}
```

### Pattern 5: Block Limit Gate
**What:** Check `ProFeature.isUnlocked(.unlimitedBlocks)` before adding a block when count >= 5. Show paywall instead of inserting.
**When to use:** In `SlashCommandPaletteView` / `BlockLibraryView` insert action.
**Example:**
```swift
// In block insertion action
func handleBlockInsert(_ block: BlockType) {
    guard ProFeature.isUnlocked(.unlimitedBlocks) || currentBlockCount < 5 else {
        showPaywall(for: .unlimitedBlocks)
        return
    }
    // proceed with insertion
}
```

### Anti-Patterns to Avoid
- **`try? result.payloadValue`**: Silently swallows `VerificationError` and may grant Pro access to tampered transactions. Use explicit switch instead.
- **Finishing unverified transactions**: Don't call `transaction.finish()` on unverified results — let Apple's system handle them.
- **Hardcoded CTA text**: `"Start 7-Day Free Trial"` breaks when users are ineligible for intro offer (repeat subscribers). Always derive from StoreKit data.
- **Multiple `ProStatusManager.shared.isProUnlocked` call sites**: Each site is a maintenance hazard and a potential place where gating logic diverges. Route through `ProFeature.isUnlocked(_:)`.
- **Showing paywall without auto-renewal disclosure**: App Review rejects apps that don't display the Schedule 2 required terms within the paywall UI itself.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Transaction verification | Custom JWS parser / receipt validation | StoreKit 2 `VerificationResult.verified` | Apple signs and verifies JWS server-side; client sees verified/unverified result |
| Subscription status caching | Timer-based polling / UserDefaults cache | `Transaction.currentEntitlements` + `Transaction.updates` | StoreKit 2 manages local cache and push updates automatically — adding your own cache introduces race conditions |
| Offer eligibility check | Track usage locally | `product.subscription?.isEligibleForIntroOffer` | StoreKit tracks per-Apple-ID eligibility across devices; local tracking is incomplete |
| Purchase dialog UI | Custom payment collection | `product.purchase()` | Apple requires their payment sheet; custom UI is against guidelines and impossible on-device |
| Subscription lifecycle tests | Mock objects / manual sandbox | `SKTestSession` from StoreKitTest | Purpose-built: simulates purchase, expiry, refund, billing retry without App Store interaction |

**Key insight:** StoreKit 2 handles the hard problems (verification, caching, offline, entitlement sync) transparently. Custom logic in these areas introduces bugs and App Review risk.

---

## Common Pitfalls

### Pitfall 1: Missing Auto-Renewal Disclosure (App Review Rejection)
**What goes wrong:** App Review rejects submissions where the paywall doesn't include the auto-renewal terms required by Schedule 2 Section 3.8(b).
**Why it happens:** Developers assume the StoreKit payment sheet covers disclosure. It does not — Apple requires the text to appear in the app's own UI.
**How to avoid:** Include in PaywallView (scrollable terms section or caption):
  - "Subscription automatically renews unless cancelled at least 24 hours before the end of the current period"
  - "Renewal price: $59.99/year. Charged within 24 hours prior to renewal"
  - Link to manage subscription via App Store (Subscription Management link)
  - Links to Privacy Policy and Terms of Service
**Warning signs:** Paywall has no small-print legal section.

### Pitfall 2: `try?` Swallowing Unverified Transactions
**What goes wrong:** Current code uses `try? result.payloadValue` in both `refreshStatus()` and `listenForTransactions()`. A tampered transaction that fails verification returns `nil`, which is treated the same as "no transaction" — access is silently denied without diagnostic logging.
**Why it happens:** `try?` is convenient but opaque.
**How to avoid:** Use explicit `switch result { case .verified(let tx): ... case .unverified(let tx, let error): Logger.storeKit.error(...) }` in every verification site.
**Warning signs:** No logging for unverified case; no test exercising the unverified path.

### Pitfall 3: Leaving Monthly Product ID in proProductIDs
**What goes wrong:** `ProStatusManager.proProductIDs` currently includes `com.pault.pro.monthly`. If this is left in and monthly is removed from App Store Connect, `Product.products(for:)` returns fewer products than expected and logs warnings. Worse, existing test expectations reference the monthly ID.
**How to avoid:** Replace `proProductIDs: [String]` with `proProductID: String = "com.pault.pro.annual"` (single value). Update `ProStatusManagerTests.test_proProductIDs_matchConfiguration` to match.

### Pitfall 4: Paywall Presented Before Products Load
**What goes wrong:** User triggers paywall immediately; product load is async. If not handled, the CTA button may show stale text or the product may be nil.
**Why it happens:** `loadProducts()` is called in `.task` which fires after first render.
**How to avoid:** Show `ProgressView` during load (current pattern is correct — keep it). Ensure `ctaButtonText` function is called only after products are loaded. The `isLoadingProducts` guard already exists — preserve it.

### Pitfall 5: Transaction Listener Not Started at App Launch
**What goes wrong:** Renewals, refunds, or billing recoveries processed by App Store while app is backgrounded are missed if listener is not active on foreground.
**Why it happens:** Listener is started in `ProStatusManager.init()` — only a problem if `ProStatusManager.shared` is lazily initialized late.
**How to avoid:** Access `ProStatusManager.shared` early in app startup (e.g., `@State private var proStatus = ProStatusManager.shared` in root App view, or explicit `_ = ProStatusManager.shared` in `App.init()`). Current pattern in PaywallView accesses it but root app initialization should be verified.

### Pitfall 6: `isEligibleForIntroOffer` is async
**What goes wrong:** Calling `subscription.isEligibleForIntroOffer` synchronously (e.g., in a `var` computed property) fails to compile or produces wrong results.
**How to avoid:** Call in an `async` context: `let eligible = await product.subscription?.isEligibleForIntroOffer ?? false`. In PaywallView, use `.task` to precompute and store in `@State var ctaText: String`.

---

## Code Examples

Verified patterns from official and authoritative sources:

### Explicit VerificationResult Switch (purchase flow)
```swift
// Source: wwdcbysundell.com StoreKit 2 guide (2021, matches current API)
func purchase(_ product: Product) async throws -> Bool {
    let purchaseResult = try await product.purchase()
    switch purchaseResult {
    case .success(let verification):
        switch verification {
        case .verified(let transaction):
            await transaction.finish()
            await refreshStatus()
            return true
        case .unverified(let transaction, let error):
            Logger.storeKit.error("Unverified transaction \(transaction.id): \(error)")
            return false
        }
    case .userCancelled:
        return false
    case .pending:
        return false
    @unknown default:
        return false
    }
}
```

### currentEntitlements with guard case (clean pattern)
```swift
// Source: swiftwithmajid.com Mastering StoreKit 2 (2023)
private func refreshStatus() async {
    var hasPro = false
    for await result in Transaction.currentEntitlements {
        guard case .verified(let transaction) = result else { continue }
        if transaction.productID == Self.proProductID {
            hasPro = true
        }
    }
    isProUnlocked = hasPro
}
```

### Transaction.updates with explicit switch
```swift
// Source: wwdcbysundell.com StoreKit 2 guide (2021)
private func listenForTransactions() async {
    for await result in Transaction.updates {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
            await refreshStatus()
        case .unverified(let transaction, let error):
            Logger.storeKit.error("Unverified update for \(transaction.id): \(error)")
        }
    }
}
```

### SKTestSession in XCTest
```swift
// Source: swiftwithmajid.com StoreKit testing in Swift (2024)
import StoreKitTest

@MainActor
final class ProStatusManagerTests: XCTestCase {
    var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Pault")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() {
        session.clearTransactions()
    }

    func test_purchase_grantsProAccess() async throws {
        let manager = ProStatusManager()
        try await session.buyProduct(identifier: "com.pault.pro.annual")
        await manager.refreshStatus()
        XCTAssertTrue(manager.isProUnlocked)
    }

    func test_expiredSubscription_revokesProAccess() async throws {
        let manager = ProStatusManager()
        try await session.buyProduct(identifier: "com.pault.pro.annual")
        try session.expireSubscription(productIdentifier: "com.pault.pro.annual")
        await manager.refreshStatus()
        XCTAssertFalse(manager.isProUnlocked)
    }

    func test_restore_grantsProAccess() async throws {
        let manager = ProStatusManager()
        try await session.buyProduct(identifier: "com.pault.pro.annual")
        session.clearTransactions() // simulate fresh install
        await manager.restorePurchases()
        XCTAssertTrue(manager.isProUnlocked)
    }
}
```

### Introductory offer eligibility check
```swift
// Source: tanaschita.com StoreKit 2 introductory offers guide (2023)
func isEligibleForFreeTrial(product: Product) async -> Bool {
    guard let subscription = product.subscription else { return false }
    return await subscription.isEligibleForIntroOffer
}
```

### .storekit Configuration File Structure (key fields)
```json
// File: Pault.storekit (created via Xcode: File > New > StoreKit Configuration File)
// Configured via Xcode UI — key properties to set:
// Subscription Group: "Pault Pro"
// Product ID: "com.pault.pro.annual"
// Reference Name: "Pro Annual"
// Price: $59.99
// Subscription Duration: 1 Year
// Introductory Offer:
//   Payment Mode: Free Trial
//   Duration: 7 Days
// Localization: English (US), display name "Pault Pro", description "..."
```

---

## Apple Required Paywall Disclosures (Compliance)

Source: Apple Developer — Auto-renewable Subscriptions page + Schedule 2 Section 3.8(b)

The following text must appear in PaywallView (not only in the StoreKit payment sheet):

| Requirement | Example Text |
|-------------|-------------|
| Auto-renewal statement | "Subscription automatically renews unless cancelled at least 24 hours before the end of the current period." |
| Renewal price and period | "Renewal: $59.99/year, charged within 24 hours prior to renewal." |
| Cancellation instructions | "Manage or cancel in your App Store Account Settings." |
| Trial terms (when trial shown) | "7-day free trial, then $59.99/year." (derive dynamically from StoreKit) |
| Privacy Policy link | Tappable URL to `pault.app/privacy` |
| Terms of Service link | Tappable URL to `pault.app/terms` |

**Note:** Privacy Policy and Terms pages at `pault.app/privacy` and `pault.app/terms` must be live web pages before App Store submission.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `try? result.payloadValue` (current code) | Explicit `switch` on `VerificationResult` | Phase 3 | Security: tampered transactions are now logged and denied |
| Two product IDs (monthly + annual) | Single `proProductID: String` | Phase 3 | Simpler loading, no Picker needed in PaywallView |
| Direct `ProStatusManager.shared.isProUnlocked` checks | `ProFeature.isUnlocked(_:)` via enum | Phase 3 | Single maintenance point; paywall metadata co-located with feature definition |
| Manual sandbox testing | `SKTestSession` automated lifecycle tests | Phase 3 | Full lifecycle coverage without Apple ID or network |

**Deprecated/outdated in this codebase:**
- `selectedProductID = "com.pault.pro.monthly"` in PaywallView — monthly product being removed
- Segmented `Picker` in PaywallView — no longer needed with single product
- `proProductIDs: [String]` array — replace with `proProductID: String`
- Hardcoded `"Start 7-Day Free Trial"` button label — replace with dynamic offer text

---

## Open Questions

1. **`ProStatusManager.shared` initialization timing**
   - What we know: Listener starts in `init()`. Current entry points access it via PaywallView.
   - What's unclear: Whether root `App` struct accesses shared instance early enough to catch renewals delivered at launch.
   - Recommendation: Verify `ProStatusManager.shared` is accessed in `App.init()` or early in root view body; add `_ = ProStatusManager.shared` if needed.

2. **Offline intro offer eligibility**
   - What we know: `isEligibleForIntroOffer` requires StoreKit to check server state.
   - What's unclear: Whether it returns a cached result or needs network.
   - Recommendation: Treat as async operation; if it throws or returns false with no network, fall back to price-only CTA gracefully. LOW confidence on offline behavior.

3. **`pault.app/privacy` and `pault.app/terms` hosting**
   - What we know: Must be live before App Store submission (R7 work).
   - What's unclear: Who creates them and when.
   - Recommendation: Add as a dependency note in the plan — Phase 3 code can link to them but submission is blocked on Phase 7 (App Store Readiness). Use placeholder URLs in code; swap when ready.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing throughout project) |
| Config file | PaultTests/ — standard Xcode test target |
| Quick run command | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R6.1 | Purchase grants Pro access | Unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_purchase_grantsProAccess` | ❌ Wave 0 |
| R6.1 | Restore grants Pro access on fresh install | Unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_restore_grantsProAccess` | ❌ Wave 0 |
| R6.1 | Expired subscription revokes Pro access | Unit (SKTestSession) | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_expiredSubscription_revokesProAccess` | ❌ Wave 0 |
| R6.1 | Unverified transaction denied and logged | Unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_unverifiedTransaction_deniesAccess` | ❌ Wave 0 |
| R6.3 | ProFeature.isUnlocked returns correct state | Unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProFeatureTests` | ❌ Wave 0 |
| R6.3 | Block limit gates at 6th block | Unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProFeatureTests/test_blockLimit_softGateAt6` | ❌ Wave 0 |
| R6.3 | proProductIDs constant matches single annual ID | Unit | `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests/test_proProductID_isAnnualOnly` | ❌ Wave 0 (replaces existing test) |
| R6.4 | All tests run against .storekit config | Infrastructure | N/A — scheme config | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Pault -only-testing PaultTests/ProStatusManagerTests -quiet`
- **Per wave merge:** `xcodebuild test -scheme Pault -destination 'platform=macOS' -quiet`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Pault/Pault.storekit` — StoreKit configuration file with `com.pault.pro.annual`, 7-day trial, $59.99 price
- [ ] Xcode scheme configured to use `Pault.storekit` in Run options
- [ ] `PaultTests/ProStatusManagerTests.swift` — expanded with `SKTestSession`-based lifecycle tests (replace current 2 stubs)
- [ ] `PaultTests/ProFeatureTests.swift` — new file covering `ProFeature` enum correctness and `isUnlocked` logic
- [ ] `import StoreKitTest` in test target — verify framework is linked (currently not used anywhere in tests)

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `Transaction.currentEntitlements`, `VerificationResult`, `AppStore.sync()` (official API, macOS 12+)
- Apple Developer — Auto-renewable Subscriptions page (Schedule 2 disclosure requirements)
- Apple Developer — Setting up StoreKit Testing in Xcode (official docs for .storekit file and scheme setup)
- Apple WWDC21 — Meet StoreKit 2 (foundational API design and patterns)

### Secondary (MEDIUM confidence)
- [swiftwithmajid.com — Mastering StoreKit 2](https://swiftwithmajid.com/2023/08/01/mastering-storekit2/) — `currentEntitlements` and `Transaction.updates` code patterns (2023, verified against Apple docs)
- [swiftwithmajid.com — StoreKit testing in Swift](https://swiftwithmajid.com/2024/01/09/storekit-testing-in-swift/) — `SKTestSession` lifecycle test patterns (2024)
- [tanaschita.com — Subscriptions introductory offers](https://tanaschita.com/20231113-subscriptions-introductory-offers/) — `isEligibleForIntroOffer` and `introductoryOffer` property usage (2023)
- [wwdcbysundell.com — Working with in-app purchases in StoreKit 2](https://wwdcbysundell.com/2021/working-with-in-app-purchases-in-storekit2/) — explicit VerificationResult switch patterns

### Tertiary (LOW confidence — flag for validation)
- Offline behavior of `isEligibleForIntroOffer`: documented as async/server-checked but exact offline fallback behavior not confirmed in official docs
- `Transaction.updates` API name: some older sources reference `Transaction.listener` — verify correct property name is `Transaction.updates` before use (MEDIUM: multiple sources agree on `Transaction.updates`)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — native Apple frameworks, no third-party uncertainty
- VerificationResult patterns: HIGH — multiple authoritative sources agree; verified against Apple docs structure
- Paywall disclosure requirements: HIGH — sourced from Apple's official subscriptions page
- Architecture (ProFeature enum): HIGH — established Swift pattern, fits project conventions
- SKTestSession lifecycle tests: HIGH — official Apple framework, documented in multiple WWDC sessions
- Introductory offer eligibility API: MEDIUM — async API behavior confirmed; offline edge case not fully documented
- .storekit file JSON structure: MEDIUM — created via Xcode UI, not hand-edited; fields confirmed via multiple guides

**Research date:** 2026-03-26
**Valid until:** 2026-09-26 (StoreKit 2 is stable; check WWDC 2026 notes for any additions)
