/**
 * Websearch tool via Exa AI's public MCP endpoint.
 *
 * Registers a `websearch` tool that wraps Exa's hosted MCP server at
 * https://mcp.exa.ai/mcp. The endpoint works unauthenticated for the free
 * tier; if EXA_API_KEY is set it's appended for paid-tier limits (matches
 * opencode's behavior in packages/opencode/src/tool/mcp-exa.ts).
 *
 * See docs/wu-json/specs/archived/2026-04-26-pi-agent-websearch-exa.md
 */

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
				headers: {
					accept: "application/json, text/event-stream",
					"content-type": "application/json",
				},
				body: JSON.stringify({
					jsonrpc: "2.0",
					id: 1,
					method: "tools/call",
					params: { name: "web_search_exa", arguments: { query, numResults } },
				}),
				signal: signal
					? AbortSignal.any([signal, AbortSignal.timeout(25_000)])
					: AbortSignal.timeout(25_000),
			});
			if (!res.ok) throw new Error(`Exa MCP HTTP ${res.status}`);
			for (const line of (await res.text()).split("\n")) {
				if (!line.startsWith("data: ")) continue;
				let parsed: any;
				try {
					parsed = JSON.parse(line.slice(6));
				} catch {
					continue;
				}
				if (parsed?.error) {
					throw new Error(parsed.error.message ?? "Exa MCP error");
				}
				const text = parsed?.result?.content?.[0]?.text;
				if (text) return { content: [{ type: "text", text }], details: {} };
			}
			return { content: [{ type: "text", text: "No results." }], details: {} };
		},
	});
}
