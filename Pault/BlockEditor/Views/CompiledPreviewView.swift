//
//  CompiledPreviewView.swift
//  Pault
//
//  Right pane showing the compiled template preview with different modes.
//

import SwiftUI

/// Right pane displaying the compiled output and inspector
struct CompiledPreviewView: View {
    @ObservedObject var model: PromptStudioModel
    @Bindable var prompt: Prompt

    var body: some View {
        VStack(spacing: 0) {
            // Preview mode picker and stats
            previewHeader

            Divider()

            // Preview content
            previewContent

            Divider()

            // Inspector section
            inspectorSection
        }
        .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var previewHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                if model.isCompiling {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // Mode picker
            Picker("", selection: $model.previewMode) {
                ForEach(PreviewMode.allCases) { mode in
                    Text(mode.shortLabel).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Token estimate
            HStack {
                Image(systemName: "number.circle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text("~\(model.tokenEstimate) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Copy button
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Preview Content

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch model.previewMode {
                case .raw:
                    rawPreview
                case .filled:
                    filledPreview
                case .diff:
                    diffPreview
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(maxHeight: .infinity)
    }

    private var rawPreview: some View {
        Text(model.rawTemplate.isEmpty ? "No blocks added yet" : model.rawTemplate)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(model.rawTemplate.isEmpty ? .tertiary : .primary)
            .textSelection(.enabled)
    }

    private var filledPreview: some View {
        Text(model.filledExample.isEmpty ? "No blocks added yet" : model.filledExample)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(model.filledExample.isEmpty ? .tertiary : .primary)
            .textSelection(.enabled)
    }

    private var diffPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.compiledTemplate.isEmpty {
                Text("No blocks added yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                // Show filled placeholders highlighted
                highlightedPreview
            }
        }
    }

    private var highlightedPreview: some View {
        // Show filled example with paragraph separators
        let text = model.filledExample

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)

                if paragraph != text.components(separatedBy: "\n\n").last {
                    Divider()
                        .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Inspector Section

    private var inspectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Favorite toggle
            Toggle(isOn: $prompt.isFavorite) {
                Label("Favorite", systemImage: prompt.isFavorite ? "star.fill" : "star")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)

            // Tags
            if !prompt.tags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    TagFlowLayout(spacing: 4) {
                        ForEach(prompt.tags) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Sync state
            if let syncState = prompt.blockSyncState {
                HStack(spacing: 4) {
                    Circle()
                        .fill(syncState == .synced ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    Text(syncState == .synced ? "Synced" : "Diverged")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Block count
            HStack(spacing: 4) {
                Image(systemName: "square.stack.3d.up")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("\(model.canvasBlocks.count) blocks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.compiledTemplate, forType: .string)
        #endif
    }
}

// MARK: - Tag Flow Layout

/// Simple flow layout for tags in the block editor preview
private struct TagFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "Test content")
    let model = PromptStudioModel(prompt: prompt)
    return CompiledPreviewView(model: model, prompt: prompt)
        .frame(height: 600)
}
