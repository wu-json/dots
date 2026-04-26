---
status: ready
---

# pi-agent websearch extension via public Exa MCP

**Date:** 2026-04-26
**Author:** Jason Wu
**Status:** Ready

## Problem

Pi ships with seven file/shell tools and no way to talk to the
internet. For "what's the latest X" style questions the only
escape hatch today is `bash → curl | head`, which burns tokens on
HTML boilerplate and can't do *search* at all.

Opencode already solved this with a thin wrapper over Exa AI's
hosted MCP at `https://mcp.exa.ai/mcp`. That endpoint answers
without authentication — verified live on 2026-04-26, `tools/call`
with `name: "web_search_exa"` returns real results from the free
tier. Pi has a first-class extension API; a ~40 LOC extension is
all we need.

## Goals

- One new file `pi/.pi/agent/extensions/websearch-exa.ts`, stowed
  to `~/.pi/agent/extensions/websearch-exa.ts` beside the existing
  `ollama-providers.ts`.
- Registers a `websearch` tool. Zero mandatory config — works on a
  fresh machine with no env vars.
- Optional `EXA_API_KEY`: appended as `?exaApiKey=…` for paid-tier
  limits (matches opencode's behavior).
- Args: `query: string`, `numResults?: number` (1–10, default 8).
- 25 s timeout, honors caller-provided `AbortSignal` so Ctrl-C
  cancels in-flight requests.

## Non-goals

- No `webfetch` companion. `bash → curl` already works when I have
  a URL; search is the gap.
- No custom `renderCall` / `renderResult`. Pi's default rendering
  is fine for v1.
- No caching, no retries, no client-side rate limiting. Dumb HTTP
  client; let Exa handle its own throttling.
- No `livecrawl` / `type` / `contextMaxCharacters`. The public Exa
  schema rejects them (`additionalProperties: false`); opencode
  sends them anyway. Shipping params Exa's documented schema
  forbids is asking for future breakage.
- No `settings.json` knob to disable. If I don't want it, I delete
  the file.
- No pi-mono fork. The extension API exists for exactly this.

## Design

One file: `pi/.pi/agent/extensions/websearch-exa.ts`. Default export
is `(pi: ExtensionAPI) => void`; calls `pi.registerTool(...)` once.

```ts
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "typebox";

const MCP_URL = process.env.EXA_API_KEY
  ? `https://mcp.exa.ai/mcp?exaApiKey=${encodeURIComponent(process.env.EXA_API_KEY)}`
  : "https://mcp.exa.ai/mcp";

const schema = Type.Object({
  query: Type.String({ description: "Natural-language search query" }),
  numResults: Type.Optional(Type.Number({ minimum: 1, maximum: 10 })),
});

export default function (pi: ExtensionAPI) {
  const year = new Date().getFullYear();
  pi.registerTool({
    name: "websearch",
    label: "websearch",
    description:
      `Search the web using Exa AI. Returns titles, URLs, publish dates, and highlights. ` +
      `The current year is ${year}; prefer queries with an explicit year for recent information.`,
    promptSnippet: "Search the web with Exa",
    parameters: schema,
    async execute(_id, { query, numResults = 8 }, signal) {
      const res = await fetch(MCP_URL, {
        method: "POST",
        headers: { accept: "application/json, text/event-stream", "content-type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          id: 1,
          method: "tools/call",
          params: { name: "web_search_exa", arguments: { query, numResults } },
        }),
        signal: signal ? AbortSignal.any([signal, AbortSignal.timeout(25_000)]) : AbortSignal.timeout(25_000),
      });
      if (!res.ok) throw new Error(`Exa MCP HTTP ${res.status}`);
      for (const line of (await res.text()).split("\n")) {
        if (!line.startsWith("data: ")) continue;
        const text = JSON.parse(line.slice(6))?.result?.content?.[0]?.text;
        if (text) return { content: [{ type: "text", text }], details: {} };
      }
      return { content: [{ type: "text", text: "No results." }], details: {} };
    },
  });
}
```

Notes on the few non-obvious bits:

- **Throw on failure, don't encode errors in `content`.** Pi's
  contract (`packages/agent/src/types.ts:316`): *"Throw on failure
  instead of encoding errors in `content`."* `AgentToolResult` has
  no `isError` field — the runtime adds it when it catches the
  throw. See `examples/extensions/truncated-tool.ts:80`.
- **`details: {}`** is required, not optional. Empty object is fine.
- **Year is inlined, not templated.** Opencode uses `{{year}}` +
  `.replaceAll(...)` because its description lives in a `.txt`
  file; a template string here is simpler.

### Output size

Pi's docs say custom tools MUST truncate (50 KB / 2000-line
ceiling, per `truncated-tool.ts:4-5`). A measured Exa response at
`numResults: 8` was 12.4 KB / 278 lines, well under both. **No
truncation.** If that ever changes, `truncateHead` from
`@mariozechner/pi-coding-agent` is a two-line addition.

### Tool name and `--tools`

`websearch`, lower-case, one word — matches pi's built-ins
(`read`, `bash`, …) and opencode's name. Slots into pi's
`--tools a,b,c` allowlist with no changes needed. Concrete
implication: `review_auto` reviewers keep their existing
`read,grep,find,ls,bash` allowlist — this extension does not
change their tool set (see archived review_auto spec's
tool-surface-area argument).

### Diff scope

- `pi/.pi/agent/extensions/websearch-exa.ts` — new, ~35 LOC.
- `docs/wu-json/specs/2026-04-26-pi-agent-websearch-exa.md` — this
  spec, moves to `archived/` after rip.

## Verification

Manual, TUI-observed:

1. `stow pi`, restart pi. No extension-load errors on startup.
2. Ask pi "search for the latest Claude Opus release" — `websearch`
   tool call fires, results come back.
3. `pi --tools read,websearch -p "..."` — allowlist mode works,
   bash is excluded.
4. Query for "latest TypeScript" — the `query` arg should include
   the current year (confirms the template-string year is live).
5. Ctrl-C mid-call — aborts cleanly, pi returns to prompt.
6. Set `EXA_API_KEY`, re-run; confirm the URL includes
   `?exaApiKey=…` (eyeball a `curl` side-by-side or add a temp
   `console.error` during implementation).

## Considered alternatives

- **Generic MCP-client extension.** Useful once I have a second
  MCP target; premature now. One hardcoded endpoint is fine until
  duplication exists.
- **Require `EXA_API_KEY`.** Rejected — zero-config is the point.
  Matches `ollama-providers.ts`, which also hardcodes a throwaway
  `apiKey: "ollama"`.
- **`bash → curl` snippets instead of a tool.** Rejected — the
  description nudging the model's query style is half the value,
  and can't be carried in a shell snippet.
- **Include `livecrawl`/`type`/`contextMaxCharacters` "to match
  opencode".** Rejected — Exa's public schema rejects them.

## Deferred

- `webfetch-exa.ts` companion if search highlights prove
  insufficient.
- Custom `renderResult` for prettier TUI output.
