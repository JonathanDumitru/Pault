//
//  SuggestionBannerView.swift
//  Pault
//
//  Inline suggestion banner shown in canvas to guide users
//  with contextual suggestions from the BlockSuggestionEngine.
//

import SwiftUI

/// Inline suggestion banner shown in canvas
struct SuggestionBannerView: View {
    let suggestion: BlockSuggestion
    let onSelectCategory: (ConsolidatedBlockCategory) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(suggestion.suggestedCategories, id: \.self) { category in
                        Button(action: { onSelectCategory(category) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                Text(category.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(category.color.opacity(0.15))
                            .foregroundStyle(category.color)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SuggestionBannerView(
        suggestion: BlockSuggestion(
            message: "Add a Task block to define what the AI should do",
            suggestedCategories: [.task, .context]
        ),
        onSelectCategory: { _ in },
        onDismiss: {}
    )
    .padding()
}
