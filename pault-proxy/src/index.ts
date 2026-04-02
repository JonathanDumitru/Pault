/**
 * Pault Proxy Service
 * 
 * A Cloudflare Worker that proxies AI requests for Pault (macOS app).
 * Handles subscription validation via StoreKit JWS, rate limiting,
 * provider routing, and metadata injection for token/cost tracking.
 */

interface Env {
  RESPONSE_CACHE: KVNamespace;
  AI_LIMITER: {
    limit: (options: { key: string }) => Promise<{ success: boolean }>;
  };
}

const PROVIDERS = {
  claude: {
    url: 'https://api.anthropic.com/v1/messages',
    version: '2023-06-01',
  },
  openai: {
    url: 'https://api.openai.com/v1/chat/completions',
  },
} as const;

// Hardcoded pricing per 1M tokens (Sonnet 3.5 and GPT-4o)
const PRICING = {
  claude: { input: 3.0, output: 15.0 },
  openai: { input: 2.5, output: 10.0 },
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // 1. Method and Path Validation
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    if (path !== '/v1/complete' && path !== '/v1/stream') {
      return new Response('Not Found', { status: 404 });
    }

    try {
      // 2. Extract Headers
      const provider = request.headers.get('X-Provider') as keyof typeof PROVIDERS;
      const providerKey = request.headers.get('X-Provider-Key');
      const storekitJWS = request.headers.get('X-Storekit-JWS');
      const streaming = request.headers.get('X-Streaming') === 'true';
      const cacheOptIn = request.headers.get('X-Cache-Opt-In') === 'true';

      if (!provider || !PROVIDERS[provider]) {
        return new Response(JSON.stringify({ error: 'invalid_provider' }), { status: 400 });
      }
      if (!providerKey) {
        return new Response(JSON.stringify({ error: 'missing_provider_key' }), { status: 400 });
      }
      if (!storekitJWS) {
        return new Response(JSON.stringify({ error: 'missing_subscription' }), { status: 401 });
      }

      // 3. StoreKit JWS Verification (Simpler version for MVP)
      const subscriberId = await verifyJWS(storekitJWS);
      if (!subscriberId) {
        return new Response(JSON.stringify({ error: 'invalid_subscription' }), { status: 401 });
      }

      // 4. Rate Limiting
      const { success } = await env.AI_LIMITER.limit({ key: subscriberId });
      if (!success) {
        return new Response(
          JSON.stringify({ error: 'rate_limit', retry_after: 60 }),
          { status: 429, headers: { 'Retry-After': '60', 'Content-Type': 'application/json' } }
        );
      }

      // 5. Body Validation & Content Safety
      const bodyText = await request.text();
      if (bodyText.length > 500 * 1024) { // 500KB limit
        return new Response(JSON.stringify({ error: 'body_too_large' }), { status: 413 });
      }

      // Basic keyword check (discretionary)
      const blocklist = ['illegal', 'malware', 'exploit']; // Example blocklist
      const lowerBody = bodyText.toLowerCase();
      if (blocklist.some(word => lowerBody.includes(word))) {
        return new Response(JSON.stringify({ error: 'content_safety_violation' }), { status: 400 });
      }

      // 6. Caching (Read)
      const cacheKey = await hashString(`${provider}:${bodyText}`);
      if (cacheOptIn && !streaming) {
        const cached = await env.RESPONSE_CACHE.get(cacheKey, 'json');
        if (cached) {
          return new Response(JSON.stringify(cached), {
            headers: { 'Content-Type': 'application/json', 'X-Cache-Hit': 'true' }
          });
        }
      }

      // 7. Provider Routing
      const upstreamHeaders = new Headers({
        'Content-Type': 'application/json',
      });

      if (provider === 'claude') {
        upstreamHeaders.set('x-api-key', providerKey);
        upstreamHeaders.set('anthropic-version', PROVIDERS.claude.version);
      } else if (provider === 'openai') {
        upstreamHeaders.set('Authorization', `Bearer ${providerKey}`);
      }

      const upstreamResponse = await fetch(PROVIDERS[provider].url, {
        method: 'POST',
        headers: upstreamHeaders,
        body: bodyText,
      });

      if (!upstreamResponse.ok) {
        return upstreamResponse;
      }

      // 8. Response Handling
      if (path === '/v1/complete') {
        const data: any = await upstreamResponse.json();
        
        // Extract token counts
        const tokens = extractTokens(provider, data);
        const cost = calculateCost(provider, tokens);

        const responseHeaders = new Headers(upstreamResponse.headers);
        responseHeaders.set('X-Input-Tokens', tokens.input.toString());
        responseHeaders.set('X-Output-Tokens', tokens.output.toString());
        responseHeaders.set('X-Estimated-Cost-USD', cost.toFixed(6));

        if (cacheOptIn) {
          await env.RESPONSE_CACHE.put(cacheKey, JSON.stringify(data), { expirationTtl: 86400 });
        }

        return new Response(JSON.stringify(data), {
          status: upstreamResponse.status,
          headers: responseHeaders,
        });
      } else {
        // Streaming path
        const { readable, writable } = new TransformStream();
        handleStream(provider, upstreamResponse.body!, writable);

        return new Response(readable, {
          headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          },
        });
      }

    } catch (err: any) {
      console.error(err);
      return new Response(JSON.stringify({ error: 'internal', message: err.message }), { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  },
};

/**
 * Basic JWS verification for StoreKit 2.
 * Decodes the payload and checks for 'pro' productId and non-expired date.
 */
async function verifyJWS(jws: string): Promise<string | null> {
  try {
    const parts = jws.split('.');
    if (parts.length !== 3) return null;

    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    
    // Check if productId includes "pro"
    const productId = payload.productId || '';
    if (!productId.toLowerCase().includes('pro')) return null;

    // Check expiration
    const expiresDate = payload.expiresDate;
    if (expiresDate && expiresDate < Date.now()) return null;

    return payload.originalTransactionId || payload.transactionId || 'unknown';
  } catch {
    return null;
  }
}

function extractTokens(provider: string, data: any) {
  if (provider === 'claude') {
    return {
      input: data.usage?.input_tokens || 0,
      output: data.usage?.output_tokens || 0,
    };
  } else {
    return {
      input: data.usage?.prompt_tokens || 0,
      output: data.usage?.completion_tokens || 0,
    };
  }
}

function calculateCost(provider: 'claude' | 'openai', tokens: { input: number; output: number }) {
  const rates = PRICING[provider];
  return (tokens.input / 1_000_000) * rates.input + (tokens.output / 1_000_000) * rates.output;
}

async function hashString(str: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(str);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

async function handleStream(provider: 'claude' | 'openai', upstreamBody: ReadableStream, writable: WritableStream) {
  const reader = upstreamBody.getReader();
  const writer = writable.getWriter();
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  let inputTokens = 0; // Estimation or from initial stream info if available
  let outputTokens = 0;
  let accumulatedText = '';

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value, { stream: true });
      const lines = chunk.split('\n');

      for (const line of lines) {
        if (!line.trim()) continue;
        
        // Pass through original SSE line
        await writer.write(encoder.encode(line + '\n'));

        // Process line for metadata estimation
        if (line.startsWith('data: ')) {
          const dataStr = line.slice(6);
          if (dataStr === '[DONE]') continue;

          try {
            const json = JSON.parse(dataStr);
            if (provider === 'claude') {
              if (json.type === 'content_block_delta') {
                accumulatedText += json.delta?.text || '';
              } else if (json.type === 'message_start') {
                inputTokens = json.message?.usage?.input_tokens || 0;
              } else if (json.type === 'message_delta') {
                outputTokens = json.usage?.output_tokens || 0;
              }
            } else {
              // OpenAI
              const content = json.choices?.[0]?.delta?.content || '';
              accumulatedText += content;
              if (json.usage) {
                inputTokens = json.usage.prompt_tokens;
                outputTokens = json.usage.completion_tokens;
              }
            }
          } catch {
            // Ignore parse errors for partial chunks
          }
        }
      }
    }

    // Heuristic for output tokens if provider didn't give usage in stream
    if (outputTokens === 0 && accumulatedText.length > 0) {
      outputTokens = Math.ceil(accumulatedText.length / 4);
    }
    if (inputTokens === 0) inputTokens = 500; // conservative fallback

    const cost = calculateCost(provider, { input: inputTokens, output: outputTokens });

    // Inject metadata event
    const metadataEvent = {
      metadata: {
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        estimated_cost_usd: cost
      }
    };
    await writer.write(encoder.encode(`data: ${JSON.stringify(metadataEvent)}\n\n`));
    await writer.write(encoder.encode('data: [DONE]\n\n'));

  } finally {
    reader.releaseLock();
    writer.close();
  }
}
