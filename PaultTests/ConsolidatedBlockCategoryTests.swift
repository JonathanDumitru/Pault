//
//  ConsolidatedBlockCategoryTests.swift
//  PaultTests
//
//  Tests for ConsolidatedBlockCategory enum which maps 20+ BlockCategory
//  values into 7 top-level groups for better discoverability.
//

import Testing
@testable import Pault

struct ConsolidatedBlockCategoryTests {

    @Test func allCases_returns7Categories() {
        #expect(ConsolidatedBlockCategory.allCases.count == 7)
    }

    @Test func role_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.role.legacyCategories
        #expect(mapped.contains(.rolePerspective))
        #expect(mapped.contains(.perspectiveFrames))
    }

    @Test func context_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.context.legacyCategories
        #expect(mapped.contains(.inputs))
        #expect(mapped.contains(.domainSpecific))
    }

    @Test func task_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.task.legacyCategories
        #expect(mapped.contains(.intent))
        #expect(mapped.contains(.instructions))
        #expect(mapped.contains(.taskTemplates))
        #expect(mapped.contains(.execution))
    }

    @Test func format_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.format.legacyCategories
        #expect(mapped.contains(.structure))
        #expect(mapped.contains(.toneStyle))
        #expect(mapped.contains(.outputStructures))
        #expect(mapped.contains(.communicationPatterns))
    }

    @Test func constraints_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.constraints.legacyCategories
        #expect(mapped.contains(.constraints))
        #expect(mapped.contains(.verification))
        #expect(mapped.contains(.qualityControls))
    }

    @Test func examples_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.examples.legacyCategories
        #expect(mapped.contains(.logic))
        #expect(mapped.contains(.transforms))
        #expect(mapped.contains(.interactionModes))
    }

    @Test func meta_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.meta.legacyCategories
        #expect(mapped.contains(.reasoning))
        #expect(mapped.contains(.metaPrompting))
        #expect(mapped.contains(.reuse))
        #expect(mapped.contains(.modelConfig))
        #expect(mapped.contains(.agenticWorkflows))
        #expect(mapped.contains(.softwareEngineering))
        #expect(mapped.contains(.dataAnalysis))
        #expect(mapped.contains(.creativeContent))
    }

    @Test func consolidate_mapsLegacyCategoryToConsolidated() {
        #expect(ConsolidatedBlockCategory.from(legacy: .rolePerspective) == .role)
        #expect(ConsolidatedBlockCategory.from(legacy: .perspectiveFrames) == .role)
        #expect(ConsolidatedBlockCategory.from(legacy: .inputs) == .context)
        #expect(ConsolidatedBlockCategory.from(legacy: .intent) == .task)
        #expect(ConsolidatedBlockCategory.from(legacy: .structure) == .format)
        #expect(ConsolidatedBlockCategory.from(legacy: .constraints) == .constraints)
        #expect(ConsolidatedBlockCategory.from(legacy: .logic) == .examples)
        #expect(ConsolidatedBlockCategory.from(legacy: .reasoning) == .meta)
    }

    @Test func icon_returnsCorrectSFSymbol() {
        #expect(ConsolidatedBlockCategory.role.icon == "person.fill")
        #expect(ConsolidatedBlockCategory.context.icon == "book.fill")
        #expect(ConsolidatedBlockCategory.task.icon == "checkmark.circle.fill")
        #expect(ConsolidatedBlockCategory.format.icon == "list.bullet.rectangle.fill")
        #expect(ConsolidatedBlockCategory.constraints.icon == "xmark.octagon.fill")
        #expect(ConsolidatedBlockCategory.examples.icon == "doc.text.fill")
        #expect(ConsolidatedBlockCategory.meta.icon == "gearshape.fill")
    }

    @Test func allLegacyCategories_areMappedExactlyOnce() {
        var mappedCategories = Set<BlockCategory>()

        for consolidated in ConsolidatedBlockCategory.allCases {
            for legacy in consolidated.legacyCategories {
                #expect(!mappedCategories.contains(legacy), "Category \(legacy) is mapped more than once")
                mappedCategories.insert(legacy)
            }
        }

        // Verify all legacy categories are covered
        for legacy in BlockCategory.allCases {
            #expect(mappedCategories.contains(legacy), "Category \(legacy) is not mapped to any consolidated category")
        }
    }

    @Test func id_returnsRawValue() {
        for category in ConsolidatedBlockCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }

    @Test func color_returnsNonNilForAllCases() {
        for category in ConsolidatedBlockCategory.allCases {
            // Just verify color can be accessed without crashing
            _ = category.color
        }
    }
}
