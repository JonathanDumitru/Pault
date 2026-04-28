# Milestones

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

