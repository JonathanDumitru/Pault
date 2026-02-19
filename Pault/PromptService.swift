//
//  PromptService.swift
//  Pault
//
//  Single source of truth for all prompt operations.
//  Every view delegates CRUD, clipboard, and filtering here.
//

import Foundation
import SwiftData
import AppKit
import os

private let serviceLogger = Logger(subsystem: "com.pault.app", category: "PromptService")

@MainActor
final class PromptService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    @discardableResult
    func createPrompt(title: String = "", content: String = "") -> Prompt {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = Prompt(title: trimmedTitle, content: trimmedContent)
        modelContext.insert(prompt)
        save("createPrompt")
        return prompt
    }

    func deletePrompt(_ prompt: Prompt) {
        AttachmentManager.deleteFiles(for: prompt.id)
        modelContext.delete(prompt)
        save("deletePrompt")
    }

    // MARK: - State Mutations

    func toggleFavorite(_ prompt: Prompt) {
        prompt.isFavorite.toggle()
        prompt.updatedAt = Date()
        save("toggleFavorite")
    }

    func toggleArchive(_ prompt: Prompt) {
        prompt.isArchived.toggle()
        prompt.updatedAt = Date()
        save("toggleArchive")
    }

    // MARK: - Clipboard

    func copyToClipboard(_ prompt: Prompt) {
        let resolved = TemplateEngine.resolve(content: prompt.content, variables: prompt.templateVariables)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Always provide plain text
        pasteboard.setString(resolved, forType: .string)

        // If rich content exists, also provide RTFD
        if let rtfdData = prompt.attributedContent {
            do {
                let attrString = try NSAttributedString(data: rtfdData, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
                let mutable = NSMutableAttributedString(attributedString: attrString)
                let rtfdOutput = try mutable.data(from: NSRange(location: 0, length: mutable.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
                pasteboard.setData(rtfdOutput, forType: .rtfd)
            } catch {
                serviceLogger.error("copyToClipboard: Failed to serialize RTFD — \(error.localizedDescription)")
            }
        }

        prompt.markAsUsed()
        let copyEvent = CopyEvent(promptID: prompt.id)
        modelContext.insert(copyEvent)
        save("copyToClipboard")
    }

    // MARK: - Tag Operations

    func addTag(_ tag: Tag, to prompt: Prompt) {
        guard !prompt.tags.contains(where: { $0.id == tag.id }) else { return }
        prompt.tags.append(tag)
        save("addTag")
    }

    func removeTag(_ tag: Tag, from prompt: Prompt) {
        prompt.tags.removeAll(where: { $0.id == tag.id })
        save("removeTag")
    }

    /// Creates a new tag, or returns the existing one if a tag with that name already exists (case-insensitive).
    func createTag(name: String, color: String = "blue") -> Tag {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for existing tag with same name (case-insensitive)
        let descriptor = FetchDescriptor<Tag>()
        if let existing = (try? modelContext.fetch(descriptor))?.first(where: {
            $0.name.lowercased() == normalizedName.lowercased()
        }) {
            serviceLogger.info("createTag: Reusing existing tag '\(existing.name)'")
            return existing
        }

        let tag = Tag(name: normalizedName, color: color)
        modelContext.insert(tag)
        save("createTag")
        return tag
    }

    // MARK: - Filtering

    /// Central filtering logic used by Sidebar, MenuBar, and HotkeyLauncher.
    /// Each surface can pass its own filter enum — this method handles the common patterns.
    func filterPrompts(
        _ prompts: [Prompt],
        showArchived: Bool = false,
        showOnlyFavorites: Bool = false,
        showOnlyRecent: Bool = false,
        recentLimit: Int = 10,
        tagFilter: Tag? = nil,
        searchText: String = "",
        maxResults: Int? = nil
    ) -> [Prompt] {
        var result = prompts

        // Archive filtering
        if showArchived {
            result = result.filter { $0.isArchived }
        } else {
            result = result.filter { !$0.isArchived }
        }

        // Favorites
        if showOnlyFavorites {
            result = result.filter { $0.isFavorite }
        }

        // Recent — sort by lastUsedAt and cap
        if showOnlyRecent {
            result = result
                .filter { $0.lastUsedAt != nil }
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            result = Array(result.prefix(recentLimit))
        }

        // Tag
        if let tag = tagFilter {
            result = result.filter { $0.tags.contains(where: { $0.id == tag.id }) }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.name.lowercased().contains(query) })
            }
        }

        // Cap results
        if let max = maxResults {
            result = Array(result.prefix(max))
        }

        return result
    }

    // MARK: - Versioning

    func saveSnapshot(for prompt: Prompt, changeNote: String? = nil, limit: Int = 50) {
        let version = PromptVersion(
            prompt: prompt,
            title: prompt.title,
            content: prompt.content,
            changeNote: changeNote
        )
        modelContext.insert(version)

        // Prune: keep only the most recent `limit` versions for this prompt.
        // NOTE: Optional relationship traversal in #Predicate is unreliable;
        // fetch all and filter in memory.
        let promptID = prompt.id
        let descriptor = FetchDescriptor<PromptVersion>(
            sortBy: [SortDescriptor(\.savedAt, order: .forward)]
        )
        guard let allVersions = try? modelContext.fetch(descriptor) else { return }
        let promptVersions = allVersions.filter { $0.prompt?.id == promptID }

        if promptVersions.count > limit {
            let toDelete = promptVersions.prefix(promptVersions.count - limit)
            for v in toDelete {
                modelContext.delete(v)
            }
        }
        save("saveSnapshot")
    }

    // MARK: - Persistence

    private func save(_ caller: String) {
        do {
            try modelContext.save()
        } catch {
            serviceLogger.error("\(caller): Failed to save — \(error.localizedDescription)")
        }
    }
}
