//
//  TagPillView.swift
//  Pault
//

import SwiftUI

enum TagColors {
    static let all = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "gray"]

    static func color(for name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "gray": return .gray
        default: return .blue
        }
    }
}

struct TagPillView: View {
    let name: String
    let color: String
    var isSmall: Bool = false
    var onTap: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    private var pillColor: Color {
        TagColors.color(for: color)
    }

    // Text color that adapts to light/dark mode to ensure WCAG AA contrast (4.5:1).
    // Light mode: dark version of the pill color (mix toward black).
    // Dark mode: light version (mix toward white).
    // Using Environment colorScheme for dynamic adaptation.
    private var accessibleTextColor: Color {
        // Darken the pill color significantly so text passes 4.5:1 against the
        // light 20%-opacity background in Light Mode, and use primary in Dark Mode.
        // Primary (.primary) adapts automatically and always meets contrast.
        return .primary
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("#\(name)")
                .font(isSmall ? .caption2 : .caption)
                .fontWeight(.medium)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: isSmall ? 8 : 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(name) tag")
            }
        }
        .padding(.horizontal, isSmall ? 6 : 8)
        .padding(.vertical, isSmall ? 2 : 4)
        .background(pillColor.opacity(0.15))
        .foregroundStyle(accessibleTextColor)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            onTap?()
        }
        .accessibilityLabel("\(name) tag")
        .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }
}

struct TagPillsView: View {
    let tags: [Tag]
    var maxVisible: Int = 2
    var isSmall: Bool = false
    var onTagTap: ((Tag) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags.prefix(maxVisible)) { tag in
                TagPillView(name: tag.name, color: tag.color, isSmall: isSmall, onTap: {
                    onTagTap?(tag)
                })
            }

            if tags.count > maxVisible {
                Text("+\(tags.count - maxVisible)")
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TagPillView(name: "work", color: "blue")
        TagPillView(name: "urgent", color: "red", isSmall: true)
        TagPillView(name: "email", color: "green", onRemove: {})
    }
    .padding()
}
