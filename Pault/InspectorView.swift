//
//  InspectorView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct InspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Tag.name, order: .forward)]) private var allTags: [Tag]

    @Bindable var prompt: Prompt
    @State private var newTagName: String = ""
    @State private var showingTagPicker: Bool = false
    @State private var selectedTab: InspectorTab = .info

    enum InspectorTab: String, CaseIterable {
        case info = "Info"
        case history = "History"
    }

    private let tagColors = TagColors.all
    private var service: PromptService { PromptService(modelContext: modelContext) }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Tab content
            switch selectedTab {
            case .info:
                infoContent
            case .history:
                if ProStatusManager.shared.isProUnlocked {
                    RunHistoryView(prompt: prompt)
                } else {
                    proGateView
                }
            }
        }
        .frame(width: 220)
        .background(.regularMaterial)
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tags section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(prompt.tags) { tag in
                        TagPillView(name: tag.name, color: tag.color, onRemove: {
                            removeTag(tag)
                        })
                        .accessibilityLabel("Tag: \(tag.name)")
                        .accessibilityHint("Double-click to remove")
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
                            selectedTags: prompt.tags,
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

            Divider()

            // Favorite toggle
            HStack {
                Text("Favorite")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { prompt.isFavorite.toggle() }) {
                    Image(systemName: prompt.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(prompt.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
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

            Divider()

            // Archive button
            Button(action: { prompt.isArchived.toggle() }) {
                Label(prompt.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }
            .buttonStyle(.plain)
            .foregroundStyle(prompt.isArchived ? .blue : .secondary)

            Spacer()
        }
        .padding()
    }

    private var proGateView: some View {
        VStack(spacing: 12) {
            ProBadge()
            Text("Run History is a Pro feature")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func addTag(_ tag: Tag) {
        service.addTag(tag, to: prompt)
        showingTagPicker = false
    }

    private func removeTag(_ tag: Tag) {
        service.removeTag(tag, from: prompt)
    }

    private func createAndAddTag(name: String, color: String) {
        let tag = service.createTag(name: name, color: color)
        addTag(tag)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
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

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
