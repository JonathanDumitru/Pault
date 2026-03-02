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

    // MARK: - Collapsible Panel System

    enum Panels {
        /// Sidebar panel width (main window)
        static let sidebarWidth: CGFloat = 240
        /// Sidebar minimum width
        static let sidebarMinWidth: CGFloat = 220
        /// Sidebar maximum width
        static let sidebarMaxWidth: CGFloat = 280

        /// Inspector panel width (main window)
        static let inspectorWidth: CGFloat = 220
        /// Inspector minimum width
        static let inspectorMinWidth: CGFloat = 200
        /// Inspector maximum width
        static let inspectorMaxWidth: CGFloat = 260

        /// Block library width (block editor)
        static let blockLibraryWidth: CGFloat = 200
        /// Block library minimum width
        static let blockLibraryMinWidth: CGFloat = 180
        /// Block library maximum width
        static let blockLibraryMaxWidth: CGFloat = 260

        /// Block preview width (block editor)
        static let blockPreviewWidth: CGFloat = 240
        /// Block preview minimum width
        static let blockPreviewMinWidth: CGFloat = 220
        /// Block preview maximum width
        static let blockPreviewMaxWidth: CGFloat = 300

        /// Editor content-width constraint for readability
        static let editorMaxContentWidth: CGFloat = 700

        // MARK: - Animation

        enum Animation {
            /// Duration for panel slide animation (seconds)
            static let slideDuration: Double = 0.35
            /// Damping fraction for spring animation (0.0-1.0)
            static let dampingFraction: Double = 0.8
            /// Duration for fade animations (seconds)
            static let fadeDuration: Double = 0.5
        }

        // MARK: - Auto-Collapse

        enum AutoCollapse {
            /// Delay before warning phase starts (seconds after typing)
            static let warningDelay: TimeInterval = 1.5
            /// Duration of warning phase before collapse (seconds)
            static let warningDuration: TimeInterval = 0.5
            /// Total delay = warningDelay + warningDuration = 2s
            /// Opacity during warning phase
            static let warningOpacity: Double = 0.6
        }
    }
}
