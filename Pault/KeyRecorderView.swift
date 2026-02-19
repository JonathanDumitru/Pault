//
//  KeyRecorderView.swift
//  Pault
//
//  An NSViewRepresentable that captures a keyboard shortcut and converts it
//  to Carbon key code + modifier flags for use with GlobalHotkeyManager.
//

import SwiftUI
import AppKit
import Carbon

// MARK: - SwiftUI wrapper

struct KeyRecorderView: NSViewRepresentable {
    @Binding var displayString: String
    var onRecorded: (UInt32, UInt32) -> Void   // (keyCode, carbonModifiers)

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onRecorded = onRecorded
        view.displayString = displayString
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.displayString = displayString
        nsView.needsDisplay = true
    }

    // MARK: - Static helpers (shared with PreferencesView reset button)

    static func makeDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += keyCharacter(for: keyCode)
        return s
    }

    private static func keyCharacter(for keyCode: UInt32) -> String {
        // Carbon virtual key codes for the US keyboard layout
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "\\"
        case 0x2B: return ","
        case 0x2C: return "/"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x31: return "Space"
        case 0x24: return "↩"   // Return
        case 0x30: return "⇥"   // Tab
        case 0x33: return "⌫"   // Backspace
        case 0x35: return "⎋"   // Escape
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        default:   return "?"
        }
    }
}

// MARK: - NSView subclass

final class KeyRecorderNSView: NSView {
    var onRecorded: ((UInt32, UInt32) -> Void)?
    var displayString: String = "⌘⇧P" {
        didSet { needsDisplay = true }
    }

    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let cornerRadius: CGFloat = 6
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: cornerRadius, yRadius: cornerRadius)

        // Background
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        path.fill()

        // Border
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 1.5 : 1.0
        path.stroke()

        // Label
        let label = isRecording ? "Recording…" : displayString
        let color: NSColor = isRecording ? .secondaryLabelColor : .labelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: color
        ]
        let size = label.size(withAttributes: attrs)
        let origin = CGPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        label.draw(at: origin, withAttributes: attrs)
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        guard window?.makeFirstResponder(self) == true else { return }
        isRecording = true
        needsDisplay = true
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Escape cancels
        if event.keyCode == 0x35 {
            isRecording = false
            needsDisplay = true
            return
        }

        let carbonMods = carbonModifiers(from: event.modifierFlags)
        let keyCode = UInt32(event.keyCode)

        isRecording = false
        needsDisplay = true

        onRecorded?(keyCode, carbonMods)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    // MARK: Helpers

    private func carbonModifiers(from nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if nsFlags.contains(.command) { mods |= UInt32(cmdKey) }
        if nsFlags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if nsFlags.contains(.option)  { mods |= UInt32(optionKey) }
        if nsFlags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
}
