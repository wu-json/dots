/**
 * Ollama provider extension
 *
 * Mirrors the opencode `ollama` / `ollama-tailnet` providers. Registers two
 * OpenAI-compatible providers pointing at:
 *   - localhost Ollama
 *   - mac-studio over Tailscale
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
		id: "qwen3.6:35b",
		name: "Qwen3.6 35B",
		// Qwen3 ships with 32k native context; bump if you've enabled YaRN.
		contextWindow: 32768,
		maxTokens: 4096,
		reasoning: true,
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
		compat: {
			// Qwen-compatible local servers (Ollama, llama.cpp) read the
			// thinking toggle from chat_template_kwargs.enable_thinking.
			thinkingFormat: "qwen-chat-template" as const,
		},
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
}
