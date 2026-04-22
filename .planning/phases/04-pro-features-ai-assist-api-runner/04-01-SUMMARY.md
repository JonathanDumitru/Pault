---
phase: 04-pro-features-ai-assist-api-runner
plan: 01
subsystem: AI Proxy & AIService
tags: [proxy, ai-service, storekit-jws, streaming]
dependency_graph:
  requires: [04-00]
  provides: [pault-proxy, ProxyConfig, StreamEvent, proxy-routed-AIService, currentTransactionJWS]
  affects: [AIService, ProStatusManager, ResponsePanel]
tech-stack: [TypeScript, Cloudflare Workers, Swift, StoreKit 2, URLSession]
key-files:
  created:
    - pault-proxy/src/index.ts
    - pault-proxy/wrangler.jsonc
    - pault-proxy/package.json
    - pault-proxy/tsconfig.json
    - Pault/Services/ProxyConfig.swift
  modified:
    - Pault/Services/AIService.swift
    - Pault/Services/ProStatusManager.swift
    - Pault/ResponsePanel.swift
    - Pault/PromptDetailView.swift
decisions:
  - "Proxy lives in pault-proxy/ subdirectory within Pault repo for development pragmatism"
  - "AIService Claude/OpenAI calls route through proxy with X-Provider/X-Storekit-JWS headers; Ollama stays direct"
  - "ProStatusManager auto-refreshes JWS token every 60s for AI call auth"
  - "ProxyConfig baseURL/enableCaching use direct UserDefaults for thread-safe access from AIService actor"
metrics:
  duration: 20min
  completed_date: "2026-04-02T23:13:09Z"
retroactive: true
---

# Phase 04 Plan 01: Cloudflare Worker Proxy & AIService Rewiring Summary

Built the Cloudflare Worker proxy service and rewired AIService to route Claude/OpenAI calls through it while keeping Ollama direct.

## Key Changes

### Cloudflare Worker Proxy (`pault-proxy/`)
- **`pault-proxy/src/index.ts`** (299 lines): Worker entry point with `/v1/complete` and `/v1/stream` routes. Implements StoreKit JWS verification (decoded payload, productId + expiresDate checks), per-subscriber rate limiting via `AI_LIMITER` binding, provider routing (Claude via `x-api-key` + `anthropic-version`, OpenAI via `Authorization: Bearer`), SSE passthrough with metadata injection (token counts + estimated cost), optional KV response caching, and content safety (500KB body limit).
- **`pault-proxy/wrangler.jsonc`**: Worker config with `RESPONSE_CACHE` KV binding and `AI_LIMITER` rate limit (30 req/min).
- **`pault-proxy/package.json`** + **`tsconfig.json`**: Minimal TypeScript project with `@cloudflare/workers-types`.

### AIService Proxy Routing
- **`Pault/Services/AIService.swift`**: `buildRequest` and `buildStreamRequest` now route Claude/OpenAI through `ProxyConfig.baseURL` with `X-Provider`, `X-Provider-Key`, `X-Storekit-JWS` headers. Ollama unchanged (localhost:11434). New error cases: `subscriptionRequired` (401), `rateLimited(retryAfter:)` (429). `streamRun` return type changed from `AsyncThrowingStream<String, Error>` to `AsyncThrowingStream<StreamEvent, Error>`. Added `lastCallMetadata: CallMetadata?` for non-streaming token/cost tracking.

### ProStatusManager JWS
- **`Pault/Services/ProStatusManager.swift`**: Added `currentTransactionJWS: String?` property populated from `Transaction.currentEntitlements` JWS representation. Added `refreshJWSIfNeeded()` with 60-second staleness check.

### ProxyConfig
- **`Pault/Services/ProxyConfig.swift`**: `baseURL` via `@AppStorage("ai.proxy.baseURL")`, `StreamEvent` enum (`.token(String)`, `.metadata(inputTokens:outputTokens:estimatedCostUSD:)`), `isConfigured` check.

## Deviations from Plan

- Documentation files (docs/) updated alongside implementation (not in plan scope, but included in commit).

## Self-Check: PASSED

- [x] pault-proxy/src/index.ts exists with JWS, rate limit, SSE passthrough
- [x] AIService routes Claude/OpenAI through proxy
- [x] Ollama stays direct to localhost:11434
- [x] ProStatusManager has currentTransactionJWS with 60s refresh
- [x] StreamEvent enum in ProxyConfig.swift
- [x] Commits 9c98e27 and 4212507 recorded
