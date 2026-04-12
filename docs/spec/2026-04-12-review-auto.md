# review_auto.fish

**Date:** 2026-04-12
**Author:** Jason Wu
**Status:** Draft

## Problem

The current review workflow is manual and sequential:

1. Write code with Cursor CLI (`c` / `cursor-agent --yolo`)
2. Run `review` — spawns 4 wezterm panes, each running a review agent (Evelyn, Vivian, Stella, Tiffany) against the current PR
3. Wait for all 4 reviewers to finish
4. Manually read each review, decide which findings are real
5. Ask a new agent to fix the real findings
6. Re-run `review` to verify fixes
7. Repeat until clean

Steps 3–7 are tedious babysitting. The user has to watch terminals, copy findings, and orchestrate fix/re-review cycles by hand.

## Goal

A single `review_auto` fish function that automates the full loop:

```
review → triage → fix → review → ... → clean
```

All agents run in visible wezterm panes so the user can watch progress in real time.

## Design

### High-level loop

```
┌─────────────────────────────────────┐
│  1. REVIEW  (4 panes, parallel)     │
│     Same as existing review.fish    │
│     Agents write findings to files  │
├─────────────────────────────────────┤
│  2. WAIT                            │
│     Poll until all review agents    │
│     have exited (pane programs end) │
├─────────────────────────────────────┤
│  3. TRIAGE  (1 pane)                │
│     A triage agent reads all        │
│     review outputs and produces a   │
│     consolidated list of real       │
│     issues that need fixing         │
├─────────────────────────────────────┤
│  4. DECISION                        │
│     If triage says "no real issues" │
│     → exit loop, PR is clean        │
├─────────────────────────────────────┤
│  5. FIX  (1 pane)                   │
│     A fix agent receives the        │
│     triaged issues and applies      │
│     fixes to the codebase           │
├─────────────────────────────────────┤
│  6. COMMIT                          │
│     Fix agent commits changes       │
│     (or user confirms)              │
├─────────────────────────────────────┤
│  7. GOTO 1                          │
│     Loop back to review the new     │
│     state of the code               │
└─────────────────────────────────────┘
```

### Output capture

Each agent writes its output to a temp file so downstream agents can read it:

```
/tmp/review_auto.<session>/
  review_evelyn.md
  review_vivian.md
  review_stella.md
  review_tiffany.md
  triage.md          # consolidated real issues
```

`cursor-agent --print` mode writes to stdout, which we tee into these files. This also means each pane shows live output to the user.

### Wezterm pane layout

Fixed 5-pane layout for the entire session:

```
┌─────────────────────────────────────────────┐
│              ORCHESTRATOR (pane 0)           │
│  triage agent / fix agent / status output   │
├──────────┬──────────┬──────────┬────────────┤
│ Evelyn   │ Vivian   │ Stella   │ Tiffany    │
│ (pane 1) │ (pane 2) │ (pane 3) │ (pane 4)   │
└──────────┴──────────┴──────────┴────────────┘
```

- **Top row:** 1 wide pane — the orchestrator. Runs triage and fix agents. Also displays loop status (round number, phase, etc).
- **Bottom row:** 4 equal panes — the 4 review agents. Run in parallel each round.

Split order (verified with `wezterm cli split-pane`):
1. pane_0 = `$WEZTERM_PANE` (orchestrator, top)
2. pane_1 = `split-pane --pane-id $pane_0 --bottom --percent 70` (first reviewer, bottom-left)
3. pane_2 = `split-pane --pane-id $pane_1 --right` (bottom splits 50/50)
4. pane_3 = `split-pane --pane-id $pane_1 --right` (left half splits again → 25/25)
5. pane_4 = `split-pane --pane-id $pane_2 --right` (right half splits again → 25/25)

Bottom row gets 70% of vertical space since reviewers produce the most output. All panes persist across rounds — review panes are reused each cycle, orchestrator pane runs triage then fix sequentially between review rounds.

### Waiting for agents to finish

Two complementary mechanisms (both verified working):

**Primary — sentinel files:** Each review command is chained with a `touch`:
```fish
cursor-agent --print ... | tee /tmp/review_auto.xxx/review_evelyn.md; touch /tmp/review_auto.xxx/.done_evelyn
```
The orchestrator polls for all `.done_*` files to exist. Simple, race-free, works even if the agent crashes (the touch still runs because it's `;`-chained, not `&&`-chained).

**Fallback — TTY process check:** `wezterm cli list --format json` exposes `tty_name` for each pane. We can verify no `cursor-agent` process is running on a pane's TTY:
```fish
ps -t /dev/ttysXXX -o comm= | grep -q cursor-agent
```
Verified: this correctly returns true when an agent is running and false when it has exited.

### Triage agent prompt

```
You are a senior code-review triage agent. You have 4 independent code reviews below.
Your job:
- Read all 4 reviews
- Filter out nitpicks, style-only comments, and false positives
- Output ONLY the issues that are real bugs, logic errors, security
  vulnerabilities, or missing error handling
- If there are no real issues, output exactly: NO_ISSUES_FOUND
- Format each real issue as a structured block with file, line, description, and severity
```

### Fix agent prompt

```
You are a senior engineer. You have a list of triaged code-review issues below.
Fix every issue listed. Do not fix anything not listed. Commit your changes
with a clear message referencing the fixes.
```

### Max iterations

Default cap of 3 iterations to prevent infinite loops. Configurable via argument.

### Arguments

```
review_auto [options]
  --max-rounds N     Max review/fix cycles (default: 3)
  --provider NAME    openai | anthropic (default: anthropic)
  --panes N          Number of review panes 1-4 (default: 4)
  --dry-run          Run reviews + triage only, skip fix step
```

## Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| Output format | `--print` to file via tee | Gives visible terminal output AND machine-readable files for the next agent |
| Triage sentinel | `NO_ISSUES_FOUND` string | Simple, grep-able exit condition |
| Fix agent mode | `--yolo` (full write access) | Needs to edit files and commit |
| Review agents | `--yolo --print` | Needs tool access (gh, shell) for PR inspection via review skill |
| Loop cap | 3 rounds | Prevents runaway; most real issues resolve in 1-2 rounds |

## Feasibility findings

Tested against `cursor-agent` CLI and `wezterm cli` on 2026-04-12. All core mechanics confirmed working.

### cursor-agent --print

- `--print` mode is **non-interactive**: runs the prompt, prints output to stdout, exits. This is exactly what we need for automated panes.
- Output piping works: `cursor-agent --print -p "prompt" 2>&1 | tee /tmp/out.md` gives both visible terminal output and a file for downstream agents.
- `--output-format` supports `text` (default), `json`, and `stream-json`. We use `text` for review panes (human-readable in the pane) and `text` for triage/fix (needs to be read by the next agent from file).
- `--trust` flag skips workspace trust prompt in headless/print mode — **required** for automated panes that can't interactively approve.
- `--mode ask` available for read-only review agents; `--yolo` for fix agent that needs write access.

### wezterm cli

- **`list --format json`** returns pane metadata including `pane_id`, `tty_name`, `title`, `is_active`. The `tty_name` field lets us check what processes are running in each pane via `ps -t <tty>`.
- **`split-pane`** returns the new pane ID on stdout. Supports `--bottom`, `--right`, `--percent`, `--pane-id` targeting. Confirmed: splitting a pane that was already split works correctly (splits the remaining space of that pane, not the whole window).
- **`send-text --no-paste --pane-id N`** sends raw keystrokes. Pipes and redirects in the sent text are interpreted by the pane's shell, so `cmd | tee file` works naturally.
- **`get-text --pane-id N`** scrapes visible pane buffer. Works but scrollback is limited — tee to file is more reliable for capturing full agent output.
- **`kill-pane --pane-id N`** available for cleanup.
- **`wezterm` binary location:** `/Applications/WezTerm.app/Contents/MacOS/wezterm`. Not in PATH in non-wezterm shells, but inside wezterm panes it's aliased. The fish function runs inside wezterm so this is fine.

### Pane lifecycle

- Using `send-text` approach (same as existing `review.fish`): the pane has a persistent fish shell. After cursor-agent exits, the shell stays — the pane doesn't close. This is good: we can reuse panes across rounds.
- Alternative `split-pane -- fish -c "cmd"` approach: pane runs one command and then the shell exits. Pane behavior on exit depends on wezterm `exit_behavior` config (default `CloseOnCleanExit`). **Not recommended** — we want persistent panes for reuse and visibility.

### Confirmed approach

Use `send-text` (matching existing `review.fish` pattern). Each pane has a fish shell. We send commands like:
```
cursor-agent --yolo --print --trust --model MODEL -p "PROMPT" 2>&1 | tee /tmp/session/review_NAME.md; touch /tmp/session/.done_NAME\r
```
Orchestrator pane polls for `.done_*` files, then reads the review output files to build the triage prompt.

## Open questions

- Should triage and fix reuse the same pane or split new ones each round?
- Should the function auto-push after a clean round, or leave that to the user?
- Should there be a `--notify` flag to send a macOS notification when done?
