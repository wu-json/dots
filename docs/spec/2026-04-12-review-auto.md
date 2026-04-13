# review_auto.fish

**Date:** 2026-04-12
**Author:** Jason Wu
**Status:** Draft

## Problem

The current review workflow is manual and sequential:

1. Write code with Cursor CLI (`c` / `cursor-agent --yolo`)
2. Run `review` — spawns 4 wezterm panes, each running a review agent (Evelyn, Vivian, Stella, Tiffany) against the current PR
3. Wait for all 3 reviewers to finish
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
  iter_1/
    review_evelyn.md
    review_vivian.md
    review_stella.md
    triage.md
  iter_2/
    ...
```

Each iteration gets its own subdirectory so previous iterations are preserved for debugging. All agents write their output via the Write tool and run in full TUI mode.

### Wezterm pane layout

Fixed 4-quadrant layout for the entire session:

```
┌─────────────────────┬─────────────────────┐
│   ORCHESTRATOR      │      Evelyn         │
├─────────────────────┼─────────────────────┤
│     Vivian          │      Stella         │
└─────────────────────┴─────────────────────┘
```

- **Top-left:** Orchestrator — polls for completion, prints status.
- **Top-right:** Evelyn — first reviewer, later runs triage/fix.
- **Bottom-left:** Vivian — second reviewer.
- **Bottom-right:** Stella — third reviewer.

All agents run in full TUI mode (not `--print`) so you can watch their progress live.

Split order (same pattern as `wez_quadrants.example.fish`):
1. pane_0 = `$WEZTERM_PANE` (orchestrator, top-left)
2. pane_bottom_left = `split-pane --pane-id $pane_0 --bottom` (Vivian)
3. pane_bottom_right = `split-pane --pane-id $pane_bottom_left --right` (Stella)
4. pane_top_right = `split-pane --pane-id $pane_0 --right` (Evelyn)

**After review phase:** All reviewer panes are killed. A fresh work pane is created on the right side of the orchestrator for triage/fix. This avoids the complexity of reusing panes and ensures clean agent startup.

### Waiting for agents to finish

Two complementary mechanisms (both verified working):

**Primary — sentinel files:** Each review agent is instructed to touch a sentinel file via Shell tool when done:
```
cursor-agent --yolo --model MODEL "... Then run this shell command: touch /tmp/review_auto.xxx/iter_1/.done_evelyn"
```
The orchestrator polls for all `.done_*` files to exist. If an agent crashes before touching the sentinel, the orchestrator will wait indefinitely — but this is rare and the user can Ctrl+C to abort.

**Fallback — TTY process check:** `wezterm cli list --format json` exposes `tty_name` for each pane. We can verify no `cursor-agent` process is running on a pane's TTY:
```fish
ps -t /dev/ttysXXX -o comm= | grep -q cursor-agent
```
Verified: this correctly returns true when an agent is running and false when it has exited.

### Triage agent prompt

The triage agent runs in a fresh work pane (right of orchestrator) after reviewers finish. The prompt is written to a file `{iter_dir}/triage_prompt.txt` and the agent is told to read it:

```
cursor-agent --yolo --model MODEL "Read the prompt at {iter_dir}/triage_prompt.txt and follow its instructions exactly."
```

The prompt file contains:
```
You are a code-review triage agent. Read the 3 review output files at:
  {iter_dir}/review_evelyn.md
  {iter_dir}/review_vivian.md
  {iter_dir}/review_stella.md

Your job:
- Read all 3 reviews
- Filter out nitpicks, style-only comments, and false positives
- Output ONLY the issues that are real bugs, logic errors, security
  vulnerabilities, or missing error handling
- If a review file is empty or contains an error, skip it
- If there are no real issues, output exactly: NO_ISSUES_FOUND
- Format each real issue as a structured block with file, line, description, and severity
- Write your final verdict to {iter_dir}/triage.md using the Write tool
- When done, run: touch {iter_dir}/.done_triage
```

### Fix agent prompt

The fix agent runs in a fresh work pane after triage completes. Prompt is also written to a file `{iter_dir}/fix_prompt.txt`:

```
Read the triaged issues at {iter_dir}/triage.md.
Fix every issue listed. Do not fix anything not listed. Commit your changes
with a clear message referencing the fixes. When done, run: touch {iter_dir}/.done_fix
```

### Max iterations

Default cap of 3 iterations to prevent infinite loops. Configurable via argument.

### Arguments

```
review_auto [options]
  --max-iterations N Max review/fix cycles (default: 3)
  --provider NAME    openai | anthropic (default: anthropic)
  --panes N          Number of review panes 1-3 (default: 3)
  --dry-run          Run reviews + triage only, skip fix step
```

## Key decisions

| Decision | Choice | Rationale |
|---|---|---|
| All agents | Full TUI mode (no `--print`) | Live progress visible in all panes |
| Output files | Agents write via Write tool | Agent controls file output; no pipe buffering |
| Triage sentinel | `NO_ISSUES_FOUND` in triage.md | Simple, grep-able exit condition |
| Fix agent mode | `--yolo` (full write access) | Needs to edit files, run shell tools, and commit |
| Review agents | `--yolo` (full TUI) | Without `--yolo`, agents can't run shell tools (gh cli, git, etc.) needed for PR inspection |
| Loop cap | 3 iterations | Prevents runaway; most real issues resolve in 1-2 iterations |

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

- Using `send-text` approach (same as existing `review.fish`): the pane has a persistent fish shell. After cursor-agent exits, the shell stays — the pane doesn't close. This is good: we can reuse panes across iterations.
- Alternative `split-pane -- fish -c "cmd"` approach: pane runs one command and then the shell exits. Pane behavior on exit depends on wezterm `exit_behavior` config (default `CloseOnCleanExit`). **Not recommended** — we want persistent panes for reuse and visibility.

### Confirmed approach

Use `send-text` for all agents (matching existing `review.fish` pattern). Each pane has a fish shell. All agents run in full TUI mode (no `--print`) so you can watch agent progress live.

**Review phase:**
```
cursor-agent --yolo --model MODEL "PROMPT (write output to FILE, then run: touch SENTINEL)"
```
Each reviewer writes its output via Write tool and touches a sentinel file via Shell tool when done.

**Triage/Fix phase:**
After review completes, reviewer panes are killed. A fresh work pane is created on the right of the orchestrator. Prompts are written to temp files to avoid quote/newline escaping issues with send-text:
```
echo "LONG PROMPT..." > {iter_dir}/triage_prompt.txt
cursor-agent --yolo --model MODEL "Read the prompt at {iter_dir}/triage_prompt.txt and follow its instructions exactly."
```
Orchestrator pane polls for `.done_*` files and prints status.

### Cleanup

After each review phase, reviewer panes are killed to create a clean work pane for triage/fix. After triage/fix completes, the work pane is killed before the next iteration. When the loop exits (clean PR or max iterations hit), the orchestrator pane prints a summary and returns control to the shell.

## Open questions

- Should the function auto-push after a clean iteration, or leave that to the user?
- Should there be a `--notify` flag to send a macOS notification when done?
