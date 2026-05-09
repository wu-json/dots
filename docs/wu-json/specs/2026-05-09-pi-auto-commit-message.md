---
status: ready
---

# `gc` — auto commit-message alias

**Date:** 2026-05-09
**Author:** Jason Wu
**Status:** Ready

## Problem

Every commit I make follows the same pattern:

```fish
git add .
git commit -m "feat: <thing>"
```

The message is the only part that takes thought, and it's the part I
half-ass when tired (`fix: stuff`, `chore: updates`). The diff is
right there — a small local model can read it, glance at the recent
log for tone, and produce a conventional-commit one-liner faster than
I'd type one.

I want a fish command `gc` ("git commit") that stages, hands the
diff to a small local LLM running interactively, and lets the agent
run the actual `git commit` itself. Interactive matters: I want to
*see* the tool calls and the chosen message land so I can ctrl-c if
it goes sideways.

**Cost is the other constraint.** I commit dozens of times a day; an
Anthropic / OpenAI API hit per commit adds up to real money for
something this small. The whole alias has to be free at the margin —
that means a *local* model via ollama. `gemma4:e2b` is already
installed, runs on-device, and costs nothing per invocation. If
gemma4:e2b ever stops being good enough, the fix is "swap to a
bigger local model" (e.g. `gemma4:e4b`, `qwen3.6:35b-a3b-coding`),
not "fall back to a paid API".

The name is harness-neutral (`gc`, not `pc`) on purpose — if pi or
gemma4:e2b turn out wrong for this, I want to swap the implementation
without retraining muscle memory.

## Goals

- One fish command `gc` that:
  1. Stages all changes (`git add .`, mirroring my habit).
  2. Bails early if nothing is staged.
  3. Launches `pi` interactively in the current terminal (any terminal
     — no wezterm panes), with `ollama/gemma4:e2b` and a tools
     allowlist of `read,grep,find,ls,bash`.
  4. Prompts the agent to read the staged diff, scan recent log for
     tone, pick one conventional-commit message, and run
     `git commit -m "..."` itself.
- Repo-agnostic. Lives in `fish/.config/fish/functions/gc.fish` so
  it's available everywhere fish is.

## Non-goals

- **Pushing.** Just commits — push is a separate decision.
- **Multi-line bodies / co-author trailers.** My existing log is all
  one-liners; mirror that.
- **Approve / regenerate loop.** If the message is wrong I'll
  `git commit --amend` like I would for any commit.
- **`--model` flag, `--no-stage` mode, inline hint passthrough
  (`gc auth bug fix`).** All deferred. Start minimal; add if friction
  shows up.
- **Replacing manual `git commit -m "..."`.** Opt-in. Use `gc` when I
  want it.

## Design

### File

`fish/.config/fish/functions/gc.fish` (fish autoloads from
`~/.config/fish/functions/`). No `config.fish` change — the function
name is already two chars.

### Body

```fish
function gc
    git add .

    # Bail before launching pi if nothing is staged — gemma4:e2b will
    # happily hallucinate a message for an empty diff.
    if git diff --cached --quiet
        echo "Nothing to commit"
        return 0
    end

    set -l prompt 'Write a one-line conventional-commit message for the changes already staged.

Steps:
1. Run: git diff --cached --stat
2. Run: git diff --cached
3. Run: git log --oneline -10  (match its terse tone)
4. Pick ONE message: <type>: <lowercase summary>
   - Types: feat, fix, chore, docs, refactor, style, test, perf, build, ci
   - Under 60 chars. No trailing period. No body. No surrounding quotes.
5. Run: git commit -m "<your message>"

Do not push. Do not amend. Do not stage anything else. Print the message after committing and stop.'

    pi --no-session \
        --model ollama/gemma4:e2b \
        --tools read,grep,find,ls,bash \
        "$prompt"
end
```

### Flag rationale

- **Interactive (no `-p`)** — I need to watch tool calls scroll past.
  Print mode would blank the terminal and only emit the final string,
  killing the trust-building "watch it work" property.
- **`--no-session`** — one-shot. No reason to litter
  `~/.pi/agent/sessions/` with single-commit-message runs.
- **Explicit `--model ollama/gemma4:e2b`** — local + free is a hard
  requirement (see Problem), so the model is hard-coded rather than
  inherited from `defaultProvider`/`defaultModel` in
  `pi/.pi/agent/settings.json` (which can drift to a paid provider).
  The alias is self-contained: even if I `pi config` my way into
  defaulting to anthropic tomorrow, `gc` keeps running locally and
  free.
- **No `--thinking`** — irrelevant at 2B params.
- **`--tools read,grep,find,ls,bash`** — narrowest set that still
  lets the agent run `git status`, `git diff --cached`,
  `git log --oneline`, and `git commit`. No `edit`/`write` (no files
  are being modified). Smaller tool preamble = more attention budget
  for the message.

### Pre-stage with `git add .`

Done in fish, not by the agent. Three reasons:

1. Staging is deterministic — no reason to spend tokens on it.
2. A 2B model could miss files if asked to "stage appropriately".
3. The `git diff --cached --quiet` early-exit needs staging done
   first.

`git add .` is intentionally cwd-relative (mirrors my muscle memory).
Out-of-cwd files don't get included; if I want all changes I `cd` to
the repo root first.

### Prompt notes

- "Match its terse tone" via `git log --oneline -10` is the most
  load-bearing line — it's what makes the model produce `fix: pi`
  rather than `fix(pi): correct configuration paths to align with
  recent settings refactor`. Don't drop it during the rip.
- "No surrounding quotes" exists because small models sometimes wrap
  their output in backticks or quotes, which then end up *inside* the
  commit message string.
- If the rip surfaces "model produces a list of options instead of
  one" or "model wraps message in markdown", reinforce step 4
  inline. No need to plan for that ahead of time.

### Failure modes

| Case | Behavior |
|---|---|
| No staged changes | Early-exit prints "Nothing to commit"; pi never launches. |
| Not in a git repo | `git add .` errors; function exits non-zero. |
| Ollama stopped / model not pulled | pi reports the error in the pane; ctrl-c out, fix, retry. |
| Model picks a bad message | Visible in the pane before commit; ctrl-c, or `git commit --amend` after. |
| Diff too large for context | Known limitation. The model will commit something based on truncated context, or pi will error. Acceptable for now. |

### Diff scope

- `fish/.config/fish/functions/gc.fish` (new)
- `docs/wu-json/specs/2026-05-09-pi-auto-commit-message.md` (this
  file; moves to `archived/` after the rip)

No `config.fish` change. No Brewfile change (pi, ollama, and
`gemma4:e2b` are already installed; the model is in `enabledModels`
in `pi/.pi/agent/settings.json`).

## Preconditions

1. `pi --model ollama/gemma4:e2b --tools read,grep,find,ls,bash
   "<prompt>"` runs interactively, executes git via `bash`, exits
   when the agent stops.
2. Ollama is running locally and `gemma4:e2b` is pulled.
3. `fish/.config/fish/functions/` is autoloaded (it is — that's
   where `review.fish` already lives).

## Verification plan

1. **Trivial change** — typo fix in one file. Run `gc`. Expect a
   `fix: …` one-liner that gets committed; `git log -1` shows it.
2. **Empty repo state** — `gc` with nothing changed. Expect
   "Nothing to commit"; pi must not launch.
3. **Multi-file feature** — add a function plus its test. Expect
   `feat: …` capturing the gist (not just one filename).
4. **Outside a git repo** — `cd /tmp; gc`. Expect git's
   "fatal: not a git repository" and a clean non-zero return; pi
   must not launch.
5. **Ollama down** — `brew services stop ollama; gc` on a staged
   change. Expect a visible connection error in pi's pane and clean
   ctrl-c exit (no zombie pi process, no half-commit).
6. **Tone check** — run `gc` across 5 unrelated commits. Skim
   `git log --oneline`; the new entries should be visually
   indistinguishable from the existing terse log (`fix: pi`,
   `feat: Brewfile`). If they look verbose or off-style, iterate on
   the prompt before archiving.

## Considered alternatives

- **Bigger local model (`qwen3.6:35b-a3b-coding-mxfp8`).** Rejected
  for the default — first-token latency at 35B kills the per-commit
  flow, and the quality bump isn't worth the wait for a one-line
  message. Both are local + free; the choice is purely speed. If
  gemma4:e2b's quality tanks, the upgrade path is still local
  (`gemma4:e4b` first), not a paid API.
- **Claude / cursor-agent / any paid API harness.** Rejected on
  cost. Dozens of commits a day × cents per call = a non-trivial
  monthly line item for something a 2B model handles fine. Local +
  free is a goal of this alias, not a coincidence.
- **`pi -p` (print mode), capture the message, run `git commit`
  outside pi.** Rejected — defeats the "watch it work" requirement.
- **Pre-commit hook.** Rejected — hooks fire on every commit, even
  ones where I already know the message. The whole point is opt-in.
- **Skip `git add .`, work on already-staged changes only.**
  Rejected as default — `add .` matches my muscle memory; could
  become a `--no-stage` flag if partial-staging ever matters.

## Deferred to follow-ups

- `--model` override (same shape as `review.fish`).
- `--no-stage` mode for partial staging.
- Inline hint passthrough — `gc auth bug fix` appends "additional
  context: auth bug fix" to the prompt. Useful when the diff alone
  doesn't capture intent.
- Sibling `gcp` ("commit + push") once `gc` proves itself.
- Per-repo prompt overrides (e.g. repos that want
  `feat(scope):` with mandatory scope) — natural shape is sourcing a
  `.gc-prompt` file from the repo root if I ever hit one.
