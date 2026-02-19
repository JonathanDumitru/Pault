//
//  Constants.swift
//  Pault
//

import Carbon
import CoreGraphics

/// Application-wide named constants.
/// Use these instead of inline literals for window sizes, key codes, and durations.
enum AppConstants {
    enum Windows {
        static let mainDefault    = CGSize(width: 900, height: 600)
        static let aboutDefault   = CGSize(width: 400, height: 280)
        static let promptDefault  = CGSize(width: 700, height: 620)
        static let prefsDefault   = CGSize(width: 460, height: 360)
        static let menuBarDefault = CGSize(width: 320, height: 480)
    }

    enum Hotkey {
        /// Carbon key code for the P key.
        static let defaultKeyCode:   UInt32 = 0x23
        /// Default modifier flags: ⌘⇧
        static let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    }

    enum Timing {
        /// Duration (seconds) before auto-dismissing toast notifications.
        static let toastDuration: TimeInterval = 1.5
    }
}
