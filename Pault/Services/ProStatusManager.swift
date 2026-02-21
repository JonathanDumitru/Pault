// Pault/Services/ProStatusManager.swift
import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class ProStatusManager {
    static let shared = ProStatusManager()

    static let proProductIDs = [
        "com.pault.pro.monthly",
        "com.pault.pro.annual"
    ]

    private(set) var isProUnlocked: Bool = false
    private(set) var availableProducts: [Product] = []

    nonisolated(unsafe) private var transactionListener: Task<Void, Error>?

    init() {
        transactionListener = Task {
            await listenForTransactions()
        }
        Task { await refreshStatus() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            await refreshStatus()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshStatus()
    }

    func loadProducts() async {
        availableProducts = (try? await Product.products(for: Self.proProductIDs)) ?? []
    }

    private func refreshStatus() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                if Self.proProductIDs.contains(transaction.productID) { hasPro = true }
            }
        }
        isProUnlocked = hasPro
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? result.payloadValue {
                await transaction.finish()
                await refreshStatus()
            }
        }
    }
}
