/**
 * Ollama provider extension
 *
 * Registers two OpenAI-compatible providers:
 *    - `ollama`         → localhost (small models)
 *    - `ollama-tailnet` → "ollama" tailnet node (heavy models)
 *
 * Pi auto-discovers this from ~/.pi/agent/extensions/. `/login` is not
 * needed — Ollama doesn't authenticate, but pi requires *some* apiKey on
 * the provider config, so we pass a literal placeholder.
 *
 * Models are discovered dynamically from each host's `/api/tags` (filtered
 * to tool-capable models, since the agent needs tool calling) and cached in
 * ~/.cache/pi/ollama-models.json. Startup never touches the network: the
 * cached list (or the hardcoded seeds below, when a host has never been
 * reachable) registers immediately, then a background refresh re-registers
 * the provider and updates the cache.
 */

import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface LocalModel {
	id: string;
	name: string;
	contextWindow: number;
	maxTokens: number;
	reasoning: boolean;
	vision?: boolean;
}

interface OllamaHost {
	provider: string;
	baseUrl: string;
	timeoutMs: number;
	fallback: LocalModel[];
}

const HOSTS: OllamaHost[] = [
	{
		provider: "ollama",
		baseUrl: "http://localhost:11434",
		timeoutMs: 2000,
		fallback: [
			{
				id: "qwen3.5:9b-mlx",
				name: "Qwen 3.5 9B",
				contextWindow: 128000,
				maxTokens: 4096,
				reasoning: true,
			},
		],
	},
	// Heavy models served by whichever host runs `ollama_tailnet up`, which
	// starts a tailscale sidecar container that joins the tailnet as the
	// "ollama" node and proxies ollama.<tailnet>.ts.net to the host's Ollama.
	{
		provider: "ollama-tailnet",
		baseUrl: "https://ollama.tailf2675.ts.net",
		timeoutMs: 3000,
		fallback: [
			{
				id: "qwen3.8:27b-mlx",
				name: "Qwen3.8 27B (mlx)",
				contextWindow: 256000,
				maxTokens: 4096,
				reasoning: true,
			},
		],
	},
];

const CACHE_FILE = path.join(homedir(), ".cache", "pi", "ollama-models.json");
const DEFAULT_CONTEXT_WINDOW = 128000;
const DEFAULT_MAX_TOKENS = 4096;

interface CacheEntry {
	fetchedAt: string;
	models: LocalModel[];
}

type Cache = Record<string, CacheEntry>;

function readCache(): Cache {
	try {
		return JSON.parse(readFileSync(CACHE_FILE, "utf8")) as Cache;
	} catch {
		return {};
	}
}

function writeCache(provider: string, models: LocalModel[]) {
	try {
		const cache = readCache();
		cache[provider] = { fetchedAt: new Date().toISOString(), models };
		mkdirSync(path.dirname(CACHE_FILE), { recursive: true });
		writeFileSync(CACHE_FILE, JSON.stringify(cache, null, "\t"));
	} catch {
		// Cache is best-effort; discovery still worked.
	}
}

interface TagModel {
	model: string;
	capabilities?: string[];
	details?: { context_length?: number };
}

async function discoverModels(host: OllamaHost): Promise<LocalModel[]> {
	const res = await fetch(`${host.baseUrl}/api/tags`, {
		signal: AbortSignal.timeout(host.timeoutMs),
	});
	if (!res.ok) throw new Error(`${host.baseUrl}/api/tags: HTTP ${res.status}`);
	const tags = (await res.json()) as { models?: TagModel[] };
	// Agent use requires tool calling, so skip models without it (OCR/vision-only
	// models, embedders, etc.).
	const usable = (tags.models ?? []).filter((m) => m.capabilities?.includes("tools"));

	return Promise.all(
		usable.map(async (m) => {
			const caps = m.capabilities ?? [];
			let contextWindow = m.details?.context_length;
			if (!contextWindow) {
				// mlx/safetensors models don't report context_length in /api/tags;
				// /api/show has it under model_info["<arch>.context_length"].
				try {
					const show = await fetch(`${host.baseUrl}/api/show`, {
						method: "POST",
						body: JSON.stringify({ model: m.model }),
						signal: AbortSignal.timeout(host.timeoutMs),
					});
					const info = ((await show.json()) as { model_info?: Record<string, unknown> }).model_info ?? {};
					const key = Object.keys(info).find((k) => k.endsWith(".context_length"));
					if (key && typeof info[key] === "number") contextWindow = info[key] as number;
				} catch {
					// Fall through to the default below.
				}
			}
			return {
				id: m.model,
				name: m.model,
				contextWindow: contextWindow ?? DEFAULT_CONTEXT_WINDOW,
				maxTokens: DEFAULT_MAX_TOKENS,
				reasoning: caps.includes("thinking"),
				vision: caps.includes("vision"),
			};
		}),
	);
}

function buildModelConfig(m: LocalModel) {
	return {
		id: m.id,
		name: m.name,
		reasoning: m.reasoning,
		input: (m.vision ? ["text", "image"] : ["text"]) as ("text" | "image")[],
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		contextWindow: m.contextWindow,
		maxTokens: m.maxTokens,
		// Only Qwen-compatible local servers (Ollama, llama.cpp) read the
		// thinking toggle from chat_template_kwargs.enable_thinking, so only
		// claim the format for qwen models even when others report a
		// "thinking" capability.
		...(m.reasoning && /^qwen/i.test(m.id)
			? { compat: { thinkingFormat: "qwen-chat-template" as const } }
			: {}),
	};
}

export default async function (pi: ExtensionAPI) {
	// Every model id ever registered this session, for the keep_alive hook.
	// Ids from models that disappear on refresh linger here; that only means a
	// harmless keep_alive field on a request that would fail anyway.
	const ollamaModelIds = new Set<string>();

	const register = (host: OllamaHost, models: LocalModel[]) => {
		for (const m of models) ollamaModelIds.add(m.id);
		pi.registerProvider(host.provider, {
			baseUrl: `${host.baseUrl}/v1`,
			apiKey: "ollama",
			api: "openai-completions",
			models: models.map(buildModelConfig),
		});
	};

	const refresh = async (host: OllamaHost) => {
		const models = await discoverModels(host);
		if (models.length === 0) throw new Error(`${host.provider}: no tool-capable models`);
		register(host, models);
		writeCache(host.provider, models);
	};

	// Never block startup on the network: register from cache (or the fallback
	// seeds) synchronously, then refresh in the background — pi applies
	// re-registered providers immediately, so a fresh list lands mid-session.
	const cache = readCache();
	for (const host of HOSTS) {
		const cached = cache[host.provider];
		register(host, cached?.models?.length ? cached.models : host.fallback);
		void refresh(host).catch(() => {});
	}

	// Inject keep_alive: "1h" into all ollama requests so that the Ollama server
	// keeps loaded models for 1 hour instead of unloading after the
	// default 5 minutes. This avoids cold-start lag when the agent pauses between
	// agentic turns.
	// See docs/wu-json/specs/archived/2026-04-26-ollama-model-keepalive.md
	pi.on("before_provider_request", (event) => {
		const p = event.payload as Record<string, unknown> | undefined;
		const modelId = p?.model?.toString() ?? "";
		if (ollamaModelIds.has(modelId)) {
			// Return a new object instead of mutating in place: the runner currently
			// threads the same reference, but `emitContext` already structuredClones
			// its payload, and `emitBeforeProviderRequest` could be refactored to do
			// the same — at which point an in-place mutation would silently drop.
			return { ...(p as object), keep_alive: "1h" };
		}
		return event.payload;
	});
}
