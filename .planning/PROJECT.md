# Pault — Project Context

## What This Is

Pault is a macOS-exclusive, local-first prompt library and AI workflow tool. It provides power users with a centralized, on-device system for managing, composing, and executing AI prompts across three surfaces: main window, menu bar popover, and global hotkey launcher. v1.0 ships with a generous free tier and full Pro tier (AI Assist, Versioning, Analytics, API Runner, Smart Collections) behind a StoreKit 2 annual subscription paywall.

## Core Value

Local-first macOS prompt library with premium Pro tier — ship polished to App Store with full feature set.

## Requirements

### Validated

- ✓ R1.1: Canvas UX Edge Cases — v1.0
- ✓ R1.2: Block Editor Testing — v1.0
- ✓ R1.3: Block Editor Accessibility — v1.0
- ✓ R1.4: Block Editor Performance — v1.0
- ✓ R2.1: AI Prompt Improvement — v1.0
- ✓ R2.2: AI Variable Suggestion — v1.0
- ✓ R2.3: AI Auto-Tagging — v1.0
- ✓ R2.4: AI Quality Scoring — v1.0
- ✓ R2.5: Proxy Service Integration — v1.0
- ✓ R3.1: Version History — v1.0
- ✓ R3.2: Version Restore — v1.0
- ✓ R3.3: Version Diff — v1.0
- ✓ R4.1: Analytics Dashboard — v1.0
- ✓ R4.2: Analytics Data Collection — v1.0
- ✓ R4.3: Smart Collections — v1.0
- ✓ R5.1: Prompt Execution — v1.0
- ✓ R5.2: Response Management — v1.0
- ✓ R5.3: Refinement Loop — v1.0
- ✓ R6.1: Subscription Management — v1.0
- ✓ R6.2: Paywall UI — v1.0
- ✓ R6.3: Feature Gating — v1.0
- ✓ R6.4: StoreKit 2 Testing — v1.0
- ✓ R7.1: Privacy & Compliance — v1.0
- ✓ R7.2: Sandboxing & Entitlements — v1.0
- ✓ R7.3: App Store Metadata — v1.0
- ✓ R7.4: Signing & Distribution — v1.0
- ✓ R8.1: Comprehensive Testing — v1.0
- ✓ R8.2: Accessibility Audit — v1.0
- ✓ R8.3: Performance Profiling — v1.0
- ✓ R8.4: UX Consistency Pass — v1.0
- ✓ R9.1: Export — v1.0
- ✓ R9.2: Import — v1.0
- ✓ R9.3: Interoperability — v1.0
- ✓ DOC-01: REQUIREMENTS.md traceability accuracy — v1.1
- ✓ DOC-02: Phase 04 SUMMARY requirements-completed fields — v1.1
- ✓ DOC-03: Legal docs launch date placeholder — v1.1
- ✓ DATA-01: ImportOrchestrator restores attachmentFileNames — v1.1
- ✓ DATA-02: PromptService.copyToClipboard uses current CopyEvent init — v1.1
- ✓ CODE-01: SidebarView delegates to PromptService.filterPrompts — v1.1
- ✓ UX-01: Proxy-not-configured guard before AI calls — v1.1
- ✓ UX-02: AI-curated collection refresh button in sidebar — v1.1
- ✓ UX-03: ProStatusManager screenshot-mode override (sync init + async refresh) — v1.1 (Phase 17 closure)
- ✓ TEST-01: ScreenshotTests use real accessibility identifiers — v1.1 (Phase 17 closure)
- ✓ TEST-02: Phase 02 human verification (7 items) — v1.1
- ✓ TEST-03: Phase 08 human verification (3 items) — v1.1

### Active

<!-- v1.2 — TBD via /gsd:new-milestone -->

- [ ] Define v1.2 scope (run `/gsd:new-milestone`)

## Current Milestone: v1.2 (Planning)

**Status:** Not yet defined — run `/gsd:new-milestone` to scope.

### Out of Scope

- CLI companion — deferred, skeleton only
- Team sync / iCloud sync — deferred
- Block marketplace/sharing — deferred
- Collaborative editing — out of scope
- Natural language to blocks — deferred
- PaultCore integration — deferred, Swift package created but not wired
- Mobile app — macOS-exclusive

## Context

Shipped v1.0 (33/33 requirements) and v1.1 (12/12 requirements) — 17 phases total over 46 days, 327 commits.
Tech stack: SwiftUI (macOS 15+), SwiftData, StoreKit 2, Carbon (global hotkeys), XCTest + Swift Testing.
Architecture: `PaultApp.swift` → SwiftData ModelContainer, `PromptStudioModel` (main state machine), actor-based `AIService` with Cloudflare Worker proxy (`pault-proxy/`).
v1.1 closed all 15 tracked tech debt items and 3 advisory integration issues from v1.0. Audit-found gaps (TEST-01, UX-03) closed via inserted Phase 17.

Known operational constraint: macOS Stage Manager interferes with XCUITest window discovery — must be disabled during screenshot test runs (no code workaround in macOS 25.4).
Minor remaining tech debt: legacy single-arg CopyEvent init unused but not removed; 5 Thread.sleep calls in ScreenshotTests for pacing; Nyquist compliance retrofit deferred (out of scope per v1.1 REQUIREMENTS).

## Key Decisions

| # | Decision | Rationale | Outcome |
|---|----------|-----------|---------|
| 1 | All Pro features ship in v1.0 | User chose full feature set over research recommendation to defer | ✓ Good — all 6 Pro features shipped |
| 2 | Annual subscription at $59.99/yr | Research-recommended price point | — Pending (not yet launched) |
| 3 | Proxy service for AI calls | Subscription auth + rate limiting + provider abstraction | ✓ Good — decouples API keys from client |
| 4 | ProFeature.isUnlocked centralized gating | Single source of truth for feature access | ✓ Good — consistent across 14+ call sites |
| 5 | UndoManager groupsByEvent=false | Required explicit grouping for canvas operations | ⚠️ Revisit — macOS 26 Swift Concurrency + ObjC crash workarounds needed |
| 6 | SwiftData local-only (no iCloud) | Local-first privacy commitment | ✓ Good — simplifies data model |
| 7 | Xcode 16 folder sync for resources | PBXFileSystemSynchronizedRootGroup auto-includes files | ✓ Good — no manual project.pbxproj entries |
| 8 | VersionSource enum for version tracking | Distinguishes manual, AI, import, restore sources | ✓ Good — clean history attribution |
| 9 | Pault-proxy in monorepo subdirectory | Development pragmatism over separate repo | ✓ Good — simpler development workflow |
| 10 | paymentMode default: (not @unknown default:) | Swift exhaustiveness for non-open StoreKit enum | ✓ Good — compiler-verified |
| 11 | Import attachment stubs use storageMode=stub | Preserves filename metadata without implying file data is present; enables round-trip fidelity | ✓ Good — DATA-01 satisfied |
| 12 | SidebarView delegates to PromptService.filterPrompts | PromptService has extended filter fields (qualityScore, model, contentContains) not in SidebarView's inline version | ✓ Good — eliminates duplication |
| 13 | noProxyStateView ordered before noKeyStateView | Proxy misconfiguration is more fundamental than missing API key; surfaced first in AI error chain | ✓ Good — clearer onboarding |
| 14 | Screenshot-mode Pro override wrapped in #if DEBUG | Defensive — prevents release-build exposure even though App Store builds cannot inject launch arguments | ✓ Good — defense-in-depth |
| 15 | .accessibilityLabel on Analytics toolbar Button (not .accessibilityIdentifier) | Matches existing test query `app.buttons["Analytics"]` string-for-string with zero test-side change | ✓ Good — closed TEST-01 with minimal blast radius |
| 16 | .accessibilityIdentifier inside NavigationStack render tree (not outer container) | Outer-view placement is structurally invisible to XCUITest; identifiers must live in the rendered subtree | ✓ Good — surfaced as v1.1 audit lesson |
| 17 | Sync `--screenshot-mode` override in ProStatusManager.init() before async Task | Eliminates first-render race for @Observable state — Pro UI visible on first SwiftUI paint | ✓ Good — closed UX-03 race |
| 18 | Stage Manager incompatibility documented as operational constraint (not code) | macOS 25.4 XCUITest cannot reliably discover windows under Stage Manager; no code workaround available | — Pending — needs CI documentation |

## Constraints

- macOS 15+ minimum deployment target
- App Sandbox required for App Store
- Hardened Runtime required for notarization
- No user data leaves device (except proxy API calls with subscription auth)
- StoreKit 2 (not original StoreKit)
- Carbon API for global hotkeys (sandbox-compatible)

## User

- Solo developer building a premium macOS app
- High quality bar — polish and testing are first-class concerns
- Iterative deployment approach
- Experienced with Swift/SwiftUI ecosystem

## Workflow Preferences

- **Mode:** Thorough — include dedicated testing and polish phases
- **Granularity:** Medium — phases should be meaningful chunks, not too granular
- **Research:** Yes — domain research before implementation where it helps

---
*Last updated: 2026-04-29 after v1.1 milestone completion*
