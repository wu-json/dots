---
status: ready
---

# Ollama-Powered `git add . && git commit` Fish Function

**Date:** 2026-05-09
**Author:** Jason Wu
**Status:** Ready

## Problem

Current workflow for tiny dotfile/agent commits is:

```fish
git add .
git commit -m "feat: brewfile updates"
```

The commit subject is almost always derived directly from the diff (`feat: <thing>`, `fix: <thing>`, `chore: <thing>`). Typing it manually every time is friction, and `git log` shows the current pattern is short conventional-commit subjects (`feat: pi`, `fix: kimi`, `feat: lazy lock`, `chore: remove cursor-cli from brew and dotfiles`).

A small local LLM is more than capable of producing this kind of one-liner from the staged diff.

## Goal

A fish function (with a short alias) that:

1. Stages all working-tree changes (`git add -A`).
2. Sends the staged diff + recent log to a local ollama model.
3. Receives back a single conventional-commit subject line.
4. Shows it, lets the user accept / regenerate / edit / abort.
5. On accept, runs `git commit -m "<message>"`.

Default model: `gemma4:e2b` (already pulled on this machine, ~7.2 GB, plenty for one-line subjects).

Privacy: prompt + diff are sent only to the local ollama daemon. No data leaves the machine.

## Non-goals

- Multi-line commit bodies. Recent history shows only one-line subjects; generating bodies is out of scope.
- Pre-commit hook integration / replacing `git commit` globally.
- Anything that makes a *network* call to a hosted LLM. Local ollama only (the host is configurable for tailnet ollama, but that's still a LAN call, not a public API).
- Picking the right files to stage. Mirrors current habit of `git add .`; partial staging falls back to `git` directly.
- Editing existing commits / amends.
- Auto-installing ollama or auto-pulling the model. The function fails fast with a clear suggestion instead.

## Decisions

These were open questions in the draft; closing them now.

- **Alias**: `gc` — short, mnemonic ("git commit"), not currently bound in `config.fish`.
- **Default behavior**: prompt for confirmation. `-y` opts into zero-prompt commit. Bad commit messages are cheap to amend but annoying to discover after a push; the prompt is one keystroke (`Y`/`Enter`).
- **Model**: `gemma4:e2b`. Override via `--model` or `AI_COMMIT_MODEL`.
- **Confirm read style**: line-based (`read -P`) to match `review.fish` and avoid surprising single-keypress behavior in vi mode.

## Design

### 1. Function & alias

New function: `fish/.config/fish/functions/ai_commit.fish`

Alias added in `fish/.config/fish/config.fish` next to the existing git block (`ghc`, `gho`):

```fish
# AI commit
alias gc="ai_commit"
```

### 2. Flags & env

```
ai_commit [-y|--yes] [-m|--model MODEL] [-n|--no-add] [-h|--help]
```

| Flag | Behavior |
|------|----------|
| `-y`, `--yes` | Skip the accept/regenerate/edit/abort prompt and commit directly. |
| `-m`, `--model MODEL` | Override the ollama model (default `gemma4:e2b`). Validated against `^[A-Za-z0-9._/:-]+$` (same charset guard as `review.fish`). |
| `-n`, `--no-add` | Skip `git add -A`; commit only what is already staged. |
| `-h`, `--help` | Help text. |

Use fish's `argparse` builtin (cleaner than the manual loop in `review.fish` since this function only takes flags, no positional args):

```fish
argparse -n ai_commit 'y/yes' 'm/model=' 'n/no-add' 'h/help' -- $argv
or return
```

Env overrides (read only when the matching flag is *not* passed):

| Env var | Default | Purpose |
|---------|---------|---------|
| `AI_COMMIT_MODEL` | `gemma4:e2b` | Default model. Lets `config.local.fish` set per-machine defaults (e.g. a heavier model on a tailnet). |
| `AI_COMMIT_OLLAMA_HOST` | `http://127.0.0.1:11434` | Ollama daemon URL. Lets users point at the mac-studio tailnet ollama if desired. |

### 3. Pipeline

```
1. Parse flags via argparse.
2. Verify we are inside a git work tree:   git rev-parse --is-inside-work-tree
3. Preflight ollama daemon (see §6.A).
4. Preflight target model is pulled (see §6.B).
5. (unless --no-add) git add -A
6. Capture staged diff:                    git diff --staged
   - If empty → "Nothing to commit." return 0.
7. Capture context for the prompt:
   - git status --short
   - git log -10 --pretty=format:"%s"   (style cues)
8. Build prompt (see §4) and POST to /api/generate.
9. Sanitize + validate model output (see §5).
10. If -y: git commit -m "<msg>"
    else loop on prompt: [Y]es / [r]egenerate / [e]dit / [n]o
        - Y or empty input → commit
        - r              → re-call the model (back to step 8)
        - e              → open $EDITOR with msg pre-filled, commit edited result
        - n              → abort, leave index staged so user can commit manually
```

### 4. Prompt to the model

Send via `curl` to `$AI_COMMIT_OLLAMA_HOST/api/generate` with `stream: false` so we get a single JSON response and can `jq -r .response` it cleanly.

```
You are generating a one-line git commit subject for a personal dotfiles repo.

Rules:
- Conventional commits format: "<type>: <subject>" where type ∈ feat, fix, chore, docs, refactor, test, style, build, ci, perf, revert.
- Lowercase subject, imperative mood, no trailing period.
- 72 characters max, ideally under 50.
- Output ONLY the subject line. No prose, no quotes, no code fences, no leading "-".

Recent commit subjects (style reference):
{git log -10 --pretty=format:"%s"}

Files changed:
{git status --short}

Staged diff (truncated to 30000 bytes):
{git diff --staged | head -c 30000}
```

`head -c 30000` is a hard byte cap (not token-aware) — simple, and large enough for typical dotfile commits while protecting against lockfile/binary-blob blowups. Cutting mid-line is acceptable; the model only needs the gist for a one-liner.

Request body shape:

```json
{
  "model": "gemma4:e2b",
  "prompt": "...",
  "stream": false,
  "keep_alive": "1h",
  "options": { "temperature": 0.2, "num_predict": 64 }
}
```

- `keep_alive: "1h"` mirrors `2026-04-26-ollama-model-keepalive.md` so consecutive `gc` calls stay warm.
- `temperature: 0.2` for stable, short output.
- `num_predict: 64` is enough for one subject line and prevents the model from rambling on a body even if it ignores the prompt rules.

Curl invocation pattern:

```fish
set -l body (jq -nc \
    --arg model $model \
    --arg prompt $prompt \
    '{model:$model, prompt:$prompt, stream:false, keep_alive:"1h",
      options:{temperature:0.2, num_predict:64}}')

set -l raw (curl -fsS -X POST "$ollama_host/api/generate" \
    -H 'Content-Type: application/json' \
    -d $body | jq -r '.response')
```

Building JSON with `jq -n` (not string interpolation) is required — the prompt contains diff hunks with backslashes, quotes, and newlines that would otherwise need manual escaping.

### 5. Output sanitization & validation

Models often add fluff even when told not to. Apply, in order:

1. `string trim` whitespace.
2. Drop surrounding triple-backtick fences if present.
3. Drop leading `- `, `* `, or `> ` (common list/quote markers).
4. Drop surrounding straight or smart quotes.
5. Take only the **first non-empty line**.
6. Truncate to 100 chars as a hard ceiling.
7. **Validate** against the conventional-commit regex:
   `^(feat|fix|chore|docs|refactor|test|style|build|ci|perf|revert)(\([\w\-]+\))?!?: .+`
   - On match → use the message.
   - On mismatch → print the raw response (pre-sanitization) and the sanitized line, leave the index staged, return 1. The user can `git commit` manually or rerun `gc`.

Never auto-commit a fallback string like `chore: update`. Silent fallbacks would let bad messages slip through unnoticed.

### 6. Error handling — preflight checks

These two checks happen before any work, with explicit, actionable error messages.

#### 6.A. Ollama daemon reachable

```fish
set -l ollama_host (set -q AI_COMMIT_OLLAMA_HOST; and echo $AI_COMMIT_OLLAMA_HOST; or echo http://127.0.0.1:11434)

if not curl -fsS --max-time 3 "$ollama_host/api/tags" >/dev/null 2>&1
    echo "ai_commit: cannot reach ollama at $ollama_host" >&2
    echo "" >&2
    echo "  Is the daemon running? Start it with:" >&2
    echo "    ollama serve" >&2
    echo "" >&2
    echo "  On macOS, the menu-bar app starts it automatically — make sure it's running." >&2
    echo "  If ollama isn't installed, see https://ollama.com/download" >&2
    echo "" >&2
    echo "  To point at a different host, set AI_COMMIT_OLLAMA_HOST." >&2
    return 1
end
```

#### 6.B. Target model is pulled

`/api/show` returns 404 when the model isn't pulled. We check with the resolved model name (after `--model` / env / default):

```fish
set -l show_body (jq -nc --arg name $model '{name:$name}')
if not curl -fsS --max-time 5 -X POST "$ollama_host/api/show" \
        -H 'Content-Type: application/json' \
        -d $show_body >/dev/null 2>&1
    echo "ai_commit: model '$model' is not available on $ollama_host." >&2
    echo "" >&2
    echo "  Pull it with:" >&2
    echo "    ollama pull $model" >&2
    echo "" >&2
    echo "  Or pick a different model:" >&2
    echo "    gc --model <other>           # one-off override" >&2
    echo "    set -gx AI_COMMIT_MODEL <m>  # persistent override" >&2
    echo "" >&2
    echo "  Models currently available on this host:" >&2
    curl -fsS "$ollama_host/api/tags" 2>/dev/null \
        | jq -r '.models[].name' 2>/dev/null \
        | sed 's/^/    /' >&2
    return 1
end
```

Listing the host's available models in the failure message is the high-value bit — it tells the user immediately whether they have a typo, need to pull the model, or are pointed at the wrong host.

### 7. Other error paths

| Condition | Behavior |
|-----------|----------|
| Not in a git repo | `ai_commit: not a git repository` → return 1. |
| `git add -A` fails | Surface git's stderr → return 1. |
| Empty staged diff after `git add -A` | `Nothing to commit.` → return 0. |
| `curl` to `/api/generate` non-2xx | Print HTTP status + body excerpt → return 1. Index left staged. |
| Empty response from `jq -r .response` | Print raw response → return 1. Index left staged. |
| Sanitized output fails regex | Print raw + sanitized → return 1. Index left staged. |
| User answers `n` at prompt | Leave index staged, return 0. |
| `e` (edit) chosen but `$EDITOR` unset | Fall back to `nvim` (matches `v` alias) then `vi` if absent. |

### 8. Help text

Style-match `review.fish --help`: usage line, args, flags, env vars, examples.

```
Usage: ai_commit [-y|--yes] [-m|--model MODEL] [-n|--no-add] [-h|--help]

Stages all changes, generates a conventional-commit subject with a local
ollama model, and commits after a [Y]es / [r]egen / [e]dit / [n]o prompt.

Flags:
  -y, --yes            Commit without prompting.
  -m, --model MODEL    Override model (default: $AI_COMMIT_MODEL or gemma4:e2b).
  -n, --no-add         Skip `git add -A`; commit only what is already staged.
  -h, --help           Show this help.

Env:
  AI_COMMIT_MODEL        Default model (default: gemma4:e2b).
  AI_COMMIT_OLLAMA_HOST  Ollama daemon URL (default: http://127.0.0.1:11434).

Examples:
  gc                                # generate, prompt, commit
  gc -y                             # generate and commit, no prompt
  gc -m qwen3-vl:4b-instruct        # one-off model override
  gc -n                             # only commit pre-staged files
```

## Implementation steps

1. Add `fish/.config/fish/functions/ai_commit.fish` implementing the pipeline above.
2. Add `alias gc="ai_commit"` to `fish/.config/fish/config.fish` near the existing git aliases (around the `ghc` / `gho` block).
3. Manually test:
   - **Happy path**: touch a file, run `gc`. Prompt appears, message is reasonable, `Y` commits.
   - `gc` with empty input at prompt → commits (Y is default).
   - `gc -y` on a one-line change skips the prompt.
   - `gc` with no changes → `Nothing to commit.` exit 0.
   - `gc --model gemma4:e4b` works.
   - `gc --model bogus/model` → preflight fails with the model-not-pulled message and lists available models.
   - Quit the ollama menu-bar app, `gc` → preflight fails with the ollama-not-running message.
   - `gc -n` after a manual `git add path/to/file` only commits that file.
   - `e` (edit) opens `$EDITOR` (verify `nvim` fallback works by `set -e EDITOR; gc`).
   - `r` (regenerate) re-calls the model and shows a fresh suggestion.
   - Force the model to emit garbage (e.g. point it at a non-coding model) → validation fails, raw output shown, index stays staged.
4. Once green, archive this spec to `docs/wu-json/specs/archived/`.
