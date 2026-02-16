//
//  PromptPreviewView.swift
//  Pault
//
//  Preview of a prompt shown in the main window's detail column.
//  Displays title, content with inline variable fields, summary panel,
//  attachments, and inspector.
//

import SwiftUI
import SwiftData

struct PromptPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    let prompt: Prompt
    @Binding var showInspector: Bool

    private var service: PromptService {
        PromptService(modelContext: modelContext)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main content area
            VStack(alignment: .leading, spacing: 0) {
                // Title (read-only)
                Text(prompt.title.isEmpty ? "Untitled" : prompt.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(prompt.title.isEmpty ? .tertiary : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                // Content — inline variable fields when variables exist
                if !prompt.templateVariables.isEmpty {
                    if prompt.attributedContent != nil {
                        RichTextEditor(
                            attributedContent: .constant(prompt.attributedContent),
                            plainContent: .constant(prompt.content),
                            isEditable: false
                        )
                        .frame(maxHeight: 200)
                        .padding(.horizontal, 16)

                        Divider().padding(.horizontal, 16)

                        Text("Fill in template variables")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }

                    InlineVariablePreview(prompt: prompt)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else if prompt.attributedContent != nil || !prompt.content.isEmpty {
                    RichTextEditor(
                        attributedContent: .constant(prompt.attributedContent),
                        plainContent: .constant(prompt.content),
                        isEditable: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else {
                    Text("No content")
                        .foregroundStyle(.tertiary)
                        .italic()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // Variables summary panel
                VariablesSummaryPanel(prompt: prompt)

                // Attachments strip (read-only)
                if !prompt.attachments.isEmpty {
                    ReadOnlyAttachmentsStrip(attachments: prompt.attachments)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Inspector panel (read-only)
            if showInspector {
                Divider()
                ReadOnlyInspectorPanel(prompt: prompt)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showInspector)
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showInspector.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundStyle(showInspector ? .blue : .secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: .command)
            .help("Toggle Inspector (⌘I)")
            .accessibilityLabel(showInspector ? "Hide inspector" : "Show inspector")
        }
    }
}

// MARK: - Variables Summary Panel

private struct VariablesSummaryPanel: View {
    let prompt: Prompt

    private var sortedVariables: [TemplateVariable] {
        prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var filledCount: Int {
        prompt.templateVariables.filter { !$0.defaultValue.isEmpty }.count
    }

    /// Names that appear more than once, so we know when to add occurrence labels.
    private var duplicatedNames: Set<String> {
        var counts: [String: Int] = [:]
        for v in prompt.templateVariables { counts[v.name, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    private func displayLabel(for variable: TemplateVariable) -> String {
        if duplicatedNames.contains(variable.name) {
            return "\(variable.name) [\(variable.occurrenceIndex + 1)]"
        }
        return variable.name
    }

    var body: some View {
        if !prompt.templateVariables.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    // Header with filled count
                    HStack {
                        Label("Variables", systemImage: "curlybraces")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(filledCount)/\(prompt.templateVariables.count) filled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Name → value rows
                    ForEach(sortedVariables) { variable in
                        HStack(spacing: 6) {
                            Text(displayLabel(for: variable))
                                .font(.caption.monospaced())
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            if variable.defaultValue.isEmpty {
                                Text("empty")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text(variable.defaultValue)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                            }

                            Spacer()
                        }
                        .accessibilityLabel("\(displayLabel(for: variable)): \(variable.defaultValue.isEmpty ? "empty" : variable.defaultValue)")
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Read-Only Inspector Panel

private struct ReadOnlyInspectorPanel: View {
    let prompt: Prompt

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tags (read-only)
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if prompt.tags.isEmpty {
                    Text("No tags")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(prompt.tags) { tag in
                            TagPillView(name: tag.name, color: tag.color)
                                .accessibilityLabel("Tag: \(tag.name)")
                        }
                    }
                }
            }

            Divider()

            // Favorite (read-only display)
            HStack {
                Text("Favorite")
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: prompt.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(prompt.isFavorite ? .yellow : .secondary)
            }

            Divider()

            // Dates
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Created")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(prompt.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
                HStack {
                    Text("Modified")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(prompt.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
                HStack {
                    Text("Last Used")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let lastUsed = prompt.lastUsedAt {
                        Text(lastUsed.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                    } else {
                        Text("Never")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 220)
        .background(.regularMaterial)
    }
}

// MARK: - Read-Only Attachments Strip

private struct ReadOnlyAttachmentsStrip: View {
    let attachments: [Attachment]

    private var sorted: [Attachment] {
        attachments.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Label("Attachments", systemImage: "paperclip")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sorted) { attachment in
                        AttachmentThumbnailView(attachment: attachment)
                            .accessibilityLabel(attachment.filename)
                            .contextMenu {
                                Button("Open") { openAttachment(attachment) }
                                Button("Quick Look") { quickLookAttachment(attachment) }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func openAttachment(_ attachment: Attachment) {
        AttachmentManager.withResolvedURL(for: attachment) { url in
            NSWorkspace.shared.open(url)
        }
    }

    private func quickLookAttachment(_ attachment: Attachment) {
        AttachmentManager.withResolvedURL(for: attachment) { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
