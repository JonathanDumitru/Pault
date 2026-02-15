//
//  RichTextEditor.swift
//  Pault
//
//  An NSViewRepresentable wrapping NSTextView that supports rich text
//  editing with inline images via NSTextAttachment.
//

import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedContent: Data?
    @Binding var plainContent: String
    var onImageDrop: ((URL) -> Void)?

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

        textView.registerForDraggedTypes([.fileURL, .png, .tiff])

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

        init(parent: RichTextEditor) {
            self.parent = parent
            super.init()
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
            parent.attributedContent = try? textView.textStorage?.data(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
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
            let imageTypes: [NSPasteboard.PasteboardType] = [.fileURL]

            for type in imageTypes where pasteboard.canReadItem(withDataConformingToTypes: [type.rawValue]) {
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                    for url in urls where isImageURL(url) {
                        onImageDrop(url)
                    }
                }
            }
        }

        return super.performDragOperation(sender)
    }

    private func isImageURL(_ url: URL) -> Bool {
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "gif", "bmp", "webp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}
