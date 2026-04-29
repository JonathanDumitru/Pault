# Requirements: Pault

**Defined:** 2026-04-27
**Core Value:** Local-first macOS prompt library with premium Pro tier — ship polished to App Store with full feature set.

## v1.1 Requirements

Requirements for tech debt cleanup. Each maps to roadmap phases.

### Documentation

- [x] **DOC-01**: REQUIREMENTS.md traceability updated — all 33 v1.0 entries reflect actual completion status
- [x] **DOC-02**: Phase 04 SUMMARY files have requirements-completed fields populated
- [x] **DOC-03**: Legal docs [Launch Date] placeholder replaced with actual launch date

### Data Integrity

- [x] **DATA-01**: ImportOrchestrator restores attachmentFileNames from export records (no silent data loss)
- [x] **DATA-02**: PromptService.copyToClipboard uses current CopyEvent init (not legacy)

### UX Polish

- [x] **UX-01**: ProxyConfig.baseURL shows proper onboarding/error UI when no proxy URL configured before first AI call
- [x] **UX-02**: AI-curated collection refresh button present in sidebar
- [ ] **UX-03**: Screenshot capture can show Pro features via ProStatusManager override

### Testing

- [ ] **TEST-01**: ScreenshotTests use correct accessibility identifiers (not best-guess)
- [x] **TEST-02**: Phase 02 human verification completed (7 items: drag-drop visual, VoiceOver, animations)
- [x] **TEST-03**: Phase 08 human verification completed (3 items: Instruments, VoiceOver, visual polish)

### Code Quality

- [x] **CODE-01**: SidebarView.filteredPrompts refactored to reuse SmartCollectionFilter

## Future Requirements

None — v1.1 is a focused cleanup milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| New features or capabilities | v1.1 is purely tech debt — new work deferred to v1.2+ |
| iCloud sync | Deferred from v1.0 — still out of scope |
| CLI companion | Deferred from v1.0 — skeleton only exists |
| Nyquist compliance retrofit | Would require re-running all 12 v1.0 validations — separate effort |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOC-01 | Phase 13 | Complete |
| DOC-02 | Phase 13 | Complete |
| DOC-03 | Phase 13 | Complete |
| DATA-01 | Phase 14 | Complete |
| DATA-02 | Phase 14 | Complete |
| CODE-01 | Phase 14 | Complete |
| UX-01 | Phase 15 | Complete |
| UX-02 | Phase 15 | Complete |
| UX-03 | Phase 17 | Pending |
| TEST-01 | Phase 17 | Pending |
| TEST-02 | Phase 16 | Complete |
| TEST-03 | Phase 16 | Complete |

**Coverage:**
- v1.1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-27*
*Last updated: 2026-04-29 — milestone audit found TEST-01 and UX-03 partially satisfied; reassigned to Phase 17 (gap closure)*
