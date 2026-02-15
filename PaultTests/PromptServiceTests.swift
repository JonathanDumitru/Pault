//
//  PromptServiceTests.swift
//  PaultTests
//

import Testing
import SwiftData
import AppKit
@testable import Pault

@MainActor
struct PromptServiceTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - createPrompt

    @Test func createPromptInsertsWithDefaults() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt()
        #expect(prompt.title == "")
        #expect(prompt.content == "")
        #expect(!prompt.isFavorite)
        #expect(!prompt.isArchived)
    }

    @Test func createPromptTrimsWhitespace() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "  Hello  ", content: "\nWorld\n")
        #expect(prompt.title == "Hello")
        #expect(prompt.content == "World")
    }

    @Test func createPromptPersists() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        _ = service.createPrompt(title: "Test", content: "Body")

        let descriptor = FetchDescriptor<Prompt>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.title == "Test")
    }

    // MARK: - deletePrompt

    @Test func deletePromptRemovesFromContext() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "To Delete", content: "")
        service.deletePrompt(prompt)

        let descriptor = FetchDescriptor<Prompt>()
        let results = try context.fetch(descriptor)
        #expect(results.isEmpty)
    }

    // MARK: - toggleFavorite

    @Test func toggleFavoriteFlipsFlag() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "")
        #expect(!prompt.isFavorite)

        service.toggleFavorite(prompt)
        #expect(prompt.isFavorite)

        service.toggleFavorite(prompt)
        #expect(!prompt.isFavorite)
    }

    @Test func toggleFavoriteUpdatesTimestamp() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "")
        let before = prompt.updatedAt

        Thread.sleep(forTimeInterval: 0.01)
        service.toggleFavorite(prompt)

        #expect(prompt.updatedAt > before)
    }

    // MARK: - toggleArchive

    @Test func toggleArchiveFlipsFlag() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "")
        #expect(!prompt.isArchived)

        service.toggleArchive(prompt)
        #expect(prompt.isArchived)

        service.toggleArchive(prompt)
        #expect(!prompt.isArchived)
    }

    // MARK: - Tag operations

    @Test func addTagAppendsToPrompt() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "")
        let tag = service.createTag(name: "Work")

        service.addTag(tag, to: prompt)
        #expect(prompt.tags.count == 1)
        #expect(prompt.tags.first?.name == "Work")
    }

    @Test func addTagPreventsDuplicates() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "")
        let tag = service.createTag(name: "Work")

        service.addTag(tag, to: prompt)
        service.addTag(tag, to: prompt) // duplicate
        #expect(prompt.tags.count == 1)
    }

    @Test func removeTagRemovesFromPrompt() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "")
        let tag = service.createTag(name: "Work")

        service.addTag(tag, to: prompt)
        service.removeTag(tag, from: prompt)
        #expect(prompt.tags.isEmpty)
    }

    // MARK: - createTag

    @Test func createTagPersists() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let tag = service.createTag(name: "Personal", color: "red")
        #expect(tag.name == "Personal")
        #expect(tag.color == "red")

        let descriptor = FetchDescriptor<Pault.Tag>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
    }

    @Test func createTagDeduplicatesCaseInsensitive() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let tag1 = service.createTag(name: "Work")
        let tag2 = service.createTag(name: "work")
        let tag3 = service.createTag(name: "WORK")

        #expect(tag1.id == tag2.id)
        #expect(tag2.id == tag3.id)

        let descriptor = FetchDescriptor<Pault.Tag>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
    }

    @Test func createTagTrimsName() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let tag = service.createTag(name: "  Spaced  ")
        #expect(tag.name == "Spaced")
    }

    // MARK: - copyToClipboard

    @Test func copyToClipboardSetsPlainText() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "Hello World")
        service.copyToClipboard(prompt)

        let pasteboard = NSPasteboard.general
        let text = pasteboard.string(forType: .string)
        #expect(text == "Hello World")
    }

    @Test func copyToClipboardResolvesTemplateVariables() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "Hi {{name}}")
        let variable = TemplateVariable(name: "name", defaultValue: "Alice")
        context.insert(variable)
        prompt.templateVariables.append(variable)

        service.copyToClipboard(prompt)

        let pasteboard = NSPasteboard.general
        let text = pasteboard.string(forType: .string)
        #expect(text == "Hi Alice")
    }

    @Test func copyToClipboardUpdatesLastUsedAt() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let prompt = service.createPrompt(title: "Test", content: "Content")
        #expect(prompt.lastUsedAt == nil)

        service.copyToClipboard(prompt)
        #expect(prompt.lastUsedAt != nil)
    }

    // MARK: - filterPrompts

    @Test func filterExcludesArchivedByDefault() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let p1 = service.createPrompt(title: "Active", content: "")
        let p2 = service.createPrompt(title: "Archived", content: "")
        p2.isArchived = true
        try context.save()

        let result = service.filterPrompts([p1, p2])
        #expect(result.count == 1)
        #expect(result.first?.title == "Active")
    }

    @Test func filterShowsArchivedWhenRequested() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let p1 = service.createPrompt(title: "Active", content: "")
        let p2 = service.createPrompt(title: "Archived", content: "")
        p2.isArchived = true

        let result = service.filterPrompts([p1, p2], showArchived: true)
        #expect(result.count == 1)
        #expect(result.first?.title == "Archived")
    }

    @Test func filterFavoritesOnly() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let p1 = service.createPrompt(title: "Regular", content: "")
        let p2 = service.createPrompt(title: "Faved", content: "")
        p2.isFavorite = true

        let result = service.filterPrompts([p1, p2], showOnlyFavorites: true)
        #expect(result.count == 1)
        #expect(result.first?.title == "Faved")
    }

    @Test func filterRecentSortsAndCaps() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        var prompts: [Prompt] = []
        for i in 0..<5 {
            let p = service.createPrompt(title: "P\(i)", content: "")
            p.lastUsedAt = Date().addingTimeInterval(Double(i) * 60)
            prompts.append(p)
        }

        let result = service.filterPrompts(prompts, showOnlyRecent: true, recentLimit: 3)
        #expect(result.count == 3)
        #expect(result[0].title == "P4")
        #expect(result[1].title == "P3")
        #expect(result[2].title == "P2")
    }

    @Test func filterRecentExcludesNeverUsed() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let p1 = service.createPrompt(title: "Used", content: "")
        p1.lastUsedAt = Date()
        let p2 = service.createPrompt(title: "Never", content: "")

        let result = service.filterPrompts([p1, p2], showOnlyRecent: true)
        #expect(result.count == 1)
        #expect(result.first?.title == "Used")
    }

    @Test func filterByTag() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let tag = service.createTag(name: "Work")
        let p1 = service.createPrompt(title: "Tagged", content: "")
        let p2 = service.createPrompt(title: "Untagged", content: "")
        service.addTag(tag, to: p1)

        let result = service.filterPrompts([p1, p2], tagFilter: tag)
        #expect(result.count == 1)
        #expect(result.first?.title == "Tagged")
    }

    @Test func filterBySearchTextMatchesTitle() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let p1 = service.createPrompt(title: "Meeting Notes", content: "")
        let p2 = service.createPrompt(title: "Shopping List", content: "")

        let result = service.filterPrompts([p1, p2], searchText: "meeting")
        #expect(result.count == 1)
        #expect(result.first?.title == "Meeting Notes")
    }

    @Test func filterBySearchTextMatchesContent() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let p1 = service.createPrompt(title: "A", content: "Hello world")
        let p2 = service.createPrompt(title: "B", content: "Goodbye moon")

        let result = service.filterPrompts([p1, p2], searchText: "hello")
        #expect(result.count == 1)
        #expect(result.first?.title == "A")
    }

    @Test func filterBySearchTextMatchesTagName() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let tag = service.createTag(name: "Urgent")
        let p1 = service.createPrompt(title: "A", content: "")
        let p2 = service.createPrompt(title: "B", content: "")
        service.addTag(tag, to: p1)

        let result = service.filterPrompts([p1, p2], searchText: "urgent")
        #expect(result.count == 1)
        #expect(result.first?.title == "A")
    }

    @Test func filterMaxResultsCaps() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        var prompts: [Prompt] = []
        for i in 0..<10 {
            prompts.append(service.createPrompt(title: "P\(i)", content: ""))
        }

        let result = service.filterPrompts(prompts, maxResults: 3)
        #expect(result.count == 3)
    }

    @Test func filterEmptyInputReturnsEmpty() throws {
        let context = try makeContext()
        let service = PromptService(modelContext: context)

        let result = service.filterPrompts([])
        #expect(result.isEmpty)
    }
}
