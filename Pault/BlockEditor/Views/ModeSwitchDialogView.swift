//
//  ModeSwitchDialogView.swift
//  Pault
//
//  Dialog for switching between Text and Blocks editing modes.
//  Offers AI parsing for Pro users, Start Fresh for all users.
//

import SwiftUI

/// Dialog presented when user switches from Text to Blocks mode
struct ModeSwitchDialogView: View {
    @Binding var isPresented: Bool
    let hasExistingContent: Bool
    let isPro: Bool
    let onParse: () -> Void
    let onStartFresh: () -> Void
    let onShowPaywall: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Switch to Blocks Mode")
                    .font(.headline)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                Text("How would you like to start?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Parse option (Pro only)
                if hasExistingContent {
                    parseOption
                }

                // Start Fresh option
                startFreshOption
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()
            }
            .padding()
        }
        .frame(width: 420)
    }

    // MARK: - Parse Option

    private var parseOption: some View {
        Button(action: {
            if isPro {
                isPresented = false
                onParse()
            } else {
                onShowPaywall()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Parse with AI")
                            .font(.callout)
                            .fontWeight(.semibold)

                        if isPro {
                            Text("Recommended")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        } else {
                            ProBadge()
                        }
                    }

                    Text("AI analyzes your text and creates matching blocks automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.blue.opacity(isPro ? 0.3 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Start Fresh Option

    private var startFreshOption: some View {
        Button(action: {
            isPresented = false
            onStartFresh()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus.square.dashed")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Fresh")
                        .font(.callout)
                        .fontWeight(.semibold)

                    Text(hasExistingContent
                        ? "Begin with an empty canvas; your text stays in preview for reference"
                        : "Begin with an empty canvas and build your prompt block by block")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Blocks to Text Warning

/// Warning dialog when switching from Blocks to Text with diverged state
struct BlocksToTextWarningView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Switch to Text Mode?")
                    .font(.headline)

                Spacer()
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 12) {
                Text("Your block composition will be compiled into text.")
                    .font(.subheadline)

                Text("You can switch back to Blocks mode later, but you'll need to re-parse or start fresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Switch to Text") {
                    isPresented = false
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 380)
    }
}

#Preview("Mode Switch Dialog") {
    ModeSwitchDialogView(
        isPresented: .constant(true),
        hasExistingContent: true,
        isPro: true,
        onParse: {},
        onStartFresh: {},
        onShowPaywall: {}
    )
}

#Preview("Blocks to Text Warning") {
    BlocksToTextWarningView(
        isPresented: .constant(true),
        onConfirm: {}
    )
}
