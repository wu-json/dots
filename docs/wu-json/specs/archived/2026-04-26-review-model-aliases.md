---
status: implemented
---

# Short Model Aliases for review / review_auto

**Date:** 2026-04-26
**Author:** Jason Wu
**Status:** Implemented

## Problem

The `review` and `review_auto` fish functions accept `--model PATTERN` with the full provider/model string (e.g. `anthropic/claude-opus-4-7` or `ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8`). You currently switch between:

- `anthropic/claude-opus-4-7` (Opus 4.7)
- `ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8` (Qwen 3.6 on tailnet)

Typed repeatedly — `review --model ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8` — this is tedious.

## Goal

Allow short, memorable aliases for model providers so common models can be invoked with minimal typing:

```fish
review --model opus            # → anthropic/claude-opus-4-7
review --model qwen            # → ollama-tailnet/qwen3.6:...
review --model opus --agents 3       # aliases work with any other flags
```

## Design

### 1. Colocated alias definitions & resolver

Aliases are defined inside both `review.fish` and `review_auto.fish` using a `switch` statement. This is the most reliable approach in fish since indirect variable expansion (`$$`) works correctly in bash but not cleanly in fish (fish uses `$$` for PID). A switch is simple, explicit, and self-documenting.

Each function gets this right after argument parsing, before the model is used:

```fish
switch $model_override
    case ''
        # Empty — no alias resolution needed, skip to assignment below
    case opus
        set model_override "anthropic/claude-opus-4-7"
    case qwen
        set model_override "ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8"
    case '*'
        # Not a recognized alias — check if it's a full provider string (contains '/')
        if not string match -q '*/*' -- $model_override
            echo "Unknown model alias: '$model_override'" >&2
            echo "Full provider strings (containing '/') are passed through as-is." >&2
            echo "Available aliases: opus, qwen" >&2
            return 1
        end
        # Full provider string — no conversion needed; fall through
end

# Assign the resolved (or pass-through) value to model
if test -n "$model_override"
    set model $model_override
end
```

### 2. Help output update

In the `--help` block of both functions, add an **Aliases** section showing the actual provider strings:

```fish
echo "Aliases:"
echo "   opus         → anthropic/claude-opus-4-7"
echo "   qwen         → ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8"
echo "   Full provider strings (e.g. openai/gpt-5.5-high) are passed through as-is."
```

### 3. Charset guard (unchanged)

The existing charset guard regex (`'^[A-Za-z0-9._/:-]+$'`) continues to validate `--model` values before alias resolution happens. It accepts both aliases and full provider strings. No change needed here.

## Non-goals

- Dynamic provider/model discovery (no auto-scanning of installed providers).
- Changing the default model (still `anthropic/claude-opus-4-7`).
- Per-user configurable aliases (e.g. via `config.local.fish`). Colocated aliases are hardcoded in the functions, which limits extensibility but keeps things simple and in one place. This tradeoff is accepted because adding 2–3 common aliases rarely needs extension.

## Scope-out decision

- **Fuzzy/partial matching** (e.g. `opus-4` → `opus`): scoped out. Exact match is fast, unambiguous, and avoids ambiguity (what about `opus4`? `opus-4`?). Can revisit later if needed.

## Implementation steps

1. Add the alias `switch` block into both `review.fish` and `review_auto.fish` right after `model_override` is set (keeping the existing `if test -n` assignment block).
2. Update the `--help` output in both functions with the Aliases section showing actual provider strings.
3. Test:
    - `review --model opus` → uses Claude Opus 4.7
    - `review --model qwen` → uses Qwen 3.6 on tailnet
    - `review --model anthropic/claude-opus-4-7` → passes through (no change)
    - `review --model nonexist` → errors with helpful message
    - `review --model opus --agents 3` → alias + other flags work together
    - `review` (no flag) → default model still works

## Open questions

- None — the design is straightforward and the switch approach avoids fish's indirect variable pitfalls.
