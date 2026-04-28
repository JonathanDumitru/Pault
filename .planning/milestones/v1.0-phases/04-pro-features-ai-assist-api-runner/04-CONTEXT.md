# Phase 4: Pro Features — AI Assist & API Runner - Context

**Gathered:** 2026-03-26
**Updated:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Pro users can improve prompts with AI assistance and execute prompts directly against LLMs with streaming responses. This phase builds the shared AI infrastructure (proxy service), all AI Assist features (rewrite, variables, tagging, scoring, refinement), and the API Runner (execution, response management, history). All AI calls route through a BYOK proxy service with subscription authentication. Ollama (local) bypasses the proxy.

</domain>

<decisions>
## Implementation Decisions

### Proxy Service Architecture
- Self-hosted Cloudflare Worker in a separate repo (not monorepo)
- Full build + deploy as part of Phase 4 Plan 01 — the proxy is a deliverable
- BYOK (Bring Your Own Key) model: users provide their own API keys, proxy forwards them
- Subscription receipt verification: app sends StoreKit JWS per request, proxy validates subscription is active server-side
- Full JWS verification per request (signature + expiry + product ID)
- API keys stored in Keychain (existing pattern), sent per-request in header to proxy — never stored server-side
- SSE streaming passthrough from day one — proxy streams events from AI provider back to client
- All three providers supported: Claude + OpenAI routed through proxy, Ollama stays direct (local, bypasses proxy)
- Dumb relay + auth only — no content filtering, no KV caching for v1.0
- Server-side rate limits: simple fixed rate limit (100 req/hr guidance) via Cloudflare KV with 429 + Retry-After header; app shows "Rate limit reached — try again in Xm" inline
- Proxy returns token counts only (input/output) in response metadata — no cost estimation for v1.0
- Graceful offline: AI features show "AI unavailable — check connection" inline when proxy unreachable; no retry loop, no direct API fallback
- Hardcoded production URL at api.pault.app (not configurable in Preferences)
- Staging + production Workers for deployment pipeline
- GitHub Actions auto-deploy from separate repo

### Proxy API Contract
- Unified proxy API: POST /v1/proxy (not mirrored provider APIs)
- Unified SSE format: `{type: "token", text: "..."}` and `{type: "done", usage: {...}}`
- Custom X- headers: X-Provider, X-Provider-Key, X-StoreKit-JWS, X-Request-Stream
- Usage + rate limit response headers
- Structured JSON errors with codes (rate_limited, subscription_expired, provider_error, invalid_request, internal_error)
- Health endpoint: GET /health

### AI Assist Panel
- Below canvas (current pattern), collapsible section — same position in both Edit and Build tabs
- Operates on full compiled prompt text (not per-block) in Build mode; operates on prompt.content directly in Edit mode
- All 5 tabs ship: Improve, Variables, Tags, Score, Refine
- Improve tab: streaming display (token-by-token), shows word-level diff (using existing DiffView component) between original and improved text, accept/reject controls
- Variable Suggestion: analyzes compiled prompt text, suggests {{variables}} for literal values — user accepts/rejects individually
- Contextual preview for variable suggestions: show original text → {{variable}} replacement
- Auto-Tagging: on-demand only (user clicks "Suggest Tags") — no automatic tagging on save
- Quality Score: radial/spider chart for four-axis score (clarity, specificity, completeness, conciseness) — custom SwiftUI Path implementation, not progress bars — PLUS 2-3 actionable improvement tips
- Refinement Loop: all iterations go through proxy (same as all AI calls), uses existing DiffView + star rating UX; full iteration history included in Refine prompt
- Auto-snapshot before any AI-suggested change is applied: creates PromptVersion with full prompt state (content, blocks, tags, variables), source-labeled ('ai-improve', 'ai-variable-accept', etc.), brief human-readable summary ('Before AI Improve')
- Inline error banner + retry button on failure
- Remember last selected tab between prompt switches
- Ephemeral results: clear AI results on prompt switch
- Spinner + 'Analyzing...' for non-streaming calls (Score, Variables, Tags)
- Idle state with action buttons on panel open
- Buttons disabled when prompt is empty
- Cancel in-flight AI call when switching prompts
- Discard AI result if user edits prompt while suggestion is pending
- 'No changes' message when Improve returns identical text
- Warn at ~50K chars for long prompts
- Keyboard shortcut: Cmd+Shift+I opens/toggles AI panel
- Esc closes AI panel (added to layered Esc chain)
- Main window only — no AI features in menu bar popover or hotkey launcher
- Lazy connectivity check: panel always visible, error shown on actual AI call failure (no proactive NWPathMonitor)

### AI System Prompts
- Hardcoded in app (not in proxy, not user-configurable)
- Improve: clarity + conciseness focus
- Score: structured JSON response (4 axes + tips)
- Variables: structured JSON suggestions (name, description, original_text, suggested)
- Tags: include existing tag vocabulary in prompt for consistency
- Non-streaming calls (Score, Variables, Tags) use single request/response
- Streaming only for Improve and Refine
- Refine: full iteration history included in prompt
- API Runner: no system prompt, prompt content is the user message only

### API Runner (Run tab)
- Dedicated "Run" tab alongside Edit/Build in PromptDetailView — third top-level tab
- Run tab available in both Edit and Build modes
- Scrollable single column layout
- Variable form: detected {{variables}} shown as text fields, pre-filled with TemplateVariable defaults
- Skip variable form entirely when no variables detected
- Tab cycles variable fields → Execute in Run tab
- Prominent full-width accent Execute button → transforms to Cancel during streaming
- Model indicator as subtitle below Execute button
- Cmd+Enter to execute
- Streaming response: auto-scrolling monospace font ScrollView, token-by-token, cancel button during stream
- Save partial responses on cancel with 'Cancelled' badge
- Response footer: token count + latency (no cost estimation for v1.0)
- Variable form + Execute as empty state (no 'No runs yet' placeholder)
- Section header separator between current response and history
- Run Again: same variable values, immediate re-execution
- Per-prompt history only (no global run history view)
- Collapsed history rows show: model, timestamp, token count, latency
- Paginated fetch: latest 20 runs initially + 'Load more'
- Basic A/B: stacked responses in history — user expands any two runs to compare visually, no dedicated comparison view
- Star rating: optional 1-5 stars on any run — tap to set, tap same to clear
- "Run Again" button in expanded history row
- Run history deletable: swipe/button to delete individual runs with confirmation
- Response actions: Copy to clipboard + Save as Prompt (no Markdown export — deferred to Phase 6)

### Run Tab Layout
- Native segmented control for Edit|Build|Run tabs
- Scrollable single column
- Prominent full-width accent Execute button → Cancel during streaming
- Model indicator as subtitle below Execute

### Model & Provider Selection
- Configuration in Preferences pane: dedicated "AI" section — rebuild AI Preferences tab
- Segmented control for provider picker (Claude, OpenAI, Ollama)
- Dropdown + custom option for model picker (not free text field); baked-in model list, no proxy fetch
- Query Ollama /api/tags for installed models (on Ollama tab selection)
- Single global model selection used for all AI features (Improve, Variables, Tags, Score, Refine, API Runner)
- Three providers for v1.0: Claude, OpenAI, Ollama — no custom/OpenAI-compatible endpoint
- Pro-only for all providers including Ollama
- SecureField + reveal toggle for API keys
- API key validation: models list call on save in Preferences, green checkmark or red error
- Keep everything on provider switch (keys, model selections persist)
- Summary status bar at top of AI Preferences
- No default provider: first AI action shows setup prompt linking to Preferences
- Visible-but-locked when no key configured: AI panel shows "Set up your API key in Preferences to use AI features" with link

### Privacy & Data
- 'Data Not Collected' App Store designation stays
- Add NSPrivacyAccessedAPICategoryNetworking if required by Apple review
- No disclosure dialog before first AI call
- Minimal structured proxy logs (no prompt content, no API keys)
- Standard HTTPS for proxy communication (no TLS pinning)
- BYOK note: user's API key is transmitted to proxy but not collected/stored by Pault server-side

### Testing Strategy
- Protocol-based mocking (AIServiceProtocol) with dependency injection everywhere
- Unit tests + 1-2 smoke tests hitting real proxy (staging)
- AsyncSequence mock for streaming tests
- Swift Testing (@Test) for all new tests
- Test stubs first (Plan 00)
- Vitest + Miniflare for proxy Worker tests

### Keyboard Shortcuts
- Cmd+1/2/3 = Edit/Build/Run tabs (reassign Phase 2 panel focus shortcuts)
- Cmd+Shift+I toggles AI panel
- Esc closes AI panel (added to layered Esc chain)
- Tab cycles variable fields → Execute in Run tab
- No per-AI-tab shortcuts
- Cmd+Enter executes in Run tab

### Performance
- Batch UI updates for streaming (every 50ms or 10 tokens, whichever comes first)
- Paginated run history fetch (20 initial)
- Store full response text in SwiftData, no limit
- Shared URLSession for all AI calls

### Accessibility
- VoiceOver: announce completion only (not during streaming)
- Radar chart: text alternative accessibility label listing scores
- Error banners: assertive announcement
- Variable form: name + description accessibility labels

### Migration
- Modify existing AIService in-place (not new service)
- Replace EditingMode with DetailTab enum (.edit, .build, .run)
- Nil-safe display for old PromptRun records
- Extract DiffView to standalone file for reuse
- AIServiceProtocol with dependency injection everywhere

### Animations
- Blinking pipe cursor during streaming
- Slide up from bottom for AI panel
- Tap to set / tap same to clear for star rating
- Native segmented control for tab bar (system animation)
- Radar chart animates from center on load

### Proxy Ops
- api.pault.app custom domain
- Bundle Apple root cert for JWS verification
- Staging + production Workers
- Basic health endpoint + Cloudflare analytics
- Rate limits tracked in KV

### Feature Discoverability
- Sparkle icon + first-use nudge tooltip for AI features
- Run tab visible but locked for free users
- No AI hints in popover/launcher

### Auto-Snapshot
- Full prompt state captured (content, blocks, tags, variables)
- Source-labeled: 'ai-improve', 'ai-variable-accept', etc.
- Brief human-readable summary: 'Before AI Improve'
- Creates PromptVersion for Phase 5 versioning undo point

### Claude's Discretion
- Exact Cloudflare Worker implementation details
- Proxy API contract details beyond what's specified above
- AI system prompt exact wording
- Streaming cursor blink timing
- Variable form layout spacing
- Rate limit threshold (100/hr is guidance, not hard requirement)
- Cost estimation logic (deferred to post-v1.0)
- Run history expand/collapse animation
- Key validation models list endpoint per provider

</decisions>

<specifics>
## Specific Ideas

- Proxy lives in a separate repo — Pault repo stays Swift-only
- Ollama bypasses proxy entirely (it's the user's own hardware, no subscription check needed)
- DiffView component already exists and should be reused for Improve tab and Refinement Loop — extract to standalone file
- PromptRun model already has all needed fields (inputTokens, outputTokens, userRating, variantLabel, metadata)
- Existing AIService actor pattern stays but rewires from direct API calls to proxy relay (except Ollama)
- Phase 1 decision: privacy manifest said "Data Not Collected" — this phase maintains that
- DetailTab enum replaces EditingMode to support .edit, .build, .run
- PromptVersion model reused for auto-snapshots (source + summary fields)

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AIService.swift` (319 lines): Actor with complete API for improve, suggestVariables, autoTag, qualityScore, clusterPrompts, streamRun — needs rewiring from direct API to proxy relay
- `AIAssistPanel.swift` (389 lines): 5-tab panel (Improve/Variables/Tags/Score/Refine) with accept/reject UX — needs streaming display and diff view integration
- `ResponsePanel.swift` (140 lines): Working streaming display with cancel, copy, save-as-prompt — needs integration into Run tab
- `RefinementLoopView.swift` (252 lines): Diff + star rating + iteration history — needs proxy routing, mostly ready
- `RunHistoryView.swift` (139 lines): Expandable row list with copy/save actions — needs rating, delete, Run Again buttons
- `DiffView`: Word-level diff component (in RefinementLoopView.swift) — extract to standalone file, reuse in Improve tab
- `PromptRun` model: SwiftData model with all needed fields (tokens, rating, variant, metadata)
- `KeychainService.swift`: Key storage with save/load/delete — pattern for API key management
- `ABTestResultView.swift`: Exists but defer formal A/B to post-launch
- `ProFeature` enum: `.aiAssist` and `.apiRunner` cases already defined with paywall metadata

### Established Patterns
- Actor-based `AIService` with `async throws` methods and URLSession
- `@Observable` + `@MainActor` for state management (ProStatusManager pattern)
- SwiftData `@Model` with `@Query` for persistence (PromptRun)
- `Task {}` for async work in SwiftUI views with `MainActor.run {}` for UI updates
- SSE parsing: `bytes.lines` with `data: ` prefix stripping and `[DONE]` termination
- Keychain keys: `ai.apikey.{provider}` naming convention

### Integration Points
- `PromptDetailView.swift`: Add Run tab alongside Edit/Build, wire AI Assist panel
- `PreferencesView.swift`: Rebuild AI configuration section (provider, model, API keys)
- `AIService.swift`: Rewire from direct API calls to proxy relay (except Ollama)
- `PrivacyInfo.xcprivacy`: Update privacy declarations for network/AI usage
- `ProFeature` enum: `.aiAssist` and `.apiRunner` already gate these features
- Block editor canvas: AI Assist panel below canvas (existing position)

</code_context>

<deferred>
## Deferred Ideas

- Cost estimation (post-v1.0)
- KV response caching (post-v1.0)
- Content filtering (post-v1.0)
- Markdown export for run responses (Phase 6)
- Formal A/B comparison view (post-launch)
- Custom/OpenAI-compatible endpoints (post-v1.0)
- TLS pinning (post-v1.0)

</deferred>

---

*Phase: 04-pro-features-ai-assist-api-runner*
*Context gathered: 2026-03-26*
*Context updated: 2026-03-27*
