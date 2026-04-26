---
status: implemented
---

# review_auto: swap cursor-agent for pi

**Date:** 2026-04-26
**Author:** Jason Wu
**Status:** Implemented

## Problem

`fish/.config/fish/functions/review_auto.fish` (and the simpler
`review.fish`) shells out to `cursor-agent --yolo --model …` for every
agent it spawns — review, triage, and fix.

The core motivation for swapping to `pi`: **review is a read-and-reason
task, not a do-anything task.** A reviewer needs to read the diff,
related files, and produce findings. It does not need web search, MCP
servers, fetch tools, IDE integrations, or any of the broader cursor
agent surface area. Every extra capability the agent has is:

- **Tokens spent on tool definitions** that get prepended to every
  request. Three reviewers × N iterations × the full cursor-agent tool
  preamble adds up fast on Opus pricing.
- **Tokens spent on tool exploration** when the model decides to web-
  search a stack-overflow link or fetch external docs mid-review.
  That's almost never load-bearing for finding real bugs in a diff,
  but the model will reach for it because it's there.
- **Latency and flakiness** from tools that can stall (network fetch,
  MCP handshakes) inside an automated loop with phase timeouts.
- **Surface area for false positives** — a reviewer that web-searches
  can hallucinate a "best practice" from a random blog post and flag
  code that's fine.

Pi (interactive, full TUI in each pane) with the built-in tool set
(`read`, `bash`, `edit`, `write`, optionally `grep`/`find`/`ls`) is
exactly what a reviewer or triager needs and nothing more. Pi's
`--tools` flag is itself an allowlist — passing
`--tools read,grep,find,ls,bash` for the review and triage agents
implicitly disables `edit`/`write`, makes the no-mutation posture
explicit, and drops the tool-definition token cost for anything not
listed. The fix agent gets the full set because it actually has to
edit and commit.

Secondary motivations:

1. **Vendor lock-in to cursor-cli.** All other agent surfaces in this
   repo (claude, opencode, pi) read the same canonical `skills/` tree
   set up by the 2026-04-25 dedupe spec. `cursor-agent` is the only
   one we still launch programmatically, which means the auto-review
   loop runs against a different agent than what I use day-to-day.
2. **Model selection is cursor-specific.** `claude-opus-4-7-high` and
   `gpt-5.4-high` are cursor-agent model shorthands, not real provider
   IDs. Anything else that wants to drive the same loop has to learn
   that vocabulary.
3. **`--yolo` semantics differ from pi's permission model.** pi's
   built-in `bash`/`edit`/`write` tools don't gate on a yolo flag; the
   tool allowlist is configured per-invocation. The current prompts
   assume cursor's "approve everything" mode.

I want `review_auto` (and `review`) to drive `pi` instead.

## Goals

- `review`, triage, and fix agents in `review_auto.fish` all run via
  the `pi` CLI installed at `/opt/homebrew/bin/pi`.
- `review.fish` (the manual 1–4 pane variant) gets the same swap so
  the two functions stay consistent.
- Default models stay anthropic Claude Opus on the `pi` provider
  (`anthropic/claude-opus-4-7` with `--thinking high`), matching the
  current default behavior.
- A new `--model <pattern>` flag lets the user override the model for
  a single run. Value is passed straight through to `pi --model`,
  including pi's `provider/id:thinking` shorthand (e.g. `--model
  anthropic/claude-sonnet-4-5:medium` or `--model sonnet:high` if pi's
  fuzzy match resolves it). Applies to all three agent roles in one
  invocation — review, triage, and fix all use the same model when
  the flag is set.
- Per-role tool allowlists, all three with `bash` so reviewers can run
  `gh pr diff` / `git diff`:
  - **Review:**  `read,grep,find,ls,bash`
  - **Triage:**  `read,grep,find,ls,bash,write`  (`write` for `triage.md`)
  - **Fix:**     `read,grep,find,ls,bash,edit,write`

  Honest framing: "no mutation" for review/triage comes from the
  *absence of `edit`/`write`* plus the existing `no_checkout` prompt
  guard against shell-based branch changes. A motivated `bash`
  invocation could still touch the tree; we trust model + prompt +
  allowlist together, not a pure read-only sandbox.
- All existing review/triage/fix prompts keep working: the `review`
  and `pr` skills resolve via pi's description-match discovery (the
  prompts already say "the local review skill" / "the /pr skill";
  pi loads both from `~/.pi/agent/skills/` automatically), Write /
  Read / Bash tool calls land, sentinel files get touched, `triage.md`
  gets written.
- Wezterm pane orchestration, sentinel polling, timeouts, TTY restore,
  spinner UI, and the iteration loop are unchanged.
- No regression in the "no PR for current branch" / argument-parsing
  paths.

## Non-goals

- Rewriting the orchestration layer. Pane layout, sentinel polling,
  triage decision logic, max-iter cap, dry-run flag, etc. all stay.
- Changing the prompts' content beyond what the agent swap requires
  (e.g. tool names, no-checkout guard wording).
- Supporting an `--provider openai` path. Pi's installed providers on
  this machine are anthropic + ollama only (`pi --list-models` shows
  no `gpt-5*` model). The `openai` branch is removed for now; can be
  re-added when a real OpenAI key is configured for pi.
- Adding new pi-specific features (resume sessions, custom system
  prompts per agent, etc.). Straight 1:1 swap.
- Touching `claude/` agent config. Skills already resolve through
  the canonical `skills/` symlink chain.
- Bumping the ollama model id. The `qwen3.6:35b` →
  `qwen3.6:35b-a3b-coding-mxfp8` swap in
  `pi/.pi/agent/extensions/ollama-providers.ts` and
  `opencode/.config/opencode/opencode.json` shipped earlier on `main`
  (commit `835abde`, “feat: pi adjustments”). It’s mentioned in this
  spec only as the precondition for the local-model `--model` example
  below; this PR does not re-touch those files.

## Design

### CLI shape change

Shared base: `pi --no-session --thinking high --model <model>`.
Per-role suffix is just the `--tools` allowlist:

| Step | Before | After |
|---|---|---|
| Review | `cursor-agent --yolo --model claude-opus-4-7-high "<prompt>"` | `<base> --tools read,grep,find,ls,bash "<prompt>"` |
| Triage | `cursor-agent --yolo --model claude-opus-4-7-high "<prompt>"` | `<base> --tools read,grep,find,ls,bash,write "<prompt>"` |
| Fix    | `cursor-agent --yolo --model claude-opus-4-7-high "<prompt>"` | `<base> --tools read,grep,find,ls,bash,edit,write "<prompt>"` |

Notes on flag choices:

- **Interactive TUI** — each pane runs pi in its default interactive
  mode (no `-p` / `--print`). The wezterm-quadrant layout exists
  specifically to let the user watch reviewers, triager, and fixer
  work in real time — tool calls, thinking, and edits all appear in
  the pane as they happen. `-p` (print mode) was considered and
  rejected: it suppresses progress output entirely and only emits
  the final assistant message at the end, leaving panes blank for
  minutes while pi runs invisibly. Completion detection still uses
  the existing sentinel-file mechanism (the prompt instructs the
  agent to `touch $sentinel` when finished), so we don't depend on
  `-p`'s exit semantics for that.
- **`--no-session`** — each pane invocation is one-shot from this
  loop's perspective; we never go back and `pi -r` an Evelyn run
  from three iterations ago. Without `--no-session`, every reviewer,
  triager, and fixer run accumulates a `.jsonl` under
  `~/.pi/agent/sessions/` that nothing reads. `--no-session` keeps
  the session list focused on sessions actually worth resuming.
- **`--thinking high`** — kept as a separate flag rather than
  encoded in the model pattern. Matches `settings.json`
  (`defaultThinkingLevel: high`) and avoids `:thinking` mangling of
  user-supplied `--model` values. The override path (below) handles
  user-supplied `:thinking` correctly.
- **`--model anthropic/claude-opus-4-7`** — explicit provider/id pair
  so we don't depend on `defaultProvider` in `settings.json`.
- **No `--yolo` analog needed.** Pi's `bash`, `edit`, `write` tools
  run without per-call approval; the per-role `--tools` allowlist
  scopes the blast radius.

### Pane invocation

Today the function builds the command as a string and `printf '%s\r' …
| wezterm cli send-text` into the pane's persistent fish shell, with
the prompt on disk to dodge quoting issues:

```fish
set -l cmd "$review_cmd \"\$(cat $prompt_file)\""
printf '%s\r' "$cmd" | wezterm cli send-text --no-paste --pane-id $pane
```

Same pattern after the swap, but the single `$review_cmd` becomes
three role-specific commands sharing a base. Sketch:

```fish
set -l model anthropic/claude-opus-4-7
if test -n "$model_override"
    set model $model_override
end

# Suppress --thinking when the user encoded it in :suffix
set -l thinking_levels off minimal low medium high xhigh
set -l thinking_flag --thinking high
set -l suffix (string match -rg '^.*:([^:]+)$' -- $model)
if contains -- "$suffix" $thinking_levels
    set thinking_flag
end

set -l pi_base pi --no-session $thinking_flag --model $model
set -l review_cmd "$pi_base --tools read,grep,find,ls,bash"
set -l triage_cmd "$pi_base --tools read,grep,find,ls,bash,write"
set -l fix_cmd    "$pi_base --tools read,grep,find,ls,bash,edit,write"
```

(The actual function builds `pi_base` as a string, conditionally
appending `--thinking high` only when the resolved model has no
`:level` suffix — see the live source for the exact shape.)

```fish
```

`$(cat $prompt_file)` still expands in the pane's fish, so prompt-file
contents pass through unchanged. No quoting work needed beyond what
already exists.

### Prompt edits

Audit (`grep -nE 'Write tool|Read tool|cursor' review_auto.fish`
on the original code) showed three references in prompt strings:
"using the Write tool" in review/fix, "Read tool" in triage/fix —
plus the agent CLI string `cursor-agent` on lines 93, 367, 450. Pi's
tool names are lower-case (`read`, `bash`, `edit`, `write`); the
model resolves title-case "Write tool" / "Read tool" against pi's
`write`/`read` correctly (verified in pre-implementation smoketests).
No prompt-text changes required — only the `cursor-agent ...` lines
get rewritten per the previous section.

The `no_checkout` guard, sentinel-touch instruction, and
`NO_ISSUES_FOUND` exit string all stay byte-identical.

### Provider option

`--provider {openai|anthropic}` is removed from both functions:

- The `anthropic` path becomes the only path.
- Argument parsing for `--provider` is deleted (and from `review.fish`'s
  positional `openai|anthropic` token).
- The header line `"$provider · $num_agents reviewers · …"` drops the
  `$provider` segment entirely. Replaced with the active model id,
  truncated against `$COLUMNS` the same way `pr_label` already is:
  `" review_auto · PR #123  3 reviewers · 10 max iterations · anthropic/claude-opus-4-7"`.
  When the model is the default, this is the only place the
  Opus-4-7 string appears in the UI.

If/when an OpenAI provider is wired into pi, re-add the flag and pick a
real OpenAI model id (e.g. `openai/gpt-5-pro` or whatever exists at
that point). Until then, `--model openai/<id>` still works as a
one-shot override once the provider key is in the environment.

### Model override

New flag, both functions:

```
review      [1-4] [--model PATTERN]
review_auto […existing flags…] [--model PATTERN]
```

Semantics:

- **Default (no flag):** the per-role models stay as today's behavior
  collapsed onto pi — review/triage/fix all `anthropic/claude-opus-4-7`
  with `--thinking high`.
- **With `--model`:** the supplied pattern replaces the model for
  *all three roles* (review, triage, fix). One model, one run. This
  is the common case ("try this whole loop on Sonnet").
- **Pattern is opaque to the function.** No validation against
  `pi --list-models` — if pi can resolve it, it works; if not, pi
  errors out in the pane and the orchestrator times out on sentinels
  exactly like any other agent failure. Keeps the function ignorant
  of pi's model catalog.
- **Thinking-level handling.** If the user encodes a thinking level
  as the trailing `:level` suffix in the pattern (`...:high`), drop
  the explicit `--thinking high` flag to avoid double-specifying.

  Detection: split on the *last* `:`; if the suffix matches the pi
  thinking vocabulary `{off,minimal,low,medium,high,xhigh}`, treat
  it as encoded thinking. Otherwise treat the whole string as a
  model id. This matters because ollama tags use `:` natively
  (`qwen3.6:35b-a3b-coding-mxfp8`) — its trailing token is
  `35b-a3b-coding-mxfp8`, not a thinking level, so `--thinking high`
  must stay.

  Implementation lives next to the `pi_base` build (see the Pane
  invocation section above).
- **Local-model example.** Once the ollama config bump (next section)
  lands, the canonical local override is:

  ```fish
  review_auto --model ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8
  # or, on the mac-studio itself:
  review_auto --model ollama-local/qwen3.6:35b-a3b-coding-mxfp8
  ```

  This routes the entire review/triage/fix loop through the local
  Qwen coding model. Doubles down on the token-cost motivation —
  local inference is free, and the no-edit `--tools` allowlist
  (review/triage) keeps the model from wandering into edits it
  isn't great at.

  The default stays `anthropic/claude-opus-4-7` with `--thinking
  high` for quality on real PRs.
- **Header line:** show the override in the banner, e.g.
  `" review_auto · PR #123  3 reviewers · anthropic/claude-sonnet-4-5"`.
  Truncate the same way `pr_label` is truncated on narrow terminals.

Argument parsing additions in `review_auto.fish` (alongside the
existing `--max-iterations` / `--agents` / `--timeout` / `--dry-run`
block):

```fish
case --model
    set i (math $i + 1)
    if test $i -gt $argc
        echo "Missing value for --model"
        return 1
    end
    set model_override $argv[$i]
```

`review.fish` currently uses a `for token in $argv` positional loop
(pane count `1`–`4` plus an `openai|anthropic` token). Two changes:

1. Drop the `openai|anthropic` token-recognition branch.
2. Add `--model PATTERN` parsing.

Simplest concrete port: switch `review.fish` to the same
`while test $i -le $argc / case` index loop `review_auto.fish`
already uses, so both functions share an arg-parsing shape. Pane
count stays positional; `--model` is the only flag.

No per-role model override (e.g. "sonnet for review, opus for fix") in
this spec — punt to a follow-up if it ever matters. One model per run
is enough.

### Models config

No change to `pi/.pi/agent/settings.json`. `defaultProvider: anthropic`
+ `defaultModel: claude-opus-4-7` + `defaultThinkingLevel: high` already
match what we're going to pass explicitly. The explicit `--model` and
`--thinking` flags exist so the function doesn't break if defaults
change later.

### Skills

The `review` skill prompt referenced in both functions
("Use the local review skill to review PR #N…") resolves through pi's
skill discovery at `~/.pi/agent/skills/review/SKILL.md`, which is the
symlink set up by the dedupe spec. Same applies to `/pr` invoked from
the fix prompt. No changes needed in `skills/`.

### Diff scope

Files touched in this PR:

- `fish/.config/fish/functions/review_auto.fish`
- `fish/.config/fish/functions/review.fish`
- `docs/wu-json/specs/archived/2026-04-26-review-auto-pi-agent.md` (this file)

Nothing else. No `Brewfile` change (cursor-agent stays installed for
manual `c` use; just no longer driven by these two functions). No
`justfile` change. No skills change. Claude config untouched.

The ollama model-id bump (`qwen3.6:35b` →
`qwen3.6:35b-a3b-coding-mxfp8`) referenced by the local-model
`--model` example landed earlier on `main` in commit `835abde`
(“feat: pi adjustments”), touching
`pi/.pi/agent/extensions/ollama-providers.ts` and
`opencode/.config/opencode/opencode.json`. It is a precondition for
the example, not part of this PR’s diff.

## Preconditions

1. `pi --thinking high --model anthropic/claude-opus-4-7 --tools
   read,write,bash <prompt>` runs interactively in a shell pane,
   executes the prompted tool calls, and stays at pi's prompt for
   further interaction (or until the user closes the pane).
2. Skills auto-resolve from `~/.pi/agent/skills/` in interactive
   mode — the canonical set (`review`, `pr`, `pick`, `llm-docs`,
   `llm-docs-true-up`) is available without any `--skill` flag.
3. `pi --list-models` shows `anthropic/claude-opus-4-7` and the
   ollama-local / ollama-tailnet `qwen3.6:35b-a3b-coding-mxfp8`
   entries.
4. `ANTHROPIC_API_KEY` is in the user's env (assumed; if absent, pi
   errors clearly on first invocation — not a code path we need to
   handle).

## Verification plan

1. `review` (manual) on a small PR with `num_panes=2` — confirm both panes spin up pi, both reviews stream into their panes (TUI visible: tool calls, thinking, etc.), skills resolve.
2. `review_auto --max-iterations 1 --dry-run` on a PR with one obvious fixable bug — confirm review files written, triage runs in its work pane, `triage.md` produced, and exit-on-`NO_ISSUES_FOUND` still works.
3. `review_auto --max-iterations 2` end-to-end — confirm fix agent commits + pushes, second iteration runs against the new HEAD, exits clean.
4. Ctrl-C mid-review — confirm `__review_auto_restore_tty` still runs and the orchestrator TTY isn't left in `-echo -icanon`.
5. `review_auto --model anthropic/claude-sonnet-4-5 --max-iterations 1 --dry-run` — confirm the override flows to all three agents, the banner reflects it, and `:high`-encoded thinking suppresses the explicit `--thinking` flag (visible directly in the pane's command line since panes are interactive).
6. `review_auto --model bogus/does-not-exist --max-iterations 1` — confirm the failure mode is "pi errors visibly in the pane, orchestrator times out on sentinels" and not a silent hang or argument-parser crash.
7. `pi --list-models qwen` — confirm `ollama-local/qwen3.6:35b-a3b-coding-mxfp8` and `ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8` both appear after the extension bump.
8. `opencode` (interactive) — confirm the new model id resolves under both `ollama` and `ollama-tailnet` providers, and the default `model` field still picks up on launch.
9. `review_auto --model ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8 --max-iterations 1 --dry-run` — end-to-end smoke of the local-model path. Quality is expected to be lower than Opus; the test is just "the loop completes and produces a `triage.md`".

## Considered alternatives

- **`pi -p` (print mode) for the panes.** Rejected after first
  end-to-end run: print mode suppresses agent progress output and
  only emits the final assistant message. Reviewer panes stayed
  blank for minutes while pi worked invisibly, defeating the whole
  point of the wezterm-quadrant layout. Switched to interactive TUI;
  the sentinel-file completion mechanism we already had does the
  job that `-p`'s exit was supposed to.
- **Encoding `--thinking` in the model pattern** (e.g.
  `anthropic/claude-opus-4-7:high`) instead of a separate flag.
  Rejected for the *function default* because it makes the
  `$model` variable carry two concerns. Kept as a *user-side*
  override shape: `--model anthropic/claude-opus-4-7:high` works
  and the function suppresses its own `--thinking high` to avoid
  double-specifying (last-`:`-suffix detection against pi's
  thinking vocabulary).
- **Header layout with `$provider`.** Dropped; replaced with the
  active model id. With per-pane interactive output, the model id
  is what you actually want to glance at to confirm the run.

## Deferred to follow-ups

- **Per-role model override.** Could grow to `--review-model` /
  `--triage-model` / `--fix-model` if the one-model-per-run shape
  ever feels limiting. Out of scope for this spec.
- **OpenAI revival.** If/when re-added, the natural shape is
  `--provider {anthropic|openai}` mapping to `--model
  anthropic/claude-opus-4-7` vs `--model openai/<id>`. With `--model`
  already in place, `--provider` is a convenience preset, not a
  hard requirement. Out of scope for this spec.
