//
//  StudioTab.swift
//  Pault
//
//  Studio tab enumeration (from Schemap)
//

import Foundation

/// High-level tabs: Build, Variants, Exports
enum StudioTab: String, CaseIterable, Identifiable {
    case build = "Build"
    case variants = "Variants"
    case exports = "Exports"

    var id: String { rawValue }
}
