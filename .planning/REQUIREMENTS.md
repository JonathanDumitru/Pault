# Requirements: Pault

**Defined:** 2026-04-27
**Core Value:** Local-first macOS prompt library with premium Pro tier — ship polished to App Store with full feature set.

## v1.1 Requirements

Requirements for tech debt cleanup. Each maps to roadmap phases.

### Documentation

- [ ] **DOC-01**: REQUIREMENTS.md traceability updated — all 33 v1.0 entries reflect actual completion status
- [ ] **DOC-02**: Phase 04 SUMMARY files have requirements-completed fields populated
- [ ] **DOC-03**: Legal docs [Launch Date] placeholder replaced with actual launch date

### Data Integrity

- [ ] **DATA-01**: ImportOrchestrator restores attachmentFileNames from export records (no silent data loss)
- [ ] **DATA-02**: PromptService.copyToClipboard uses current CopyEvent init (not legacy)

### UX Polish

- [ ] **UX-01**: ProxyConfig.baseURL shows proper onboarding/error UI when no proxy URL configured before first AI call
- [ ] **UX-02**: AI-curated collection refresh button present in sidebar
- [ ] **UX-03**: Screenshot capture can show Pro features via ProStatusManager override

### Testing

- [ ] **TEST-01**: ScreenshotTests use correct accessibility identifiers (not best-guess)
- [ ] **TEST-02**: Phase 02 human verification completed (7 items: drag-drop visual, VoiceOver, animations)
- [ ] **TEST-03**: Phase 08 human verification completed (3 items: Instruments, VoiceOver, visual polish)

### Code Quality

- [ ] **CODE-01**: SidebarView.filteredPrompts refactored to reuse SmartCollectionFilter

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
| DOC-01 | — | Pending |
| DOC-02 | — | Pending |
| DOC-03 | — | Pending |
| DATA-01 | — | Pending |
| DATA-02 | — | Pending |
| UX-01 | — | Pending |
| UX-02 | — | Pending |
| UX-03 | — | Pending |
| TEST-01 | — | Pending |
| TEST-02 | — | Pending |
| TEST-03 | — | Pending |
| CODE-01 | — | Pending |

**Coverage:**
- v1.1 requirements: 12 total
- Mapped to phases: 0
- Unmapped: 12 ⚠️

---
*Requirements defined: 2026-04-27*
*Last updated: 2026-04-27 after initial definition*
