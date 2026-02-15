//
//  TagPickerPopover.swift
//  Pault
//

import SwiftUI

struct TagPickerPopover: View {
    let allTags: [Tag]
    let selectedTags: [Tag]
    let onSelect: (Tag) -> Void
    let onCreate: (String, String) -> Void

    @State private var newTagName: String = ""
    @State private var selectedColor: String = "blue"

    private let colors = TagColors.all

    private var availableTags: [Tag] {
        allTags.filter { tag in
            !selectedTags.contains(where: { $0.id == tag.id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Tag")
                .font(.headline)

            if !availableTags.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(availableTags) { tag in
                            Button(action: { onSelect(tag) }) {
                                HStack {
                                    TagPillView(name: tag.name, color: tag.color, isSmall: true)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 120)

                Divider()
            }

            Text("Create New")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 4) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(TagColors.color(for: color))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }

            Button("Create") {
                let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onCreate(trimmed, selectedColor)
                newTagName = ""
            }
            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}
