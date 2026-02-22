//
//  VisualPromptEditor.swift
//  Pault
//
//  A WYSIWYG prompt editor that renders {{variable}} placeholders as
//  interactive pill/chip tokens inline. Under the hood the plain-text
//  representation (with raw {{name}} syntax) is always kept in sync
//  so TemplateEngine and the rest of the app work unchanged.
//

import SwiftUI
import AppKit
import os

private let editorLogger = Logger(subsystem: "com.pault.app", category: "VisualPromptEditor")

// MARK: - SwiftUI Wrapper

struct VisualPromptEditor: NSViewRepresentable {
    @Binding var plainContent: String
    var isEditable: Bool = true
    /// Called when the user triggers the "Insert Variable" action (e.g. /-key).
    var onInsertVariable: (() -> Void)?

    @AppStorage("fontSizePreference") private var fontSizePreference: String = "medium"

    private var editorFontSize: CGFloat {
        switch fontSizePreference {
        case "small": return 13
        case "large": return 17
        default:      return 15
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = VisualEditorTextView()
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesRuler = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.font = NSFont.systemFont(ofSize: editorFontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .textColor
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.onInsertVariable = onInsertVariable

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }

        context.coordinator.textView = textView
        context.coordinator.editorFont = NSFont.systemFont(ofSize: editorFontSize)

        // Load initial content: convert {{variables}} to chips
        context.coordinator.loadPlainContent(plainContent, into: textView)

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
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coord = context.coordinator
        let newFont = NSFont.systemFont(ofSize: editorFontSize)

        // Update font if preference changed
        if coord.editorFont.pointSize != newFont.pointSize {
            coord.editorFont = newFont
            // Reflow chips with new font
            coord.loadPlainContent(plainContent, into: textView)
            return
        }

        // Don't clobber user edits while they're typing
        guard !coord.isEditing else { return }

        // Only reload if the external plain content diverged from our last sync
        if plainContent != coord.lastSyncedPlain {
            coord.loadPlainContent(plainContent, into: textView)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VisualPromptEditor
        var isEditing = false
        weak var textView: NSTextView?
        var editorFont: NSFont = .systemFont(ofSize: 15)
        /// The last plain-text value we synced to the binding, used to
        /// avoid unnecessary reload loops.
        var lastSyncedPlain: String = ""

        private static let variablePattern = /\{\{\s*(\w+)\s*\}\}/
        private var chipInsertObserver: NSObjectProtocol?

        init(parent: VisualPromptEditor) {
            self.parent = parent
            super.init()

            chipInsertObserver = NotificationCenter.default.addObserver(
                forName: .insertVariableChip,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let name = notification.userInfo?["variableName"] as? String else { return }
                self.insertVariableChip(name: name)
            }
        }

        deinit {
            if let observer = chipInsertObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        // MARK: Load plain → chips

        /// Converts plain text with {{variable}} markers into an
        /// NSAttributedString with chip attachments and loads it
        /// into the text view.
        func loadPlainContent(_ plain: String, into textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let result = NSMutableAttributedString()
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: editorFont,
                .foregroundColor: NSColor.textColor,
            ]

            var lastEnd = plain.startIndex
            for match in plain.matches(of: Self.variablePattern) {
                let name = String(match.1).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }

                // Append text before this match
                if lastEnd < match.range.lowerBound {
                    let textPart = String(plain[lastEnd..<match.range.lowerBound])
                    result.append(NSAttributedString(string: textPart, attributes: baseAttrs))
                }

                // Append chip
                result.append(.variableChip(name: name, font: editorFont))

                lastEnd = match.range.upperBound
            }

            // Append trailing text
            if lastEnd < plain.endIndex {
                let trailing = String(plain[lastEnd..<plain.endIndex])
                result.append(NSAttributedString(string: trailing, attributes: baseAttrs))
            }

            textStorage.setAttributedString(result)
            lastSyncedPlain = plain
        }

        // MARK: Chips → plain text

        /// Walks the text storage and serialises chip attachments
        /// back to `{{name}}` syntax, producing the canonical plain text.
        func serializeToPlain() -> String {
            guard let textStorage = textView?.textStorage else { return "" }

            var plain = ""
            textStorage.enumerateAttributes(
                in: NSRange(location: 0, length: textStorage.length),
                options: []
            ) { attrs, range, _ in
                if let varName = attrs[kVariableNameAttributeKey] as? String {
                    plain += "{{\(varName)}}"
                } else {
                    let fragment = textStorage.attributedSubstring(from: range).string
                    plain += fragment
                }
            }
            return plain
        }

        // MARK: Auto-chipify on typing

        /// After each text change, scan for any raw `{{name}}` text and
        /// convert it into a chip attachment in place. This fires when
        /// the user finishes typing `}}`.
        func chipifyRawVariables() {
            guard let textStorage = textView?.textStorage,
                  let textView else { return }

            let fullString = textStorage.string
            let matches = fullString.matches(of: Self.variablePattern)
            guard !matches.isEmpty else { return }

            // Process in reverse so earlier indices stay valid
            let selectedRange = textView.selectedRange()
            var cursorOffset = 0

            textStorage.beginEditing()
            for match in matches.reversed() {
                let name = String(match.1).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }

                let nsRange = NSRange(match.range, in: fullString)
                let chip = NSAttributedString.variableChip(name: name, font: editorFont)

                // Track how cursor shifts: replacing N chars with 1 attachment char
                if nsRange.location + nsRange.length <= selectedRange.location {
                    cursorOffset -= (nsRange.length - 1)
                }

                textStorage.replaceCharacters(in: nsRange, with: chip)
            }
            textStorage.endEditing()

            // Restore cursor position
            let newCursorPos = max(0, min(selectedRange.location + cursorOffset, textStorage.length))
            textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
        }

        // MARK: Insert chip programmatically

        /// Inserts a variable chip at the current cursor position.
        func insertVariableChip(name: String) {
            guard let textView, let textStorage = textView.textStorage else { return }

            let chip = NSAttributedString.variableChip(name: name, font: editorFont)
            let insertionPoint = textView.selectedRange().location

            textStorage.beginEditing()
            textStorage.insert(chip, at: insertionPoint)
            textStorage.endEditing()

            textView.setSelectedRange(NSRange(location: insertionPoint + 1, length: 0))
            syncPlainContent()
        }

        // MARK: NSTextViewDelegate

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            chipifyRawVariables()
            syncPlainContent()
        }

        func textDidChange(_ notification: Notification) {
            // Check if user just typed `}}` — auto-convert any raw variables
            chipifyRawVariables()
            syncPlainContent()
        }

        // MARK: Sync

        private func syncPlainContent() {
            let plain = serializeToPlain()
            lastSyncedPlain = plain
            parent.plainContent = plain
        }
    }
}

// MARK: - VisualEditorTextView

/// Custom NSTextView subclass for the visual prompt editor.
final class VisualEditorTextView: NSTextView {
    var onInsertVariable: (() -> Void)?

    /// Handle delete: when cursor is right after a chip attachment,
    /// select the whole chip first so next delete removes it.
    override func deleteBackward(_ sender: Any?) {
        let loc = selectedRange().location
        if selectedRange().length == 0, loc > 0,
           let textStorage = self.textStorage {
            let prevCharRange = NSRange(location: loc - 1, length: 1)
            let attrs = textStorage.attributes(at: prevCharRange.location, effectiveRange: nil)
            if attrs[kVariableNameAttributeKey] != nil {
                // Select the attachment character so it gets deleted as a unit
                setSelectedRange(prevCharRange)
            }
        }
        super.deleteBackward(sender)
    }

    /// Forward-delete through chips.
    override func deleteForward(_ sender: Any?) {
        let loc = selectedRange().location
        if selectedRange().length == 0,
           let textStorage = self.textStorage,
           loc < textStorage.length {
            let nextCharRange = NSRange(location: loc, length: 1)
            let attrs = textStorage.attributes(at: nextCharRange.location, effectiveRange: nil)
            if attrs[kVariableNameAttributeKey] != nil {
                setSelectedRange(nextCharRange)
            }
        }
        super.deleteForward(sender)
    }
}

// MARK: - Notification for inserting a variable chip

extension Notification.Name {
    static let insertVariableChip = Notification.Name("insertVariableChip")
}
