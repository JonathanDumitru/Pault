//
//  AboutView.swift
//  Pault
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            VStack(spacing: 4) {
                Text("Pault")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Turn prompt experimentation into repeatable craft.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Divider()

            HStack(spacing: 12) {
                Link("hello@pault.app", destination: URL(string: "mailto:hello@pault.app")!)
                    .font(.caption)

                Text("·")
                    .foregroundStyle(.tertiary)

                Link("Privacy Policy", destination: URL(string: "https://pault.app/privacy")!)
                    .font(.caption)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("© 2026 Pault")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    AboutView()
}
