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
    @State private var selectedProductID = "com.pault.pro.monthly"
    @State private var purchaseError: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            // Header
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

            // Product picker
            if !proStatus.availableProducts.isEmpty {
                Picker("Plan", selection: $selectedProductID) {
                    ForEach(proStatus.availableProducts.filter {
                        ProStatusManager.proProductIDs.contains($0.id)
                    }) { product in
                        Text("\(product.displayName) — \(product.displayPrice)").tag(product.id)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            // CTA
            Button {
                Task { await purchaseSelected() }
            } label: {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Start 7-Day Free Trial")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 280)
            .disabled(isLoading)

            if let error = purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

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
        .padding(32)
        .frame(width: 400, height: 440)
        .task { await proStatus.loadProducts() }
    }

    private func purchaseSelected() async {
        guard let product = proStatus.availableProducts.first(where: { $0.id == selectedProductID })
        else { return }
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
