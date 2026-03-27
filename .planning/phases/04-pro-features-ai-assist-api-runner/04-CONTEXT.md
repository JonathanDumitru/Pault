# Phase 4: Pro Features — AI Assist & API Runner - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Pro users can improve prompts with AI assistance and execute prompts directly against LLMs with streaming responses. This phase builds the shared AI infrastructure (proxy service), all AI Assist features (rewrite, variables, tagging, scoring, refinement), and the API Runner (execution, response management, history). All AI calls route through a BYOK proxy service with subscription authentication. Ollama (local) bypasses the proxy.

</domain>

<decisions>
## Implementation Decisions

### Proxy service architecture
- Self-hosted Cloudflare Worker in a separate repo (not monorepo)
- Full build + deploy as part of Phase 4 Plan 01 — the proxy is a deliverable
- BYOK (Bring Your Own Key) model: users provide their own API keys, proxy forwards them
- Subscription receipt verification: app sends StoreKit transaction/receipt per request, proxy validates subscription is active server-side
- API keys stored in Keychain (existing pattern), sent per-request in header to proxy — never stored server-side
- SSE streaming passthrough from day one — proxy streams events from AI provider back to client
- All three providers supported: Claude + OpenAI routed through proxy, Ollama stays direct (local, bypasses proxy)
- User opt-in caching: content-hash based cache in Cloudflare KV, user enables in Preferences
- Safety: request size limits (e.g. 100K tokens) AND basic content filtering (keyword/pattern checks)
- Server-side rate limits per subscriber with 429 + retry-after header; app shows "Rate limit reached — try again in Xm" inline
- Proxy returns token counts (input/output) + estimated USD cost per request in response metadata
- Graceful offline: AI features show "AI unavailable — check connection" inline when proxy unreachable; no retry loop, no direct API fallback

### AI Assist panel
- Below canvas (current pattern), collapsible section — same position in both Edit and Build tabs
- Operates on full compiled prompt text (not per-block) in Build mode; operates on prompt.content directly in Edit mode
- All 5 tabs ship: Improve, Variables, Tags, Score, Refine
- Improve tab: streaming display (token-by-token as it generates), shows word-level diff (using existing DiffView component) between original and improved text, accept/reject controls
- Variable Suggestion: analyzes compiled prompt text, suggests {{variables}} for literal values — user accepts/rejects individually
- Auto-Tagging: on-demand only (user clicks "Suggest Tags") — no automatic tagging on save
- Quality Score: returns four-axis score (clarity, specificity, completeness, conciseness) PLUS 2-3 actionable improvement tips
- Refinement Loop: all iterations go through proxy (same as all AI calls), uses existing DiffView + star rating UX
- Auto-snapshot before any AI-suggested change is applied (creates version snapshot for Phase 5 versioning undo point)
- Keyboard shortcut: Cmd+Shift+I opens/focuses AI Improve tab
- Main window only — no AI features in menu bar popover or hotkey launcher
- Lazy connectivity check: panel always visible, error shown on actual AI call failure (no proactive NWPathMonitor)

### Model & provider selection
- Configuration in Preferences pane: dedicated "AI" section with per-provider API key fields + model picker
- Hardcoded model defaults per provider (e.g. claude-sonnet-4-5, gpt-4o, llama3) + custom model name text field for new releases
- Single global model selection used for all AI features (Improve, Variables, Tags, Score, Refine, API Runner)
- Three providers for v1.0: Claude, OpenAI, Ollama — no custom/OpenAI-compatible endpoint
- No default provider: first AI action shows setup prompt linking to Preferences
- Visible-but-locked when no key configured: AI panel shows "Set up your API key in Preferences to use AI features" with link
- API key validation: lightweight test call on save in Preferences, green checkmark or red error

### API Runner (Run tab)
- Dedicated "Run" tab alongside Edit/Build in PromptDetailView — third top-level tab
- Stacked layout: variable form → Execute button → streaming response → history
- Inline variable form: detected {{variables}} shown as text fields, pre-filled with TemplateVariable defaults
- Streaming response: auto-scrolling monospace font ScrollView, token-by-token, cancel button during stream, cursor animation at end
- Response footer: "1,234 tokens · ~$0.02 · 1.8s" — data from proxy response metadata
- Per-prompt history only (no global run history view)
- Basic A/B: stacked responses in history — user expands any two runs to compare visually, no dedicated comparison view
- Star rating: optional 1-5 stars on any run (not just Refinement Loop) — tappable in expanded RunHistoryRowView
- "Run Again" button in expanded history row — re-executes with same resolved input and model
- Run history deletable: swipe/button to delete individual runs with confirmation
- Response actions: Copy to clipboard + Save as Prompt (no Markdown export — deferred to Phase 6)

### Privacy manifest
- Update PrivacyInfo.xcprivacy in this phase to declare network usage for AI proxy calls
- BYOK note: user's API key is transmitted to proxy but not collected/stored by Pault server-side

### Claude's Discretion
- Exact Cloudflare Worker implementation details (routing, KV cache schema, content filter patterns)
- Proxy API contract design (endpoints, request/response schema)
- Exact streaming UI animation (cursor/caret style)
- Variable form layout and spacing in Run tab
- AI system prompts for each feature (improve, variables, tags, score)
- Rate limit thresholds and retry-after durations
- Cost estimation calculation logic per provider/model
- Run history row expand/collapse animation
- Key validation test call endpoint selection per provider

</decisions>

<specifics>
## Specific Ideas

- Proxy lives in a separate repo — Pault repo stays Swift-only
- Ollama bypasses proxy entirely (it's the user's own hardware, no subscription check needed)
- DiffView component already exists and should be reused for Improve tab and Refinement Loop
- PromptRun model already has all needed fields (inputTokens, outputTokens, userRating, variantLabel, metadata)
- Existing AIService actor pattern stays but rewires from direct API calls to proxy relay (except Ollama)
- Phase 1 decision: privacy manifest said "Data Not Collected" — this phase updates it

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AIService.swift` (319 lines): Actor with complete API for improve, suggestVariables, autoTag, qualityScore, clusterPrompts, streamRun — needs rewiring from direct API to proxy relay
- `AIAssistPanel.swift` (389 lines): 5-tab panel (Improve/Variables/Tags/Score/Refine) with accept/reject UX — needs streaming display and diff view integration
- `ResponsePanel.swift` (140 lines): Working streaming display with cancel, copy, save-as-prompt — needs integration into Run tab
- `RefinementLoopView.swift` (252 lines): Diff + star rating + iteration history — needs proxy routing, mostly ready
- `RunHistoryView.swift` (139 lines): Expandable row list with copy/save actions — needs rating, delete, Run Again buttons
- `DiffView`: Word-level diff component (in RefinementLoopView.swift) — reuse in Improve tab
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
- `PreferencesView.swift`: Add AI configuration section (provider, model, API keys)
- `AIService.swift`: Rewire from direct API calls to proxy relay (except Ollama)
- `PrivacyInfo.xcprivacy`: Update privacy declarations for network/AI usage
- `ProFeature` enum: `.aiAssist` and `.apiRunner` already gate these features
- Block editor canvas: AI Assist panel below canvas (existing position)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-pro-features-ai-assist-api-runner*
*Context gathered: 2026-03-26*
