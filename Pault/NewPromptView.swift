//
//  NewPromptView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct NewPromptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Tag.name, order: .forward)]) private var allTags: [Tag]

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedTags: [Tag] = []
    @State private var showingTagPicker: Bool = false

    private var service: PromptService { PromptService(modelContext: modelContext) }

    private var detectedVariables: [String] {
        TemplateEngine.extractVariableNames(from: content)
    }

    /// How many times each variable name appears in the content.
    private var variableOccurrenceCounts: [String: Int] {
        let occurrences = TemplateEngine.extractAllOccurrences(from: content)
        var counts: [String: Int] = [:]
        for occ in occurrences { counts[occ.name, default: 0] += 1 }
        return counts
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            TextField("Prompt Title", text: $title)
                .textFieldStyle(.plain)
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            // Content
            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 200)
                .scrollContentBackground(.hidden)

            Divider()

            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(selectedTags) { tag in
                        TagPillView(name: tag.name, color: tag.color, onRemove: {
                            removeTag(tag)
                        })
                    }

                    Button(action: { showingTagPicker.toggle() }) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .padding(6)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingTagPicker) {
                        TagPickerPopover(
                            allTags: allTags,
                            selectedTags: selectedTags,
                            onSelect: { tag in
                                addTag(tag)
                            },
                            onCreate: { name, color in
                                createAndAddTag(name: name, color: color)
                            }
                        )
                        .frame(width: 260, height: 380)
                    }
                }
            }

            // Template variables indicator
            if !detectedVariables.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Template Variables")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 4) {
                        ForEach(detectedVariables, id: \.self) { name in
                            HStack(spacing: 2) {
                                Text("{{\(name)}}")
                                    .font(.caption)
                                    .fontDesign(.monospaced)

                                if let count = variableOccurrenceCounts[name], count > 1 {
                                    Text("×\(count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create Prompt") {
                    createPrompt()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func addTag(_ tag: Tag) {
        guard !selectedTags.contains(where: { $0.id == tag.id }) else { return }
        selectedTags.append(tag)
        showingTagPicker = false
    }

    private func removeTag(_ tag: Tag) {
        selectedTags.removeAll(where: { $0.id == tag.id })
    }

    private func createAndAddTag(name: String, color: String) {
        let tag = service.createTag(name: name, color: color)
        addTag(tag)
    }

    private func createPrompt() {
        let prompt = service.createPrompt(title: title, content: content)

        for tag in selectedTags {
            service.addTag(tag, to: prompt)
        }

        TemplateEngine.syncVariables(for: prompt, in: modelContext)

        NotificationCenter.default.post(
            name: .promptCreated,
            object: nil,
            userInfo: ["promptID": prompt.id]
        )

        dismiss()
    }
}

#Preview {
    NewPromptView()
        .modelContainer(for: [Prompt.self, Tag.self, TemplateVariable.self], inMemory: true)
}
