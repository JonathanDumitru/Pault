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
- [x] **Phase 3: StoreKit 2 Paywall** - Harden existing StoreKit 2 implementation for App Store compliance (completed 2026-03-27)
- [x] **Phase 4: Pro Features -- AI Assist & API Runner** - Build shared AI infrastructure, prompt improvement, and prompt execution (completed 2026-04-02)
- [x] **Phase 5: Pro Features -- Versioning, Analytics & Smart Collections** - Complete the remaining Pro tier features (completed 2026-04-09)
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
- [x] 01-01: Privacy manifest and entitlement cleanup
- [x] 01-02: Test infrastructure and block editor test coverage

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
- [x] 02-01-PLAN.md -- Undo/redo system, compilation cache fix, and design constants
- [x] 02-02-PLAN.md -- Canvas UX polish: drag-drop position indicator, keyboard shortcuts, focus management
- [x] 02-03-PLAN.md -- Accessibility (VoiceOver, Reduce Motion, high contrast) and performance benchmarks
- [x] 02-04-PLAN.md -- Gap closure: first-input focus after slash palette insert

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
- [x] 03-01-PLAN.md -- ProFeature enum, ProStatusManager hardening, and centralized feature gating
- [x] 03-02-PLAN.md -- PaywallView compliance rebuild with dynamic offers and legal disclosures
- [x] 03-03-PLAN.md -- StoreKit configuration file and subscription lifecycle tests

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
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md -- Cloudflare Worker proxy service and AIService rewiring to proxy routing
- [x] 04-02-PLAN.md -- AI Assist panel: streaming Improve, Variables, Tags, Score, Refine tabs
- [x] 04-03-PLAN.md -- API Runner: Run tab, response management, history, privacy manifest

### Phase 5: Pro Features -- Versioning, Analytics & Smart Collections
**Goal**: Pro users have full prompt version history, usage analytics with visual dashboards, and dynamic smart collections
**Depends on**: Phase 3
**Requirements**: R3.1, R3.2, R3.3, R4.1, R4.2, R4.3
**Success Criteria** (what must be TRUE):
  1. Version history captures every major change; user can compare any two versions with a side-by-side diff view
  2. User can restore any previous version, creating a new current version from the historical state
  3. Analytics dashboard shows prompt usage frequency, token consumption, and estimated cost over time
  4. User can create smart collections based on complex filters (tags, last used date, quality score, model)
  5. Smart collections update in real-time as prompt metadata changes
**Plans**: 3 plans

Plans:
- [ ] 05-01-PLAN.md -- VersionSource tracking, date headers, source badges, V2V diff with sync scrolling
- [ ] 05-02-PLAN.md -- Extended event tracking, Swift Charts analytics dashboard, token consumption
- [ ] 05-03-PLAN.md -- Smart collection filter extension, count badges, preset collections

### Phase 6: Import/Export
**Goal**: Users can easily move their data in and out of Pault with standard formats
**Depends on**: Phase 2
**Requirements**: R8.1, R8.2
**Success Criteria** (what must be TRUE):
  1. User can export the entire library or individual collections to a standard JSON format
  2. User can export prompts to Markdown files, including metadata as frontmatter
  3. User can import prompts from JSON/Markdown with duplicate detection and conflict resolution
**Plans**: 2 plans

Plans:
- [ ] 06-01-PLAN.md -- v2 DTOs, MarkdownFrontmatterParser, JSON/Markdown export, Copy as Markdown
- [ ] 06-02-PLAN.md -- ImportOrchestrator, preview sheet with conflict resolution, UI wiring (menus, drag-drop, share)

### Phase 7: App Store Readiness
**Goal**: Pault is fully prepared for submission with all required metadata, assets, and legal compliance
**Depends on**: All previous phases
**Requirements**: R7.1, R7.2
**Success Criteria** (what must be TRUE):
  1. App bundle is correctly signed for distribution; Sandbox and Hardened Runtime are enabled
  2. App Store screenshots are generated for all required device sizes
  3. App Store metadata (description, keywords, support URL) is finalized
  4. Privacy manifest is complete and verified against all app features
**Plans**: 2 plans

Plans:
- [ ] 07-01-PLAN.md -- Distribution signing and sandbox verification
- [ ] 07-02-PLAN.md -- Asset generation and metadata finalization

### Phase 8: Final Quality & Polish
**Goal**: Pault ships as a 5-star experience with zero known critical bugs and a "delightful" UX
**Depends on**: All previous phases
**Requirements**: All
**Success Criteria** (what must be TRUE):
  1. Zero known crashes in the distribution build
  2. Performance benchmarks meet or exceed targets (launch < 1s, canvas sync < 100ms)
  3. Accessibility audit passes with 100% keyboard/VoiceOver coverage
  4. UI polish: consistent spacing, typography, and "delightful" micro-interactions throughout
**Plans**: 4 plans

Plans:
- [ ] 08-01-PLAN.md -- Final bug scrub and stability pass
- [ ] 08-02-PLAN.md -- Performance profiling and optimization
- [ ] 08-03-PLAN.md -- Comprehensive accessibility audit and fixes
- [ ] 08-04-PLAN.md -- Visual polish and micro-interactions
