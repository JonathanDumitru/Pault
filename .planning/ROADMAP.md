# Roadmap: Pault

## Milestones

- ✅ **v1.0 App Store Launch** — Phases 1-12 (shipped 2026-04-27)
- **v1.1 Tech Debt Cleanup** — Phases 13-16 (active)

## Phases

<details>
<summary>✅ v1.0 App Store Launch (Phases 1-12) — SHIPPED 2026-04-27</summary>

- [x] Phase 1: Compliance & Test Infrastructure (2/2 plans) — completed 2026-03-15
- [x] Phase 2: Block Editor Polish (4/4 plans) — completed 2026-03-26
- [x] Phase 3: StoreKit 2 Paywall (3/3 plans) — completed 2026-03-27
- [x] Phase 4: Pro Features — AI Assist & API Runner (4/4 plans) — completed 2026-04-02
- [x] Phase 5: Pro Features — Versioning, Analytics & Smart Collections (3/3 plans) — completed 2026-04-09
- [x] Phase 6: Import/Export (2/2 plans) — completed 2026-04-09
- [x] Phase 7: App Store Readiness (2/2 plans) — completed 2026-04-19
- [x] Phase 8: Final Quality & Polish (5/5 plans) — completed 2026-04-21
- [x] Phase 9: PrivacyInfo Xcode Wiring (1/1 plan) — completed 2026-04-21
- [x] Phase 10: Phase 04 Verification & Gap Closure (1/1 plan) — completed 2026-04-21
- [x] Phase 11: Phase 06 Verification & Gap Closure (1/1 plan) — completed 2026-04-28
- [x] Phase 12: Phase 05 Traceability Fix (1/1 plan) — completed 2026-04-28

</details>

**v1.1 Tech Debt Cleanup**

- [x] **Phase 13: Documentation & Legal** — Fix traceability docs, Phase 04 SUMMARY fields, and legal date placeholder (completed 2026-04-28)
- [x] **Phase 14: Data Integrity & Code Quality** — Fix silent data loss on import, legacy CopyEvent init, and filter duplication (completed 2026-04-28)
- [x] **Phase 15: UX Polish** — Fix proxy URL onboarding UI, add AI collection refresh button, enable Pro feature screenshots (completed 2026-04-28)
- [ ] **Phase 16: Testing & Verification** — Fix screenshot test identifiers and complete human verification from Phases 02 and 08

## Phase Details

### Phase 13: Documentation & Legal
**Goal**: All documentation accurately reflects v1.0 completion state and contains no placeholder values
**Depends on**: Nothing (documentation-only, no code dependencies)
**Requirements**: DOC-01, DOC-02, DOC-03
**Success Criteria** (what must be TRUE):
  1. REQUIREMENTS.md traceability table shows all 33 v1.0 requirements as Complete with correct phase assignments
  2. Phase 04 SUMMARY files have requirements-completed fields populated (not empty)
  3. Legal documents show an actual launch date, not the string "[Launch Date]"
**Plans:** 1/1 plans complete
Plans:
- [ ] 13-01-PLAN.md — Fix traceability table, Phase 04 SUMMARY fields, and legal date placeholders

### Phase 14: Data Integrity & Code Quality
**Goal**: Import/export round-trips preserve all data, clipboard events use current APIs, and filter logic is not duplicated
**Depends on**: Phase 13 (documentation complete before code work begins)
**Requirements**: DATA-01, DATA-02, CODE-01
**Success Criteria** (what must be TRUE):
  1. A prompt with attachments exported to JSON and re-imported has the same attachmentFileNames as the original (no silent data loss)
  2. Copying a prompt to clipboard calls the current CopyEvent initializer (no deprecation warnings, no legacy path)
  3. SidebarView.filteredPrompts delegates to SmartCollectionFilter rather than re-implementing its logic
**Plans:** 1/1 plans complete
Plans:
- [ ] 14-01-PLAN.md — Fix attachment import round-trip, CopyEvent init, and SidebarView filter delegation

### Phase 15: UX Polish
**Goal**: Users are guided correctly when no proxy URL is set, can refresh AI-curated collections, and screenshots can capture Pro UI states
**Depends on**: Phase 13
**Requirements**: UX-01, UX-02, UX-03
**Success Criteria** (what must be TRUE):
  1. Launching Pault with no proxy URL configured and triggering an AI call shows an onboarding or error UI instead of a silent failure
  2. The sidebar shows a refresh button for AI-curated collections that triggers a new curation request
  3. Running the app in screenshot mode with ProStatusManager override shows Pro features visible in the UI
**Plans:** 1/1 plans complete
Plans:
- [ ] 15-01-PLAN.md — Proxy error UI, AI collection refresh button, and Pro screenshot override

### Phase 16: Testing & Verification
**Goal**: Screenshot tests use real accessibility identifiers and all human verification items from v1.0 are signed off
**Depends on**: Phase 15 (UX changes must be in place before verifying screenshots and accessibility)
**Requirements**: TEST-01, TEST-02, TEST-03
**Success Criteria** (what must be TRUE):
  1. ScreenshotTests reference accessibility identifiers that match identifiers defined in the production SwiftUI views
  2. All 7 Phase 02 human verification items are checked: drag-drop visual feedback, VoiceOver announcements for block operations, and animation correctness
  3. All 3 Phase 08 human verification items are checked: Instruments memory profile shows no leaks, VoiceOver reads all Pro feature labels, visual polish targets confirmed
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Compliance & Test Infrastructure | v1.0 | 2/2 | Complete | 2026-03-15 |
| 2. Block Editor Polish | v1.0 | 4/4 | Complete | 2026-03-26 |
| 3. StoreKit 2 Paywall | v1.0 | 3/3 | Complete | 2026-03-27 |
| 4. Pro Features — AI Assist & API Runner | v1.0 | 4/4 | Complete | 2026-04-02 |
| 5. Versioning, Analytics & Smart Collections | v1.0 | 3/3 | Complete | 2026-04-09 |
| 6. Import/Export | v1.0 | 2/2 | Complete | 2026-04-09 |
| 7. App Store Readiness | v1.0 | 2/2 | Complete | 2026-04-19 |
| 8. Final Quality & Polish | v1.0 | 5/5 | Complete | 2026-04-21 |
| 9. PrivacyInfo Xcode Wiring | v1.0 | 1/1 | Complete | 2026-04-21 |
| 10. Phase 04 Verification | v1.0 | 1/1 | Complete | 2026-04-21 |
| 11. Phase 06 Verification | v1.0 | 1/1 | Complete | 2026-04-28 |
| 12. Phase 05 Traceability Fix | v1.0 | 1/1 | Complete | 2026-04-28 |
| 13. Documentation & Legal | 1/1 | Complete    | 2026-04-28 | — |
| 14. Data Integrity & Code Quality | 1/1 | Complete    | 2026-04-28 | — |
| 15. UX Polish | 1/1 | Complete    | 2026-04-28 | — |
| 16. Testing & Verification | v1.1 | 0/? | Not started | — |

_Full v1.0 details archived in `milestones/v1.0-ROADMAP.md`_
