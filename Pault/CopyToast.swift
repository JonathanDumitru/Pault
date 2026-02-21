//
//  CopyToast.swift
//  Pault
//

import SwiftUI

enum ToastStyle {
    case success, error, warning

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error:   return .red
        case .warning: return .orange
        }
    }
}

struct CopyToastView: View {
    let message: String
    var style: ToastStyle = .success

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: style.icon)
                .foregroundStyle(style.color)
            Text(message)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

/// Existing copy toast — backward compatible, no call-site changes needed.
struct CopyToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    var message: String = "Copied!"

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isShowing {
                CopyToastView(message: message, style: .success)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        // Announce to VoiceOver users that the copy succeeded
                        NSAccessibility.post(element: NSApp as AnyObject,
                                             notification: .announcementRequested,
                                             userInfo: [NSAccessibilityAnnouncementKey: message,
                                                        NSAccessibilityPriorityKey: NSAccessibilityPriorityLevel.medium.rawValue])
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Timing.toastDuration) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: isShowing)
    }
}

/// New generic status toast (success / error / warning).
struct StatusToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    var style: ToastStyle
    var message: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isShowing {
                CopyToastView(message: message, style: style)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Timing.toastDuration) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: isShowing)
    }
}

extension View {
    /// Backward-compatible copy toast.
    func copyToast(isShowing: Binding<Bool>, message: String = "Copied!") -> some View {
        modifier(CopyToastModifier(isShowing: isShowing, message: message))
    }

    /// Generic status toast for success, error, or warning messages.
    func statusToast(isShowing: Binding<Bool>, style: ToastStyle, message: String) -> some View {
        modifier(StatusToastModifier(isShowing: isShowing, style: style, message: message))
    }
}
