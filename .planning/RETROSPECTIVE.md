# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — App Store Launch

**Shipped:** 2026-04-27
**Phases:** 12 | **Plans:** 29 | **Commits:** 285

### What Was Built
- Complete macOS prompt library with 3 access surfaces (main window, menu bar, global hotkey)
- Block editor with drag-drop, undo/redo, slash command palette, accessibility
- Full Pro tier: AI Assist (improve, variables, tags, score, refine), API Runner, Versioning with V2V diff, Analytics with Swift Charts, Smart Collections
- StoreKit 2 subscription paywall with ProFeature gating
- JSON/Markdown import/export with conflict resolution
- App Store readiness: privacy manifest, signing, screenshots, legal docs
- Comprehensive quality pass: accessibility audit, performance profiling, animation polish

### What Worked
- Phase-based execution with PLAN/SUMMARY/VERIFICATION structure kept work organized across 12 phases
- Gap closure phases (9-12) caught real issues: missing SUMMARY claims, wrong requirement IDs, PrivacyInfo bundling false positive
- Milestone audit before completion identified 15 tech debt items that would have been invisible
- All 33 requirements verified through 3-source cross-reference (VERIFICATION, SUMMARY, REQUIREMENTS)
- Actor-based AIService with proxy routing kept AI integration clean and testable
- ProFeature.isUnlocked centralized gating pattern scaled well across 14+ call sites

### What Was Inefficient
- REQUIREMENTS.md traceability table fell behind — 26/33 entries still showed "Pending" despite completion. Automation or per-plan updates needed
- Phase 04 SUMMARY files had empty requirements-completed fields — bookkeeping gap discovered late
- Phase 06 SUMMARY files had wrong requirement IDs (R8.x instead of R9.x) — copy-paste error persisted through execution
- ScreenshotDataSeeder cannot show Pro features because ProStatusManager.isProUnlocked stays false in --screenshot-mode — design oversight
- attachmentFileNames exported but not imported — incomplete round-trip caught only in audit

### Patterns Established
- `XCTestCase async + MainActor.run` pattern for macOS 26 Swift Concurrency + ObjC UndoManager compatibility
- `pendingFirstInputFocusBlockID` pattern: model publishes UUID?, view consumes with asyncAfter and clears
- `ProFeature.isUnlocked` → `ProStatusManager.shared.isProUnlocked` delegation pattern
- StoreKit `VerificationResult` always explicit switch, never `try? payloadValue`
- `@Environment(\.accessibilityReduceMotion)` guard on every `withAnimation` and `.animation()`
- VersionSource enum for distinguishing manual, AI, import, restore version origins

### Key Lessons
1. **Run milestone audit before archiving** — Gap closure phases 9-12 caught 13 requirements that appeared unverified. The audit was the safety net.
2. **SUMMARY files are the source of truth for requirement claims** — REQUIREMENTS.md traceability table is redundant and drifts. VERIFICATION.md is the final check.
3. **Requirement ID assignment matters** — R8 vs R9 numbering error in Phase 06 created 3 "orphaned" requirements. Validate IDs at plan creation time.
4. **macOS 26 beta breaks Swift Concurrency + ObjC patterns** — UndoManager, SKTestSession, and StoreKit propagation all needed workarounds. Budget time for platform beta issues.
5. **Screenshot automation cannot test Pro features without a status override** — Design Pro status injection for screenshot mode early.

### Cost Observations
- Model mix: primarily Opus 4.6 for planning/execution, Sonnet for research agents
- Sessions: ~30+ across 44 days
- Notable: Gap closure phases (9-12) were very fast (2-8 min each) — verification/traceability fixes are cheap when the code is already correct

---

## Milestone: v1.1 — Tech Debt Cleanup

**Shipped:** 2026-04-29
**Phases:** 5 (13-17) | **Plans:** 6 | **Commits:** 42

### What Was Built
- v1.0 documentation accuracy: full traceability table populated, Phase 04 SUMMARY frontmatter restored, legal launch date placeholder fixed
- Data integrity: JSON import restores attachment stubs (DATA-01), CopyEvent uses current two-arg init (DATA-02), SidebarView delegates to canonical PromptService.filterPrompts (CODE-01)
- UX polish: proxy-not-configured guard before API key check (UX-01), AI-curated collection refresh button with spinner (UX-02), DEBUG-guarded ProStatusManager screenshot-mode override (UX-03)
- Test reachability: accessibility identifiers on 5 production SwiftUI views, ScreenshotTests rewritten with real identifiers (TEST-01)
- Human verification sign-off: all 7 Phase 02 + 3 Phase 08 deferred items closed (TEST-02/03)
- Audit-driven Phase 17 closure: Analytics toolbar XCUI-reachable, sync `--screenshot-mode` override eliminates first-paint race, `analytics-view` identifier moved into NavigationStack render tree

### What Worked
- Cleanup-only milestone with no new features kept scope tight — 5 phases, 2 days end-to-end
- Phase 13 (docs) first established accurate baseline before any code touched — caught requirement-ID drift before it propagated
- 3-source audit cross-reference (VERIFICATION + SUMMARY frontmatter + REQUIREMENTS traceability) caught TEST-01 and UX-03 partial states that single-source verification missed
- Inserting Phase 17 mid-audit instead of patching v1.1 retroactively kept history honest — gap closure documented as its own phase
- Cross-phase integration check (`v1.1-INTEGRATION-CHECK.md`) verified 6 of 6 milestone flows end-to-end before declaring shipped

### What Was Inefficient
- SUMMARY frontmatter lacks a top-level `one_liner` field, so `gsd-tools milestone complete` produced an empty accomplishments list — required manual enrichment
- Phase 16 used `.accessibilityIdentifier` on outer container; XCUITest could not see it. Took a second phase (17) to discover the identifier-must-be-inside-render-tree rule
- ProStatusManager screenshot-mode override originally landed in `refreshStatus()` only — first-paint race not caught until end-to-end test failed; sync version in `init()` added in Phase 17
- Stage Manager incompatibility surfaced only when running tests — would have saved time if documented upfront

### Patterns Established
- **AX identifier render-tree rule**: `.accessibilityIdentifier(...)` must live inside the rendered view subtree (inside NavigationStack), not on outer container — outer placement is structurally invisible to XCUITest
- **Screenshot-mode override in two places**: synchronous in `init()` (first-paint Pro UI) + async in `refreshStatus()` (covers refresh path); both DEBUG-guarded
- **Toolbar Button identification via `.accessibilityLabel`** (not `.accessibilityIdentifier`) when test queries by label string match — zero test-side change required
- **Import attachment stubs use `storageMode=stub`** — preserves filename metadata without implying file data is present; enables round-trip fidelity
- **Audit-then-insert-phase** pattern: when audit surfaces gaps, insert a dedicated closure phase rather than patching prior phases

### Key Lessons
1. **3-source audit catches what single-source verification misses** — TEST-01 and UX-03 looked complete in Phase 16 SUMMARY but failed end-to-end test. Cross-referencing VERIFICATION + SUMMARY + REQUIREMENTS exposed the gap.
2. **SwiftUI AX identifier placement matters** — outer-container placement is invisible to XCUITest. Always place inside the rendered subtree (inside NavigationStack, inside the actual view body).
3. **First-paint races for `@Observable` state** — async Task-based initialization races SwiftUI's first render. Use synchronous setup in `init()` for state needed on the first paint.
4. **Stage Manager breaks XCUITest** — operational constraint with no code workaround in macOS 25.4. Document early for CI; disable Stage Manager before screenshot test runs.
5. **Audit-driven phases are honest history** — inserting Phase 17 to close audit gaps preserved the original v1.1 phase boundaries. Better than retroactively expanding earlier phase scopes.
6. **SUMMARY frontmatter needs `one_liner` for tooling** — without it, milestone-completion automation produces empty accomplishment lists. Future SUMMARY templates should include this field.

### Cost Observations
- Model mix: primarily Opus 4.7 (1M context) for planning + execution; Sonnet for research where needed
- Sessions: ~6 across 2 days (efficient turnaround)
- Notable: Cleanup-only milestone with tight scope ran ~22× faster per phase than v1.0 (2 days for 5 phases vs. 44 days for 12 phases) — no design exploration cost when the work is "fix what already exists"

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Commits | Phases | Key Change |
|-----------|---------|--------|------------|
| v1.0 | 285 | 12 | Established phase-based workflow with audit safety net |
| v1.1 | 42 | 5 | Audit-driven phase insertion (Phase 17) for gap closure; 3-source requirement cross-reference |

### Cumulative Quality

| Milestone | Files Changed | Lines Δ | Requirements |
|-----------|---------------|---------|--------------|
| v1.0 | 458 | 45,970 LOC Swift | 33/33 satisfied |
| v1.1 | 46 | +4,050 / -105 | 12/12 satisfied |

### Top Lessons (Verified Across Milestones)

1. Milestone audit catches gaps that per-phase verification misses — always audit before archiving (verified in both v1.0 gap-closure phases 9-12 and v1.1 audit-driven Phase 17)
2. Centralized feature gating (single enum) scales better than per-view checks
3. 3-source requirement cross-reference (VERIFICATION + SUMMARY + REQUIREMENTS) is the audit pattern that catches partial-completion drift
4. SwiftUI AX identifiers must live inside the rendered view subtree — outer-container placement is invisible to XCUITest (lesson from v1.1 Phase 17)
5. Cleanup-only milestones with no new features can ship 20× faster per phase than feature milestones — keep cleanup scopes tight
