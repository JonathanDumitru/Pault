# StoreKit 2 Research: macOS Implementation for Pault

**Domain:** In-app purchases / subscription monetization for macOS productivity apps
**Researched:** 2026-03-14
**Overall confidence:** HIGH (StoreKit 2 is well-established since WWDC 2021; API stable through macOS 15)

---

## Executive Summary

Pault already has a solid StoreKit 2 foundation: `ProStatusManager` handles product loading, purchasing, transaction listening, and restore; `PaywallView` presents a segmented plan picker with error handling; `ProBadge` provides visual gating. The existing code follows correct patterns for the most part, but there are several improvements needed before App Store submission -- particularly around receipt/transaction verification, subscription status handling, grace periods, and StoreKit Configuration file testing.

For a local-first macOS productivity app, **auto-renewable subscriptions** (monthly + annual) are the right monetization model. The existing product IDs (`com.pault.pro.monthly`, `com.pault.pro.annual`) are correct. One-time purchase ("lifetime") could be added later but is not needed for v1.0 -- subscriptions provide recurring revenue and align with App Store review expectations for apps offering "ongoing value."

The biggest risks are: (1) App Store rejection for unclear subscription terms in the paywall UI, (2) not handling subscription expiration/grace periods properly, and (3) inadequate sandbox testing on macOS where StoreKit behaves slightly differently than iOS.

---

## 1. StoreKit 2 Best Practices for macOS

### What the Existing Code Does Right

- Uses `Product.products(for:)` for product loading (correct StoreKit 2 API)
- Uses `product.purchase()` with proper `PurchaseResult` switch handling
- Listens for `Transaction.updates` in a long-lived task (correct pattern)
- Uses `Transaction.currentEntitlements` for status refresh
- Calls `transaction.finish()` after processing (required)
- Uses `AppStore.sync()` for restore (correct StoreKit 2 approach)
- `@Observable` + `@MainActor` for thread-safe UI updates

### What Needs Improvement

#### A. Transaction Verification (CRITICAL)

The current code uses `try? result.payloadValue` which silently ignores verification failures. StoreKit 2 performs automatic JWS verification, but you should explicitly handle the verification result:

```swift
// Current (unsafe -- swallows verification failures):
if let transaction = try? result.payloadValue { ... }

// Recommended:
switch result {
case .verified(let transaction):
    // Safe to grant access
    await transaction.finish()
case .unverified(let transaction, let error):
    // Log the error, do NOT grant access
    // Optionally: report to analytics
    ErrorLogger.log("Unverified transaction: \(error)")
}
```

This matters because on macOS, receipt tampering is more feasible than on iOS (users have filesystem access). Treating unverified transactions as failures is the correct posture.

**Confidence:** HIGH -- this is documented Apple guidance.

#### B. Subscription Status & Expiration

The current `refreshStatus()` checks `Transaction.currentEntitlements` which is correct for determining current access. However, it does not distinguish between:

- Active subscription
- In billing retry (grace period)
- Expired
- Revoked

For a better UX (and to avoid "you lost Pro" flicker during billing retry), check `Product.SubscriptionInfo.Status`:

```swift
func refreshStatus() async {
    guard let statuses = try? await Product.SubscriptionInfo.status(
        for: "your_subscription_group_id"  // from App Store Connect
    ) else {
        isProUnlocked = false
        return
    }

    for status in statuses {
        guard case .verified(let renewalInfo) = status.renewalInfo,
              case .verified(let transaction) = status.transaction else { continue }

        switch status.state {
        case .subscribed, .inBillingRetryPeriod, .inGracePeriod:
            isProUnlocked = true
            return
        case .expired, .revoked:
            continue
        default:
            continue
        }
    }
    isProUnlocked = false
}
```

**Confidence:** HIGH -- `Product.SubscriptionInfo.Status` is the canonical way to check subscription state.

#### C. Offer Introductory Pricing / Free Trials

The PaywallView CTA says "Start 7-Day Free Trial" but this must match the actual offer configured in App Store Connect. StoreKit 2 provides `product.subscription?.introductoryOffer` to check eligibility:

```swift
if let intro = product.subscription?.introductoryOffer {
    let eligible = await product.subscription?.isEligibleForIntroOffer ?? false
    if eligible {
        // Show "Start \(intro.period.value)-\(intro.period.unit) Free Trial"
    } else {
        // Show "Subscribe" (user already used trial)
    }
}
```

Do NOT hardcode "7-Day Free Trial" -- query the offer dynamically and check eligibility.

**Confidence:** HIGH -- this is a well-known App Store rejection reason.

### macOS-Specific Considerations

| Concern | Detail |
|---------|--------|
| **No SubscriptionStoreView on macOS** | `SubscriptionStoreView` (the built-in paywall UI from iOS 17) is NOT available on macOS as of macOS 15. You must build a custom paywall, which Pault already does. |
| **Sandbox account management** | On macOS, sandbox account settings are in System Settings > App Store > Sandbox Account (not in Settings app like iOS). Developers often miss this. |
| **Receipt location** | macOS app receipts live at `Bundle.main.appStoreReceiptURL`. With StoreKit 2, you generally do NOT need to validate receipts manually -- `Transaction.currentEntitlements` handles it. But receipt presence can be checked for anti-piracy. |
| **App sandbox entitlement** | Mac App Store apps MUST use App Sandbox. StoreKit 2 works within sandbox without additional entitlements. Ensure `com.apple.security.app-sandbox = true` in entitlements. |
| **No StoreKit overlay** | `manageSubscriptionsSheet` works on macOS 13+ but opens System Settings, not an in-app overlay. Fine for UX, just know it navigates away. |
| **Transaction.updates behavior** | On macOS, family sharing transactions also appear in `Transaction.updates`. Filter by `transaction.ownershipType == .purchased` if you only want direct purchases. |
| **StoreKit Configuration files** | Work identically on macOS in Xcode. Use these for development -- they are faster and more reliable than sandbox on macOS. |

**Confidence:** HIGH for most items. MEDIUM for SubscriptionStoreView macOS availability (based on training data through mid-2025; verify against Xcode 16 release notes).

---

## 2. Subscription vs One-Time Purchase

### Recommendation: Auto-Renewable Subscriptions (Monthly + Annual)

For a productivity app like Pault with Pro features that include AI capabilities (which have ongoing API costs), subscriptions are correct because:

1. **Ongoing costs justify subscriptions** -- AI Assist features cost money per use (API calls)
2. **App Store guidelines require "ongoing value"** for subscriptions -- Pault delivers this via AI features, continued development, and prompt ecosystem updates
3. **Revenue sustainability** -- solo developer needs predictable revenue
4. **Apple's 15% commission after Year 1** -- Apple reduces the commission from 30% to 15% for subscriptions after the first year (Small Business Program may reduce further)

### Pricing Strategy (Research-Informed)

Typical macOS productivity app pricing for indie apps in 2025-2026:

| Plan | Price Range | Recommendation for Pault |
|------|-------------|-------------------------|
| Monthly | $3.99 - $9.99 | $4.99/month |
| Annual | $29.99 - $79.99 | $39.99/year (33% savings vs monthly) |
| Lifetime (optional, later) | $79.99 - $149.99 | Consider post-launch if requested |

Key: The annual plan should offer visible savings (show "Save X%") to drive annual adoption.

### Free Tier vs Pro Tier Feature Split

The free tier must be genuinely useful (not a crippled demo) or Apple will reject. Based on the existing codebase:

**Free tier (generous -- drives adoption):**
- Prompt CRUD (create, edit, delete, favorite, archive)
- Template variables (basic)
- Tags and search
- All three access surfaces (main window, menu bar, hotkey launcher)
- Clipboard/paste integration
- Export (basic formats)
- Block editor (core blocks only)

**Pro tier (worth paying for):**
- AI Assist (prompt improvement, variable suggestion, quality scoring)
- Prompt Versioning (history, diff, restore)
- Usage Analytics (stats, insights)
- API Runner (direct LLM execution with streaming)
- Smart Collections (dynamic filters)
- Attachments (file attachments on prompts)
- Rich Text Editor
- Advanced export formats
- Custom blocks (create your own block types)

**Confidence:** MEDIUM -- pricing is market-dependent; feature split is well-grounded in the existing codebase.

---

## 3. Paywall View Implementation

### Current State Assessment

The existing `PaywallView` is functional but needs refinements for App Store compliance:

#### Required Changes

1. **Dynamic trial text** -- Replace hardcoded "Start 7-Day Free Trial" with dynamic text based on `introductoryOffer` and eligibility check (see Section 1C above)

2. **Subscription terms disclosure** -- App Store Review Guidelines 3.1.2(c) requires clearly showing:
   - Price per period (e.g., "$4.99/month")
   - What happens after trial ends
   - Auto-renewal notice
   - Link to Terms of Service and Privacy Policy

   Add below the CTA button:
   ```
   "After the free trial, $X.XX/month. Auto-renews. Cancel anytime."
   ```
   Plus links to Terms of Service and Privacy Policy.

3. **Manage Subscription link** -- For existing subscribers, provide a way to manage/cancel:
   ```swift
   // Opens macOS System Settings subscription management
   try await AppStore.showManageSubscriptions(in: windowScene)
   // Or on macOS where window scene isn't available:
   if let url = URL(string: "macappstores://showManageSubscriptions") {
       NSWorkspace.shared.open(url)
   }
   ```

4. **Price formatting** -- Use `product.displayPrice` (already done) which respects locale. Good.

#### Recommended Paywall Structure

```
+------------------------------------------+
|          [Feature Icon]                   |
|     Unlock [Feature Name]  [PRO]         |
|     [Feature description text]           |
|                                          |
|  +-- Pro Features Include: ------------+ |
|  | - AI Assist                          | |
|  | - Prompt Versioning                  | |
|  | - Usage Analytics                    | |
|  | - API Runner                         | |
|  | - Smart Collections                  | |
|  +--------------------------------------+ |
|                                          |
|   [Monthly $4.99/mo] [Annual $39.99/yr]  |
|            Save 33% ^                    |
|                                          |
|   [=== Start Free Trial ===]            |
|                                          |
|   After trial, $X.XX/period.            |
|   Auto-renews. Cancel anytime.           |
|                                          |
|   Restore Purchases  |  Terms  | Privacy |
+------------------------------------------+
```

**Confidence:** HIGH -- based on successfully reviewed App Store apps and Apple guidelines.

---

## 4. Testing StoreKit 2

### Three Testing Tiers

#### Tier 1: StoreKit Configuration File (Primary -- Use This for Development)

Create a `.storekit` configuration file in Xcode:

1. File > New > File > StoreKit Configuration File
2. Add products matching your product IDs:
   - `com.pault.pro.monthly` -- Auto-Renewable Subscription, $4.99
   - `com.pault.pro.annual` -- Auto-Renewable Subscription, $39.99
3. Set subscription group (e.g., "Pault Pro")
4. Configure introductory offer (7-day free trial)
5. In scheme settings: Run > Options > StoreKit Configuration > select your `.storekit` file

**Advantages on macOS:**
- No Apple ID needed
- Transactions are instant (no network delay)
- Can simulate failure scenarios, refunds, expiration
- Can speed up subscription renewal (1 minute = 1 month)
- Can test ask-to-buy, interrupted purchases
- Transaction Manager in Xcode shows all transactions

**What to test:**
- [ ] Product loading success
- [ ] Product loading failure (disable configuration to test)
- [ ] Purchase flow (success, cancel, pending)
- [ ] Subscription renewal
- [ ] Subscription expiration
- [ ] Restore purchases
- [ ] Introductory offer eligibility
- [ ] Introductory offer after prior usage (should NOT show trial)
- [ ] App launch with existing entitlement (Pro status persists)
- [ ] App launch with expired entitlement (Pro revoked)
- [ ] Transaction listener receives updates

#### Tier 2: Sandbox Testing (Pre-Submission)

Uses real App Store Connect products but fake money:

1. Create sandbox tester accounts in App Store Connect
2. On Mac: System Settings > App Store > Sandbox Account
3. Run app WITHOUT StoreKit Configuration selected in scheme
4. Subscriptions auto-renew at accelerated rates:
   - 1 week = 3 minutes
   - 1 month = 5 minutes
   - 1 year = 1 hour
   - Max 6 auto-renewals per sandbox account

**macOS Sandbox Gotchas:**
- Must sign out of production App Store account first
- Sandbox sign-in is separate from production
- Sometimes requires app restart after sign-in change
- Sandbox environment can be flaky -- retry if products fail to load
- Each sandbox tester gets max 6 renewals, then you need a new account

#### Tier 3: TestFlight (Final Validation)

- Uses production App Store Connect products
- Real purchase flow but in sandbox
- Best for validating the complete end-to-end flow before submission

### Automated Testing

StoreKit 2 supports unit testing with `SKTestSession`:

```swift
import StoreKitTest

class StoreKitTests: XCTestCase {
    var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.disableDialogs = true
        session.clearTransactions()
    }

    func testPurchaseGrantsProStatus() async throws {
        let manager = ProStatusManager()
        let products = try await Product.products(for: ["com.pault.pro.monthly"])
        let product = try XCTUnwrap(products.first)

        let result = try await product.purchase()
        // Verify the purchase succeeded and ProStatusManager updated
    }
}
```

**Confidence:** HIGH -- StoreKit testing infrastructure is well-documented and stable.

---

## 5. Feature Gating Patterns

### Current Pattern Assessment

The existing pattern uses `ProStatusManager.shared.isProUnlocked` checks scattered across views:

```swift
// Current pattern (found in 10+ locations):
if ProStatusManager.shared.isProUnlocked { ... }
guard ProStatusManager.shared.isProUnlocked else { showPaywall = true; return }
```

This works but has maintenance problems:
- Feature checks are scattered across the codebase
- No centralized definition of what is/isn't Pro
- Changing the gate logic requires touching many files

### Recommended Pattern: Centralized Feature Flags

```swift
// ProFeature.swift
enum ProFeature: String, CaseIterable {
    case aiAssist
    case versioning
    case analytics
    case apiRunner
    case smartCollections
    case attachments
    case richTextEditor
    case customBlocks
    case advancedExport
}

// Extend ProStatusManager
extension ProStatusManager {
    func isUnlocked(_ feature: ProFeature) -> Bool {
        // For now, all Pro features are gated the same way.
        // This allows per-feature gating later (e.g., tiered plans).
        return isProUnlocked
    }
}

// Usage in views:
@State private var proStatus = ProStatusManager.shared

// Check:
if proStatus.isUnlocked(.aiAssist) { ... }

// Gate with paywall:
func requirePro(_ feature: ProFeature, action: () -> Void) {
    if proStatus.isUnlocked(feature) {
        action()
    } else {
        showPaywall(for: feature)
    }
}
```

### View Modifier Pattern for Paywall Gating

```swift
struct ProGateModifier: ViewModifier {
    let feature: ProFeature
    @State private var showPaywall = false
    @State private var proStatus = ProStatusManager.shared

    func body(content: Content) -> some View {
        content
            .disabled(!proStatus.isUnlocked(feature))
            .overlay {
                if !proStatus.isUnlocked(feature) {
                    // Lock overlay
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(feature: feature)
            }
    }
}

extension View {
    func proGated(_ feature: ProFeature) -> some View {
        modifier(ProGateModifier(feature: feature))
    }
}
```

### Paywall Trigger Points (UX Best Practice)

- **Soft gate:** Show the feature exists, let user interact briefly, then prompt upgrade (better conversion)
- **Hard gate:** Block entirely with lock icon + "Upgrade to Pro" (simpler, less frustrating)
- **Contextual paywall:** When user tries to use a Pro feature, show paywall explaining THAT specific feature's value

The existing codebase uses contextual paywalls (e.g., `PaywallView(featureName: "API Runner", ...)`) which is the best approach for conversion.

**Confidence:** HIGH -- these are standard patterns used by successful indie macOS apps.

---

## 6. App Store Review Guidelines for IAP

### Requirements Checklist (from Apple Guidelines 3.1.1 and 3.1.2)

| Requirement | Status in Pault | Action Needed |
|-------------|----------------|---------------|
| Use StoreKit for unlocking features | Done | None |
| Restore purchases mechanism | Done (`AppStore.sync()`) | None |
| Clear subscription terms before purchase | Partial | Add price/period/auto-renew text |
| Free trial description (duration, what expires) | Missing | Add dynamic trial terms |
| Subscription available on all user's devices | N/A (macOS only) | None for v1.0 |
| Don't remove features existing users paid for | N/A (new app) | None |
| No artificial barriers to paid content | OK | None |
| Privacy policy link | Needed | Add to paywall + Settings |
| Terms of service link | Needed | Add to paywall + Settings |

### Subscription-Specific Requirements (3.1.2)

1. **Minimum 7-day subscription period** -- Monthly and annual both satisfy this
2. **Must provide "ongoing value"** -- AI features + continued development qualifies
3. **Clear pricing disclosure** -- Must show exact price, billing period, renewal terms
4. **Introductory offer clarity** -- Must clearly state trial duration and post-trial price
5. **Seamless upgrade/downgrade** -- Monthly <-> Annual should be smooth (StoreKit 2 handles this automatically within a subscription group)

### Mac App Store Specific (3.1.1)

- Mac apps **may** host plug-ins/extensions with non-App Store mechanisms (not relevant for Pault)
- All feature unlocking must use StoreKit (no license keys, no external activation)

**Confidence:** HIGH -- sourced directly from Apple Review Guidelines (fetched and verified).

---

## 7. Common App Store Rejection Reasons for IAP

### Critical Rejection Risks (Address Before Submission)

#### 1. Hardcoded Trial Language Without Matching Offer
**Risk:** HIGH
**Problem:** PaywallView says "Start 7-Day Free Trial" but if the App Store Connect product doesn't have a matching introductory offer, or if the user already used their trial, this is misleading.
**Fix:** Query `product.subscription?.introductoryOffer` and `isEligibleForIntroOffer` dynamically. Show "Subscribe" for ineligible users.

#### 2. Missing Subscription Terms Disclosure
**Risk:** HIGH
**Problem:** No text showing price, auto-renewal, cancellation instructions near the purchase button.
**Fix:** Add legally required disclosure text below CTA: "Auto-renews at $X.XX/period. Cancel anytime in System Settings > Subscriptions."

#### 3. Missing Privacy Policy / Terms of Service Links
**Risk:** HIGH
**Problem:** The paywall (and app generally) must link to Privacy Policy and Terms of Service.
**Fix:** Add tappable links in PaywallView footer and in Settings/Preferences.

#### 4. Products Not Available During Review
**Risk:** MEDIUM
**Problem:** If products aren't properly set up in App Store Connect, or if the reviewer's region doesn't have them available, the paywall shows "Could not load plans."
**Fix:** Ensure products are in "Ready to Submit" or "Approved" state in App Store Connect. Add reviewer notes explaining how to test IAP.

#### 5. Free Tier Too Limited
**Risk:** MEDIUM
**Problem:** If the free version feels like a demo/trial rather than a useful app, Apple may reject under the "app must be useful without IAP" principle.
**Fix:** Ensure core prompt management (CRUD, templates, tags, search, all surfaces) works fully without Pro.

#### 6. Unclear What's Free vs Pro
**Risk:** LOW-MEDIUM
**Problem:** If users can't tell what requires Pro before encountering the paywall, it feels like a bait-and-switch.
**Fix:** Use `ProBadge` consistently on all Pro features in the UI. Consider a "Pro Features" section in Settings showing what's included.

### Moderate Rejection Risks

#### 7. No "Manage Subscription" Option
**Risk:** MEDIUM
**Problem:** Users need a way to manage/cancel their subscription from within the app.
**Fix:** Add a "Manage Subscription" button in Preferences that opens System Settings.

#### 8. Sandbox Testing Issues During Review
**Risk:** LOW
**Problem:** Reviewers test in sandbox which can be flaky.
**Fix:** Include detailed review notes: "To test Pro features, purchase any subscription plan. Sandbox accounts auto-renew at accelerated rates."

**Confidence:** HIGH -- based on widely documented rejection patterns and Apple guidelines.

---

## 8. Implementation Improvements for Existing Code

### Priority 1: Must Fix Before Submission

1. **Proper verification result handling** in `ProStatusManager` (replace `try?` with explicit `switch .verified/.unverified`)
2. **Dynamic introductory offer text** in `PaywallView` (remove hardcoded "7-Day Free Trial")
3. **Subscription terms disclosure** in `PaywallView` (price, auto-renew, cancel info)
4. **Privacy Policy + Terms of Service links** in PaywallView and Preferences
5. **StoreKit Configuration file** for development/testing

### Priority 2: Should Fix

6. **Subscription status checking** via `Product.SubscriptionInfo.Status` (handle grace periods)
7. **Centralized feature flags** (`ProFeature` enum) instead of scattered `isProUnlocked` checks
8. **"Manage Subscription" button** in Preferences
9. **Family sharing awareness** (filter `transaction.ownershipType` if needed)

### Priority 3: Nice to Have

10. **Promotional offer support** (for win-back campaigns post-launch)
11. **SubscriptionStoreView** adoption if/when Apple adds macOS support
12. **Subscription analytics** (track conversion, churn, trial-to-paid)
13. **Lifetime purchase option** (non-consumable, post-launch based on user demand)

---

## 9. StoreKit Configuration File Setup

### Recommended Configuration

Create `Pault.storekit` in the project:

```
Subscription Group: "Pault Pro" (group ID: "pault_pro")

  Product 1:
    Reference Name: Monthly Pro
    Product ID: com.pault.pro.monthly
    Type: Auto-Renewable Subscription
    Price: $4.99
    Duration: 1 Month
    Introductory Offer: Free Trial, 7 Days

  Product 2:
    Reference Name: Annual Pro
    Product ID: com.pault.pro.annual
    Type: Auto-Renewable Subscription
    Price: $39.99
    Duration: 1 Year
    Introductory Offer: Free Trial, 7 Days

Subscription Group Level:
  Monthly: Level 1
  Annual: Level 1 (same level = upgrade/downgrade between them)
```

### Xcode Scheme Configuration

1. Edit Scheme > Run > Options > StoreKit Configuration: `Pault.storekit`
2. This routes all StoreKit calls to local configuration during development
3. Remove this setting for sandbox/TestFlight testing

---

## 10. Architecture Recommendation

### File Structure

```
Pault/
  Services/
    ProStatusManager.swift          (existing -- needs updates)
    StoreKitConfiguration/
      Pault.storekit                (new -- StoreKit Configuration file)
  Models/
    ProFeature.swift                (new -- feature flag enum)
  Views/
    PaywallView.swift               (existing -- needs updates)
    ProBadge.swift                  (existing -- good as-is)
    SubscriptionTermsView.swift     (new -- legal disclosure component)
    ManageSubscriptionButton.swift  (new -- opens System Settings)
  ViewModifiers/
    ProGateModifier.swift           (new -- view modifier for gating)
```

### Data Flow

```
App Launch
  -> ProStatusManager.init()
    -> Task: listenForTransactions() (long-lived)
    -> Task: refreshStatus()
      -> Transaction.currentEntitlements / SubscriptionInfo.Status
      -> Sets isProUnlocked

User Taps Pro Feature
  -> View checks proStatus.isUnlocked(.feature)
  -> If false: present PaywallView(feature:)
  -> PaywallView loads products, shows plans
  -> User purchases -> product.purchase()
  -> PurchaseResult.success -> verify -> finish -> refreshStatus
  -> isProUnlocked = true -> dismiss paywall

Background
  -> Transaction.updates fires on renewal/expiration/refund
  -> refreshStatus() updates isProUnlocked
  -> UI reacts automatically via @Observable
```

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| StoreKit 2 API patterns | HIGH | Stable API since 2021, well-documented |
| macOS-specific gotchas | HIGH | Based on established platform differences |
| App Store review requirements | HIGH | Fetched directly from Apple guidelines |
| Rejection reasons | HIGH | Well-documented community patterns |
| Pricing recommendations | MEDIUM | Market-dependent, based on indie app trends |
| SubscriptionStoreView macOS availability | MEDIUM | Training data says unavailable; verify against latest Xcode 16/17 |
| Feature gating patterns | HIGH | Standard architecture patterns |

## Gaps to Address

- **Exact macOS 15+ API surface for SubscriptionStoreView** -- verify whether WWDC 2025 or later added macOS support. If available, it could replace the custom PaywallView.
- **App Store Connect product setup** -- actual configuration needs to happen in App Store Connect dashboard (cannot be researched, must be done)
- **Win-back offer strategies** -- defer to post-launch; not needed for v1.0
- **Family Sharing configuration** -- decide whether Pro should be shareable via Family Sharing (adds complexity, consider post-launch)

## Sources

- Apple App Store Review Guidelines Section 3 (fetched 2026-03-14) -- HIGH confidence
- StoreKit 2 framework knowledge (API stable since WWDC 2021, updates through WWDC 2024) -- HIGH confidence
- Existing Pault codebase analysis (`ProStatusManager.swift`, `PaywallView.swift`, `ProBadge.swift`) -- direct source
