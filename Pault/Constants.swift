//
//  Constants.swift
//  Pault
//

import Carbon
import CoreGraphics
import SwiftUI

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

    // MARK: - Spacing (8pt grid system)

    enum Spacing {
        /// 4pt — half of base grid unit
        static let halfGrid: CGFloat = 4
        /// 8pt — base grid unit
        static let grid: CGFloat = 8
        /// 16pt — double grid unit
        static let doubleGrid: CGFloat = 16
    }

    // MARK: - Corner Radii

    enum CornerRadius {
        /// 4pt — small elements (badges, tags)
        static let small: CGFloat = 4
        /// 8pt — medium elements (block rows, cards)
        static let medium: CGFloat = 8
        /// 12pt — large elements (overlays, dialogs)
        static let large: CGFloat = 12
    }

    // MARK: - Shadow Scale

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        /// Subtle rest-state shadow for block rows
        static let subtle = ShadowStyle(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        /// Medium shadow for hover and selected states
        static let medium = ShadowStyle(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        /// Elevated shadow for overlays and dialogs
        static let elevated = ShadowStyle(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    // MARK: - Standard Animations

    enum StandardAnimation {
        /// Standard easeInOut at 0.2s — for most UI transitions
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
        /// Spring for interactive elements — response 0.3, damping 0.8
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
    }

    // MARK: - Canvas Layout

    enum Canvas {
        /// Minimum canvas width before panels auto-collapse
        static let minWidth: CGFloat = 300
        /// Maximum height for block input text fields before scrolling
        static let maxInputHeight: CGFloat = 500
        /// Block count at which a performance/complexity warning is shown
        static let blockCountWarning: Int = 30
    }
}
