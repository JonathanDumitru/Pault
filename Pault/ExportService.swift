//
//  ExportService.swift
//  Pault
//

import SwiftUI
import SwiftData
import os
import UniformTypeIdentifiers

private let exportLogger = Logger(subsystem: "com.pault.app", category: "ExportService")

// MARK: - Codable DTOs

struct PromptExportBundle: Codable {
    let version: Int
    let exportedAt: Double
    let prompts: [PromptExportRecord]
}

struct PromptExportRecord: Codable {
    let id: String
    let title: String
    let content: String
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: Double
    let updatedAt: Double
    let tags: [String]
    let templateVariables: [VariableExportRecord]
}

struct VariableExportRecord: Codable {
    let name: String
    let defaultValue: String
    let sortOrder: Int
}

// MARK: - ExportService

enum ExportService {

    // MARK: Export

    /// Encodes prompts into a JSON bundle and presents NSSavePanel.
    /// Returns `true` if the file was written successfully, `false` if cancelled or an error occurred.
    @discardableResult
    static func exportAll(prompts: [Prompt]) -> Bool {
        let records = prompts.map { prompt in
            PromptExportRecord(
                id: prompt.id.uuidString,
                title: prompt.title,
                content: prompt.content,
                isFavorite: prompt.isFavorite,
                isArchived: prompt.isArchived,
                createdAt: prompt.createdAt.timeIntervalSince1970,
                updatedAt: prompt.updatedAt.timeIntervalSince1970,
                tags: prompt.tags.map(\.name),
                templateVariables: prompt.templateVariables
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map { v in
                        VariableExportRecord(
                            name: v.name,
                            defaultValue: v.defaultValue,
                            sortOrder: v.sortOrder
                        )
                    }
            )
        }

        let bundle = PromptExportBundle(
            version: 1,
            exportedAt: Date().timeIntervalSince1970,
            prompts: records
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(bundle) else {
            exportLogger.error("exportAll: Failed to encode prompts to JSON")
            return false
        }

        let panel = NSSavePanel()
        panel.title = "Export Prompts"
        panel.nameFieldStringValue = "pault-prompts.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try data.write(to: url, options: .atomic)
            exportLogger.info("exportAll: Exported \(records.count) prompts to \(url.lastPathComponent)")
            return true
        } catch {
            exportLogger.error("exportAll: Write failed — \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Import

    /// Presents NSOpenPanel, decodes bundle, inserts non-duplicate prompts into SwiftData context.
    /// Returns the count of newly inserted prompts, or nil if cancelled/failed.
    @discardableResult
    static func importPrompts(into context: ModelContext) -> Int? {
        let panel = NSOpenPanel()
        panel.title = "Import Prompts"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(PromptExportBundle.self, from: data)
            return insert(bundle.prompts, into: context)
        } catch {
            exportLogger.error("importPrompts: Decode failed — \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: Private

    private static func insert(_ records: [PromptExportRecord], into context: ModelContext) -> Int {
        // Fetch existing IDs to detect duplicates
        let existingIDs: Set<UUID> = {
            let descriptor = FetchDescriptor<Prompt>()
            let all = (try? context.fetch(descriptor)) ?? []
            return Set(all.map(\.id))
        }()

        var inserted = 0

        for record in records {
            guard let uuid = UUID(uuidString: record.id), !existingIDs.contains(uuid) else {
                exportLogger.debug("import: Skipping duplicate id \(record.id)")
                continue
            }

            let prompt = Prompt(
                id: uuid,
                title: record.title,
                content: record.content,
                isFavorite: record.isFavorite,
                isArchived: record.isArchived,
                createdAt: Date(timeIntervalSince1970: record.createdAt),
                updatedAt: Date(timeIntervalSince1970: record.updatedAt)
            )
            context.insert(prompt)

            // Resolve or create tags
            for tagName in record.tags {
                let tag = resolveTag(named: tagName, in: context)
                prompt.tags.append(tag)
            }

            // Insert template variables
            for (index, v) in record.templateVariables.enumerated() {
                let variable = TemplateVariable(
                    name: v.name,
                    defaultValue: v.defaultValue,
                    sortOrder: v.sortOrder,
                    occurrenceIndex: index
                )
                variable.prompt = prompt
                prompt.templateVariables.append(variable)
                context.insert(variable)
            }

            inserted += 1
        }

        do {
            try context.save()
            exportLogger.info("import: Inserted \(inserted) prompts")
        } catch {
            exportLogger.error("import: Save failed — \(error.localizedDescription)")
        }

        return inserted
    }

    private static func resolveTag(named name: String, in context: ModelContext) -> Tag {
        let lower = name.lowercased()
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.name == lower })
        if let existing = try? context.fetch(descriptor), let tag = existing.first {
            return tag
        }
        let tag = Tag(name: lower)
        context.insert(tag)
        return tag
    }
}
