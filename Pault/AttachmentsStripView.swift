//
//  AttachmentsStripView.swift
//  Pault
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AttachmentsStripView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: Prompt

    @State private var dragOver: Bool = false

    private var sortedAttachments: [Attachment] {
        prompt.attachments.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                Label("Attachments", systemImage: "paperclip")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: addAttachment) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .padding(6)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add attachment")
            }

            if !sortedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedAttachments) { attachment in
                            AttachmentThumbnailView(attachment: attachment)
                                .contextMenu {
                                    Button("Open") { openAttachment(attachment) }
                                    Button("Quick Look") { quickLookAttachment(attachment) }
                                    if AttachmentManager.isImage(attachment.mediaType) {
                                        Button("Insert Inline") { insertInline(attachment) }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) { deleteAttachment(attachment) }
                                }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers)
            return true
        }
        .overlay(
            dragOver ? RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 2)
                .padding(2) : nil
        )
    }

    private func addAttachment() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .movie, .audio, .pdf,
                                      .init("com.microsoft.word.doc") ?? .data,
                                      .init("org.openxmlformats.wordprocessingml.document") ?? .data,
                                      .init("com.microsoft.excel.xls") ?? .data,
                                      .init("org.openxmlformats.spreadsheetml.sheet") ?? .data,
                                      .init("com.microsoft.powerpoint.ppt") ?? .data,
                                      .init("org.openxmlformats.presentationml.presentation") ?? .data]

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            addFile(at: url)
        }
    }

    private func addFile(at url: URL) {
        do {
            let attachment = try AttachmentManager.storeFile(at: url, for: prompt.id)
            attachment.sortOrder = prompt.attachments.count

            // Generate thumbnail for images
            if AttachmentManager.isImage(attachment.mediaType) {
                let resolvedURL = AttachmentManager.resolveURL(for: attachment) ?? url
                attachment.thumbnailData = AttachmentManager.generateThumbnail(for: resolvedURL)
            }

            modelContext.insert(attachment)
            prompt.attachments.append(attachment)
            prompt.updatedAt = Date()
            try modelContext.save()
        } catch {
            // Log error silently — could show alert in future
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    addFile(at: url)
                }
            }
        }
    }

    private func deleteAttachment(_ attachment: Attachment) {
        AttachmentManager.deleteFile(for: attachment)
        prompt.attachments.removeAll { $0.id == attachment.id }
        modelContext.delete(attachment)
        prompt.updatedAt = Date()
        try? modelContext.save()
    }

    private func openAttachment(_ attachment: Attachment) {
        guard let url = AttachmentManager.resolveURL(for: attachment) else { return }
        NSWorkspace.shared.open(url)
    }

    private func quickLookAttachment(_ attachment: Attachment) {
        guard let url = AttachmentManager.resolveURL(for: attachment) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func insertInline(_ attachment: Attachment) {
        // Post notification — RichTextEditor listens and inserts the image
        guard let url = AttachmentManager.resolveURL(for: attachment) else { return }
        NotificationCenter.default.post(
            name: .insertInlineImage,
            object: nil,
            userInfo: ["url": url]
        )
    }
}

private struct AttachmentThumbnailView: View {
    let attachment: Attachment

    var body: some View {
        VStack(spacing: 4) {
            if let thumbnailData = attachment.thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                    Image(systemName: iconForMediaType(attachment.mediaType))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 80, height: 80)
            }

            Text(attachment.filename)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 80)
        }
    }

    private func iconForMediaType(_ type: String) -> String {
        if AttachmentManager.isImage(type) { return "photo" }
        if type.contains("movie") || type.contains("video") { return "film" }
        if type.contains("audio") { return "waveform" }
        if type.contains("pdf") { return "doc.richtext" }
        if type.contains("word") || type.contains("document") { return "doc.text" }
        if type.contains("excel") || type.contains("spreadsheet") { return "tablecells" }
        if type.contains("powerpoint") || type.contains("presentation") { return "rectangle.on.rectangle" }
        return "doc"
    }
}
