# Technology Stack: Testing & QA

**Project:** Pault
**Researched:** 2026-03-14

## Recommended Stack

### Test Frameworks
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift Testing | Built-in (Xcode 16+) | Unit & integration tests | Already adopted in 26/29 test files. Modern `@Test` macro, parameterized tests, better async support than XCTest |
| XCUITest | Built-in | UI smoke tests | Only viable option for macOS app UI testing. Already scaffolded in PaultUITests target |

### Visual Regression
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| swift-snapshot-testing (PointFree) | 1.17+ | Snapshot/visual regression tests | Industry standard for Swift. Supports NSView/NSImage snapshots on macOS. No viable alternative |

### Code Quality
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftLint | Latest | Lint rules enforcement | Catches common issues pre-commit. Pairs with test quality |
| Xcode Code Coverage | Built-in | Coverage measurement | Built into Xcode, no setup needed. Use scheme settings to enable |

### Performance Profiling
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| XCTMetric / XCTest Performance | Built-in | Automated performance baselines | XCTApplicationLaunchMetric already used. Add XCTMemoryMetric, XCTCPUMetric, XCTClockMetric |
| Instruments | Built-in | Deep profiling | Time Profiler, Allocations, SwiftUI view body profiling. Manual but essential pre-launch |

### Accessibility Testing
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Accessibility Inspector | Built-in (Xcode) | Audit accessibility tree | Free, Apple-provided. Catches missing labels, broken navigation |
| XCUIElement accessibility queries | Built-in | Automated a11y verification | Verify elements are findable by assistive technology in XCUITests |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| View testing | Snapshot testing | ViewInspector | ViewInspector is fragile on macOS, breaks with SwiftUI updates, limited macOS support. Snapshot testing catches visual regressions without depending on SwiftUI internals |
| View testing | Snapshot testing | PreviewTesting (Xcode 16) | Apple's `@Previewable` testing is iOS-focused and limited. Good supplement but not primary strategy |
| Mocking | Protocol-based manual mocks | Mockolo / Sourcery | Project size doesn't justify code generation overhead. Manual protocol mocks are sufficient for ~10 services |
| CI | Xcode Cloud | GitHub Actions + fastlane | If already on Xcode Cloud, stick with it. Otherwise GitHub Actions is fine. Not a research priority |
| Fuzzing | Not recommended | swift-fuzz | Overkill for this app type. Focus on parameterized tests for input edge cases |

## NOT Recommended

| Technology | Why Not |
|------------|---------|
| ViewInspector | Fragile. Relies on SwiftUI internal structure that changes between OS versions. macOS support lags iOS. High maintenance cost for low value |
| Quick/Nimble | Legacy BDD frameworks. Swift Testing's `#expect` macro is better. Adding a dependency for style preference is not worth it |
| UI Testing via accessibility identifiers everywhere | Over-engineering. Add identifiers only to elements you actually test, not blanket coverage |

## Installation

```bash
# Add to Package.swift or via Xcode SPM:
# swift-snapshot-testing
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")

# Test target dependency:
.testTarget(
    name: "PaultTests",
    dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
    ]
)
```

## Configuration Notes

### Enable Code Coverage
In Xcode: Edit Scheme > Test > Options > Code Coverage > check "Gather coverage for: Pault target"

### Snapshot Testing Directory
By default, snapshots are stored next to test files in `__Snapshots__/` directories. This is fine -- commit them to git.

### Swift Testing + XCTest Coexistence
Both frameworks work in the same test target. The 3 files still using XCTest (KeychainServiceTests, AIServiceTests, ProStatusManagerTests) can coexist but should be migrated for consistency.

## Sources

- Codebase analysis: 29 test files, 26 using Swift Testing, 3 using XCTest
- Training data: Swift Testing framework, swift-snapshot-testing library (MEDIUM confidence)
