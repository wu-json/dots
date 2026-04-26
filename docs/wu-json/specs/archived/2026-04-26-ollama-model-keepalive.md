---
status: implemented
---
# Ollama Model Keep-Alive Configuration

## Goal
Inject `keep_alive` with a **1-hour** window into every ollama request payload, keeping both local and remote mac-studio Ollama models loaded instead of unloading after the default 5 minutes. This avoids cold-start latency during agentic pauses.

## Current State
- Ollama daemon (both local and on mac-studio) defaults to unloading models after **5 minutes** of inactivity.
- The Pi coding agent registers `ollama-local` and `ollama-tailnet` as OpenAI-compatible providers.
- When the Pi agent pauses for more than 5 minutes, the model unloads on whichever Ollama instance is being used.
- Cold-start latency (re-downloading weights) breaks context continuity and slows down iterative agent loops.

## Target State
- Every ollama request includes `"keep_alive": "1h"`.
- Both local and remote mac-studio Ollama retain the model in VRAM/RAM for 1 hour after the last request.
- No impact on model unloading behavior outside the 1-hour window.

## Implementation Plan

### 1. Why Request Parameter vs. Server-Side Env Var?
Ollama supports a `keep_alive` field in the `/api/chat` and `/api/generate` endpoints. Crucially, it is **also supported** in the OpenAI-compatible API (`/v1/chat/completions`).

Setting an environment variable (`OLLAMA_KEEP_ALIVE`) locally works, but is awkward to configure remotely on mac-studio and applies globally to all connections regardless of user intent. By setting it in the **client request payload**, we ensure it applies specifically for the Pi agent's session.

### 2. Configuration Change
Use the `before_provider_request` extension event to intercept ollama LLM requests and append `keep_alive: "1h"` to the JSON request body before it's sent. Applied to all ollama requests — both local and tailnet — since we identify them by matching on the model ID pattern.

### 3. Where to Apply

In `pi/.pi/agent/extensions/ollama-providers.ts`:

1. Subscribe to the `before_provider_request` event via `pi.on("before_provider_request", ...)`.
2. In the handler, match on the ollama model ID in the payload:

```ts
pi.on("before_provider_request", (event) => {
     // Match on the ollama model ID pattern (covers both local and tailnet)
    const p = event.payload as Record<string, unknown> | undefined;
    if (p?.model?.toString().includes("qwen3.6:35b-a3b-coding-mxfp8")) {
         // Return a new payload object with keep_alive appended. We deliberately
         // avoid mutating `event.payload` in place: the runner currently threads
         // the same reference, but `emitContext` already structuredClones its
         // payload, and `emitBeforeProviderRequest` could be refactored to do
         // the same — at which point an in-place mutation would silently drop.
        return { ...(p as object), keep_alive: "1h" };
    }
     // Return undefined / the original payload to pass through unmodified.
    return event.payload;
});
```

**Why model ID pattern matching:**
- `before_provider_request` fires for **every** provider request, and the event payload (`BeforeProviderRequestEvent`) only exposes `type` and `payload` — there's no `provider` or `baseUrl` field.
- Matching on `model` (which contains `qwen3.6:35b-a3b-coding-mxfp8`) reliably identifies ollama requests without needing separate model registrations or a provider-identifying event field.
- This applies `keep_alive` to both `ollama-local` and `ollama-tailnet` in one handler, which is desirable since Ollama keeps models in VRAM cheaply and both benefit from faster cold starts.

### 4. Verification
- Use the Pi agent for a task.
- After the agent finishes, wait > 6 minutes.
- From a terminal, run:
    ```bash
    ollama ps
    ```
- Confirm that the model `qwen3.6:35b-a3b-coding-mxfp8` is still "loaded" and the time elapsed indicates it survived > 5 minutes.

### 5. Trade-offs
- **Pros**: Client-side config. No remote server configuration needed. Works reliably across server reboots and config changes. Applies to both local and remote ollama.
- **Cons**: Ensures ollama models are held in memory for 1 hour. A 35B model takes ~20GB VRAM/RAM — acceptable on a Mac with unified memory, but could be reduced if needed (e.g., `"30m"` or `"30m"`).

## Out of Scope
- Changing model loading/unloading logic on the server side.
- Adjusting `contextWindow` or `maxTokens`.
- Configuring GPU offloading or model quantization.

## Notes
- `keep_alive` values in Ollama use Go duration format (e.g., `"1h"`, `"30m"`, `"3600s"`).
- The `before_provider_request` event type only exposes `type` and `payload` fields — no `provider` or `baseUrl`. Model ID pattern matching is the reliable signal for ollama requests.
- `keep_alive` is an unknown field to non-ollama providers (OpenAI, Anthropic, etc.) and will be silently ignored — safe to attach to all requests, but matching on the ollama model ID keeps the intent explicit and avoids any chance of a strict API rejecting unknown fields.
- The handler returns a shallow-copied payload rather than mutating `event.payload` in place. This keeps the extension correct even if the pi runner ever switches `emitBeforeProviderRequest` to clone its payload (as `emitContext` already does), at which point an in-place mutation would be silently dropped.
