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
    static let teamProductIDs = [
        "com.pault.team.monthly"
    ]

    private(set) var isProUnlocked: Bool = false
    private(set) var isTeamUnlocked: Bool = false
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
        availableProducts = (try? await Product.products(
            for: Self.proProductIDs + Self.teamProductIDs
        )) ?? []
    }

    private func refreshStatus() async {
        var hasPro = false
        var hasTeam = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue {
                if Self.proProductIDs.contains(transaction.productID) { hasPro = true }
                if Self.teamProductIDs.contains(transaction.productID) { hasTeam = true }
            }
        }
        isProUnlocked = hasPro
        isTeamUnlocked = hasTeam
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
