//
//  CopyToast.swift
//  Pault
//

import SwiftUI

struct CopyToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
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

/// A view modifier that shows a brief "Copied!" toast overlay.
struct CopyToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    var message: String = "Copied!"

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isShowing {
                CopyToastView(message: message)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
    func copyToast(isShowing: Binding<Bool>, message: String = "Copied!") -> some View {
        modifier(CopyToastModifier(isShowing: isShowing, message: message))
    }
}
