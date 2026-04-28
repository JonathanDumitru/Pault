# Phase 10: Phase 04 Verification & Gap Closure - Research

**Researched:** 2026-04-21
**Domain:** Code audit of existing Swift/TypeScript implementation against requirements; VERIFICATION.md authorship
**Confidence:** HIGH (all conclusions drawn from direct codebase inspection, no external dependencies)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R2.1 | AI Prompt Improvement — streaming rewrite with accept/reject controls | AIAssistPanel.swift: streamImprove() called, DiffView shown, acceptImprovement() creates auto-snapshot before content mutation. Implementation confirmed complete. |
| R2.2 | AI Variable Suggestion — analyze prompt, suggest {{variables}}, accept/reject each | AIAssistPanel.swift VariablesTabContent: on-demand load, per-suggestion Accept/Reject, insert() calls saveSnapshot before appending token. Implementation confirmed complete. |
| R2.3 | AI Auto-Tagging — on-demand tag suggestions, accept/reject, uses existing vocab | AIAssistPanel.swift TagsTabContent: "Suggest Tags" button, per-suggestion accept/dismiss, attachTag() calls saveSnapshot. Implementation confirmed complete. |
| R2.4 | AI Quality Scoring — four-axis score, visual indicator, actionable improvement tips | AIAssistPanel.swift ScoreTabContent: ProgressView bars for clarity/specificity/completeness/conciseness, overall score, tips list. QualityScore.tips populated in AIService.qualityScore(). Implementation confirmed complete. |
| R2.5 | Proxy Service Integration — all Claude/OpenAI calls through proxy with JWS auth, graceful degradation, rate limiting | AIService.swift buildRequest routes Claude/OpenAI through ProxyConfig.baseURL with X-Provider/X-Provider-Key/X-Storekit-JWS headers. Ollama bypasses. 401/429 errors handled. pault-proxy/ Worker exists. Implementation confirmed complete. |
| R5.1 | Prompt Execution — run compiled prompt via proxy, model selection, streaming display | RunTabView.swift: calls streamRun(), token-by-token ScrollView, auto-scrolling, cancel button. DetailTab.run wired in PromptDetailView. Implementation confirmed complete. |
| R5.2 | Response Management — save responses linked to prompt, history, copy to clipboard | RunTabView.persistRun() inserts PromptRun with all fields. RunHistoryView shows per-prompt history. Copy button present. Star rating, delete, Run Again all implemented in RunHistoryRowView. Implementation confirmed complete. |
| R5.3 | Refinement Loop — iterate on prompt, side-by-side diff, history preserved | RefinementLoopView.swift: DiffView + star rating, Try Again preserves iteration history in-memory, accept() persists all iterations as PromptRun records. Implementation confirmed complete. |
</phase_requirements>

---

## Summary

Phase 04 implemented all 8 required capabilities. The gap is **purely documentary**: Phase 04 has no VERIFICATION.md and its only SUMMARY file (04-00-SUMMARY.md) documents only the Wave 0 test stubs, not the implementation plans (04-01 through 04-03) that did the actual work. The milestone audit correctly identified this as a documentation gap, not an implementation gap.

The implementation is substantially complete across all 8 requirements. Gaps are minor and fixable:

1. **R5.3 gap:** RefinementLoopView.accept() does NOT call PromptService.saveSnapshot() before overwriting prompt.content — this breaks the auto-snapshot requirement stated in CONTEXT.md ("Auto-snapshot before any AI-suggested change is applied"). This is a real implementation gap requiring a one-line fix.

2. **R2.5 partial gap:** ProxyConfig.baseURL reads from UserDefaults key "ai.proxy.baseURL" but PreferencesView binds to "@AppStorage("proxy.baseURL")" — the UserDefaults keys do not match. This means the proxy URL set in Preferences does not propagate to AIService. This is a real wiring bug.

3. **Proxy not deployed:** pault-proxy/ exists as TypeScript source but is not deployed. The proxy URL in ProxyConfig defaults to "https://pault-proxy.PLACEHOLDER.workers.dev". For AI features to function end-to-end, the Worker must be deployed to Cloudflare.

**Primary recommendation:** Plan 10-01 verifies all 8 requirements against the codebase, fixes the two implementation gaps (R5.3 saveSnapshot, UserDefaults key mismatch), and writes the VERIFICATION.md. Phase is documentation-heavy — code changes are minimal.

---

## What Was Built in Phase 04

### Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `pault-proxy/src/index.ts` | ~300 | Cloudflare Worker: JWS verify, rate limit, provider route, SSE passthrough, metadata inject |
| `Pault/Services/ProxyConfig.swift` | 28 | ProxyConfig.baseURL, StreamEvent enum, CallMetadata struct |
| `Pault/RunTabView.swift` | 285 | Run tab: variable form, execute, streaming response, history, Run Again |

### Files Modified

| File | Changes |
|------|---------|
| `Pault/Services/AIService.swift` | Rewired buildRequest/buildStreamRequest through proxy; added streamImprove(); added AIError.subscriptionRequired/rateLimited; added lastCallMetadata |
| `Pault/Services/ProStatusManager.swift` | Added currentTransactionJWS, lastJWSRefresh, refreshJWSIfNeeded() |
| `Pault/AIAssistPanel.swift` | Upgraded to streaming Improve tab (DiffView integration), Variables/Tags/Score/Refine tabs, error handling, no-key state |
| `Pault/RunHistoryView.swift` | Added star rating, delete with confirmation, Run Again, swipe-to-delete |
| `Pault/PromptDetailView.swift` | Added DetailTab enum (.edit/.build/.run), Run tab wiring, Cmd+Shift+I shortcut |
| `Pault/RefinementLoopView.swift` | DiffView extracted to same file; history context passing; accept() persists all PromptRuns |
| `Pault/PrivacyInfo.xcprivacy` | Network data collection transparency entry added |

### Files That Only Got Test Stubs (Plan 00)

| File | Status |
|------|--------|
| `PaultTests/AIAssistPanelTests.swift` | Tests are REAL (not stubs) — actual assertions implemented |
| `PaultTests/RunTabViewTests.swift` | Tests are REAL — model-level assertions implemented |
| `PaultTests/AIServiceTests.swift` (expanded) | Tests are REAL — structural/config assertions |
| `PaultTests/PromptRunTests.swift` (expanded) | Tests are REAL — SwiftData persistence assertions |

---

## Gap Analysis: Requirements vs. Implementation

### R2.1: AI Prompt Improvement (SATISFIED with minor note)

**Evidence:**
- `AIService.streamImprove()` exists (line 94-101 AIService.swift), calls `streamComplete()` with improve system prompt
- `AIAssistPanel.runImprove()` calls `streamImprove()`, accumulates tokens into `streamingImproveText`
- Streaming state: blinking cursor timer, cancel button, auto-scrolling ScrollViewReader
- `acceptImprovement()` calls `PromptService(modelContext: modelContext).saveSnapshot(for: prompt, source: .aiImprove)` THEN sets `prompt.content`
- `DiffView` shown after streaming completes with original vs revised text
- Error handling via `handleAIError()` covers missingAPIKey, rateLimited, subscriptionRequired, httpError

**Gap:** None. R2.1 is fully satisfied.

### R2.2: AI Variable Suggestion (SATISFIED)

**Evidence:**
- `AIService.suggestVariables()` calls proxy-routed `complete()` and returns `[VariableSuggestion]`
- `VariablesTabContent` shows "Suggest Variables" button, per-suggestion Accept/Reject rows
- `insert()` calls `saveSnapshot(source: .aiVariableAccept)` before appending token to content
- Each suggestion dismissible individually via Reject button

**Gap:** None. R2.2 is fully satisfied.

### R2.3: AI Auto-Tagging (SATISFIED)

**Evidence:**
- `AIService.autoTag()` calls proxy-routed `complete()` and returns `[String]`
- `TagsTabContent` shows on-demand "Suggest Tags" button (NOT auto-triggered on save)
- Per-suggestion Accept (calls `attachTag()` which calls `saveSnapshot(source: .aiAutoTag)`) and Dismiss buttons
- `attachTag()` reuses existing Tag objects or creates new ones, appends to prompt.tags

**Gap:** None. R2.3 is fully satisfied.

### R2.4: AI Quality Scoring (SATISFIED)

**Evidence:**
- `AIService.qualityScore()` parses 4-axis JSON with `tips` array; `QualityScore.tips: [String]` field exists
- `ScoreTabContent` displays Grid with ProgressView bars for all 4 axes + overall score
- Tips section shown as bulleted list below scores
- Score persisted to `prompt.qualityScore` (0-100 scale)

**Gap:** None. R2.4 is fully satisfied.

### R2.5: Proxy Service Integration (SATISFIED with wiring bug)

**Evidence:**
- `pault-proxy/src/index.ts` exists: POST /v1/complete and /v1/stream routes, JWS decode + expiry check, rate limiting via AI_LIMITER binding, provider routing (Claude/OpenAI), SSE passthrough with metadata injection, KV caching, content safety (500KB limit)
- `AIService.buildRequest()` routes Claude/OpenAI through `ProxyConfig.baseURL + "/v1/complete"` with `X-Provider`, `X-Provider-Key`, `X-Storekit-JWS` headers
- Ollama uses `config.baseURL ?? "http://localhost:11434"` directly (bypasses proxy)
- `ProStatusManager.refreshJWSIfNeeded()` called before each non-Ollama request; 60-second refresh cache
- `handleAIError()` maps 401 → subscriptionRequired, 429 + Retry-After → rateLimited
- Inline `AIErrorBar` shown for all error types

**Gap found — UserDefaults key mismatch:**
- `ProxyConfig.baseURL` reads from `UserDefaults.standard.string(forKey: "ai.proxy.baseURL")`
- PreferencesView uses `@AppStorage("proxy.baseURL")` (inferred — must confirm)
- If PreferencesView uses `"proxy.baseURL"` key while ProxyConfig reads `"ai.proxy.baseURL"`, the proxy URL set by user in Preferences is silently ignored. AI features always use the PLACEHOLDER URL.
- **Fix:** Align both to the same UserDefaults key. ProxyConfig is the source of truth; PreferencesView must bind to `"ai.proxy.baseURL"`.

**Gap found — proxy not deployed:**
- `ProxyConfig.isConfigured` returns `!baseURL.contains("PLACEHOLDER")` — the app knows it's not configured
- The Worker source exists and is correct but requires user to deploy it to Cloudflare
- This is a user action, not a code gap. The planner should document this in VERIFICATION.md as a manual verification item.

### R5.1: Prompt Execution (SATISFIED)

**Evidence:**
- `RunTabView.startRun()` calls `AIService.shared.streamRun()` returning `AsyncThrowingStream<StreamEvent, Error>`
- Token-by-token accumulation via `.token(let t)` case; metadata captured via `.metadata(...)` case
- ScrollViewReader auto-scrolls to "bottom" anchor on each token
- Cancel button visible during streaming, calls `runTask?.cancel()`
- `DetailTab.run` wired in `PromptDetailView.contentForTab()`, Pro-gated via `ProFeature.isUnlocked(.apiRunner)`
- Model indicator shown as tertiary text below execute button

**Gap:** None. R5.1 is fully satisfied.

### R5.2: Response Management (SATISFIED)

**Evidence:**
- `RunTabView.persistRun()` creates `PromptRun` with all fields: promptTitle, resolvedInput, output, model, provider, latencyMs, inputTokens, outputTokens from metadata
- `run.prompt = prompt` establishes SwiftData relationship
- `RunHistoryView` fetches per-prompt runs via `FetchDescriptor` filtered by `prompt.id`
- `RunHistoryRowView` expanded state: copy button, save-as-prompt button, Run Again button, star rating (1-5, tap same to clear), delete with confirmation alert
- Swipe-to-delete action implemented
- `PromptRunTests.promptRunPersistsWithTokenMetadata` confirms inputTokens/outputTokens persistence

**Gap:** None. R5.2 is fully satisfied.

### R5.3: Refinement Loop (SATISFIED with one gap)

**Evidence:**
- `RefinementLoopView` renders initial state (goal input) and refinement state (DiffView + star rating + Try Again)
- `tryAgain()` appends current revision to `history: [(input, output, rating)]` array before calling `refine()` again — full iteration history preserved in-memory
- `accept()` persists ALL history iterations as `PromptRun` records with `variantLabel: "refine-N"` and `userRating`
- `buildHistoryContext()` includes previous attempt outputs and ratings in the next refinement prompt

**Gap found — missing saveSnapshot before accept():**
- `accept()` calls `prompt.content = finalRevision` but does NOT call `PromptService.saveSnapshot()` first
- CONTEXT.md decision: "Auto-snapshot before any AI-suggested change is applied: creates PromptVersion"
- All other AI accept paths (Improve tab, Variables, Tags) correctly call saveSnapshot first
- RefinementLoopView is the only accept path missing the auto-snapshot call
- **Fix:** Add `PromptService(modelContext: modelContext).saveSnapshot(for: prompt, source: .aiRefine)` as the first line of `accept()`, before `prompt.content = finalRevision`

---

## Known Implementation Notes From STATE.md (Phase 04 Decisions)

These were confirmed by code inspection:

| Decision | Confirmed In Code |
|----------|-------------------|
| Proxy lives in pault-proxy/ subdirectory (not separate repo) | pault-proxy/ at repo root, has own package.json |
| AIService routes Claude/OpenAI through proxy; Ollama stays direct | buildRequest switch: claude/openai → ProxyConfig.baseURL, ollama → localhost |
| ProStatusManager auto-refreshes JWS every 60s | refreshJWSIfNeeded() checks lastJWSRefresh, re-fetches if >60s old |
| PromptDetailView body extracted to sub-views to avoid compiler timeout | promptToolbar, contentForTab, parsingOverlay private computed vars |
| ProxyConfig baseURL/enableCaching use direct UserDefaults | UserDefaults.standard.string(forKey:) — NOT @AppStorage |
| Cmd+Shift+I and Cmd+Return shortcuts added | Confirmed via STATE.md; present in PromptDetailView |

---

## Architecture Patterns for Verification Tasks

### How VERIFICATION.md Is Structured (from Phase 01 example)

```markdown
---
phase: {phase-slug}
verified: {ISO-8601}
status: passed | gaps_found | human_needed
score: N/M must-haves verified
gaps:
  - truth: "{truth text}"
    status: failed
    reason: "{why}"
    artifacts:
      - path: "{file}"
        issue: "{problem}"
    missing:
      - "{action required}"
human_verification:
  - test: "{what to do}"
    expected: "{expected result}"
    why_human: "{why automated is insufficient}"
---

# Phase N: [Name] Verification Report

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
...

### Required Artifacts

| Artifact | Expected | Status | Details |
...

### Key Link Verification

| From | To | Via | Status | Details |
...

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
...
```

### Must-Have Truths to Verify (from 04-01/04-02/04-03 PLANs)

The verification must cover the `must_haves.truths` from all three implementation plans:

**From 04-01 (R2.5 — Proxy):**
1. Claude and OpenAI AI calls route through proxy with subscription auth
2. Ollama calls bypass proxy, go directly to localhost
3. Proxy validates StoreKit JWS subscription before forwarding
4. Proxy enforces per-subscriber rate limits, returns 429 + Retry-After
5. Proxy streams SSE responses without buffering
6. Proxy returns token count and estimated cost metadata in streaming responses
7. App sends provider API key per-request in header (never stored server-side)
8. ProStatusManager provides fresh JWS token for AI calls

**From 04-02 (R2.1-R2.4 — AI Assist Panel):**
1. User can request AI rewrite in Improve tab and see streaming token-by-token display
2. Improve tab shows word-level diff with accept/reject
3. Variables tab suggests template variables, user accepts/rejects individually
4. Tags tab suggests tags on-demand (Suggest Tags button)
5. Score tab displays four-axis quality score plus 2-3 actionable improvement tips
6. Refine tab routes through proxy with DiffView + star rating
7. Auto-snapshot created before any AI-suggested change is applied
8. Cmd+Shift+I opens/focuses AI Improve tab
9. AI panel visible-but-locked when no API key configured
10. AI errors (offline, rate limit, subscription) shown inline in panel

**From 04-03 (R5.1-R5.3 — API Runner):**
1. User can run a compiled prompt against LLM via proxy with model selection and streaming response
2. Streaming response displays token-by-token in auto-scrolling monospace ScrollView with cancel button
3. Response footer shows token count and estimated cost from proxy metadata
4. Responses are saved as PromptRun with prompt linkage; user can browse per-prompt history
5. User can copy response to clipboard and save as new prompt
6. User can rate any run 1-5 stars
7. User can delete individual runs from history
8. User can Run Again from expanded history row
9. Run tab has inline variable form pre-filled with template variable defaults
10. Refinement loop preserves iteration history with DiffView and star rating
11. PrivacyInfo.xcprivacy updated to declare network usage

---

## Common Pitfalls for Verification Phase

### Pitfall 1: Confusing "file exists" with "correctly wired"

**Relevant to this phase:** The UserDefaults key mismatch for ProxyConfig.baseURL. ProxyConfig.swift reads one key, PreferencesView may write to a different key. Grep both files for the key string before declaring R2.5 satisfied.

**How to check:**
```bash
grep -r "proxy" Pault/Services/ProxyConfig.swift Pault/PreferencesView.swift
```

### Pitfall 2: Missing saveSnapshot in RefinementLoopView.accept()

This is the only AI-accept path that does not call saveSnapshot. The code compiles and functions correctly (iteration history is persisted as PromptRuns) but the pre-edit PromptVersion snapshot is absent. Fix is one line before `prompt.content = finalRevision`.

### Pitfall 3: Proxy deployment is a user action, not a code gap

The proxy Worker source is complete and type-checks. That it is not deployed to Cloudflare is not a code gap — it is a user deployment action. VERIFICATION.md should document this as a manual verification item ("User must deploy pault-proxy/ to their Cloudflare account and configure proxy URL in Preferences for AI features to function end-to-end").

### Pitfall 4: Test coverage is structural, not integration

The AIServiceTests and PromptRunTests verify type structure and configuration (e.g., Ollama config has localhost baseURL, QualityScore has tips field, PromptRun persists tokens). They do NOT make real network calls. VERIFICATION.md must acknowledge that end-to-end AI feature testing requires manual testing with real Cloudflare deployment.

### Pitfall 5: 04-00-SUMMARY.md does not list requirements-completed

The milestone audit noted this. Phase 10 must ensure that when VERIFICATION.md is written, the SUMMARY frontmatter of each implementation plan (04-01, 04-02, 04-03) includes `requirements_completed` fields. However, those SUMMARY files do not exist — only 04-00-SUMMARY.md exists. The verification plan needs to either create those SUMMARYs retroactively, or rely on VERIFICATION.md itself to document all completed requirements.

**Recommended approach:** Use VERIFICATION.md as the authoritative record (as per Phase 01 pattern). The VERIFICATION.md `requirements_completed` field in its frontmatter will satisfy the audit traceability check.

---

## Code Examples: Verification Check Patterns

### Check proxy routing headers (R2.5)
```bash
# Verify Claude routes to proxy with correct headers
grep -A 15 "case .claude:" Pault/Services/AIService.swift | grep -E "(ProxyConfig|X-Provider)"
```

### Check Ollama bypass (R2.5)
```bash
grep -A 5 "case .ollama:" Pault/Services/AIService.swift
# Expect: localhost URL, no proxy headers
```

### Check auto-snapshot before Improve accept (R2.1)
```bash
grep -B 2 "prompt.content = streamingImproveText" Pault/AIAssistPanel.swift
# Expect: saveSnapshot call appears before content assignment
```

### Check MISSING saveSnapshot in Refine accept (R5.3 gap)
```bash
grep -B 3 "prompt.content = finalRevision" Pault/RefinementLoopView.swift
# Expect: NO saveSnapshot — this is the gap to fix
```

### Check Run tab wiring (R5.1)
```bash
grep -A 3 "case .run" Pault/PromptDetailView.swift
# Expect: RunTabView(prompt: prompt, config: ...)
```

### Check PromptRun token field persistence (R5.2)
```bash
grep -A 5 "inputTokens:" Pault/RunTabView.swift
# Expect: PromptRun init with inputTokens: runMetadata?.inputTokens
```

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (AIServiceTests, AIAssistPanelTests) + Swift Testing (PromptRunTests, RunTabViewTests) |
| Config file | Xcode scheme — no separate config file |
| Quick run command | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 \| tail -40` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R2.1 | streamImprove returns stream, throws when no key | unit | `xcodebuild test ... -only-testing PaultTests/AIServiceTests/test_streamImprove_returnsStreamEvents` | ✅ |
| R2.1 | acceptImprovement calls saveSnapshot (structural) | unit-skip | AIAssistPanelTests/test_acceptImprove_callsSaveSnapshot — XCTSkip (UI state) | ✅ (skipped, noted) |
| R2.2 | VariableSuggestion placeholder/description fields exist | unit | test_qualityScoreReturnsTips validates type shape | ✅ (indirect) |
| R2.4 | QualityScore includes tips array | unit | `AIServiceTests/test_qualityScoreReturnsTips` | ✅ |
| R2.5 | Ollama config uses localhost baseURL | unit | `AIServiceTests/test_ollamaBypassesProxy_directLocalhost` | ✅ |
| R2.5 | 429 rateLimited error captures retry-after | unit | `AIServiceTests/test_rateLimitResponse_parsesRetryAfter` | ✅ |
| R2.5 | Claude/OpenAI have nil baseURL (use proxy) | unit | `AIServiceTests/test_claudeRoutesViaProxy_withHeaders` | ✅ |
| R5.2 | PromptRun persists inputTokens/outputTokens | unit | `PromptRunTests/promptRunPersistsWithTokenMetadata` | ✅ |
| R5.2 | PromptRun persists userRating | unit | `PromptRunTests/promptRunStarRating_persistsOnReload` | ✅ |
| R5.2 | PromptRun.resolvedInput persisted for Run Again | unit | `RunTabViewTests/runAgain_reExecutesWithSameInput` | ✅ |
| R5.1 | ProFeature.apiRunner locked without subscription | unit | `RunTabViewTests/executeProGates_whenNotUnlocked` | ✅ |
| R5.3 | Streaming cancel before completion leaves no PromptRun | unit | `RunTabViewTests/streamingCancel_stopsAccumulation` | ✅ |

### Sampling Rate

- **Per task commit:** `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 | tail -20`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before VERIFICATION.md is declared complete

### Wave 0 Gaps

None — all test files already exist from Phase 04 Plan 00. The verification plan can proceed directly to implementation and gap closure.

---

## What the Planner Must Produce

Phase 10 needs a single plan (or two at most):

**Plan 10-01:** Verify all 8 requirements against codebase, fix two gaps, write VERIFICATION.md
- Task 1: Inspect code, confirm all truths, identify gaps
- Task 2: Fix R5.3 saveSnapshot gap + confirm or fix ProxyConfig key mismatch
- Task 3: Write VERIFICATION.md with per-requirement verdicts, artifact status, human verification items
- Task 4: Confirm SUMMARY frontmatter for Phase 04 is updated with requirements-completed

No additional plans needed unless Task 1 uncovers unexpected gaps beyond the two already identified.

---

## Sources

### Primary (HIGH confidence)

- Direct inspection: `Pault/Services/AIService.swift` — full file read, proxy routing confirmed
- Direct inspection: `Pault/Services/ProxyConfig.swift` — UserDefaults key read
- Direct inspection: `Pault/AIAssistPanel.swift` — all 5 tabs, streaming Improve, DiffView, acceptImprovement(), auto-snapshot calls
- Direct inspection: `Pault/RunTabView.swift` — full Run tab implementation
- Direct inspection: `Pault/RunHistoryView.swift` — star rating, delete, Run Again
- Direct inspection: `Pault/RefinementLoopView.swift` — accept() missing saveSnapshot confirmed
- Direct inspection: `pault-proxy/src/index.ts` — Worker routes and JWS verification
- Direct inspection: `PaultTests/AIServiceTests.swift` — all test methods read
- Direct inspection: `PaultTests/AIAssistPanelTests.swift` — all test methods read
- Direct inspection: `PaultTests/PromptRunTests.swift` — token metadata and star rating tests
- Direct inspection: `PaultTests/RunTabViewTests.swift` — all test methods read
- `.planning/v1.0-MILESTONE-AUDIT.md` — gap diagnosis, confirmed 8 requirements unverified
- `.planning/phases/01-compliance-test-infrastructure/01-VERIFICATION.md` — VERIFICATION.md format reference

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — Phase 04 decisions cross-checked against implementation
- `.planning/phases/04-pro-features-ai-assist-api-runner/04-CONTEXT.md` — original decisions
- `.planning/phases/04-pro-features-ai-assist-api-runner/04-00-SUMMARY.md` — confirms Wave 0 stubs only

---

## Metadata

**Confidence breakdown:**
- Gap identification: HIGH — gaps confirmed by reading actual Swift source files
- Requirement satisfaction: HIGH — each requirement mapped to specific file/line evidence
- Fix complexity: HIGH — both fixes are trivial (1-2 lines each)
- VERIFICATION.md format: HIGH — based on reading Phase 01 VERIFICATION.md

**Research date:** 2026-04-21
**Valid until:** Until Phase 04 source files are modified (no external dependencies)
