//
//  DiagnosticReportView.swift
//  Pault
//
//  Shown on launch when a crash report from the previous session is found.
//  The user can review the report and optionally copy it or dismiss.
//

import SwiftUI

struct DiagnosticReportView: View {
    @Environment(\.dismiss) private var dismiss

    let reportText: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pault crashed last session")
                        .font(.headline)
                    Text("A diagnostic report was saved. You can copy it to share with support.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Report text (scrollable, read-only)
            ScrollView {
                Text(reportText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(height: 240)

            // Actions
            HStack {
                Button("Discard Report") {
                    CrashReportingService.clearPendingCrashReport()
                    dismiss()
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button(copied ? "Copied!" : "Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(reportText, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copied = false }
                    }
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    CrashReportingService.clearPendingCrashReport()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
