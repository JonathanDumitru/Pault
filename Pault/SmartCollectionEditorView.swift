//
//  SmartCollectionEditorView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct SmartCollectionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]
    @Query(sort: [SortDescriptor(\Prompt.title)]) private var allPrompts: [Prompt]

    @State private var name: String = ""
    @State private var icon: String = "folder"
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var onlyFavorites = false
    @State private var recentDays: Int? = nil
    @State private var isGenerating = false
    @State private var generationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name & Icon") {
                    TextField("Collection name", text: $name)
                    TextField("SF Symbol name", text: $icon)
                }

                Section("Filter Rules") {
                    Toggle("Favorites only", isOn: $onlyFavorites)
                    Picker("Last used within", selection: $recentDays) {
                        Text("Any time").tag(nil as Int?)
                        Text("7 days").tag(7 as Int?)
                        Text("30 days").tag(30 as Int?)
                    }
                    if !allTags.isEmpty {
                        ForEach(allTags) { tag in
                            Toggle(tag.name, isOn: Binding(
                                get: { selectedTagIDs.contains(tag.id) },
                                set: { if $0 { selectedTagIDs.insert(tag.id) } else { selectedTagIDs.remove(tag.id) } }
                            ))
                        }
                    }
                }

                Section {
                    Button(action: createSavedFilter) {
                        Label("Save as Filter Collection", systemImage: "folder.badge.plus")
                    }
                    .disabled(name.isEmpty)

                    Button(action: generateWithAI) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.7)
                        } else {
                            Label("Generate with AI", systemImage: "sparkles")
                        }
                    }
                    .disabled(isGenerating || allPrompts.isEmpty)
                }

                if let error = generationError {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("New Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(width: 340, height: 480)
    }

    private func createSavedFilter() {
        let tags = allTags.filter { selectedTagIDs.contains($0.id) }
        let filter = SmartCollectionFilter(tags: tags, onlyFavorites: onlyFavorites, recentDays: recentDays)
        let nextOrder = (try? modelContext.fetch(FetchDescriptor<SmartCollection>()))?.map(\.sortOrder).max().map { $0 + 1 } ?? 0
        let collection = SmartCollection(name: name, icon: icon, filter: filter, sortOrder: nextOrder)
        modelContext.insert(collection)
        try? modelContext.save()
        dismiss()
    }

    private func generateWithAI() {
        isGenerating = true
        generationError = nil
        let config = AIConfig.defaults[.claude] ?? AIConfig(provider: .claude, model: "claude-opus-4-6")
        let titles = Array(allPrompts.prefix(100).map(\.title))
        Task {
            do {
                let suggestions = try await AIService.shared.clusterPrompts(titles: titles, config: config)
                await MainActor.run {
                    for (i, suggestion) in suggestions.enumerated() {
                        let ids = allPrompts
                            .filter { suggestion.promptTitles.contains($0.title) }
                            .map(\.id)
                        let col = SmartCollection(name: suggestion.name, icon: suggestion.icon,
                                                  promptIDs: ids, sortOrder: i)
                        col.lastRefreshed = Date()
                        modelContext.insert(col)
                    }
                    try? modelContext.save()
                    isGenerating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    generationError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}
