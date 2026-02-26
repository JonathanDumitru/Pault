//
//  PreviewStripView.swift
//  Pault
//
//  Compact always-visible preview strip below the canvas.
//  Shows 2-line preview of compiled template, token count with color coding,
//  and placeholder fill stats.
//

import SwiftUI

/// Compact always-visible preview strip below the canvas
struct PreviewStripView: View {
    @ObservedObject var model: PromptStudioModel
    @Binding var isExpanded: Bool

    private var tokenColor: Color {
        if model.tokenEstimate < 1000 {
            return .green
        } else if model.tokenEstimate < 3000 {
            return .yellow
        } else {
            return .red
        }
    }

    private var placeholderStats: (filled: Int, total: Int) {
        var filled = 0
        var total = 0

        for block in model.canvasBlocks {
            let placeholders = PromptStudioModel.placeholders(in: block.snippet)
            total += placeholders.count

            let inputs = model.blockInputs[block.id] ?? [:]
            filled += placeholders.filter { p in
                let value = inputs[p] ?? ""
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
        }

        return (filled, total)
    }

    private var previewText: String {
        let text = model.filledExample.isEmpty ? model.rawTemplate : model.filledExample
        return text.isEmpty ? "No blocks added yet" : text
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .top, spacing: 12) {
                // Preview text (truncated)
                Text(previewText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(model.canvasBlocks.isEmpty ? .tertiary : .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 32)

                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tokenColor)
                            .frame(width: 6, height: 6)

                        Text("~\(model.tokenEstimate) tokens")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if placeholderStats.total > 0 {
                        Text("\(placeholderStats.filled)/\(placeholderStats.total) filled")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: .command)
                .help("Toggle full preview (\u{2318}P)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "")
    let model = PromptStudioModel(prompt: prompt)

    return PreviewStripView(model: model, isExpanded: .constant(false))
}
