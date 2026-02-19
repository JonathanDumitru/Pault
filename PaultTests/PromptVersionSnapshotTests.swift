//
//  PromptVersionSnapshotTests.swift
//  PaultTests
//

import Testing
import Foundation
import SwiftData
@testable import Pault

@MainActor
struct PromptVersionSnapshotTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
                CopyEvent.self, PromptRun.self, PromptVersion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - saveSnapshot_createsVersion

    @Test func saveSnapshot_createsVersion() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "My Prompt", content: "Hello")
        service.saveSnapshot(for: prompt)

        let descriptor = FetchDescriptor<PromptVersion>()
        let versions = try context.fetch(descriptor)
        #expect(versions.count == 1)
    }

    // MARK: - saveSnapshot_setsAllFields

    @Test func saveSnapshot_setsAllFields() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Title A", content: "Content A")
        service.saveSnapshot(for: prompt)

        let descriptor = FetchDescriptor<PromptVersion>()
        let versions = try context.fetch(descriptor)
        let version = try #require(versions.first)

        #expect(version.title == "Title A")
        #expect(version.content == "Content A")
        #expect(version.prompt?.id == prompt.id)
        #expect(version.changeNote == nil)
        #expect(version.savedAt <= Date())
    }

    // MARK: - saveSnapshot_withChangeNote

    @Test func saveSnapshot_withChangeNote() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Noted", content: "Body")
        service.saveSnapshot(for: prompt, changeNote: "Initial draft")

        let descriptor = FetchDescriptor<PromptVersion>()
        let versions = try context.fetch(descriptor)
        let version = try #require(versions.first)

        #expect(version.changeNote == "Initial draft")
    }

    // MARK: - saveSnapshot_prunesOldVersionsBeyondLimit

    @Test func saveSnapshot_prunesOldVersionsBeyondLimit() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "P", content: "v0")
        let base = Date(timeIntervalSince1970: 1_000_000)

        // Pre-insert 4 versions with distinct, ordered savedAt values to avoid
        // ties when sorted by savedAt (tight loops can produce identical Date() ticks).
        for i in 1...4 {
            let v = PromptVersion(
                prompt: prompt,
                title: "P",
                content: "v\(i)",
                savedAt: base.addingTimeInterval(Double(i)),
                changeNote: nil
            )
            context.insert(v)
        }

        // saveSnapshot adds v5 and prunes to keep only the 3 most recent
        prompt.content = "v5"
        service.saveSnapshot(for: prompt, limit: 3)

        let descriptor = FetchDescriptor<PromptVersion>(
            sortBy: [SortDescriptor(\.savedAt, order: .forward)]
        )
        let versions = try context.fetch(descriptor)
        #expect(versions.count == 3)

        let contents = versions.map(\.content)
        #expect(!contents.contains("v1"))
        #expect(!contents.contains("v2"))
        #expect(contents.contains("v3"))
        #expect(contents.contains("v4"))
        #expect(contents.contains("v5"))
    }

    // MARK: - saveSnapshot_keepsExactLimitVersions

    @Test func saveSnapshot_keepsExactLimitVersions() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "P", content: "v0")

        // Save exactly `limit` snapshots — no pruning should occur
        let limit = 3
        for i in 1...limit {
            prompt.content = "v\(i)"
            service.saveSnapshot(for: prompt, limit: limit)
        }

        let descriptor = FetchDescriptor<PromptVersion>()
        let versions = try context.fetch(descriptor)
        #expect(versions.count == limit)
    }
}
