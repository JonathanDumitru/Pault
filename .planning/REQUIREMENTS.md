# Pault v1.0 — Requirements

## Milestone: App Store Launch (Annual Subscription Model)

---

## R1: Block Editor Polish
**Priority:** P0 — Must ship
**Status:** ~95% complete, needs edge cases and polish

### R1.1: Canvas UX Edge Cases
- Drag-drop reordering handles all edge cases (empty canvas, single block, rapid reorder)
- Slash command palette works reliably with keyboard navigation in all states
- Block expansion/collapse animations are smooth with no layout jumps
- Auto-collapse manager respects all user interaction patterns
- Undo/redo support for canvas operations

### R1.2: Block Editor Testing
- Unit tests for all PromptStudioModel state transitions
- Unit tests for BlockSuggestionEngine heuristics
- Unit tests for SlashCommandState filtering and selection
- Integration tests for block composition → compiled preview pipeline
- Snapshot/visual regression tests for canvas layout states

### R1.3: Block Editor Accessibility
- VoiceOver support for canvas navigation, block manipulation, and preview
- Keyboard-only workflow for all block editor operations
- Dynamic Type support where applicable
- Sufficient color contrast for placeholder status indicators (red/yellow/green)

### R1.4: Block Editor Performance
- Canvas remains responsive with 20+ blocks
- Compiled preview updates within 300ms of input change
- Slash command palette opens in <100ms
- Memory footprint stable during extended editing sessions

---

## R2: Pro Features — AI Assist
**Priority:** P0 — Must ship
**Status:** Actor-based AIService exists, needs full integration

### R2.1: AI Prompt Improvement
- User can request AI rewrite of selected prompt or block content
- AI suggestions appear inline with accept/reject controls
- Streaming response display for long rewrites
- Error handling for API failures with user-friendly messaging

### R2.2: AI Variable Suggestion
- AI analyzes prompt text and suggests template variables
- User can accept/reject each suggestion individually
- Suggestions integrate with existing TemplateEngine

### R2.3: AI Auto-Tagging
- AI suggests tags for new/untagged prompts
- Suggestions based on prompt content and existing tag vocabulary
- Bulk auto-tag support for library organization

### R2.4: AI Quality Scoring
- AI rates prompts on clarity, specificity, completeness, tone, structure
- Score displayed as visual indicator in prompt detail view
- Actionable feedback for improving low-scoring prompts

### R2.5: Proxy Service Integration
- All AI calls route through proxy service (not direct API)
- Authentication with proxy service (tied to subscription status)
- Graceful degradation when proxy is unreachable
- Rate limiting awareness and user feedback

---

## R3: Pro Features — Prompt Versioning
**Priority:** P0 — Must ship
**Status:** PromptVersion model exists, needs UI and workflow

### R3.1: Version History
- Every meaningful edit creates a version snapshot automatically
- Version history view shows timeline with diff summaries
- User can browse and compare any two versions

### R3.2: Version Restore
- User can restore any previous version
- Restore creates a new version (non-destructive)
- Confirmation dialog before restore

### R3.3: Version Diff
- Side-by-side or inline diff view between versions
- Highlights additions, deletions, and modifications
- Diff works for both plain text and block composition snapshots

---

## R4: Pro Features — Usage Analytics
**Priority:** P0 — Must ship
**Status:** CopyEvent model and AnalyticsService exist, needs dashboard

### R4.1: Analytics Dashboard
- Usage statistics: copies per prompt, copies over time, most-used prompts
- Visual charts (bar, line) for usage trends
- Filter by date range, tag, and prompt

### R4.2: Analytics Data Collection
- Track copy events with timestamp, source surface, and prompt ID
- Track prompt creation, editing, and deletion events
- All data stored locally (no telemetry)

### R4.3: Smart Collections (Analytics-Driven)
- Auto-generated collections: "Most Used", "Recently Created", "Stale Prompts"
- User can create custom smart collections with filter rules
- Smart collections update dynamically

---

## R5: Pro Features — API Runner
**Priority:** P0 — Must ship
**Status:** PromptRun model exists, needs full implementation

### R5.1: Prompt Execution
- User can run a compiled prompt against AI via proxy service
- Model selection (Claude, GPT, etc.) if proxy supports multiple
- Streaming response display in response panel

### R5.2: Response Management
- Save responses linked to prompt and version
- Response history per prompt
- Copy response to clipboard

### R5.3: Refinement Loop
- User can iterate on prompt based on response quality
- Side-by-side prompt editor and response view
- "Try again" with modified prompt preserves history

---

## R6: StoreKit 2 Paywall
**Priority:** P0 — Must ship (prerequisite for launch)
**Status:** PaywallView and ProStatusManager exist as stubs

### R6.1: Subscription Management
- Annual subscription product configured in App Store Connect
- Purchase flow with Apple ID authentication
- Restore purchases support
- Subscription status persisted and checked on app launch

### R6.2: Paywall UI
- Paywall view showing Free vs Pro feature comparison
- Triggered when user attempts a Pro-gated feature
- Clean, non-intrusive design consistent with app aesthetic

### R6.3: Feature Gating
- Clear separation of Free and Pro features throughout the app
- Free tier: Prompt CRUD, templates, tags, favorites, search, all 3 surfaces, block editor (basic)
- Pro tier: AI Assist, Versioning, Analytics, API Runner, Smart Collections, unlimited blocks
- Graceful upgrade prompts (not hard blocks) when free users discover Pro features

### R6.4: StoreKit 2 Testing
- StoreKit Configuration file for local testing
- Sandbox testing with test Apple IDs
- Subscription lifecycle testing (purchase, renew, cancel, expire, restore)

---

## R7: App Store Readiness
**Priority:** P0 — Must ship
**Status:** Docs exist, implementation needed

### R7.1: Privacy & Compliance
- PrivacyInfo.xcprivacy manifest with all required API declarations
- App Store privacy labels accurately reflect data handling
- No user data leaves device (except proxy API calls with subscription auth)

### R7.2: Sandboxing & Entitlements
- All entitlements justified and minimal
- Clipboard access properly entitled
- Accessibility permissions requested gracefully with fallback UX
- Global hotkey (Carbon) compatible with sandbox

### R7.3: App Store Metadata
- App name, subtitle, description, keywords optimized
- 6+ screenshots for macOS (at required resolutions)
- App icon finalized at all required sizes
- Category: Developer Tools or Productivity
- Age rating configured

### R7.4: Signing & Distribution
- Apple Distribution certificate and provisioning
- Hardened runtime enabled
- Notarization passing
- DMG installer for direct distribution (secondary channel)

---

## R9: Import/Export
**Priority:** P0 — Must ship (table stakes per competitive analysis)
**Status:** Not implemented

### R9.1: Export
- Export individual prompts as JSON or Markdown
- Export entire library as archive (JSON bundle)
- Export includes template variables, tags, block compositions

### R9.2: Import
- Import prompts from JSON or Markdown files
- Import library archive with conflict resolution (skip/overwrite/duplicate)
- Drag-drop import support

### R9.3: Interoperability
- Copy prompt as Markdown to clipboard (already partially exists)
- Share sheet integration for macOS

---

## R8: Quality & Polish
**Priority:** P0 — Must ship
**Status:** Ongoing

### R8.1: Comprehensive Testing
- All existing tests pass and are up to date
- New tests for all Pro features (unit + integration)
- UI tests for critical user flows
- Edge case testing for all three surfaces

### R8.2: Accessibility Audit
- Full VoiceOver pass across all surfaces
- Keyboard navigation for all features
- Accessibility labels on all interactive elements
- Reduce Motion support

### R8.3: Performance Profiling
- Instruments profiling for memory leaks
- CPU profiling during heavy operations (large library, complex block compositions)
- Launch time optimization (<2s to interactive)
- SwiftData query performance with large datasets

### R8.4: UX Consistency Pass
- Consistent spacing, typography, and color usage
- All animations follow system conventions
- Error states have clear messaging and recovery paths
- Empty states have helpful guidance

---

## Feature Tier Matrix

| Feature | Free | Pro |
|---------|------|-----|
| Prompt CRUD | ✅ | ✅ |
| Template Variables | ✅ | ✅ |
| Tags & Favorites | ✅ | ✅ |
| Search & Filter | ✅ | ✅ |
| Menu Bar & Hotkey | ✅ | ✅ |
| Block Editor (basic) | ✅ | ✅ |
| Block Editor (unlimited) | — | ✅ |
| AI Assist | — | ✅ |
| Prompt Versioning | — | ✅ |
| Usage Analytics | — | ✅ |
| API Runner | — | ✅ |
| Smart Collections | — | ✅ |

---

## Success Criteria
1. App Store submission accepted on first attempt
2. All Pro features functional and polished
3. StoreKit 2 subscription lifecycle works end-to-end
4. Zero critical bugs, zero accessibility blockers
5. App launches in <2s, stays responsive under load
6. All tests pass with >80% coverage on new code

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| R1.1: Canvas UX Edge Cases | Phase 2 | Pending |
| R1.2: Block Editor Testing | Phase 1 | Pending |
| R1.3: Block Editor Accessibility | Phase 2 | Pending |
| R1.4: Block Editor Performance | Phase 2 | Pending |
| R2.1: AI Prompt Improvement | Phase 4 → Phase 10 | Pending |
| R2.2: AI Variable Suggestion | Phase 4 → Phase 10 | Pending |
| R2.3: AI Auto-Tagging | Phase 4 → Phase 10 | Pending |
| R2.4: AI Quality Scoring | Phase 4 → Phase 10 | Pending |
| R2.5: Proxy Service Integration | Phase 4 → Phase 10 | Pending |
| R3.1: Version History | Phase 5 | Pending |
| R3.2: Version Restore | Phase 5 | Pending |
| R3.3: Version Diff | Phase 5 | Pending |
| R4.1: Analytics Dashboard | Phase 5 → Phase 12 | Pending |
| R4.2: Analytics Data Collection | Phase 5 → Phase 12 | Pending |
| R4.3: Smart Collections | Phase 5 | Pending |
| R5.1: Prompt Execution | Phase 4 → Phase 10 | Pending |
| R5.2: Response Management | Phase 4 → Phase 10 | Pending |
| R5.3: Refinement Loop | Phase 4 → Phase 10 | Pending |
| R6.1: Subscription Management | Phase 3 | Pending |
| R6.2: Paywall UI | Phase 3 | Pending |
| R6.3: Feature Gating | Phase 3 | Pending |
| R6.4: StoreKit 2 Testing | Phase 3 | Pending |
| R7.1: Privacy & Compliance | Phase 1 | Complete |
| R7.2: Sandboxing & Entitlements | Phase 1 | Complete |
| R7.3: App Store Metadata | Phase 7 | Pending |
| R7.4: Signing & Distribution | Phase 7 | Pending |
| R8.1: Comprehensive Testing | Phase 8 | Pending |
| R8.2: Accessibility Audit | Phase 8 | Pending |
| R8.3: Performance Profiling | Phase 8 | Pending |
| R8.4: UX Consistency Pass | Phase 8 | Pending |
| R9.1: Export | Phase 6 → Phase 11 | Pending |
| R9.2: Import | Phase 6 → Phase 11 | Pending |
| R9.3: Interoperability | Phase 6 → Phase 11 | Pending |
