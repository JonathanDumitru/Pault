//
//  ExpandingTextEditor.swift
//  Pault
//
//  An auto-expanding text editor that grows vertically as text wraps
//  or the user enters newlines. Wraps NSTextView via NSViewRepresentable.
//

import SwiftUI
import AppKit

struct ExpandingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder, font: font)
    }

    func makeNSView(context: Context) -> AutoExpandingScrollView {
        let scrollView = AutoExpandingScrollView(
            coordinator: context.coordinator,
            font: font
        )
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = scrollView.textView
        scrollView.textView.string = text
        context.coordinator.updatePlaceholder()
        context.coordinator.recalculateHeight()
        return scrollView
    }

    func updateNSView(_ scrollView: AutoExpandingScrollView, context: Context) {
        let textView = scrollView.textView

        // Only update text if the value actually changed to avoid cursor jumps
        if textView.string != text {
            textView.string = text
            context.coordinator.recalculateHeight()
        }

        context.coordinator.updatePlaceholder()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        let placeholder: String
        let font: NSFont
        weak var scrollView: AutoExpandingScrollView?
        weak var textView: NSTextView?
        private var heightRecalcPending = false

        init(text: Binding<String>, placeholder: String, font: NSFont) {
            self.text = text
            self.placeholder = placeholder
            self.font = font
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
            updatePlaceholder()
            scheduleHeightRecalc()
        }

        private func scheduleHeightRecalc() {
            guard !heightRecalcPending else { return }
            heightRecalcPending = true
            DispatchQueue.main.async { [weak self] in
                self?.heightRecalcPending = false
                self?.recalculateHeight()
            }
        }

        func recalculateHeight() {
            guard let textView, let scrollView else { return }
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let textInsets = textView.textContainerInset

            let newHeight = max(
                usedRect.height + textInsets.height * 2,
                AutoExpandingScrollView.minimumHeight
            )

            if abs(scrollView.currentHeight - newHeight) > 0.5 {
                scrollView.currentHeight = newHeight
                scrollView.invalidateIntrinsicContentSize()
            }
        }

        func updatePlaceholder() {
            guard let textView else { return }
            let placeholderLayer = scrollView?.placeholderLayer

            if textView.string.isEmpty && !placeholder.isEmpty {
                if placeholderLayer == nil {
                    let layer = CATextLayer()
                    layer.string = placeholder
                    layer.font = font
                    layer.fontSize = font.pointSize
                    layer.foregroundColor = NSColor.placeholderTextColor.cgColor
                    layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
                    layer.isWrapped = true

                    let insets = textView.textContainerInset
                    let containerOrigin = textView.textContainerOrigin
                    let xOffset = insets.width + containerOrigin.x + 5
                    let yOffset = insets.height + containerOrigin.y
                    layer.frame = CGRect(
                        x: xOffset,
                        y: yOffset,
                        width: textView.bounds.width - xOffset * 2,
                        height: font.pointSize + 4
                    )

                    textView.wantsLayer = true
                    textView.layer?.addSublayer(layer)
                    scrollView?.placeholderLayer = layer
                }
                placeholderLayer?.isHidden = false
            } else {
                placeholderLayer?.isHidden = true
            }
        }
    }
}

// MARK: - AutoExpandingScrollView

/// A scroll view that wraps NSTextView, reports its intrinsic height based on
/// text content, and disables scrollbars so the view expands instead.
final class AutoExpandingScrollView: NSScrollView {
    static let minimumHeight: CGFloat = 30

    let textView: NSTextView
    var currentHeight: CGFloat = AutoExpandingScrollView.minimumHeight
    var placeholderLayer: CATextLayer?

    init(coordinator: ExpandingTextEditor.Coordinator, font: NSFont) {
        let textView = NSTextView()
        self.textView = textView

        super.init(frame: .zero)

        // Configure the text view
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = .textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.delegate = coordinator

        textView.autoresizingMask = [.width]

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }

        // Configure the scroll view — no scrollbars, view grows instead
        self.documentView = textView
        self.hasVerticalScroller = false
        self.hasHorizontalScroller = false
        self.drawsBackground = false
        self.backgroundColor = .clear
        self.autohidesScrollers = true

        self.translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: currentHeight)
    }

    override func layout() {
        super.layout()
        // Keep the text view width in sync with the scroll view
        textView.frame.size.width = contentView.bounds.width
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("ExpandingTextEditor Preview")
                    .font(.headline)

                ExpandingTextEditor(text: $text, placeholder: "Type something...")
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Current text: \(text)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
