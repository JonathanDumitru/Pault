//
//  VariableChipAttachment.swift
//  Pault
//
//  Custom NSTextAttachment + NSTextAttachmentCell that renders a
//  {{variable}} placeholder as a styled pill/chip inline in NSTextView.
//

import AppKit

/// Key used in NSAttributedString to mark variable chip attachments.
let kVariableNameAttributeKey = NSAttributedString.Key("PaultVariableName")

// MARK: - VariableChipAttachment

/// An NSTextAttachment whose cell draws a rounded-rect chip with
/// the variable name centred inside.
final class VariableChipAttachment: NSTextAttachment {
    let variableName: String

    init(variableName: String, font: NSFont) {
        self.variableName = variableName
        super.init(data: nil, ofType: nil)
        self.attachmentCell = VariableChipCell(variableName: variableName, font: font)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

// MARK: - VariableChipCell

/// Draws the pill: accent-tinted rounded rect background with
/// monospaced variable name text.
final class VariableChipCell: NSTextAttachmentCell {
    let variableName: String
    let chipFont: NSFont
    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 3
    private let cornerRadius: CGFloat = 8

    init(variableName: String, font: NSFont) {
        self.variableName = variableName
        // Use a slightly smaller monospaced font for the chip label
        let chipSize = max(font.pointSize - 1, 11)
        self.chipFont = NSFont.monospacedSystemFont(ofSize: chipSize, weight: .medium)
        super.init()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Sizing

    override func cellSize() -> NSSize {
        let textSize = labelSize()
        return NSSize(
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )
    }

    override func cellBaselineOffset() -> NSPoint {
        // Align the chip baseline with the surrounding text baseline.
        let descent = chipFont.descender  // negative value
        return NSPoint(x: 0, y: descent - verticalPadding)
    }

    // MARK: - Drawing

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        let chipRect = cellFrame

        // Background pill
        let accentColor = NSColor.controlAccentColor
        let bgColor = accentColor.withAlphaComponent(0.15)
        let borderColor = accentColor.withAlphaComponent(0.35)
        let path = NSBezierPath(roundedRect: chipRect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)

        bgColor.setFill()
        path.fill()

        borderColor.setStroke()
        path.lineWidth = 0.75
        path.stroke()

        // Label text
        let label = variableName
        let attrs: [NSAttributedString.Key: Any] = [
            .font: chipFont,
            .foregroundColor: accentColor.blended(withFraction: 0.3, of: NSColor.textColor) ?? accentColor,
        ]
        let attrString = NSAttributedString(string: label, attributes: attrs)
        let textSize = attrString.size()
        let textRect = NSRect(
            x: chipRect.minX + (chipRect.width - textSize.width) / 2,
            y: chipRect.minY + (chipRect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrString.draw(in: textRect)
    }

    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView?) {
        if flag {
            let accentColor = NSColor.controlAccentColor
            let highlightColor = accentColor.withAlphaComponent(0.3)
            let path = NSBezierPath(roundedRect: cellFrame.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
            highlightColor.setFill()
            path.fill()
        }
        draw(withFrame: cellFrame, in: controlView)
    }

    // MARK: - Helpers

    private func labelSize() -> NSSize {
        let attrs: [NSAttributedString.Key: Any] = [.font: chipFont]
        return (variableName as NSString).size(withAttributes: attrs)
    }
}

// MARK: - NSAttributedString Helpers

extension NSAttributedString {
    /// Create an attributed string containing a single variable chip attachment.
    static func variableChip(name: String, font: NSFont) -> NSAttributedString {
        let attachment = VariableChipAttachment(variableName: name, font: font)
        let attrString = NSMutableAttributedString(attachment: attachment)
        // Tag the attachment character with the variable name so we can
        // convert back to {{name}} on serialisation.
        attrString.addAttribute(
            kVariableNameAttributeKey,
            value: name,
            range: NSRange(location: 0, length: attrString.length)
        )
        return attrString
    }
}
