// Pault/Services/ProStatusManager.swift
import Foundation
import StoreKit
import Observation
import os

@MainActor
@Observable
final class ProStatusManager {
    static let shared = ProStatusManager()

    /// Single annual product — monthly offering removed.
    static let proProductID = "com.pault.pro.annual"

    private static let logger = Logger(subsystem: "com.pault", category: "StoreKit")

    private(set) var isProUnlocked: Bool = false
    private(set) var currentTransactionJWS: String?
    private(set) var availableProducts: [Product] = []
    private var lastJWSRefresh: Date?

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
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshStatus()
                return true
            case .unverified(let transaction, let error):
                Self.logger.error("Unverified purchase \(transaction.id): \(error.localizedDescription)")
                return false
            }
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
        availableProducts = (try? await Product.products(for: [Self.proProductID])) ?? []
    }

    func refreshStatus() async {
        var hasPro = false
        var latestJWS: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                if case .unverified(let transaction, let error) = result {
                    Self.logger.error("Unverified entitlement \(transaction.id): \(error.localizedDescription)")
                }
                continue
            }
            if transaction.productID == Self.proProductID {
                hasPro = true
                latestJWS = result.jwsRepresentation
            }
        }
        isProUnlocked = hasPro
        currentTransactionJWS = latestJWS
        lastJWSRefresh = Date()
    }

    func refreshJWSIfNeeded() async {
        if currentTransactionJWS == nil || lastJWSRefresh == nil || Date().timeIntervalSince(lastJWSRefresh!) > 60 {
            await refreshStatus()
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await transaction.finish()
                await refreshStatus()
            case .unverified(let transaction, let error):
                Self.logger.error("Unverified transaction update \(transaction.id): \(error.localizedDescription)")
            }
        }
    }
}
