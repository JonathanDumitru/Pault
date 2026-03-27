// Pault/Views/PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    let featureName: String
    let featureDescription: String
    let featureIcon: String

    @Environment(\.dismiss) private var dismiss
    @State private var proStatus = ProStatusManager.shared
    @State private var isLoading = false
    @State private var isLoadingProducts = true
    @State private var purchaseError: String? = nil
    @State private var ctaText: String = "Subscribe"
    @State private var isEligibleForTrial: Bool = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                proFeaturesSection
                comparisonGridSection
                ctaSection
                disclosureSection
                legalLinksSection
                restoreSection
            }
            .padding(32)
        }
        .frame(width: 420)
        .task { await loadProducts() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: featureIcon)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                )

            HStack(spacing: 8) {
                Text("Unlock \(featureName)")
                    .font(.title2)
                    .fontWeight(.bold)
                ProBadge()
            }

            Text(featureDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }

    // MARK: - Pro Features List

    private var proFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Everything in Pro")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(ProFeature.allCases, id: \.self) { feature in
                HStack(spacing: 10) {
                    Image(systemName: feature.sfSymbol)
                        .foregroundStyle(
                            featureName == feature.displayName
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.secondary, .secondary], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: 20)

                    Text(feature.displayName)
                        .font(.subheadline)
                        .fontWeight(featureName == feature.displayName ? .semibold : .regular)
                        .foregroundStyle(featureName == feature.displayName ? .primary : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Free vs Pro Comparison Grid

    private var comparisonGridSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Feature")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .center)
                Text("Pro")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 44, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .separatorColor).opacity(0.1))

            Divider()

            comparisonRow(name: "Prompt CRUD", freeCheck: true, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Templates & Tags", freeCheck: true, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Search & Surfaces", freeCheck: true, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Block Editor (5 blocks)", freeCheck: true, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "AI Assist", freeCheck: false, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Versioning", freeCheck: false, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Analytics", freeCheck: false, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "API Runner", freeCheck: false, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Smart Collections", freeCheck: false, proCheck: true)
            Divider().padding(.horizontal, 12)
            comparisonRow(name: "Unlimited Blocks", freeCheck: false, proCheck: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private func comparisonRow(name: String, freeCheck: Bool, proCheck: Bool) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            checkmark(filled: freeCheck)
                .frame(width: 44, alignment: .center)
            checkmark(filled: proCheck, usePro: true)
                .frame(width: 44, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func checkmark(filled: Bool, usePro: Bool = false) -> some View {
        if filled {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(
                    usePro
                        ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.secondary, .secondary], startPoint: .leading, endPoint: .trailing)
                )
        } else {
            Image(systemName: "xmark.circle")
                .foregroundStyle(Color.secondary.opacity(0.4))
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Group {
                if isLoadingProducts {
                    ProgressView()
                        .controlSize(.regular)
                        .frame(height: 44)
                } else if proStatus.availableProducts.isEmpty {
                    VStack(spacing: 8) {
                        Text("Could not load plans.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await loadProducts() }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .frame(height: 44)
                } else {
                    Button {
                        Task { await purchaseSelected() }
                    } label: {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(ctaText)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 320)
                    .disabled(isLoading)
                }
            }

            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
    }

    // MARK: - Auto-renewal Disclosure (Apple Schedule 2 Required)

    private var disclosureSection: some View {
        VStack(spacing: 6) {
            if let product = proStatus.availableProducts.first {
                Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Payment will be charged to your Apple ID account at \(product.displayPrice)/year. Manage or cancel anytime in System Settings > Apple ID > Subscriptions.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Payment will be charged to your Apple ID account. Manage or cancel anytime in System Settings > Apple ID > Subscriptions.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 340)
    }

    // MARK: - Legal Links

    private var legalLinksSection: some View {
        HStack(spacing: 16) {
            Link("Privacy Policy", destination: URL(string: "https://pault.app/privacy")!)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("·")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link("Terms of Service", destination: URL(string: "https://pault.app/terms")!)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        Button("Restore Purchases") {
            Task {
                await proStatus.restorePurchases()
                if proStatus.isProUnlocked { dismiss() }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadProducts() async {
        isLoadingProducts = true
        await proStatus.loadProducts()

        // Compute dynamic CTA text from introductory offer
        if let product = proStatus.availableProducts.first,
           let subscription = product.subscription {
            let eligible = await subscription.isEligibleForIntroOffer
            isEligibleForTrial = eligible
            if eligible, let offer = subscription.introductoryOffer {
                switch offer.paymentMode {
                case .freeTrial:
                    let period = periodLabel(offer.period)
                    ctaText = "Start \(period) Free Trial"
                case .payAsYouGo:
                    let period = periodLabel(offer.period)
                    ctaText = "Start for \(offer.displayPrice)/\(period)"
                default:
                    ctaText = "Subscribe for \(product.displayPrice)/year"
                }
            } else {
                ctaText = "Subscribe for \(product.displayPrice)/year"
            }
        }

        isLoadingProducts = false
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day:   return value == 1 ? "1-Day" : "\(value)-Day"
        case .week:  return value == 1 ? "1-Week" : "\(value)-Week"
        case .month: return value == 1 ? "1-Month" : "\(value)-Month"
        case .year:  return value == 1 ? "1-Year" : "\(value)-Year"
        @unknown default: return "\(value) period"
        }
    }

    private func purchaseSelected() async {
        guard let product = proStatus.availableProducts.first else { return }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let success = try await proStatus.purchase(product)
            if success { dismiss() }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

#Preview {
    PaywallView(
        featureName: "AI Assist",
        featureDescription: "Improve prompts, suggest variables, and score quality using AI.",
        featureIcon: "sparkles"
    )
}
