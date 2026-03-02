//
//  InspectorView.swift
//  Pault
//
//  Collapsible inspector panel with single-scroll layout.
//  Combines Tags, Stats (Pro), and History into one scrollable view.
//

import SwiftUI
import SwiftData

struct InspectorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Tag.name, order: .forward)]) private var allTags: [Tag]

    @Bindable var prompt: Prompt
    @State private var newTagName: String = ""
    @State private var showingTagPicker: Bool = false
    @State private var showHistory: Bool = false

    private let tagColors = TagColors.all
    private var service: PromptService { PromptService(modelContext: modelContext) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Tags section
                tagsSection

                sectionDivider

                // Favorite toggle
                favoriteSection

                sectionDivider

                // Quick info
                infoSection

                // Stats section (Pro only)
                if ProStatusManager.shared.isProUnlocked {
                    sectionDivider
                    statsSection
                }

                sectionDivider

                // History section (collapsible)
                historySection

                sectionDivider

                // Archive button
                archiveSection
            }
            .padding(.vertical, 8)
        }
        .frame(minWidth: AppConstants.Panels.inspectorMinWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption)
                .fontWeight(.semibold)
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
                        .font(.caption2)
                        .padding(5)
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
        .padding(.horizontal, 12)
    }

    // MARK: - Favorite Section

    private var favoriteSection: some View {
        HStack {
            Text("Favorite")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { prompt.isFavorite.toggle() }) {
                Image(systemName: prompt.isFavorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(prompt.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Group {
                infoRow(label: "Created", value: prompt.createdAt.formatted(date: .abbreviated, time: .omitted))
                infoRow(label: "Modified", value: prompt.updatedAt.formatted(date: .abbreviated, time: .omitted))
                infoRow(label: "Last Used", value: prompt.lastUsedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Never")
            }
        }
        .padding(.horizontal, 12)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Section (Pro)

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stats")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Inline mini stats - only show available data
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(prompt.versions.count)")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Versions")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: 2) {
                    Text("\(prompt.templateVariables.count)")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Variables")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: 2) {
                    Text("\(prompt.attachments.count)")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Files")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation { showHistory.toggle() } }) {
                HStack {
                    Text("History")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text("(\(prompt.versions.count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: showHistory ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if showHistory {
                PromptVersionHistoryView(prompt: prompt)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Archive Section

    private var archiveSection: some View {
        Button(action: { prompt.isArchived.toggle() }) {
            HStack {
                Image(systemName: "archivebox")
                    .font(.caption)
                Text(prompt.isArchived ? "Unarchive" : "Archive")
                    .font(.caption)
            }
            .foregroundStyle(prompt.isArchived ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    // MARK: - Tag Actions

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
