//
//  SmartCollectionTests.swift
//  PaultTests
//

import Testing
import SwiftData
import Foundation
@testable import Pault

@MainActor
struct SmartCollectionTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SmartCollection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func savedFilter_storesFilterJSON() throws {
        let context = try makeContext()
        let filter = SmartCollectionFilter(onlyFavorites: true, recentDays: 7)
        let collection = SmartCollection(name: "Favorites", icon: "star", filter: filter)
        context.insert(collection)
        try context.save()

        #expect(collection.ruleType == .savedFilter)
        #expect(!collection.filterJSON.isEmpty)
        #expect(collection.filterJSON != "{}")

        let roundTripped = collection.filter
        #expect(roundTripped != nil)
        #expect(roundTripped?.onlyFavorites == true)
    }

    @Test func aiCurated_storesPromptIDs() throws {
        let context = try makeContext()
        let ids = [UUID(), UUID(), UUID()]
        let collection = SmartCollection(name: "AI Pick", icon: "wand.and.stars", promptIDs: ids)
        context.insert(collection)
        try context.save()

        #expect(collection.ruleType == .aiCurated)
        #expect(collection.promptIDs.count == 3)
    }

    @Test func filter_returnsNilForAICurated() throws {
        let context = try makeContext()
        let collection = SmartCollection(name: "AI Pick", icon: "wand.and.stars", promptIDs: [UUID()])
        context.insert(collection)
        try context.save()

        #expect(collection.filter == nil)
    }

    @Test func sortOrder_defaultsToZero() throws {
        let context = try makeContext()
        let filter = SmartCollectionFilter()
        let collection = SmartCollection(name: "Default", icon: "folder", filter: filter)
        context.insert(collection)
        try context.save()

        #expect(collection.sortOrder == 0)
    }
}
