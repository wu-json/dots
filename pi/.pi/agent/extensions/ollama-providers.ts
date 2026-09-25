import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

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
	const usable = (tags.models ?? []).filter((m) => m.capabilities?.includes("tools"));

	return Promise.all(
		usable.map(async (m) => {
			const caps = m.capabilities ?? [];
			let contextWindow = m.details?.context_length;
			if (!contextWindow) {
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
		...(m.reasoning && /^qwen/i.test(m.id)
			? { compat: { thinkingFormat: "qwen-chat-template" as const } }
			: {}),
	};
}

export default async function (pi: ExtensionAPI) {
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

	const cache = readCache();
	for (const host of HOSTS) {
		const cached = cache[host.provider];
		register(host, cached?.models?.length ? cached.models : host.fallback);
		void refresh(host).catch(() => {});
	}

	pi.on("before_provider_request", (event) => {
		const p = event.payload as Record<string, unknown> | undefined;
		const modelId = p?.model?.toString() ?? "";
		if (ollamaModelIds.has(modelId)) {
			return { ...(p as object), keep_alive: "1h" };
		}
		return event.payload;
	});
}
