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

## Cross-Milestone Trends

### Process Evolution

| Milestone | Commits | Phases | Key Change |
|-----------|---------|--------|------------|
| v1.0 | 285 | 12 | Established phase-based workflow with audit safety net |

### Cumulative Quality

| Milestone | Swift LOC | Files | Requirements |
|-----------|-----------|-------|--------------|
| v1.0 | 45,970 | 458 | 33/33 satisfied |

### Top Lessons (Verified Across Milestones)

1. Milestone audit catches gaps that per-phase verification misses — always audit before archiving
2. Centralized feature gating (single enum) scales better than per-view checks
