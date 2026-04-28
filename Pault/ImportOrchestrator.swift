//
//  ImportOrchestrator.swift
//  Pault
//
//  Parses JSON and Markdown import files, detects duplicates by UUID,
//  and applies per-prompt conflict resolutions (skip / overwrite / keepBoth).
//

import Foundation
import SwiftData
import os

private let importLogger = Logger(subsystem: "com.pault.app", category: "ImportOrchestrator")

// MARK: - ConflictResolution

enum ConflictResolution: String, CaseIterable {
    case skip
    case overwrite
    case keepBoth
}

// MARK: - ImportCandidate

struct ImportCandidate: Identifiable {
    let id: UUID
    let incoming: PromptExportRecord
    var existing: Prompt?
    var resolution: ConflictResolution
    var isExpanded: Bool = false

    init(incoming: PromptExportRecord, existing: Prompt?) {
        self.id = UUID()
        self.incoming = incoming
        self.existing = existing
        // Duplicates default to skip; new prompts default to keepBoth (import as-is)
        self.resolution = existing != nil ? .skip : .keepBoth
    }
}

// MARK: - ImportSession

struct ImportSession: Identifiable {
    let id: UUID = UUID()
    var records: [ImportCandidate]
    var globalResolution: ConflictResolution? = nil
}

// MARK: - ImportResult

struct ImportResult {
    let imported: Int
    let overwritten: Int
    let skipped: Int
    let errors: Int
}

// MARK: - ImportOrchestrator

enum ImportOrchestrator {

    // MARK: - prepare

    /// Parses JSON and Markdown URLs, detects duplicates, and returns an ImportSession for preview.
    /// Returns nil if no parseable records are found or all files fail.
    static func prepare(
        jsonURLs: [URL],
        markdownURLs: [URL],
        context: ModelContext
    ) -> ImportSession? {
        var allRecords: [PromptExportRecord] = []

        // Parse JSON files
        for url in jsonURLs {
            allRecords.append(contentsOf: parseJSON(at: url))
        }

        // Parse Markdown files
        if !markdownURLs.isEmpty {
            allRecords.append(contentsOf: parseMarkdown(at: markdownURLs))
        }

        guard !allRecords.isEmpty else {
            importLogger.warning("prepare: No parseable records found")
            return nil
        }

        // Fetch all existing prompts to check for duplicates (UUID match only)
        let fetchDescriptor = FetchDescriptor<Prompt>()
        let existingPrompts = (try? context.fetch(fetchDescriptor)) ?? []
        let existingByID: [UUID: Prompt] = Dictionary(
            uniqueKeysWithValues: existingPrompts.map { ($0.id, $0) }
        )

        // Build candidates, filtering out truly malformed records (no valid UUID)
        var candidates: [ImportCandidate] = []
        for record in allRecords {
            guard UUID(uuidString: record.id) != nil else {
                importLogger.warning("prepare: Skipping record with invalid UUID: \(record.id)")
                continue
            }
            let uuid = UUID(uuidString: record.id)!
            let existing = existingByID[uuid]
            candidates.append(ImportCandidate(incoming: record, existing: existing))
        }

        guard !candidates.isEmpty else {
            return nil
        }

        return ImportSession(records: candidates)
    }

    // MARK: - parseJSON

    /// Decodes a PromptExportBundle (v1 or v2) from a JSON file. Returns an empty array on failure.
    static func parseJSON(at url: URL) -> [PromptExportRecord] {
        do {
            let data = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(PromptExportBundle.self, from: data)
            importLogger.info("parseJSON: Parsed \(bundle.prompts.count) records from \(url.lastPathComponent)")
            return bundle.prompts
        } catch {
            importLogger.error("parseJSON: Failed to parse \(url.lastPathComponent) — \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - parseMarkdown

    /// Parses an array of Markdown file URLs via MarkdownFrontmatterParser,
    /// converting each MarkdownImportRecord into a PromptExportRecord for uniform handling.
    static func parseMarkdown(at urls: [URL]) -> [PromptExportRecord] {
        var records: [PromptExportRecord] = []

        for url in urls {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let importRecord = MarkdownFrontmatterParser.parse(markdown: content, filename: url.lastPathComponent)

                // Convert MarkdownImportRecord to PromptExportRecord
                let id = importRecord.id ?? UUID().uuidString
                let record = PromptExportRecord(
                    id: id,
                    title: importRecord.title,
                    content: importRecord.content,
                    isFavorite: importRecord.isFavorite,
                    isArchived: importRecord.isArchived,
                    createdAt: importRecord.createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
                    updatedAt: importRecord.updatedAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
                    tags: importRecord.tags,
                    templateVariables: importRecord.variables.enumerated().map { index, v in
                        VariableExportRecord(name: v.name, defaultValue: v.defaultValue, sortOrder: index)
                    },
                    qualityScore: importRecord.qualityScore
                )
                records.append(record)
                importLogger.info("parseMarkdown: Parsed '\(importRecord.title)' from \(url.lastPathComponent)")
            } catch {
                importLogger.error("parseMarkdown: Failed to read \(url.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        return records
    }

    // MARK: - applyImport

    /// Applies all candidate resolutions to the SwiftData context.
    /// - skip: does nothing for that candidate
    /// - overwrite: saves snapshot, then updates existing prompt fields
    /// - keepBoth (for duplicates) or keepBoth (for new): inserts a new Prompt with a fresh UUID
    static func applyImport(
        session: ImportSession,
        context: ModelContext,
        promptService: PromptService
    ) -> ImportResult {
        var imported = 0
        var overwritten = 0
        var skipped = 0
        var errors = 0

        // In-memory tag cache to avoid redundant fetches
        var tagCache: [String: Tag] = [:]

        for candidate in session.records {
            let record = candidate.incoming

            switch candidate.resolution {
            case .skip:
                skipped += 1
                continue

            case .overwrite:
                guard let existingPrompt = candidate.existing else {
                    // No existing prompt to overwrite — treat as import
                    if let newPrompt = insertPrompt(from: record, context: context, tagCache: &tagCache) {
                        _ = newPrompt
                        imported += 1
                    } else {
                        errors += 1
                    }
                    continue
                }
                // Snapshot before overwrite
                promptService.saveSnapshot(
                    for: existingPrompt,
                    changeNote: "Before import overwrite",
                    source: .manual
                )
                // Apply incoming fields
                updatePrompt(existingPrompt, from: record, context: context, tagCache: &tagCache)
                overwritten += 1

            case .keepBoth:
                if candidate.existing != nil {
                    // Duplicate with keepBoth: create fresh copy with "(Imported)" suffix and new UUID
                    if let _ = insertPrompt(
                        from: record,
                        withFreshUUID: true,
                        titleSuffix: " (Imported)",
                        context: context,
                        tagCache: &tagCache
                    ) {
                        imported += 1
                    } else {
                        errors += 1
                    }
                } else {
                    // New prompt — insert preserving original UUID
                    if let _ = insertPrompt(from: record, context: context, tagCache: &tagCache) {
                        imported += 1
                    } else {
                        errors += 1
                    }
                }
            }
        }

        do {
            try context.save()
            importLogger.info("applyImport: imported=\(imported) overwritten=\(overwritten) skipped=\(skipped) errors=\(errors)")
        } catch {
            importLogger.error("applyImport: Save failed — \(error.localizedDescription)")
        }

        return ImportResult(
            imported: imported,
            overwritten: overwritten,
            skipped: skipped,
            errors: errors
        )
    }

    // MARK: - Private helpers

    /// Creates and inserts a new Prompt from a record. Returns the prompt or nil on failure.
    @discardableResult
    private static func insertPrompt(
        from record: PromptExportRecord,
        withFreshUUID: Bool = false,
        titleSuffix: String = "",
        context: ModelContext,
        tagCache: inout [String: Tag]
    ) -> Prompt? {
        guard let uuid = withFreshUUID ? Optional(UUID()) : UUID(uuidString: record.id) else {
            importLogger.warning("insertPrompt: Invalid UUID '\(record.id)' — skipping")
            return nil
        }

        let prompt = Prompt(
            id: uuid,
            title: record.title + titleSuffix,
            content: record.content,
            isFavorite: record.isFavorite,
            isArchived: record.isArchived,
            createdAt: Date(timeIntervalSince1970: record.createdAt),
            updatedAt: Date(timeIntervalSince1970: record.updatedAt)
        )

        // Copy v2 fields if present
        if let blockData = record.blockCompositionData {
            prompt.blockCompositionData = blockData
        }
        if let score = record.qualityScore {
            prompt.qualityScore = score
        }
        if let lastUsed = record.lastUsedAt {
            prompt.lastUsedAt = Date(timeIntervalSince1970: lastUsed)
        }
        if let modeRaw = record.editingModeRaw {
            prompt.editingModeRaw = modeRaw
        }
        if let variantB = record.variantB {
            prompt.variantB = variantB
        }

        context.insert(prompt)

        // Restore attachment stubs from attachmentFileNames (DATA-01)
        if let fileNames = record.attachmentFileNames {
            for (index, name) in fileNames.enumerated() {
                let attachment = Attachment(
                    filename: name,
                    mediaType: "application/octet-stream",
                    fileSize: 0,
                    storageMode: "stub",
                    sortOrder: index
                )
                attachment.prompt = prompt
                prompt.attachments.append(attachment)
                context.insert(attachment)
            }
        }

        // Resolve tags
        for tagName in record.tags {
            let tag = resolveTagCached(named: tagName, context: context, cache: &tagCache)
            prompt.tags.append(tag)
        }

        // Insert template variables (frontmatter-defined)
        var frontmatterVarNames: Set<String> = []
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
            frontmatterVarNames.insert(v.name)
        }

        // Auto-detect {{variables}} in content; merge with frontmatter (frontmatter takes precedence)
        let autoNames = TemplateEngine.extractVariableNames(from: record.content)
        for (index, name) in autoNames.enumerated() {
            guard !frontmatterVarNames.contains(name) else { continue }
            let variable = TemplateVariable(
                name: name,
                defaultValue: "",
                sortOrder: record.templateVariables.count + index,
                occurrenceIndex: index
            )
            variable.prompt = prompt
            prompt.templateVariables.append(variable)
            context.insert(variable)
        }

        return prompt
    }

    /// Updates an existing Prompt's fields from a PromptExportRecord in-place.
    private static func updatePrompt(
        _ prompt: Prompt,
        from record: PromptExportRecord,
        context: ModelContext,
        tagCache: inout [String: Tag]
    ) {
        prompt.title = record.title
        prompt.content = record.content
        prompt.isFavorite = record.isFavorite
        prompt.isArchived = record.isArchived
        prompt.updatedAt = Date(timeIntervalSince1970: record.updatedAt)

        if let score = record.qualityScore {
            prompt.qualityScore = score
        }
        if let lastUsed = record.lastUsedAt {
            prompt.lastUsedAt = Date(timeIntervalSince1970: lastUsed)
        }
        if let modeRaw = record.editingModeRaw {
            prompt.editingModeRaw = modeRaw
        }
        if let variantB = record.variantB {
            prompt.variantB = variantB
        }
        if let blockData = record.blockCompositionData {
            prompt.blockCompositionData = blockData
        }

        // Clear and re-set tags
        prompt.tags.removeAll()
        for tagName in record.tags {
            let tag = resolveTagCached(named: tagName, context: context, cache: &tagCache)
            prompt.tags.append(tag)
        }

        // Clear and re-set attachments (DATA-01)
        for attachment in prompt.attachments {
            context.delete(attachment)
        }
        prompt.attachments.removeAll()
        if let fileNames = record.attachmentFileNames {
            for (index, name) in fileNames.enumerated() {
                let attachment = Attachment(
                    filename: name,
                    mediaType: "application/octet-stream",
                    fileSize: 0,
                    storageMode: "stub",
                    sortOrder: index
                )
                attachment.prompt = prompt
                prompt.attachments.append(attachment)
                context.insert(attachment)
            }
        }

        // Clear and re-set template variables
        for variable in prompt.templateVariables {
            context.delete(variable)
        }
        prompt.templateVariables.removeAll()

        var frontmatterVarNames: Set<String> = []
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
            frontmatterVarNames.insert(v.name)
        }

        // Auto-detect variables from content
        let autoNames = TemplateEngine.extractVariableNames(from: record.content)
        for (index, name) in autoNames.enumerated() {
            guard !frontmatterVarNames.contains(name) else { continue }
            let variable = TemplateVariable(
                name: name,
                defaultValue: "",
                sortOrder: record.templateVariables.count + index,
                occurrenceIndex: index
            )
            variable.prompt = prompt
            prompt.templateVariables.append(variable)
            context.insert(variable)
        }
    }

    /// Resolves a tag by name (case-insensitive), creating it if not found.
    /// Uses an in-memory cache to avoid redundant fetches within a single import.
    private static func resolveTagCached(
        named name: String,
        context: ModelContext,
        cache: inout [String: Tag]
    ) -> Tag {
        let lower = name.lowercased()
        if let cached = cache[lower] { return cached }

        let tag = ExportService.resolveTag(named: name, in: context)
        cache[lower] = tag
        return tag
    }
}
