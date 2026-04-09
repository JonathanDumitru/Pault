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
    let collectionName: String?

    init(version: Int, exportedAt: Double, prompts: [PromptExportRecord], collectionName: String? = nil) {
        self.version = version
        self.exportedAt = exportedAt
        self.prompts = prompts
        self.collectionName = collectionName
    }
}

struct PromptExportRecord: Codable {
    // v1 fields
    let id: String
    let title: String
    let content: String
    let isFavorite: Bool
    let isArchived: Bool
    let createdAt: Double
    let updatedAt: Double
    let tags: [String]
    let templateVariables: [VariableExportRecord]

    // v2 optional fields — nil when decoding v1 bundles (missing keys decode as nil)
    let blockCompositionData: Data?
    let qualityScore: Int?
    let lastUsedAt: Double?
    let editingModeRaw: String?
    let variantB: String?
    let attachmentFileNames: [String]?

    init(
        id: String,
        title: String,
        content: String,
        isFavorite: Bool,
        isArchived: Bool,
        createdAt: Double,
        updatedAt: Double,
        tags: [String],
        templateVariables: [VariableExportRecord],
        blockCompositionData: Data? = nil,
        qualityScore: Int? = nil,
        lastUsedAt: Double? = nil,
        editingModeRaw: String? = nil,
        variantB: String? = nil,
        attachmentFileNames: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.templateVariables = templateVariables
        self.blockCompositionData = blockCompositionData
        self.qualityScore = qualityScore
        self.lastUsedAt = lastUsedAt
        self.editingModeRaw = editingModeRaw
        self.variantB = variantB
        self.attachmentFileNames = attachmentFileNames
    }
}

struct VariableExportRecord: Codable {
    let name: String
    let defaultValue: String
    let sortOrder: Int
}

// MARK: - ExportService

enum ExportService {

    // MARK: - buildRecord

    /// Maps all Prompt fields (including v2 metadata) to a PromptExportRecord.
    static func buildRecord(from prompt: Prompt) -> PromptExportRecord {
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
                },
            blockCompositionData: prompt.blockCompositionData,
            qualityScore: prompt.qualityScore,
            lastUsedAt: prompt.lastUsedAt?.timeIntervalSince1970,
            editingModeRaw: prompt.editingModeRaw,
            variantB: prompt.variantB,
            attachmentFileNames: prompt.attachments.isEmpty ? nil : prompt.attachments
                .sorted { $0.sortOrder < $1.sortOrder }
                .map(\.filename)
        )
    }

    // MARK: - exportAll (backward-compatible: now produces v2 bundles)

    /// Encodes prompts into a v2 JSON bundle and presents NSSavePanel.
    /// Returns `true` if the file was written successfully, `false` if cancelled or an error occurred.
    @discardableResult
    static func exportAll(prompts: [Prompt]) -> Bool {
        exportLibraryJSON(prompts: prompts, collectionName: nil)
    }

    // MARK: - exportLibraryJSON

    /// Exports prompts as a v2 JSON bundle to a user-chosen file.
    /// - Parameters:
    ///   - prompts: Prompts to export.
    ///   - collectionName: Optional collection scope label (nil = library-wide).
    @discardableResult
    static func exportLibraryJSON(prompts: [Prompt], collectionName: String? = nil) -> Bool {
        let records = prompts.map { buildRecord(from: $0) }
        let bundle = PromptExportBundle(
            version: 2,
            exportedAt: Date().timeIntervalSince1970,
            prompts: records,
            collectionName: collectionName
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(bundle) else {
            exportLogger.error("exportLibraryJSON: Failed to encode prompts to JSON")
            return false
        }

        let defaultName: String
        if let name = collectionName {
            defaultName = "\(MarkdownFrontmatterParser.slugify(name, existing: [])).json"
        } else {
            defaultName = "pault-prompts.json"
        }

        let panel = NSSavePanel()
        panel.title = "Export Prompts"
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try data.write(to: url, options: .atomic)
            exportLogger.info("exportLibraryJSON: Exported \(records.count) prompts to \(url.lastPathComponent)")
            return true
        } catch {
            exportLogger.error("exportLibraryJSON: Write failed — \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - exportMarkdown

    /// Exports each prompt as an individual Markdown file with YAML frontmatter.
    /// Uses NSOpenPanel (folder picker) to let the user choose the destination folder.
    @discardableResult
    static func exportMarkdown(prompts: [Prompt]) -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.prompt = "Export Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folder = panel.url else { return false }

        var usedSlugs: Set<String> = []
        var writtenCount = 0

        for prompt in prompts {
            let record = buildRecord(from: prompt)
            let slug = MarkdownFrontmatterParser.slugify(record.title, existing: usedSlugs)
            usedSlugs.insert(slug)

            let markdown = MarkdownFrontmatterParser.serialize(record: record)
            let fileURL = folder.appendingPathComponent("\(slug).md")

            do {
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
                writtenCount += 1
            } catch {
                exportLogger.error("exportMarkdown: Failed to write \(slug).md — \(error.localizedDescription)")
            }
        }

        exportLogger.info("exportMarkdown: Wrote \(writtenCount) of \(prompts.count) prompts to \(folder.lastPathComponent)")
        return writtenCount > 0
    }

    // MARK: - copyAsMarkdown

    /// Copies a single prompt as Markdown with YAML frontmatter to the system clipboard.
    @discardableResult
    static func copyAsMarkdown(prompt: Prompt) -> Bool {
        let record = buildRecord(from: prompt)
        let markdown = MarkdownFrontmatterParser.serialize(record: record)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(markdown, forType: .string)

        if success {
            exportLogger.info("copyAsMarkdown: Copied prompt '\(prompt.title)' to clipboard")
        } else {
            exportLogger.error("copyAsMarkdown: Failed to write to clipboard")
        }
        return success
    }

    // MARK: - Import

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

    // MARK: - Private

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
