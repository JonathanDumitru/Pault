# Milestones

## v1.1 Tech Debt Cleanup (Shipped: 2026-04-29)

**Phases:** 5 (13-17) | **Plans:** 6 | **Commits:** 42
**Timeline:** 2 days (2026-04-27 to 2026-04-29)
**Files changed:** 46 | **Lines:** +4,050 / -105
**Git range:** `99b8317` (docs: start milestone v1.1) to `3c9a426` (docs(phase-17): complete phase execution)

**Key accomplishments:**
1. Documentation accuracy — v1.0 traceability table fully populated, Phase 04 SUMMARY frontmatter restored, legal launch date placeholder fixed (DOC-01/02/03)
2. Data integrity — JSON import restores attachment stubs (DATA-01); CopyEvent uses current two-arg init (DATA-02); SidebarView delegates filtering to PromptService canonical path (CODE-01)
3. UX polish — proxy-not-configured guard before API key check, AI-curated collection refresh button with spinner, DEBUG-guarded ProStatusManager screenshot-mode override (UX-01/02/03)
4. Test reachability — accessibility identifiers added to 5 production SwiftUI views, ScreenshotTests rewritten to use real identifiers (TEST-01)
5. Human verification sign-off — all 7 Phase 02 + 3 Phase 08 deferred items signed off (TEST-02/03)
6. Audit-driven Phase 17 closure — Analytics toolbar XCUI-reachable via `.accessibilityLabel("Analytics")`, sync `--screenshot-mode` override eliminates first-paint race in `ProStatusManager.init()`, `analytics-view` identifier moved into NavigationStack render tree; `testShot06_AnalyticsDashboard` runs end-to-end

**Delivered:** All 15 tracked tech debt items and 3 advisory integration issues from v1.0 closed. 12/12 requirements fully satisfied across 3 audit sources (VERIFICATION.md, SUMMARY frontmatter, REQUIREMENTS.md traceability). Cross-phase integration check verified 6 of 6 milestone flows end-to-end.

### Known Gaps

**Minor tech debt (deferred, not blocking):**
- Legacy single-arg `CopyEvent` init still exists in `CopyEvent.swift:32` with zero production callers — could be removed in a future cleanup
- `ScreenshotTests.swift` contains 5 fixed-duration `Thread.sleep` calls between navigation steps (standard UI-test pacing, not substitutes for `waitForExistence`) — replace with explicit waits in a future iteration
- `menu-bar-content` accessibility identifier exists in production (`MenuBarContentView:147`) but is not queried by any test — `testShot05` navigates via `app.menuBars.buttons['Pault']` instead

**Operational constraint (not code):**
- macOS 25.4 Stage Manager interferes with XCUITest window discovery — must be disabled during screenshot test runs. Documented in `17-01-SUMMARY.md`. Future CI configuration should disable Stage Manager before invoking screenshot test suites.

**Nyquist:** PARTIAL — explicitly out of scope for v1.1 per `REQUIREMENTS.md:48` (would require re-running all 12 v1.0 validations as separate effort). Phase 13 compliant; Phase 15 partial; Phases 14, 16, 17 missing.

---

## v1.0 App Store Launch (Shipped: 2026-04-28)

**Phases:** 12 | **Plans:** 29 | **Commits:** 285
**Timeline:** 44 days (2026-03-14 to 2026-04-27)
**LOC:** 45,970 Swift | **Files:** 458 modified
**Git range:** `a7981f5` (feat(01-01)) to `dffb0bd` (docs(phase-12))

**Key accomplishments:**
1. Privacy manifest, entitlement cleanup, and test infrastructure foundation
2. Block editor polish — drag-drop, undo/redo, accessibility, performance benchmarks
3. StoreKit 2 paywall — ProFeature gating, dynamic offers, subscription lifecycle tests
4. AI Assist & API Runner — proxy service, streaming improve/variables/tags/score, prompt execution
5. Versioning, Analytics & Smart Collections — V2V diff, Swift Charts dashboard, filter-based collections
6. Import/Export — JSON/Markdown export, import with conflict resolution, drag-drop
7. App Store readiness — signing, privacy manifest, screenshots, legal docs
8. Final quality pass — bug scrub, performance profiling, accessibility audit, animation polish

**Delivered:** A polished, premium macOS prompt library with free tier and full Pro tier (AI Assist, Versioning, Analytics, API Runner, Smart Collections) behind a StoreKit 2 annual subscription paywall. 33/33 requirements satisfied.

### Known Gaps

**Tech Debt (15 items):**
- REQUIREMENTS.md traceability: 26/33 entries still showed "Pending" (documentation debt)
- 7 human verification items pending in Phase 02 (drag-drop visual, VoiceOver, animations)
- ProxyConfig.baseURL defaults to PLACEHOLDER — no UI before first AI call fails
- Phase 04 SUMMARY files have empty requirements-completed fields
- AI-curated collection refresh button absent from sidebar
- PromptService.copyToClipboard uses legacy CopyEvent init
- attachmentFileNames exported but not restored on import (silent data loss)
- Legal docs contain [Launch Date] placeholder
- ScreenshotTests use best-guess accessibility identifiers
- Screenshots cannot show Pro features (no Pro status override)
- 3 human verification items pending in Phase 08 (Instruments, VoiceOver, visual polish)

**Advisory Integration Issues (3):**
- Screenshot capture cannot show Pro features (ProStatusManager.isProUnlocked=false in --screenshot-mode)
- ImportOrchestrator does not restore attachmentFileNames from export records
- SidebarView.filteredPrompts re-implements subset of SmartCollectionFilter

**Nyquist:** PARTIAL — all 12 phases have VALIDATION.md but none are nyquist_compliant: true

---

