//
//  AutoCollapseManager.swift
//  Pault
//
//  Manages automatic panel collapse behavior triggered by editor typing activity.
//  Provides fade-warning before collapse and cancellation on user interaction.
//

import SwiftUI
import Combine

/// Manages automatic collapse of panels when the user starts typing in the editor.
///
/// Features:
/// - Debounced typing detection (configurable delay)
/// - Fade-warning phase before collapse
/// - Cancel collapse on panel interaction
/// - Support for multiple panels
///
/// Usage:
/// ```swift
/// @StateObject var autoCollapse = AutoCollapseManager()
///
/// // In your editor's onChange:
/// .onChange(of: content) { _, _ in
///     autoCollapse.userDidType()
/// }
///
/// // Wire up panels:
/// .onChange(of: autoCollapse.shouldCollapse) { _, shouldCollapse in
///     if shouldCollapse {
///         withAnimation { showSidebar = false; showInspector = false }
///         autoCollapse.didCollapse()
///     }
/// }
/// ```
final class AutoCollapseManager: ObservableObject {
    /// When true, panels should collapse
    @Published private(set) var shouldCollapse: Bool = false

    /// When true, panels should show fade-warning (about to collapse)
    @Published private(set) var isInWarningPhase: Bool = false

    /// Panels that are currently protected from auto-collapse (e.g., user is interacting)
    @Published var protectedPanels: Set<PanelIdentifier> = []

    /// User preference for auto-collapse behavior
    @AppStorage("autoCollapsePanels") var isEnabled: Bool = true

    /// Delay before warning phase starts (seconds)
    var warningDelay: TimeInterval = AppConstants.Panels.AutoCollapse.warningDelay

    /// Duration of warning phase before collapse (seconds)
    var warningDuration: TimeInterval = AppConstants.Panels.AutoCollapse.warningDuration

    private var warningTimer: AnyCancellable?
    private var collapseTimer: AnyCancellable?

    enum PanelIdentifier: Hashable {
        case sidebar
        case inspector
        case blockLibrary
        case blockPreview
    }

    // MARK: - Public Methods

    /// Call when user types in the editor
    func userDidType() {
        guard isEnabled else { return }
        guard protectedPanels.isEmpty else {
            // Don't start collapse if user is interacting with a panel
            return
        }

        // Cancel any existing timers
        cancelTimers()

        // Start warning timer
        warningTimer = Timer.publish(every: warningDelay, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.enterWarningPhase()
            }
    }

    /// Call when user interacts with a panel (pauses auto-collapse)
    func userDidInteractWithPanel(_ panel: PanelIdentifier) {
        protectedPanels.insert(panel)
        cancelTimers()
        isInWarningPhase = false
    }

    /// Call when user stops interacting with a panel
    func userDidStopInteractingWithPanel(_ panel: PanelIdentifier) {
        protectedPanels.remove(panel)
    }

    /// Call after panels have collapsed
    func didCollapse() {
        shouldCollapse = false
        isInWarningPhase = false
    }

    /// Cancel any pending collapse
    func cancelCollapse() {
        cancelTimers()
        isInWarningPhase = false
        shouldCollapse = false
    }

    /// Call when user explicitly expands a panel (resets state)
    func userDidExpandPanel() {
        cancelTimers()
        isInWarningPhase = false
        shouldCollapse = false
    }

    // MARK: - Private Methods

    private func enterWarningPhase() {
        guard protectedPanels.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            isInWarningPhase = true
        }

        // Start collapse timer
        collapseTimer = Timer.publish(every: warningDuration, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.triggerCollapse()
            }
    }

    private func triggerCollapse() {
        guard protectedPanels.isEmpty else {
            isInWarningPhase = false
            return
        }

        isInWarningPhase = false
        shouldCollapse = true
    }

    private func cancelTimers() {
        warningTimer?.cancel()
        warningTimer = nil
        collapseTimer?.cancel()
        collapseTimer = nil
    }
}

// MARK: - View Modifier for Auto-Collapse Warning

/// A view modifier that dims content when auto-collapse warning is active
struct AutoCollapseWarningModifier: ViewModifier {
    @ObservedObject var manager: AutoCollapseManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(manager.isInWarningPhase ? AppConstants.Panels.AutoCollapse.warningOpacity : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: AppConstants.Panels.Animation.fadeDuration), value: manager.isInWarningPhase)
    }
}

extension View {
    /// Apply auto-collapse warning visual effect
    func autoCollapseWarning(_ manager: AutoCollapseManager) -> some View {
        modifier(AutoCollapseWarningModifier(manager: manager))
    }
}

// MARK: - View Modifier for Panel Protection

/// A view modifier that protects a panel from auto-collapse while hovered
struct PanelProtectionModifier: ViewModifier {
    @ObservedObject var manager: AutoCollapseManager
    let panelID: AutoCollapseManager.PanelIdentifier

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    manager.userDidInteractWithPanel(panelID)
                } else {
                    manager.userDidStopInteractingWithPanel(panelID)
                }
            }
    }
}

extension View {
    /// Protect this panel from auto-collapse while user hovers over it
    func protectFromAutoCollapse(_ manager: AutoCollapseManager, panel: AutoCollapseManager.PanelIdentifier) -> some View {
        modifier(PanelProtectionModifier(manager: manager, panelID: panel))
    }
}

// MARK: - Preview

#Preview("Auto-Collapse Demo") {
    struct PreviewWrapper: View {
        @StateObject private var autoCollapse = AutoCollapseManager()
        @State private var showPanel = true
        @State private var text = ""

        var body: some View {
            VStack(spacing: 20) {
                // Status
                VStack {
                    Text("Warning: \(autoCollapse.isInWarningPhase ? "YES" : "NO")")
                    Text("Should Collapse: \(autoCollapse.shouldCollapse ? "YES" : "NO")")
                    Text("Protected: \(autoCollapse.protectedPanels.isEmpty ? "None" : "Sidebar")")
                }
                .font(.caption)
                .padding()
                .background(.regularMaterial)

                HStack(spacing: 0) {
                    // Panel
                    if showPanel {
                        VStack {
                            Text("Panel")
                                .font(.headline)
                            Spacer()
                        }
                        .frame(width: 150)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .autoCollapseWarning(autoCollapse)
                        .protectFromAutoCollapse(autoCollapse, panel: .sidebar)
                        .transition(.move(edge: .leading))
                    }

                    // Editor
                    VStack {
                        Text("Type here to trigger auto-collapse:")
                        TextField("Start typing...", text: $text)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: text) { _, _ in
                                autoCollapse.userDidType()
                            }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }

                Button("Reset") {
                    showPanel = true
                    autoCollapse.cancelCollapse()
                }
            }
            .frame(width: 500, height: 400)
            .onChange(of: autoCollapse.shouldCollapse) { _, shouldCollapse in
                if shouldCollapse {
                    withAnimation { showPanel = false }
                    autoCollapse.didCollapse()
                }
            }
        }
    }

    return PreviewWrapper()
}
