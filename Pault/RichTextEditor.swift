//
//  RichTextEditor.swift
//  Pault
//
//  An NSViewRepresentable wrapping NSTextView that supports rich text
//  editing with inline images via NSTextAttachment.
//

import SwiftUI
import AppKit
import os

private let richTextLogger = Logger(subsystem: "com.pault.app", category: "RichTextEditor")

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedContent: Data?
    @Binding var plainContent: String
    var onImageDrop: ((URL) -> Void)?
    var isEditable: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = RichEditorTextView()
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.usesRuler = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .textColor
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.isEditable = isEditable
        textView.isSelectable = true

        if isEditable {
            textView.registerForDraggedTypes([.fileURL, .URL, .png, .tiff])
        }

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }

        // Load initial content
        if let data = attributedContent {
            loadRTFDData(data, into: textView)
        } else {
            textView.string = plainContent
        }

        textView.onImageDrop = onImageDrop
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard !context.coordinator.isEditing else { return }
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if let data = attributedContent {
            loadRTFDData(data, into: textView)
        }
    }

    private func loadRTFDData(_ data: Data, into textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        guard let attributedString = NSAttributedString(
            rtfd: data,
            documentAttributes: nil
        ) else { return }

        textStorage.setAttributedString(attributedString)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isEditing = false
        weak var textView: NSTextView?
        private var imageObserver: NSObjectProtocol?

        init(parent: RichTextEditor) {
            self.parent = parent
            super.init()

            if parent.isEditable {
                imageObserver = NotificationCenter.default.addObserver(
                    forName: .insertInlineImage,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    self?.handleInsertInlineImage(notification)
                }
            }
        }

        deinit {
            if let observer = imageObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        private func handleInsertInlineImage(_ notification: Notification) {
            guard let textView,
                  let image = notification.userInfo?["image"] as? NSImage else {
                richTextLogger.warning("insertInlineImage: Missing textView or image")
                return
            }

            // Scale image to fit within editor width
            let maxWidth = textView.textContainer?.containerSize.width ?? 400
            let scale = min(1.0, (maxWidth - 20) / image.size.width)
            let scaledSize = NSSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let scaledImage = NSImage(size: scaledSize)
            scaledImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: scaledSize))
            scaledImage.unlockFocus()

            let attachment = NSTextAttachment()
            let cell = NSTextAttachmentCell(imageCell: scaledImage)
            attachment.attachmentCell = cell

            let attrString = NSAttributedString(attachment: attachment)

            let insertionPoint = textView.selectedRange().location
            textView.textStorage?.insert(attrString, at: insertionPoint)

            // Move cursor past the inserted image
            textView.setSelectedRange(NSRange(location: insertionPoint + 1, length: 0))

            syncContent()
            richTextLogger.info("Inserted inline image")
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            syncContent()
        }

        func textDidChange(_ notification: Notification) {
            syncContent()
        }

        private func syncContent() {
            guard let textView else { return }

            parent.plainContent = textView.string

            let fullRange = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
            do {
                parent.attributedContent = try textView.textStorage?.data(
                    from: fullRange,
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                )
            } catch {
                richTextLogger.error("syncContent: Failed to serialize RTFD — \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - RichEditorTextView

/// Custom NSTextView subclass that reports dropped image URLs via a callback.
final class RichEditorTextView: NSTextView {
    var onImageDrop: ((URL) -> Void)?

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let onImageDrop {
            let pasteboard = sender.draggingPasteboard
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                for url in urls where isImageURL(url) {
                    onImageDrop(url)
                }
            }
        }

        // Delegate all remaining handling (including non-image content) to NSTextView
        return super.performDragOperation(sender)
    }

    private func isImageURL(_ url: URL) -> Bool {
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "gif", "bmp", "webp", "heic", "heif"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
