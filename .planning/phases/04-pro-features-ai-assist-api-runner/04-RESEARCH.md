# Phase 4: Pro Features — AI Assist & API Runner - Research

**Researched:** 2026-03-26
**Domain:** Cloudflare Workers (TypeScript), Swift actor rewiring, SSE streaming, StoreKit subscription auth, SwiftUI AI panel integration
**Confidence:** HIGH (core patterns verified from official docs + existing codebase)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Proxy service architecture**
- Self-hosted Cloudflare Worker in a separate repo (not monorepo)
- Full build + deploy as part of Phase 4 Plan 01 — the proxy is a deliverable
- BYOK model: users provide their own API keys, proxy forwards them
- Subscription receipt verification: app sends StoreKit transaction/receipt per request, proxy validates subscription is active server-side
- API keys stored in Keychain (existing pattern), sent per-request in header to proxy — never stored server-side
- SSE streaming passthrough from day one — proxy streams events from AI provider back to client
- All three providers supported: Claude + OpenAI routed through proxy, Ollama stays direct (local, bypasses proxy)
- User opt-in caching: content-hash based cache in Cloudflare KV, user enables in Preferences
- Safety: request size limits (e.g. 100K tokens) AND basic content filtering (keyword/pattern checks)
- Server-side rate limits per subscriber with 429 + retry-after header; app shows "Rate limit reached — try again in Xm" inline
- Proxy returns token counts (input/output) + estimated USD cost per request in response metadata
- Graceful offline: AI features show "AI unavailable — check connection" inline when proxy unreachable; no retry loop, no direct API fallback

**AI Assist panel**
- Below canvas (current pattern), collapsible section — same position in both Edit and Build tabs
- Operates on full compiled prompt text (not per-block) in Build mode; operates on prompt.content directly in Edit mode
- All 5 tabs ship: Improve, Variables, Tags, Score, Refine
- Improve tab: streaming display (token-by-token), shows word-level diff (using existing DiffView component), accept/reject controls
- Variable Suggestion: analyzes compiled prompt text, suggests {{variables}} for literal values — user accepts/rejects individually
- Auto-Tagging: on-demand only (user clicks "Suggest Tags") — no automatic tagging on save
- Quality Score: returns four-axis score (clarity, specificity, completeness, conciseness) PLUS 2-3 actionable improvement tips
- Refinement Loop: all iterations go through proxy, uses existing DiffView + star rating UX
- Auto-snapshot before any AI-suggested change is applied (creates version snapshot for Phase 5 versioning undo point)
- Keyboard shortcut: Cmd+Shift+I opens/focuses AI Improve tab
- Main window only — no AI features in menu bar popover or hotkey launcher
- Lazy connectivity check: panel always visible, error shown on actual AI call failure (no proactive NWPathMonitor)

**Model & provider selection**
- Configuration in Preferences pane: dedicated "AI" section (AISettingsTab already exists)
- Hardcoded model defaults + custom model name text field
- Single global model selection used for all AI features
- Three providers: Claude, OpenAI, Ollama — no custom/OpenAI-compatible endpoint
- No default provider: first AI action shows setup prompt linking to Preferences
- Visible-but-locked when no key configured: "Set up your API key in Preferences" with link
- API key validation: lightweight test call on save in Preferences, green checkmark or red error

**API Runner (Run tab)**
- Dedicated "Run" tab alongside Edit/Build in PromptDetailView — third top-level tab
- Stacked layout: variable form → Execute button → streaming response → history
- Inline variable form: detected {{variables}} shown as text fields, pre-filled with TemplateVariable defaults
- Streaming response: auto-scrolling monospace font ScrollView, token-by-token, cancel button during stream, cursor animation at end
- Response footer: "1,234 tokens · ~$0.02 · 1.8s" — data from proxy response metadata
- Per-prompt history only (no global run history view)
- Basic A/B: stacked responses in history — user expands any two runs to compare visually, no dedicated comparison view
- Star rating: optional 1-5 stars on any run — tappable in expanded RunHistoryRowView
- "Run Again" button in expanded history row — re-executes with same resolved input and model
- Run history deletable: swipe/button to delete individual runs with confirmation
- Response actions: Copy to clipboard + Save as Prompt

**Privacy manifest**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| R2.1 | AI Prompt Improvement — streaming rewrite with accept/reject controls | AIService.improve() exists; needs proxy rewiring + streaming display in Improve tab |
| R2.2 | AI Variable Suggestion — analyze prompt, suggest {{variables}}, accept/reject each | AIService.suggestVariables() exists; needs proxy rewiring; VariablesTabContent UI mostly complete |
| R2.3 | AI Auto-Tagging — on-demand tag suggestions from content + existing vocab | AIService.autoTag() exists; needs proxy rewiring; TagsTabContent UI mostly complete |
| R2.4 | AI Quality Scoring — four-axis score + actionable improvement tips | AIService.qualityScore() exists; needs proxy rewiring + tips field added to response schema; ScoreTabContent exists |
| R2.5 | Proxy Service Integration — all AI calls route through proxy, subscription auth, graceful degradation, rate limiting | New Cloudflare Worker deliverable; AIService actor rewired for non-Ollama calls |
| R5.1 | Prompt Execution — run compiled prompt via proxy with model selection and streaming display | streamRun() exists in AIService; ResponsePanel exists; needs Run tab in PromptDetailView + proxy routing |
| R5.2 | Response Management — save responses with prompt linkage, history, clipboard | PromptRun model complete; RunHistoryView exists; needs star rating, delete, Run Again additions |
| R5.3 | Refinement Loop — iteration on prompt based on response, history preserved | RefinementLoopView exists; needs proxy routing |
</phase_requirements>

---

## Summary

Phase 4 is primarily a **rewiring phase**: the vast majority of the UI and data models already exist and are functional with direct API calls. The core work is (1) building and deploying a Cloudflare Worker proxy that receives forwarded API keys and StoreKit JWS tokens, and (2) redirecting AIService calls through that proxy for Claude and OpenAI. Ollama remains direct. The proxy becomes the source of truth for rate limiting, token counting, cost estimation, and optional caching.

The existing AIService actor, AIAssistPanel, ResponsePanel, RefinementLoopView, RunHistoryView, and PromptRun model cover ~70% of the needed surface. The gaps are: proxy construction and deploy, AIService URL rewriting to proxy endpoint, streaming metadata (tokens + cost) surfaced from proxy response headers/trailers, the Run tab in PromptDetailView, and UI augmentations to RunHistoryRowView (star rating, delete, Run Again).

The StoreKit subscription auth pattern is: the app passes `transaction.jwsRepresentation` per request; the proxy decodes the JWS (signed by Apple's certificate chain), verifies `productID` and `expirationDate` server-side, and returns 401/403 if expired. No Apple server-to-server API call is required at request time — the JWS is self-contained and cryptographically verifiable using Apple's public root certificates.

**Primary recommendation:** Build the proxy first (Plan 01), rewire AIService second (Plan 01 tail), then complete AI Assist UI polish and streaming display (Plan 02), then Run tab + response management completions (Plan 03).

---

## Standard Stack

### Proxy (Cloudflare Worker — separate repo)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Wrangler CLI | 3.x | Build, dev, deploy Cloudflare Workers | Official Cloudflare toolchain |
| TypeScript | 5.x | Worker implementation language | Native Cloudflare support, type-safe bindings |
| Cloudflare Workers KV | native binding | Optional response cache, keyed by content hash | Low-latency edge storage, no extra dependency |
| Workers Rate Limiting API | native binding | Per-subscriber request rate limiting | Built-in, atomic counters at Cloudflare PoP |
| `@cloudflare/workers-types` | generated via `wrangler types` | TypeScript types for Workers runtime | Official, version-accurate |

No npm packages required for the proxy beyond dev tooling. All Worker functionality (fetch, TransformStream, KV, rate limiter) is native.

### Swift Client (existing project)

| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| URLSession | system | HTTP calls to proxy, SSE bytes streaming | Already used; `bytes(for:)` API for streaming |
| KeychainService | project | Store API keys per provider | Already implemented |
| SwiftData + `@Model` | system | PromptRun persistence | Already implemented |
| `@Observable` / `@MainActor` | system | State management | Established project pattern |

**Installation (proxy repo):**
```bash
npm create cloudflare@latest pault-proxy -- --type worker --ts
cd pault-proxy
wrangler types   # generate runtime types
```

---

## Architecture Patterns

### Proxy Project Structure
```
pault-proxy/
├── src/
│   └── index.ts          # Single Worker entry point
├── wrangler.jsonc         # name, compatibility_date, KV bindings, ratelimits
├── package.json
└── tsconfig.json
```

The proxy is a single Worker. No routing library needed — route on `request.method` and `url.pathname`.

### Pattern 1: SSE Streaming Passthrough

**What:** Proxy receives client request with forwarded API key + provider target, calls upstream (Anthropic/OpenAI), streams SSE response back using TransformStream.

**When to use:** All streaming calls (streamRun in AIService, streaming Improve tab).

```typescript
// Source: https://developers.cloudflare.com/workers/examples/openai-sdk-streaming/
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // 1. Verify subscription (JWS check)
    // 2. Check rate limit
    // 3. Forward to upstream provider
    const upstream = await fetch(upstreamURL, {
      method: 'POST',
      headers: upstreamHeaders,
      body: request.body,        // pass through — no buffering
    });

    // 4. Stream response back — TransformStream intercepts for metadata injection
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();
    // pipe upstream SSE → client SSE; inject x-token-count trailer
    upstream.body!.pipeTo(writable);  // or use ReadableStream.tee() for metadata

    return new Response(readable, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'X-Input-Tokens': inputTokenCount.toString(),
      },
    });
  }
};
```

**Key constraint:** For SSE passthrough, do NOT buffer the full response. Use `pipeTo` or iterate `bytes()` and re-yield. Buffering defeats streaming.

### Pattern 2: StoreKit JWS Verification (Server-Side, No Apple Server Call)

**What:** App sends `transaction.jwsRepresentation` as `X-Storekit-JWS` header. Proxy decodes JWT header to get x5c certificate chain, verifies signature against Apple root CA bundle, checks `productID` and `expiresDate`.

**Why no App Store Server API call:** JWS is self-contained. Verification requires only Apple's public root certificates (downloaded once and bundled). No Apple server roundtrip needed per request — critical for low proxy latency.

```typescript
// Pseudo-pattern (full JWT verification using Web Crypto API)
async function verifyStoreKitJWS(jws: string): Promise<boolean> {
  const [header64, payload64, sig64] = jws.split('.');
  const header = JSON.parse(atob(header64));
  const payload = JSON.parse(atob(payload64));

  // Verify certificate chain from header.x5c against bundled Apple Root CA
  // Use Web Crypto subtle.verify() with the leaf cert public key
  // Check payload.productId matches expected, payload.expiresDate > now
  return isValid;
}
```

**Confidence:** MEDIUM — JWS structure is documented (Apple Developer docs). Exact Web Crypto implementation for x5c chain verification needs careful implementation. Alternative: trust `payload.expiresDate` and `payload.environment` fields after basic signature check, relying on the fact that only Apple can produce valid JWS. Full x5c validation is defense-in-depth.

**Simpler alternative (lower security, acceptable for BYOK):** Proxy trusts the decoded JWS payload fields (productID + expiresDate) without full x5c chain verification, since the API key is BYOK — a malicious actor would be using their own key. Full JWS validation still recommended.

### Pattern 3: Per-Subscriber Rate Limiting (Workers Native API)

**What:** Use Workers native Rate Limiting binding — atomic, no KV overhead.

```typescript
// wrangler.jsonc
// "ratelimits": [{"name": "AI_LIMITER", "namespace_id": "1001", "simple": {"limit": 60, "period": 60}}]

const { success } = await env.AI_LIMITER.limit({ key: subscriberID });
if (!success) {
  return new Response('Rate limit exceeded', {
    status: 429,
    headers: { 'Retry-After': '60' },
  });
}
```

Rate limit key = StoreKit `originalTransactionId` (stable per subscriber). Period options: 10s or 60s only (Workers constraint).

### Pattern 4: Content-Hash Cache (KV, User Opt-In)

**What:** SHA-256 hash of `provider + model + resolvedPrompt` as KV key. Cached response returned for identical requests. User enables in Preferences; app sends `X-Cache-Opt-In: true` header.

```typescript
const cacheKey = await sha256(`${provider}:${model}:${resolvedPrompt}`);
const cached = await env.RESPONSE_CACHE.get(cacheKey);
if (cached && request.headers.get('X-Cache-Opt-In') === 'true') {
  return new Response(cached, { headers: { 'X-Cache': 'HIT' } });
}
// ... call upstream, store result
await env.RESPONSE_CACHE.put(cacheKey, output, { expirationTtl: 86400 });
```

Cache applies to non-streaming (complete) responses only. SSE streaming cannot be cached this way — cache miss always streams.

### Pattern 5: AIService Actor Rewiring

**What:** Replace provider-specific URL construction in `buildRequest` / `buildStreamRequest` with a single proxy URL. API key moves from `Authorization`/`x-api-key` header to `X-Provider-Key`. Provider identifier moves to `X-Provider` header.

```swift
// Before: direct call to https://api.anthropic.com/v1/messages
// After: proxy call
private let proxyBaseURL = "https://pault-proxy.YOUR_ACCOUNT.workers.dev"

private func buildProxyRequest(
    body: [String: Any],
    provider: AIConfig.Provider,
    apiKey: String,
    streaming: Bool
) throws -> URLRequest {
    let endpoint = streaming ? "/v1/stream" : "/v1/complete"
    var request = URLRequest(url: URL(string: proxyBaseURL + endpoint)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(provider.rawValue, forHTTPHeaderField: "X-Provider")
    request.setValue(apiKey, forHTTPHeaderField: "X-Provider-Key")
    request.setValue(storeKitJWS, forHTTPHeaderField: "X-Storekit-JWS")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
}
```

Ollama bypasses this entirely — `buildRequest` for Ollama hits `http://localhost:11434` directly, unchanged.

### Pattern 6: Streaming Metadata from Proxy

**What:** Proxy returns token counts and cost in response headers (non-streaming) or as a final SSE event (`event: metadata`) before `[DONE]`. Client parses from the stream.

```swift
// In AIService.streamRun — look for metadata event before [DONE]
for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let payload = String(line.dropFirst(6))
    if payload == "[DONE]" { break }
    // Check for metadata event
    if let data = payload.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let meta = json["metadata"] as? [String: Any] {
        // Extract inputTokens, outputTokens, estimatedCost
        continuation.yield(.metadata(meta))
        continue
    }
    guard let token = parseStreamToken(data: Data(payload.utf8), config: config) else { continue }
    continuation.yield(.token(token))
}
```

The `AsyncThrowingStream` element type changes from `String` to an enum: `.token(String)` | `.metadata([String: Any])`. All existing callers need updating.

### Pattern 7: Run Tab in PromptDetailView

**What:** Add "Run" as a third `StudioTab` case (alongside Edit and Build) or use a top-level TabView. Based on the existing code structure, the cleanest approach is a Picker/segmented control in the toolbar: "Edit | Build | Run".

```swift
// Add to PromptDetailView toolbar picker
enum DetailTab: String, CaseIterable {
    case edit = "Edit"
    case build = "Build"
    case run = "Run"
}
@State private var selectedDetailTab: DetailTab = .edit
```

Content area switches on `selectedDetailTab`. The Run tab renders `RunTabView(prompt: prompt, config: resolvedConfig)` which contains: variable form → Execute button → ResponsePanel → RunHistoryView.

### Pattern 8: Auto-Scrolling Streaming Response

**What:** ScrollViewReader with an anchor ID at the end of the streamed text, scrolled to on each token append.

```swift
ScrollViewReader { proxy in
    ScrollView {
        Text(streamingText)
            .font(.system(.body, design: .monospace))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        Color.clear.frame(height: 1).id("bottom")
    }
    .onChange(of: streamingText) { _, _ in
        proxy.scrollTo("bottom", anchor: .bottom)
    }
}
```

### Anti-Patterns to Avoid

- **Buffering SSE before forwarding:** Kills streaming UX — always pipe upstream body directly
- **Storing API keys server-side:** BYOK model explicitly prohibits this — keys travel in headers, not persisted in Worker KV
- **Direct API fallback when proxy is unreachable:** Decision is to show inline error — no silent fallback to direct calls
- **Proactive NWPathMonitor connectivity checks:** Decision is lazy — show error only on actual call failure
- **Multiple xcodebuild processes:** Project memory rule — never run concurrent xcodebuild (see feedback_xcodebuild_ram.md)
- **Buffering full SSE response for KV cache:** Cache only non-streaming (complete) calls; streaming responses skip cache

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SSE streaming passthrough | Custom byte-by-byte forwarder | `ReadableStream.pipeTo()` / `TransformStream` | Workers native, handles backpressure |
| Rate limiting counters | KV-based manual counter with TTL | Workers native Rate Limiting binding | Atomic, co-located with Worker, no race conditions |
| API key storage on client | Custom encryption scheme | `KeychainService` (existing) | Already implemented, correct for macOS sandbox |
| JWS JWT decode | Manual base64 parsing | Standard `atob()` + `JSON.parse()` in Worker | JWS is just base64url-encoded JSON segments |
| Word-level diff display | New diff renderer | Existing `DiffView` component in RefinementLoopView.swift | Already tested, reuse by moving to standalone file |
| Token streaming state | Manual `@State` token accumulator | Existing pattern in `ResponsePanel.swift` | Pattern already proven; extend don't replace |

---

## Common Pitfalls

### Pitfall 1: Proxy SSE Response Missing Content-Type Header
**What goes wrong:** Client URLSession receives response with no `Content-Type: text/event-stream` — `bytes.lines` still works but upstream provider may add `Transfer-Encoding: chunked` that conflicts.
**Why it happens:** Worker returning `new Response(readable)` without explicit headers.
**How to avoid:** Always explicitly set `Content-Type: text/event-stream` and `Cache-Control: no-cache` in proxy response headers.
**Warning signs:** `bytes.lines` returns empty or client receives non-SSE body.

### Pitfall 2: Ollama Bypasses Proxy — Config Logic Must Be Conditional
**What goes wrong:** AIService sends Ollama requests to proxy URL, proxy doesn't understand Ollama's `/api/chat` format.
**Why it happens:** Blanket replacement of `buildRequest` without provider check.
**How to avoid:** In `buildRequest`, early-return the Ollama path using existing direct URL construction. Only Claude and OpenAI route through proxy.
**Warning signs:** Ollama calls return 400 from proxy.

### Pitfall 3: StoreKit JWS Token Staleness
**What goes wrong:** App caches the JWS token at launch; subscription expires mid-session; proxy rejects requests.
**Why it happens:** `transaction.jwsRepresentation` reflects state at fetch time, not real-time.
**How to avoid:** Re-fetch `Transaction.currentEntitlements` JWS before each AI call (or cache with short TTL, e.g. 60 seconds). Use `ProStatusManager.shared.currentJWS` that refreshes on subscription events.
**Warning signs:** 401 responses from proxy after subscription state changes.

### Pitfall 4: AsyncThrowingStream Enum Change Breaks Existing Callers
**What goes wrong:** Changing `streamRun` return type from `AsyncThrowingStream<String, Error>` to a token/metadata enum breaks `ResponsePanel`, `RefinementLoopView`, and `PromptDetailView.collectStream`.
**Why it happens:** Multiple callers depend on the simple String stream.
**How to avoid:** Either (a) keep `streamRun` returning `AsyncThrowingStream<String, Error>` and add a separate `streamRunWithMetadata` method, or (b) add a `StreamEvent` enum but update all callers in the same plan. Option (a) is safer for phased delivery.
**Warning signs:** Compile errors across 3+ files when changing stream element type.

### Pitfall 5: Workers Rate Limiting Period Constraint
**What goes wrong:** Configuring a rate limit period of 30 seconds — not supported (only 10 or 60 seconds).
**Why it happens:** Workers Rate Limiting API only supports `period: 10` or `period: 60`.
**How to avoid:** Use 60-second windows. For per-minute limits, `limit: N, period: 60` is the correct config.

### Pitfall 6: KV Cache for Streaming vs Non-Streaming
**What goes wrong:** Attempting to cache SSE stream in KV (impossible — stream isn't complete until finished).
**Why it happens:** Treating cached and streamed paths identically.
**How to avoid:** Cache applies only to non-streaming (complete) requests. Streaming always bypasses cache. Proxy distinguishes by `stream: true` in request body.

### Pitfall 7: Improve Tab Missing Streaming (Current Implementation)
**What goes wrong:** `AIAssistPanel.runImprove()` currently calls `AIService.shared.improve()` — a non-streaming completion. The CONTEXT.md decision requires **streaming display** in the Improve tab.
**Why it happens:** The existing `improve()` method uses `complete()` (non-streaming).
**How to avoid:** Add `streamImprove()` method to AIService that uses `buildStreamRequest`, and update `AIAssistPanel` Improve tab to use it with incremental `streamingText` state.

### Pitfall 8: Auto-Snapshot Before AI Change (Phase 5 Dependency)
**What goes wrong:** Applying AI-suggested changes without creating a version snapshot — Phase 5 versioning has no undo point.
**Why it happens:** `prompt.content = improvedText` in AIAssistPanel without snapshot call.
**How to avoid:** In every Accept action (Improve tab, Variables, Refine), call `PromptService.saveSnapshot(for:limit:)` before mutating `prompt.content`. This is the same `debouncedSave` pattern already in `PromptDetailView` — trigger it explicitly, synchronously, before applying.

---

## Code Examples

### Proxy: Minimal Worker Entry Point

```typescript
// Source: Cloudflare Workers docs - https://developers.cloudflare.com/workers/get-started/guide/
export interface Env {
  RESPONSE_CACHE: KVNamespace;
  AI_LIMITER: RateLimit;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    // 1. Extract headers
    const provider = request.headers.get('X-Provider') ?? '';
    const apiKey = request.headers.get('X-Provider-Key') ?? '';
    const jws = request.headers.get('X-Storekit-JWS') ?? '';
    const streaming = request.headers.get('X-Streaming') === 'true';
    const cacheOptIn = request.headers.get('X-Cache-Opt-In') === 'true';

    // 2. Verify subscription
    if (!await verifySubscription(jws)) {
      return new Response('Unauthorized', { status: 401 });
    }

    // 3. Rate limit
    const subscriberID = extractSubscriberID(jws);
    const { success } = await env.AI_LIMITER.limit({ key: subscriberID });
    if (!success) {
      return new Response('Rate limit exceeded', {
        status: 429,
        headers: { 'Retry-After': '60' },
      });
    }

    // 4. Route to provider
    return routeToProvider(request, provider, apiKey, streaming, cacheOptIn, env);
  }
};
```

### AIService: Proxy URL Resolution

```swift
// AIService.swift — buildRequest updated
private let proxyURL = "https://pault-proxy.YOUR_WORKERS_DEV_URL.workers.dev/v1/complete"
private let proxyStreamURL = "https://pault-proxy.YOUR_WORKERS_DEV_URL.workers.dev/v1/stream"

private func buildRequest(system: String, user: String, config: AIConfig) async throws -> URLRequest {
    // Ollama bypasses proxy — direct local call
    if config.provider == .ollama {
        return try await buildOllamaRequest(system: system, user: user, config: config)
    }

    guard let apiKey = try? keychain.load(key: "ai.apikey.\(config.provider.rawValue)"),
          !apiKey.isEmpty else { throw AIError.missingAPIKey }

    guard let jws = await ProStatusManager.shared.currentTransactionJWS else {
        throw AIError.subscriptionRequired
    }

    let body: [String: Any] = buildProviderBody(system: system, user: user, config: config)

    var request = URLRequest(url: URL(string: proxyURL)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(config.provider.rawValue, forHTTPHeaderField: "X-Provider")
    request.setValue(apiKey, forHTTPHeaderField: "X-Provider-Key")
    request.setValue(jws, forHTTPHeaderField: "X-Storekit-JWS")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
}
```

### RunTabView Structure

```swift
struct RunTabView: View {
    @Bindable var prompt: Prompt
    let config: AIConfig

    @State private var variableValues: [String: String] = [:]
    @State private var isRunning = false
    @State private var streamingText = ""
    @State private var runMetadata: RunMetadata? = nil   // tokens, cost, latency
    @State private var runTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Variable form (if {{variables}} present)
                if !prompt.templateVariables.isEmpty {
                    VariableFormView(variables: prompt.templateVariables, values: $variableValues)
                }

                // 2. Execute button
                HStack {
                    Button(isRunning ? "Running…" : "Run") { startRun() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunning)
                    if isRunning {
                        Button("Cancel") { runTask?.cancel() }
                            .buttonStyle(.plain)
                    }
                }

                // 3. Streaming response (visible once run starts)
                if !streamingText.isEmpty || isRunning {
                    StreamingResponseView(text: streamingText, isRunning: isRunning, metadata: runMetadata)
                }

                Divider()

                // 4. Run history
                RunHistoryView(prompt: prompt)
            }
            .padding(16)
        }
    }
}
```

### RunHistoryRowView — Missing Additions

Current `RunHistoryRowView` needs three additions per CONTEXT.md decisions:
1. Star rating (tappable 1-5) in expanded state — update `run.userRating` via modelContext
2. "Run Again" button in expanded state — re-execute with `run.resolvedInput`, same model
3. Delete button — swipe or button; call `modelContext.delete(run)` with confirmation alert

```swift
// Additions to expanded section in RunHistoryRowView
if isExpanded {
    // Star rating
    HStack(spacing: 4) {
        ForEach(1...5, id: \.self) { star in
            Image(systemName: (run.userRating ?? 0) >= star ? "star.fill" : "star")
                .foregroundStyle(.yellow)
                .onTapGesture {
                    run.userRating = star
                    try? modelContext.save()
                }
        }
    }

    // Run Again
    Button("Run Again") { onRunAgain(run) }
        .buttonStyle(.bordered)

    // Delete
    Button("Delete", role: .destructive) { onDelete(run) }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
}
```

---

## Existing Code Gap Analysis

This section maps what already exists versus what needs to be built or changed.

| Component | Exists? | State | Work Needed |
|-----------|---------|-------|-------------|
| `AIService.swift` | Yes | Direct API calls | Rewire `buildRequest`/`buildStreamRequest` to proxy (except Ollama). Add `streamImprove()` for streaming Improve tab. Add `AIError.subscriptionRequired`. |
| `AIAssistPanel.swift` | Yes | Non-streaming Improve tab | Add `streamingImprovedText` + `DiffView` to Improve tab. Wire `Cmd+Shift+I` shortcut. Add "Set up API key" guard when no key. Add auto-snapshot-before-accept calls. |
| `ResponsePanel.swift` | Yes | Direct API calls, no metadata | Wire to proxy. Add `runMetadata` footer ("N tokens · ~$X · Xs"). |
| `RefinementLoopView.swift` | Yes | Direct API calls | Wire `improve()` call through proxy. No structural changes needed. |
| `RunHistoryView.swift` | Yes | No rating/delete/Run Again | Add star rating, delete, Run Again to `RunHistoryRowView`. |
| `PromptRun.swift` | Yes | All fields present | No changes needed. |
| `PromptDetailView.swift` | Yes | No Run tab | Add Run tab (third tab in toolbar picker). Wire `RunTabView`. |
| `PreferencesView.swift` (AISettingsTab) | Yes | Direct API key storage | Add proxy URL display (read-only, informational). Add "Cache responses" toggle stored in `@AppStorage("ai.cacheOptIn")`. |
| `ProStatusManager.swift` | Exists | Manages subscription state | Add `currentTransactionJWS: String?` computed/async property returning the active transaction's JWS. |
| `DiffView` | Yes (in RefinementLoopView.swift) | Embedded in file | Extract to standalone `DiffView.swift` for reuse in Improve tab. |
| Cloudflare Worker | No | Does not exist | Build from scratch: Plan 01 deliverable. |
| `PrivacyInfo.xcprivacy` | Yes | No network declaration | Add `NSNetworkVolumes` / outgoing network usage reason for AI proxy. |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| App-side API key management with direct LLM calls | Proxy-forwarded BYOK with subscription auth | Phase 4 (now) | All AI calls auditable server-side; rate limiting; cost tracking |
| `verifyReceipt` (deprecated REST API) | JWS `transaction.jwsRepresentation` | StoreKit 2 (2021) | Self-contained, no Apple server call needed per request |
| Buffered `data(for:)` for AI responses | `bytes(for:)` SSE streaming | Swift 5.5+ | Token-by-token display, cancellable mid-stream |
| Cloudflare Workers rate limiting via KV (manual) | Workers native Rate Limiting binding | 2024 | Atomic counters, no manual TTL logic |

**Deprecated/outdated:**
- `verifyReceipt` endpoint: Legacy, not used in StoreKit 2. Do not use.
- `@cloudflare/workers-types` npm package: Replaced by `wrangler types` command for generated types.

---

## Open Questions

1. **Proxy URL configuration in the app**
   - What we know: Worker will have a `.workers.dev` URL after deploy
   - What's unclear: Should proxy URL be hardcoded in AIService, or configurable via `@AppStorage`? A hardcoded constant is simpler; an AppStorage key allows staging/prod switching.
   - Recommendation: Hardcode as a `private let` constant in `AIService.swift` initially. Can be made configurable in a later phase.

2. **ProStatusManager JWS access**
   - What we know: `ProStatusManager` manages subscription state via StoreKit; the active transaction's `jwsRepresentation` is available from `Transaction.currentEntitlements`
   - What's unclear: Whether to expose a synchronous cached JWS string or require an async fetch each time
   - Recommendation: Cache the JWS string in ProStatusManager (refreshed on subscription state change), expose as a synchronous `var currentTransactionJWS: String?`. On cache miss (nil), trigger async refresh. This avoids making every AI call async-chain through StoreKit.

3. **Cost estimation accuracy**
   - What we know: Token counts are available in provider API responses; pricing is public but changes
   - What's unclear: Should proxy hardcode pricing tables or accept pricing as configuration?
   - Recommendation: Hardcode pricing table in the Worker (Claude and OpenAI published rates); expose as a comment block at the top of `index.ts` for easy updates. Not user-configurable.

4. **wrangler.jsonc KV namespace ID**
   - What we know: KV namespace must be created in Cloudflare dashboard before deploy; `namespace_id` is account-specific
   - What's unclear: How to handle this in the proxy repo's source (can't commit account-specific IDs publicly if repo is public)
   - Recommendation: Use environment variables or `.dev.vars` file (gitignored) for the namespace ID. Commit a `wrangler.jsonc.example` with placeholder IDs.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (AIServiceTests) + Swift Testing (PromptRunTests, ProFeatureTests) |
| Config file | Xcode scheme — no separate config file |
| Quick run command | `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 | tail -20` |
| Full suite command | `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | tail -40` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| R2.1 | `streamImprove()` yields tokens then completes | unit (mock) | `xcodebuild test ... -only-testing PaultTests/AIServiceTests` | ✅ (expand existing) |
| R2.1 | Accept in Improve tab calls saveSnapshot before mutating content | unit | new test in AIServiceTests or AIAssistPanelTests | ❌ Wave 0 |
| R2.2 | `suggestVariables()` routes through proxy for non-Ollama | unit (mock URLSession) | `xcodebuild test ... -only-testing PaultTests/AIServiceTests` | ✅ (expand) |
| R2.3 | `autoTag()` routes through proxy for non-Ollama | unit | same | ✅ (expand) |
| R2.4 | `qualityScore()` returns tips field | unit | same | ✅ (expand) |
| R2.5 | Proxy error → AIError.proxyUnreachable — shown inline, no retry | unit | `AIServiceTests/test_proxyUnreachable_showsInlineError` | ❌ Wave 0 |
| R2.5 | 429 response → rate limit message extracted from Retry-After | unit | `AIServiceTests/test_rateLimitResponse_parsesRetryAfter` | ❌ Wave 0 |
| R5.1 | `streamRun()` routes through proxy, Ollama bypasses | unit (mock) | `AIServiceTests` | ✅ (expand) |
| R5.2 | PromptRun persists with inputTokens/outputTokens from metadata | unit | `PromptRunTests/test_promptRunPersistsWithTokenMetadata` | ❌ Wave 0 |
| R5.3 | RefinementLoopView accept() calls saveSnapshot | unit | new | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing PaultTests/AIServiceTests 2>&1 | tail -20`
- **Per wave merge:** Full suite (all PaultTests)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `PaultTests/AIAssistPanelTests.swift` — covers snapshot-before-accept (R2.1), streaming state management
- [ ] `PaultTests/AIServiceTests.swift` (expand) — proxy routing tests, 429 handling, Ollama bypass verification (R2.5, R5.1)
- [ ] `PaultTests/PromptRunTests.swift` (expand) — token metadata persistence (R5.2)
- [ ] `PaultTests/RunTabViewTests.swift` — variable form pre-fill, Run Again behavior (R5.1, R5.3)

Note: Proxy Worker tests are TypeScript unit tests in the proxy repo (outside Xcode). Recommend `vitest` for Worker logic tests (subscription verify, rate limit mock, routing). This is a Wave 0 gap in the proxy repo.

---

## Sources

### Primary (HIGH confidence)
- Cloudflare Workers Streams docs — https://developers.cloudflare.com/workers/runtime-apis/streams/
- Cloudflare Workers OpenAI SDK Streaming example — https://developers.cloudflare.com/workers/examples/openai-sdk-streaming/
- Cloudflare Workers Rate Limiting API — https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- Cloudflare Workers KV docs — https://developers.cloudflare.com/kv/
- Apple Developer Documentation — `jwsRepresentation` — https://developer.apple.com/documentation/storekit/verificationresult/jwsrepresentation-21vgo
- Existing codebase: `AIService.swift`, `AIAssistPanel.swift`, `ResponsePanel.swift`, `RefinementLoopView.swift`, `RunHistoryView.swift`, `PromptRun.swift`, `PromptDetailView.swift`, `PreferencesView.swift`, `ProFeature.swift`

### Secondary (MEDIUM confidence)
- Adapty blog: StoreKit 2 API Tutorial (JWS verification pattern) — https://adapty.io/blog/storekit-2-api-tutorial/
- Cloudflare Workers TypeScript guide — https://developers.cloudflare.com/workers/languages/typescript/

### Tertiary (LOW confidence)
- Community pattern for KV content-hash caching — inferred from KV docs + BYOK GitHub example

---

## Metadata

**Confidence breakdown:**
- Proxy architecture: HIGH — Cloudflare docs confirmed streaming passthrough, rate limiting, KV patterns
- AIService rewiring: HIGH — full source read, patterns clear
- StoreKit JWS auth: MEDIUM — structure is documented; exact x5c Web Crypto implementation requires careful validation
- UI patterns (Run tab, streaming scroll): HIGH — existing patterns in codebase, ScrollViewReader pattern well-documented

**Research date:** 2026-03-26
**Valid until:** 2026-04-26 (Cloudflare APIs stable; StoreKit 2 API stable)
