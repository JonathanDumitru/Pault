//
//  OnboardingView.swift
//  Pault
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "text.bubble",
            title: "Welcome to Pault",
            subtitle: "Your AI prompt library",
            description: "Organize, tag, and quickly access your prompts from anywhere on your Mac."
        ),
        OnboardingPage(
            icon: "menubar.rectangle",
            title: "Three Ways to Access",
            subtitle: "Always within reach",
            description: "Use the main window for management, the menu bar for quick access, or press ⌘⇧P to launch the hotkey search from any app."
        ),
        OnboardingPage(
            icon: "keyboard",
            title: "Built for Speed",
            subtitle: "Keyboard-first workflow",
            description: "Press ⌘⇧P to search, ⌘1-9 to select, and Return to copy or paste instantly. Star your favorites for quick access."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 16) {
                        Spacer()

                        Image(systemName: page.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)
                            .frame(height: 60)

                        Text(page.title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(page.subtitle)
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)

                        Spacer()
                    }
                    .tag(index)
                    .padding(.horizontal, 40)
                }
            }
            .tabViewStyle(.automatic)
            .frame(height: 300)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .frame(width: 440, height: 420)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
