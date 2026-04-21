//
//  CollapsiblePanelContainer.swift
//  Pault
//
//  A reusable slide-out panel container with spring animations.
//  Supports left and right edge positioning, configurable width,
//  and auto-collapse callback integration.
//

import SwiftUI

/// Edge from which the panel slides in
enum PanelEdge {
    case leading
    case trailing
}

/// A reusable container for slide-out collapsible panels.
///
/// Usage:
/// ```swift
/// CollapsiblePanelContainer(
///     isExpanded: $showSidebar,
///     edge: .leading,
///     width: 240
/// ) {
///     SidebarContent()
/// }
/// ```
struct CollapsiblePanelContainer<Content: View>: View {
    @Binding var isExpanded: Bool
    let edge: PanelEdge
    let width: CGFloat
    let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Optional callback when panel is about to collapse (for cleanup)
    var onWillCollapse: (() -> Void)?

    /// Optional callback when panel finishes expanding
    var onDidExpand: (() -> Void)?

    init(
        isExpanded: Binding<Bool>,
        edge: PanelEdge,
        width: CGFloat = AppConstants.Panels.sidebarWidth,
        onWillCollapse: (() -> Void)? = nil,
        onDidExpand: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self.edge = edge
        self.width = width
        self.onWillCollapse = onWillCollapse
        self.onDidExpand = onDidExpand
        self.content = content
    }

    var body: some View {
        content()
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 0))
            .shadow(
                color: .black.opacity(isExpanded ? 0.1 : 0),
                radius: isExpanded ? 8 : 0,
                x: edge == .leading ? 4 : -4,
                y: 0
            )
            .offset(x: offset)
            .opacity(isExpanded ? 1 : 0)
            .animation(panelAnimation, value: isExpanded)
            .onChange(of: isExpanded) { wasExpanded, nowExpanded in
                if wasExpanded && !nowExpanded {
                    onWillCollapse?()
                } else if !wasExpanded && nowExpanded {
                    // Delay callback until animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Panels.Animation.slideDuration) {
                        onDidExpand?()
                    }
                }
            }
    }

    private var offset: CGFloat {
        guard !isExpanded else { return 0 }
        return edge == .leading ? -width : width
    }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : .spring(
            response: AppConstants.Panels.Animation.slideDuration,
            dampingFraction: AppConstants.Panels.Animation.dampingFraction
        )
    }
}

// MARK: - Panel Toggle Button

/// A consistent toggle button for panel visibility
struct PanelToggleButton: View {
    @Binding var isExpanded: Bool
    let edge: PanelEdge
    let shortcutKey: KeyEquivalent?
    let shortcutModifiers: EventModifiers
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isExpanded: Binding<Bool>,
        edge: PanelEdge,
        shortcutKey: KeyEquivalent? = nil,
        shortcutModifiers: EventModifiers = .command
    ) {
        self._isExpanded = isExpanded
        self.edge = edge
        self.shortcutKey = shortcutKey
        self.shortcutModifiers = shortcutModifiers
    }

    var body: some View {
        Button(action: { withAnimation(reduceMotion ? nil : .default) { isExpanded.toggle() } }) {
            Image(systemName: iconName)
                .font(.body)
                .foregroundStyle(isExpanded ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .modifier(OptionalKeyboardShortcut(key: shortcutKey, modifiers: shortcutModifiers))
    }

    private var iconName: String {
        switch edge {
        case .leading:
            return "sidebar.left"
        case .trailing:
            return "sidebar.right"
        }
    }
}

/// View modifier that conditionally applies a keyboard shortcut
private struct OptionalKeyboardShortcut: ViewModifier {
    let key: KeyEquivalent?
    let modifiers: EventModifiers

    func body(content: Content) -> some View {
        if let key = key {
            content.keyboardShortcut(key, modifiers: modifiers)
        } else {
            content
        }
    }
}

// MARK: - Edge Hover Indicator

/// A subtle indicator shown when hovering at the panel edge
struct EdgeHoverIndicator: View {
    let edge: PanelEdge
    let isVisible: Bool
    let onTap: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(isHovering ? 0.3 : 0.15))
            .frame(width: 4)
            .opacity(isVisible ? 1 : 0)
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .onTapGesture(perform: onTap)
            .animation(reduceMotion ? nil : .easeInOut(duration: AppConstants.Panels.Animation.fadeDuration), value: isVisible)
    }
}

// MARK: - Collapsible Panel Layout

/// A layout container that positions collapsible panels around central content.
///
/// Usage:
/// ```swift
/// CollapsiblePanelLayout(
///     leadingPanel: $showSidebar,
///     trailingPanel: $showInspector,
///     leadingWidth: 240,
///     trailingWidth: 220
/// ) {
///     // Leading panel content
///     SidebarView()
/// } trailing: {
///     // Trailing panel content
///     InspectorView()
/// } center: {
///     // Main content
///     EditorView()
/// }
/// ```
struct CollapsiblePanelLayout<Leading: View, Trailing: View, Center: View>: View {
    @Binding var showLeading: Bool
    @Binding var showTrailing: Bool
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat
    let leading: () -> Leading
    let trailing: () -> Trailing
    let center: () -> Center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when typing activity should trigger auto-collapse
    var autoCollapseManager: AutoCollapseManager?

    init(
        showLeading: Binding<Bool>,
        showTrailing: Binding<Bool>,
        leadingWidth: CGFloat = AppConstants.Panels.sidebarWidth,
        trailingWidth: CGFloat = AppConstants.Panels.inspectorWidth,
        autoCollapseManager: AutoCollapseManager? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self._showLeading = showLeading
        self._showTrailing = showTrailing
        self.leadingWidth = leadingWidth
        self.trailingWidth = trailingWidth
        self.autoCollapseManager = autoCollapseManager
        self.leading = leading
        self.trailing = trailing
        self.center = center
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading panel
            if showLeading {
                leading()
                    .frame(width: leadingWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Center content
            center()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Trailing panel
            if showTrailing {
                trailing()
                    .frame(width: trailingWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(panelAnimation, value: showLeading)
        .animation(panelAnimation, value: showTrailing)
    }

    private var panelAnimation: Animation? {
        reduceMotion ? nil : .spring(
            response: AppConstants.Panels.Animation.slideDuration,
            dampingFraction: AppConstants.Panels.Animation.dampingFraction
        )
    }
}

// MARK: - Preview

#Preview("Collapsible Panel Layout") {
    struct PreviewWrapper: View {
        @State private var showLeading = true
        @State private var showTrailing = true

        var body: some View {
            VStack {
                HStack {
                    Toggle("Leading", isOn: $showLeading)
                    Toggle("Trailing", isOn: $showTrailing)
                }
                .padding()

                CollapsiblePanelLayout(
                    showLeading: $showLeading,
                    showTrailing: $showTrailing,
                    leadingWidth: 200,
                    trailingWidth: 180
                ) {
                    VStack {
                        Text("Sidebar")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                } trailing: {
                    VStack {
                        Text("Inspector")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                } center: {
                    VStack {
                        Text("Editor Content")
                            .font(.title)
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                }
            }
            .frame(width: 800, height: 500)
        }
    }

    return PreviewWrapper()
}
