# Roadmap: Pault v1.0 App Store Launch

## Overview

Pault ships as a polished, premium macOS prompt library with a generous free tier and a full Pro tier (AI Assist, Versioning, Analytics, API Runner, Smart Collections) behind a StoreKit 2 annual subscription paywall. The roadmap moves from compliance hard-blockers through the core editor, monetization infrastructure, all Pro features, import/export, App Store metadata, and a final quality pass. Every Pro feature ships in v1.0 -- nothing is deferred to post-launch.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Compliance & Test Infrastructure** - Fix hard blockers (privacy manifest, entitlements) and establish test foundation (completed 2026-03-15)
- [x] **Phase 2: Block Editor Polish** - Finish the remaining 5% of canvas UX with edge cases, accessibility, and performance (completed 2026-03-26)
- [ ] **Phase 3: StoreKit 2 Paywall** - Harden existing StoreKit 2 implementation for App Store compliance
- [ ] **Phase 4: Pro Features -- AI Assist & API Runner** - Build shared AI infrastructure, prompt improvement, and prompt execution
- [ ] **Phase 5: Pro Features -- Versioning, Analytics & Smart Collections** - Complete the remaining Pro tier features
- [ ] **Phase 6: Import/Export** - Add data portability with JSON and Markdown import/export
- [ ] **Phase 7: App Store Readiness** - Finalize metadata, screenshots, signing, and distribution
- [ ] **Phase 8: Final Quality & Polish** - Comprehensive testing, accessibility audit, performance profiling, UX consistency

## Phase Details

### Phase 1: Compliance & Test Infrastructure
**Goal**: Eliminate all hard blockers that would cause automatic App Store rejection, and establish the test infrastructure that all subsequent phases build on
**Depends on**: Nothing (first phase)
**Requirements**: R1.2, R7.1, R7.2
**Success Criteria** (what must be TRUE):
  1. PrivacyInfo.xcprivacy manifest exists with correct required-reason API declarations (UserDefaults CA92.1 at minimum)
  2. Unused Apple Events temporary-exception entitlement is removed from Pault.entitlements
  3. All entitlements are justified and minimal; sandbox compatibility is verified
  4. Shared TestModelContainer factory exists and is used by all test files (no duplicated container setup)
  5. Block editor tests cover all PromptStudioModel state transitions, BlockSuggestionEngine heuristics, and SlashCommandState filtering
**Plans**: 2 plans

Plans:
- [ ] 01-01: Privacy manifest and entitlement cleanup
- [ ] 01-02: Test infrastructure and block editor test coverage

### Phase 2: Block Editor Polish
**Goal**: Users experience a flawless block editor with no layout glitches, full keyboard/VoiceOver support, and smooth performance at scale
**Depends on**: Phase 1
**Requirements**: R1.1, R1.3, R1.4
**Success Criteria** (what must be TRUE):
  1. Drag-drop reordering works correctly for all edge cases (empty canvas, single block, rapid reorder)
  2. Slash command palette opens in under 100ms and supports full keyboard navigation in all states
  3. Block expansion/collapse animations are smooth with no layout jumps
  4. VoiceOver can navigate all canvas elements; every block editor operation is achievable via keyboard alone
  5. Canvas remains responsive with 20+ blocks; compiled preview updates within 300ms of input change
**Plans**: 4 plans

Plans:
- [ ] 02-01-PLAN.md -- Undo/redo system, compilation cache fix, and design constants
- [ ] 02-02-PLAN.md -- Canvas UX polish: drag-drop position indicator, keyboard shortcuts, focus management
- [ ] 02-03-PLAN.md -- Accessibility (VoiceOver, Reduce Motion, high contrast) and performance benchmarks
- [ ] 02-04-PLAN.md -- Gap closure: first-input focus after slash palette insert

### Phase 3: StoreKit 2 Paywall
**Goal**: Users can purchase, restore, and manage an annual Pro subscription with a compliant, polished paywall experience
**Depends on**: Phase 1
**Requirements**: R6.1, R6.2, R6.3, R6.4
**Success Criteria** (what must be TRUE):
  1. User can purchase an annual subscription and see Pro features unlock immediately
  2. User can restore purchases on a fresh install and regain Pro access
  3. Paywall displays dynamic introductory offer text (no hardcoded trial language), subscription terms, and Privacy Policy/Terms of Service links
  4. Transaction verification uses explicit verified/unverified handling (no silent `try?` swallowing)
  5. Feature gating uses a centralized ProFeature enum; free users see graceful upgrade prompts when discovering Pro features
**Plans**: 3 plans

Plans:
- [ ] 03-01-PLAN.md -- ProFeature enum, ProStatusManager hardening, and centralized feature gating
- [ ] 03-02-PLAN.md -- PaywallView compliance rebuild with dynamic offers and legal disclosures
- [ ] 03-03-PLAN.md -- StoreKit configuration file and subscription lifecycle tests

### Phase 4: Pro Features -- AI Assist & API Runner
**Goal**: Pro users can improve prompts with AI assistance and execute prompts directly against LLMs with streaming responses
**Depends on**: Phase 3
**Requirements**: R2.1, R2.2, R2.3, R2.4, R2.5, R5.1, R5.2, R5.3
**Success Criteria** (what must be TRUE):
  1. User can request an AI rewrite of any prompt or block; suggestions appear inline with accept/reject controls and streaming display
  2. AI analyzes prompt text and suggests template variables; user can accept/reject each individually
  3. AI suggests tags for untagged prompts based on content and existing tag vocabulary
  4. AI rates prompts on clarity, specificity, completeness with a visual quality score and actionable improvement feedback
  5. User can run a compiled prompt against an LLM via proxy service with model selection and streaming response display
  6. Responses are saved with prompt/version linkage; user can browse response history and copy responses to clipboard
  7. All AI calls route through proxy service with subscription auth, graceful degradation when unreachable, and rate limiting feedback
**Plans**: TBD

Plans:
- [ ] 04-01: Proxy service integration and shared AI infrastructure
- [ ] 04-02: AI Assist features (rewrite, variables, tagging, scoring)
- [ ] 04-03: API Runner (execution, response management, refinement loop)

### Phase 5: Pro Features -- Versioning, Analytics & Smart Collections
**Goal**: Pro users have full prompt version history, usage analytics with visual dashboards, and dynamic smart collections
**Depends on**: Phase 3
**Requirements**: R3.1, R3.2, R3.3, R4.1, R4.2, R4.3
**Success Criteria** (what must be TRUE):
  1. Every meaningful edit automatically creates a version snapshot; user can browse a timeline view with diff summaries
  2. User can compare any two versions side-by-side with highlighted additions/deletions; diff works for both plain text and block compositions
  3. User can restore any previous version (non-destructive, creates new version) with confirmation dialog
  4. Analytics dashboard shows copies per prompt, usage over time, and most-used prompts with visual charts and date/tag/prompt filters
  5. Smart collections auto-generate ("Most Used", "Recently Created", "Stale Prompts") and user can create custom collections with filter rules
**Plans**: TBD

Plans:
- [ ] 05-01: Prompt versioning (history, diff, restore)
- [ ] 05-02: Usage analytics dashboard and data collection
- [ ] 05-03: Smart collections (auto-generated and custom)

### Phase 6: Import/Export
**Goal**: Users can move their prompt libraries in and out of Pault with full fidelity, eliminating lock-in concerns
**Depends on**: Phase 5
**Requirements**: R9.1, R9.2, R9.3
**Success Criteria** (what must be TRUE):
  1. User can export individual prompts as JSON or Markdown, preserving template variables, tags, and block compositions
  2. User can export entire library as a JSON archive bundle
  3. User can import prompts from JSON or Markdown files with conflict resolution (skip/overwrite/duplicate)
  4. Drag-drop import works from Finder
  5. Share sheet integration works for macOS sharing workflows
**Plans**: TBD

Plans:
- [ ] 06-01: Export (individual and library archive)
- [ ] 06-02: Import with conflict resolution and drag-drop

### Phase 7: App Store Readiness
**Goal**: App Store Connect is fully configured with metadata, screenshots, and signing so the app is ready to submit
**Depends on**: Phase 6
**Requirements**: R7.3, R7.4
**Success Criteria** (what must be TRUE):
  1. App Store Connect has complete metadata: name, subtitle, description, keywords, category, age rating, copyright
  2. Six or more macOS screenshots at required Retina resolutions are uploaded
  3. App icon is finalized at all required sizes
  4. Hardened runtime is enabled, notarization passes, and app is signed with Apple Distribution certificate
  5. Review notes explain Carbon hotkey usage and provide instructions for testing IAP in sandbox
**Plans**: TBD

Plans:
- [ ] 07-01: App Store metadata and screenshots
- [ ] 07-02: Signing, notarization, and distribution

### Phase 8: Final Quality & Polish
**Goal**: The app meets an extremely high quality bar across testing, accessibility, performance, and UX consistency before submission
**Depends on**: Phase 7
**Requirements**: R8.1, R8.2, R8.3, R8.4
**Success Criteria** (what must be TRUE):
  1. All existing and new tests pass; Pro features have unit and integration test coverage; UI tests cover critical user flows across all three surfaces
  2. Full VoiceOver pass confirms all surfaces are navigable; keyboard navigation works for all features; Reduce Motion is respected
  3. Instruments profiling shows no memory leaks; launch time is under 2 seconds to interactive; SwiftData queries perform well with large datasets
  4. Spacing, typography, and color usage are consistent throughout; all animations follow system conventions
  5. Every error state has clear messaging and a recovery path; every empty state has helpful guidance
**Plans**: TBD

Plans:
- [ ] 08-01: Comprehensive test pass (unit, integration, UI)
- [ ] 08-02: Accessibility audit and fixes
- [ ] 08-03: Performance profiling and optimization
- [ ] 08-04: UX consistency pass and final polish

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Compliance & Test Infrastructure | 2/2 | Complete   | 2026-03-15 |
| 2. Block Editor Polish | 4/4 | Complete   | 2026-03-26 |
| 3. StoreKit 2 Paywall | 1/3 | In Progress|  |
| 4. Pro Features -- AI Assist & API Runner | 0/3 | Not started | - |
| 5. Pro Features -- Versioning, Analytics & Smart Collections | 0/3 | Not started | - |
| 6. Import/Export | 0/2 | Not started | - |
| 7. App Store Readiness | 0/2 | Not started | - |
| 8. Final Quality & Polish | 0/4 | Not started | - |
