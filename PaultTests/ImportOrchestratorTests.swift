//
//  ImportOrchestratorTests.swift
//  PaultTests
//

import Testing
import XCTest
import SwiftData
@testable import Pault

@MainActor
struct ImportOrchestratorTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        try TestHelpers.makeTestModelContext()
    }

    private func makeService(context: ModelContext) -> PromptService {
        PromptService(modelContext: context)
    }

    /// Creates a PromptExportBundle JSON Data with the given records.
    private func bundleData(records: [PromptExportRecord]) throws -> Data {
        let bundle = PromptExportBundle(
            version: 2,
            exportedAt: Date().timeIntervalSince1970,
            prompts: records
        )
        return try JSONEncoder().encode(bundle)
    }

    private func makeRecord(
        id: String = UUID().uuidString,
        title: String = "Test Prompt",
        content: String = "Hello {{name}}",
        tags: [String] = [],
        variables: [VariableExportRecord] = []
    ) -> PromptExportRecord {
        PromptExportRecord(
            id: id,
            title: title,
            content: content,
            isFavorite: false,
            isArchived: false,
            createdAt: Date().timeIntervalSince1970,
            updatedAt: Date().timeIntervalSince1970,
            tags: tags,
            templateVariables: variables
        )
    }

    // MARK: - prepare with JSON bundle

    @Test func prepare_json_returnsDuplicateAndNewCandidates() throws {
        let context = try makeContext()

        // Insert an existing prompt so one record becomes a duplicate
        let existingID = UUID()
        let existing = Prompt(id: existingID, title: "Existing", content: "Old content")
        context.insert(existing)
        try context.save()

        let records = [
            makeRecord(id: existingID.uuidString, title: "Existing Updated", content: "New content"),
            makeRecord(title: "New Prompt 1"),
            makeRecord(title: "New Prompt 2")
        ]
        let data = try bundleData(records: records)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-import-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = ImportOrchestrator.prepare(jsonURLs: [url], markdownURLs: [], context: context)

        #expect(session != nil)
        let candidates = session!.records
        #expect(candidates.count == 3)

        let duplicates = candidates.filter { $0.existing != nil }
        let newOnes = candidates.filter { $0.existing == nil }
        #expect(duplicates.count == 1, "Expected 1 duplicate")
        #expect(newOnes.count == 2, "Expected 2 new prompts")
    }

    // MARK: - applyImport with skip

    @Test func applyImport_skipDuplicate_insertsOnlyNew() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let existingID = UUID()
        let existing = Prompt(id: existingID, title: "Existing", content: "Old")
        context.insert(existing)
        try context.save()

        let records = [
            makeRecord(id: existingID.uuidString, title: "Existing", content: "Updated"),
            makeRecord(title: "New One"),
            makeRecord(title: "New Two")
        ]
        let data = try bundleData(records: records)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-skip-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var session = ImportOrchestrator.prepare(jsonURLs: [url], markdownURLs: [], context: context)!
        // Set duplicate to skip
        for i in session.records.indices {
            if session.records[i].existing != nil {
                session.records[i].resolution = .skip
            }
        }

        let result = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        #expect(result.imported == 2, "Should have imported 2 new prompts")
        #expect(result.skipped == 1, "Should have skipped 1 duplicate")
        #expect(result.overwritten == 0)

        // Verify existing prompt is unchanged
        let descriptor = FetchDescriptor<Prompt>()
        let allPrompts = try context.fetch(descriptor)
        let existingAfter = allPrompts.first(where: { $0.id == existingID })
        #expect(existingAfter?.content == "Old", "Existing prompt should be unchanged")
    }

    // MARK: - applyImport with overwrite

    @Test func applyImport_overwriteDuplicate_snapshotsBeforeUpdate() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let existingID = UUID()
        let existing = Prompt(id: existingID, title: "Existing", content: "Old content")
        context.insert(existing)
        try context.save()

        let records = [
            makeRecord(id: existingID.uuidString, title: "Updated Title", content: "New content")
        ]
        let data = try bundleData(records: records)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-overwrite-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var session = ImportOrchestrator.prepare(jsonURLs: [url], markdownURLs: [], context: context)!
        for i in session.records.indices {
            if session.records[i].existing != nil {
                session.records[i].resolution = .overwrite
            }
        }

        let versionsBefore = (try? context.fetch(FetchDescriptor<PromptVersion>())) ?? []
        let versionCountBefore = versionsBefore.filter { $0.prompt?.id == existingID }.count

        let result = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        #expect(result.overwritten == 1)
        #expect(result.imported == 0)

        // Verify snapshot was created
        let versionsAfter = (try? context.fetch(FetchDescriptor<PromptVersion>())) ?? []
        let versionCountAfter = versionsAfter.filter { $0.prompt?.id == existingID }.count
        #expect(versionCountAfter > versionCountBefore, "saveSnapshot should have been called before overwrite")

        // Verify content was updated
        let allPrompts = try context.fetch(FetchDescriptor<Prompt>())
        let updatedPrompt = allPrompts.first(where: { $0.id == existingID })
        #expect(updatedPrompt?.content == "New content")
        #expect(updatedPrompt?.title == "Updated Title")

        // Verify snapshot has the "Before import overwrite" note
        let overwriteVersion = versionsAfter.first(where: {
            $0.prompt?.id == existingID && $0.changeNote == "Before import overwrite"
        })
        #expect(overwriteVersion != nil, "Should have a version with 'Before import overwrite' note")
    }

    // MARK: - applyImport with keepBoth

    @Test func applyImport_keepBoth_createsFreshUUIDWithImportedSuffix() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let existingID = UUID()
        let existing = Prompt(id: existingID, title: "My Prompt", content: "Original")
        context.insert(existing)
        try context.save()

        let records = [
            makeRecord(id: existingID.uuidString, title: "My Prompt", content: "Updated version")
        ]
        let data = try bundleData(records: records)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-keepboth-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var session = ImportOrchestrator.prepare(jsonURLs: [url], markdownURLs: [], context: context)!
        for i in session.records.indices {
            if session.records[i].existing != nil {
                session.records[i].resolution = .keepBoth
            }
        }

        let result = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        #expect(result.imported == 1, "keepBoth should count as imported")

        let allPrompts = try context.fetch(FetchDescriptor<Prompt>())
        #expect(allPrompts.count == 2, "Should now have 2 prompts")

        let newPrompt = allPrompts.first(where: { $0.id != existingID })
        #expect(newPrompt != nil)
        #expect(newPrompt!.title.contains("(Imported)"), "New prompt title should contain '(Imported)'")
        #expect(newPrompt!.id != existingID, "New prompt should have a fresh UUID")
        #expect(newPrompt!.content == "Updated version")
    }

    // MARK: - partial import with malformed records

    @Test func applyImport_malformedUUID_skipsInvalidRecord() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let validRecord = makeRecord(title: "Valid Prompt", content: "Good content")
        let invalidRecord = PromptExportRecord(
            id: "not-a-valid-uuid",
            title: "Invalid Prompt",
            content: "Bad content",
            isFavorite: false,
            isArchived: false,
            createdAt: Date().timeIntervalSince1970,
            updatedAt: Date().timeIntervalSince1970,
            tags: [],
            templateVariables: []
        )

        let bundle = PromptExportBundle(
            version: 2,
            exportedAt: Date().timeIntervalSince1970,
            prompts: [invalidRecord, validRecord]
        )
        let data = try JSONEncoder().encode(bundle)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-malformed-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = ImportOrchestrator.prepare(jsonURLs: [url], markdownURLs: [], context: context)!
        let result = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        // Only the valid record should be imported; malformed one skipped during prepare
        #expect(result.imported == 1, "Only valid record should be imported")

        let allPrompts = try context.fetch(FetchDescriptor<Prompt>())
        #expect(allPrompts.count == 1, "Only 1 valid prompt should be in context")
        #expect(allPrompts.first?.title == "Valid Prompt")
    }

    // MARK: - Markdown import variable auto-detection

    @Test func markdownImport_autoDetectsVariables() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let markdown = """
---
id: \(UUID().uuidString)
title: "Template with vars"
tags: []
favorite: false
archived: false
created_at: 2026-01-01T00:00:00Z
updated_at: 2026-01-01T00:00:00Z
---

# Template with vars

Hello {{name}}, your role is {{role}}.
"""
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-vars-\(UUID()).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = ImportOrchestrator.prepare(jsonURLs: [], markdownURLs: [url], context: context)!
        let result = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        #expect(result.imported == 1)

        let vars = try context.fetch(FetchDescriptor<TemplateVariable>())
        let varNames = Set(vars.map(\.name))
        #expect(varNames.contains("name"), "Should have auto-detected 'name' variable")
        #expect(varNames.contains("role"), "Should have auto-detected 'role' variable")
    }

    // MARK: - Markdown import parses correctly

    @Test func prepareMarkdown_parsesFilesIntoSession() throws {
        let context = try makeContext()

        let markdown = """
---
id: \(UUID().uuidString)
title: "Markdown Prompt"
tags: ["swift", "tools"]
favorite: true
archived: false
created_at: 2026-01-01T00:00:00Z
updated_at: 2026-01-02T00:00:00Z
---

# Markdown Prompt

This is the content.
"""
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-md-parse-\(UUID()).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = ImportOrchestrator.prepare(jsonURLs: [], markdownURLs: [url], context: context)

        #expect(session != nil)
        #expect(session!.records.count == 1)
        let candidate = session!.records[0]
        #expect(candidate.incoming.title == "Markdown Prompt")
        #expect(candidate.incoming.isFavorite == true)
        #expect(candidate.incoming.tags == ["swift", "tools"])
    }

    // MARK: - Tag resolution (case-insensitive)

    @Test func applyImport_tagResolution_reusesCaseInsensitive() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        // Pre-insert a tag with lowercase name
        let existingTag = Pault.Tag(name: "swift")
        context.insert(existingTag)
        try context.save()

        let records = [
            makeRecord(title: "Tagged Prompt", content: "Body", tags: ["Swift"])  // Capital S
        ]
        let data = try bundleData(records: records)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-tags-\(UUID()).json")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = ImportOrchestrator.prepare(jsonURLs: [url], markdownURLs: [], context: context)!
        let result = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        #expect(result.imported == 1)

        let allTags = try context.fetch(FetchDescriptor<Pault.Tag>())
        #expect(allTags.count == 1, "Should reuse existing tag, not create duplicate")
        #expect(allTags.first?.name == "swift")
    }

    // MARK: - frontmatter variables merge with auto-detected

    @Test func applyImport_frontmatterVariablesMergeProperly() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let markdown = """
---
id: \(UUID().uuidString)
title: "Mixed vars"
tags: []
favorite: false
archived: false
created_at: 2026-01-01T00:00:00Z
updated_at: 2026-01-01T00:00:00Z
variables:
  - name: "defined_var"
    default: "default_value"
---

# Mixed vars

Hello {{defined_var}} and also {{auto_var}}.
"""
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-mixed-vars-\(UUID()).md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let session = ImportOrchestrator.prepare(jsonURLs: [], markdownURLs: [url], context: context)!
        _ = ImportOrchestrator.applyImport(session: session, context: context, promptService: service)

        let vars = try context.fetch(FetchDescriptor<TemplateVariable>())
        let varNames = Set(vars.map(\.name))

        #expect(varNames.contains("defined_var"), "Frontmatter-defined var should exist")
        #expect(varNames.contains("auto_var"), "Auto-detected var should exist")

        let definedVar = vars.first(where: { $0.name == "defined_var" })
        #expect(definedVar?.defaultValue == "default_value", "Frontmatter variable should have correct default value")
    }
}
