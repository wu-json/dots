/**
 * Ollama provider extension
 *
 * Mirrors the opencode `ollama` / `ollama-tailnet` providers. Registers two
 * OpenAI-compatible providers pointing at:
 *    - localhost Ollama
 *    - mac-studio over Tailscale
 *
 * Pi auto-discovers this from ~/.pi/agent/extensions/. Use `/login` is not
 * needed — Ollama doesn't authenticate, but pi requires *some* apiKey on
 * the provider config, so we pass a literal placeholder.
 *
 * Edit the `MODELS` list below to add more local models.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface LocalModel {
	id: string;
	name: string;
	contextWindow: number;
	maxTokens: number;
	reasoning: boolean;
}

// Models served by the Ollama hosts below. Pi expects the model id to match
// what the OpenAI-compatible endpoint returns (e.g. `ollama list`).
const MODELS: LocalModel[] = [
	{
		id: "qwen3.6:35b-a3b-coding-mxfp8",
		name: "Qwen3.6 35B A3B Coding (mxfp8)",
		// Qwen3 ships with 32k native context; bumped to 256k for pi agent's extended context needs.
		contextWindow: 256000,
		maxTokens: 4096,
		reasoning: true,
	},
	{
		id: "qwen3.6:27b-coding-mxfp8",
		name: "Qwen3.6 27B Coding (mxfp8)",
		contextWindow: 256000,
		maxTokens: 4096,
		reasoning: true,
	},
	{
		id: "gemma4:26b",
		name: "Gemma 4 26B",
		// Gemma 4 ships with a smaller native context; bumped to 256k for pi agent's extended context needs.
		contextWindow: 256000,
		maxTokens: 4096,
		// Gemma is not a reasoning/thinking model.
		reasoning: false,
	},
];

function buildModelConfig(m: LocalModel) {
	return {
		id: m.id,
		name: m.name,
		reasoning: m.reasoning,
		input: ["text"] as ("text" | "image")[],
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		contextWindow: m.contextWindow,
		maxTokens: m.maxTokens,
		// Only Qwen-compatible local servers (Ollama, llama.cpp) read the
		// thinking toggle from chat_template_kwargs.enable_thinking. Gemma
		// has no thinking mode, so don't claim a thinking format for it.
		...(m.reasoning
			? { compat: { thinkingFormat: "qwen-chat-template" as const } }
			: {}),
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerProvider("ollama-local", {
		baseUrl: "http://localhost:11434/v1",
		// Ollama ignores the key, but pi requires one. Literal value, not env var.
		apiKey: "ollama",
		api: "openai-completions",
		models: MODELS.map(buildModelConfig),
	});

	pi.registerProvider("ollama-tailnet", {
		baseUrl: "https://mac-studio.tailf2675.ts.net:11434/v1",
		apiKey: "ollama",
		api: "openai-completions",
		models: MODELS.map(buildModelConfig),
	});

	// Inject keep_alive: "1h" into all ollama requests so that the local or remote
	// Ollama server keeps loaded models for 1 hour instead of unloading after the
	// default 5 minutes. This avoids cold-start lag when the agent pauses between
	// agentic turns.
	// See docs/wu-json/specs/archived/2026-04-26-ollama-model-keepalive.md
	pi.on("before_provider_request", (event) => {
		const p = event.payload as Record<string, unknown> | undefined;
		const modelId = p?.model?.toString() ?? "";
		const isOllamaModel =
			modelId.includes("qwen3.6:35b-a3b-coding-mxfp8") ||
			modelId.includes("qwen3.6:27b-coding-mxfp8") ||
			modelId.includes("gemma4:26b");
		if (isOllamaModel) {
			// Return a new object instead of mutating in place: the runner currently
			// threads the same reference, but `emitContext` already structuredClones
			// its payload, and `emitBeforeProviderRequest` could be refactored to do
			// the same — at which point an in-place mutation would silently drop.
			return { ...(p as object), keep_alive: "1h" };
		}
		return event.payload;
	});
}
