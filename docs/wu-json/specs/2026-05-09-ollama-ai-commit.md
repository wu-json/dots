---
status: draft
---

# Ollama-Powered `git add . && git commit` Fish Function

**Date:** 2026-05-09
**Author:** Jason Wu
**Status:** Draft

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
4. Shows it, lets the user accept / edit / abort.
5. On accept, runs `git commit -m "<message>"`.

Model: `gemma4:e2b` (already pulled on this machine, ~7.2 GB, plenty for this scope).

## Non-goals

- Multi-line commit bodies. Looking at recent history the user only writes one-line subjects; generating bodies is out of scope.
- Pre-commit hook integration / replacing `git commit` globally.
- Anything that makes a *network* call. This must work offline against the local ollama daemon.
- Picking the right files to stage. Mirrors current habit of `git add .`; if the user wants partial staging they fall back to `git` directly.
- Editing existing commits / amends.

## Design

### 1. Function & alias

New function: `fish/.config/fish/functions/ai_commit.fish`

Alias added in `config.fish`:

```fish
# AI commit
alias gc="ai_commit"
```

`gc` is short, mnemonic ("git commit"), and not currently bound. Open question below for whether to pick a different short binding.

### 2. Flags

```
ai_commit [-y|--yes] [-m|--model MODEL] [-n|--no-add] [-h|--help]
```

| Flag | Behavior |
|------|----------|
| `-y`, `--yes` | Skip the accept/edit/abort prompt and commit directly. |
| `-m`, `--model` | Override the ollama model (default `gemma4:e2b`). Same charset guard as `review.fish` (`^[A-Za-z0-9._/:-]+$`). |
| `-n`, `--no-add` | Skip `git add -A`; commit only what is already staged. |
| `-h`, `--help` | Help text. |

Env override: `AI_COMMIT_MODEL` overrides the default model when `--model` is not passed. Lets `config.local.fish` set per-machine defaults (e.g. a beefier model on the mac-studio tailnet) without editing the function.

### 3. Pipeline

```
1. Verify we're inside a git work tree:        git rev-parse --is-inside-work-tree
2. Verify ollama daemon is reachable:          curl -fsS http://127.0.0.1:11434/api/tags
3. (unless --no-add) git add -A
4. Capture diff:                               git diff --staged
   - If empty → "Nothing to commit." return 0
5. Capture context for the prompt:
   - git status --short
   - git log -10 --pretty=format:"%s"   (style cues)
6. Build prompt (see §4) and call ollama generate.
7. Strip / sanitize model output (see §5).
8. If -y: git commit -m "<msg>"
   else: print msg, prompt [Y]es / [e]dit / [n]o
        - Y → commit
        - e → open $EDITOR with msg pre-filled, commit edited result
        - n → abort, leave index staged so user can `git commit` manually
```

### 4. Prompt to the model

Send via `curl` to `http://127.0.0.1:11434/api/generate` with `stream: false` so we get a single JSON response and can `jq -r .response` it cleanly.

```
You are generating a one-line git commit subject for a personal dotfiles repo.

Rules:
- Conventional commits format: "<type>: <subject>" where type ∈ feat, fix, chore, docs, refactor, test, style.
- Lowercase subject, imperative mood, no trailing period.
- 72 characters max, ideally under 50.
- Output ONLY the subject line. No prose, no quotes, no code fences, no leading "-".

Recent commit subjects (style reference):
{git log -10 --pretty=format:"%s"}

Files changed:
{git status --short}

Staged diff (truncated to 30000 chars):
{git diff --staged | head -c 30000}
```

Why a `head -c` cap: `gemma4:e2b` runs comfortably with smaller contexts and most dotfile commits are < 500 lines of diff anyway. A hard byte cap is simpler than a token-aware truncation and prevents pathological cases (lockfile rewrites, binary blobs leaking through).

Request body shape (key fields):

```json
{
  "model": "gemma4:e2b",
  "prompt": "...",
  "stream": false,
  "keep_alive": "1h",
  "options": { "temperature": 0.2 }
}
```

- `keep_alive: "1h"` mirrors the pattern set by `2026-04-26-ollama-model-keepalive.md` so this command stays warm across consecutive uses.
- Low temperature (0.2) keeps output stable and short.

### 5. Output sanitization

Models often add extra fluff even when told not to. Apply, in order:

1. `string trim` whitespace.
2. Drop surrounding triple-backtick fences if present.
3. Drop leading `- `, `* `, or `> `.
4. Drop surrounding straight or smart quotes.
5. Take only the **first non-empty line** (`string split \n | head -n1`).
6. Truncate to 100 chars as a hard ceiling.
7. If the result is empty after sanitization → error out, leave the index staged, do not commit.

### 6. Error handling

| Condition | Behavior |
|-----------|----------|
| Not in a git repo | Print error, return 1. |
| Ollama daemon unreachable | Print "ollama not running — start with `ollama serve`", return 1. |
| Model not pulled (`/api/generate` returns 404 with model error) | Print suggestion: `ollama pull gemma4:e2b`, return 1. |
| Empty staged diff after `git add -A` | Print "Nothing to commit.", return 0. |
| Empty / unusable model response | Print raw response, leave index staged, return 1. **Never** auto-commit a fallback string. |
| User answers `n` at prompt | Leave index staged, exit 0. |

### 7. Help text

Style-match `review.fish --help`: usage line, args, flags, examples.

## Implementation steps

1. Add `fish/.config/fish/functions/ai_commit.fish` implementing the pipeline above.
2. Add `alias gc="ai_commit"` to `fish/.config/fish/config.fish` near the existing git aliases.
3. Manually test:
   - In this repo, touch a file, run `gc`. Confirm prompt appears, message is reasonable, accept commits.
   - `gc -y` on a one-line change skips the prompt.
   - `gc` with nothing changed → "Nothing to commit."
   - `gc --model gemma4:e4b` works.
   - Stop the ollama daemon, `gc` errors gracefully.
   - `gc -n` after a manual `git add path/to/file` only commits that file.
   - `e` (edit) at the prompt opens `$EDITOR`, saves, commits the edited subject.

## Open questions

- **Alias name**: `gc` is the proposal. Alternatives: `gca`, `aic`, or even `c`. `gc` collides with no current binding but reads as "git commit" which is *almost* what it does. Want to confirm before wiring it up.
- **Prompt UX on accept**: single-keypress (`read -n1`) vs typed `y\n`. Single-keypress is faster but slightly more surprising; the existing fish functions in this repo use line-based reads. Default to line-based to stay consistent.
- **Should `-y` be the default?** User said "does this for me" → they may want zero-prompt by default. Counter-argument: a bad commit message is easy to amend but annoying when it lands on a PR title. Spec defaults to *prompt*, opt-in to `-y`. Easy to flip later.
- **Model choice**: `gemma4:e2b` per the request. `qwen3-vl:4b-instruct` is also pulled and would also work; not switching without a reason.
