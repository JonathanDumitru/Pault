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
    var recentDays: Int?            // nil = no recency filter

    // Extended filter fields (Plan 05-03)
    var qualityScoreMin: Int?       // nil = no minimum quality score filter
    var qualityScoreMax: Int?       // nil = no maximum quality score filter
    var model: String?              // nil = any model; non-nil = filter by LLM model
    var lastUsedWithin: Int?        // nil = no recency filter; N = used within N days
    var contentContains: String?    // nil = no content search; non-nil = substring match

    init(
        tags: [Tag] = [],
        onlyFavorites: Bool = false,
        recentDays: Int? = nil,
        qualityScoreMin: Int? = nil,
        qualityScoreMax: Int? = nil,
        model: String? = nil,
        lastUsedWithin: Int? = nil,
        contentContains: String? = nil
    ) {
        self.tagIDs = tags.map(\.id)
        self.onlyFavorites = onlyFavorites
        self.recentDays = recentDays
        self.qualityScoreMin = qualityScoreMin
        self.qualityScoreMax = qualityScoreMax
        self.model = model
        self.lastUsedWithin = lastUsedWithin
        self.contentContains = contentContains
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
    var isPreset: Bool = false      // true for auto-seeded preset collections

    // Saved filter initializer
    init(name: String, icon: String, filter: SmartCollectionFilter, sortOrder: Int = 0, isPreset: Bool = false) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
        self.ruleType = .savedFilter
        self.filterJSON = (try? String(data: JSONEncoder().encode(filter), encoding: .utf8)) ?? "{}"
        self.promptIDs = []
        self.createdAt = Date()
        self.isPreset = isPreset
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
        self.isPreset = false
    }

    var filter: SmartCollectionFilter? {
        guard ruleType == .savedFilter,
              let data = filterJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SmartCollectionFilter.self, from: data)
    }

    // MARK: - Preset Seeding

    /// Creates the 3 default preset collections on first Pro unlock.
    /// Idempotent: no-ops if any presets already exist.
    @MainActor
    static func seedPresetCollections(in context: ModelContext) {
        guard ProFeature.isUnlocked(.smartCollections) else { return }

        // Guard against re-seeding
        let descriptor = FetchDescriptor<SmartCollection>()
        guard let all = try? context.fetch(descriptor) else { return }
        let presetCount = all.filter(\.isPreset).count
        guard presetCount == 0 else { return }

        let existingMax = all.map(\.sortOrder).max() ?? -1

        // 1. Most Used — top prompts by copy/run frequency (evaluated at display time)
        let mostUsed = SmartCollection(
            name: "Most Used",
            icon: "flame.fill",
            filter: SmartCollectionFilter(),
            sortOrder: existingMax + 1,
            isPreset: true
        )

        // 2. Recently Created — prompts created in the last 7 days
        let recentlyCreated = SmartCollection(
            name: "Recently Created",
            icon: "sparkles",
            filter: SmartCollectionFilter(recentDays: 7),
            sortOrder: existingMax + 2,
            isPreset: true
        )

        // 3. Stale Prompts — prompts NOT used in the last 30 days
        let stale = SmartCollection(
            name: "Stale Prompts",
            icon: "zzz",
            filter: SmartCollectionFilter(lastUsedWithin: 30),
            sortOrder: existingMax + 3,
            isPreset: true
        )

        context.insert(mostUsed)
        context.insert(recentlyCreated)
        context.insert(stale)
        try? context.save()
    }
}
