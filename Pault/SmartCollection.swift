//
//  SmartCollection.swift
//  Pault
//

import Foundation
import SwiftData

enum CollectionRuleType: String, Codable {
    case savedFilter
    case aiCurated
}

struct SmartCollectionFilter: Codable {
    var tagIDs: [UUID]
    var onlyFavorites: Bool
    var recentDays: Int?     // nil = no recency filter

    init(tags: [Tag] = [], onlyFavorites: Bool = false, recentDays: Int? = nil) {
        self.tagIDs = tags.map(\.id)
        self.onlyFavorites = onlyFavorites
        self.recentDays = recentDays
    }
}

@Model
final class SmartCollection {
    var id: UUID
    var name: String
    var icon: String
    var sortOrder: Int
    var ruleType: CollectionRuleType
    var filterJSON: String          // JSON-encoded SmartCollectionFilter for .savedFilter
    var promptIDs: [UUID]           // cached prompt IDs for .aiCurated
    var createdAt: Date
    var lastRefreshed: Date?

    // Saved filter initializer
    init(name: String, icon: String, filter: SmartCollectionFilter, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.ruleType = .savedFilter
        self.filterJSON = (try? String(data: JSONEncoder().encode(filter), encoding: .utf8)) ?? "{}"
        self.promptIDs = []
        self.createdAt = Date()
    }

    // AI-curated initializer
    init(name: String, icon: String, promptIDs: [UUID], sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.ruleType = .aiCurated
        self.filterJSON = "{}"
        self.promptIDs = promptIDs
        self.createdAt = Date()
    }

    var filter: SmartCollectionFilter? {
        guard ruleType == .savedFilter,
              let data = filterJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SmartCollectionFilter.self, from: data)
    }
}
