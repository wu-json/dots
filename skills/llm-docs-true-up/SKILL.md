---
name: llm-docs-true-up
description: >-
  Reconcile an existing wu-json llm-docs spec (or bug/research doc) with what
  was actually implemented, so the doc reads as if it were authored against the
  final code. Rewrites goals, design, and details to match reality and folds in
  motivations from the conversation for any deltas. Use when the user asks to
  true up, reconcile, sync, backfill, or update an llm-docs spec after
  vibe-coding, post-implementation drift, or when the spec no longer matches
  the code under docs/wu-json.
---

# llm-docs true-up

True up a wu-json llm-docs doc (typically a `specs/` file) so it accurately describes what was actually built. The goal: a future agent reading the spec cold should not be misled by stale intent, abandoned approaches, or undocumented pivots.

Root: `docs/wu-json`. See the `llm-docs` skill for layout and lifecycle; this skill covers only the reconciliation step.

## When to use

- The spec was written first, then an agent implemented it, then the human vibe-coded further changes.
- The implementation diverged from the spec (different API shape, renamed module, dropped feature, new edge case, etc.).
- The user says "true up", "reconcile", "sync the spec", "update the spec to match the code", or similar.

This skill only updates the spec in place. It does not archive, unarchive, move, or rename the file. If the doc is already under an `archived/` directory, edit it there; do not move it back into the live category.

## Inputs to gather

Before editing, confirm:

1. **Target doc path** — usually under `docs/wu-json/specs/` (may also be `bugs/` or `research/`). Default to inferring it from the current branch (see below) rather than asking.
2. **Scope of the delta** — the commits on the current branch vs. its base (e.g. `main`) are almost always the "implemented reality". Use `git log` / `git diff` against the merge base.
3. **Motivations for changes** — mine the current conversation (and, if useful, commit messages on the branch) for *why* things changed. Pivots, tradeoffs, and abandoned approaches matter more than what was added.

### Inferring the target doc from the branch

A true-up is almost always run on the same branch that implemented the spec, so start there:

1. Get the current branch and its merge base with `main` (or the repo's default branch).
2. List files touched on the branch under `docs/wu-json/`, including `archived/` subdirectories — the target may already be archived.
3. **Exactly one doc touched** → that's the target. Proceed (whether it lives in the live category or `archived/`).
4. **Zero docs touched** → look for a doc whose slug matches the branch name (branches are often named after the spec slug); check both the live category and `archived/`. If still nothing, ask the user.
5. **Multiple docs touched** → ask which one to true up.

Example commands (adapt to the repo):

```bash
git merge-base HEAD main
git diff --name-only $(git merge-base HEAD main)...HEAD -- 'docs/wu-json/**'
git log --oneline $(git merge-base HEAD main)..HEAD
```

If the branch is `main` itself, or the doc lives on a different branch than the implementation, fall back to asking the user for the path.

## Workflow

Copy this checklist and track progress:

```
True-up progress:
- [ ] 1. Identify the target doc from the current branch
- [ ] 2. Read the current spec end-to-end
- [ ] 3. Inspect the implemented code (branch diff vs. merge base)
- [ ] 4. Enumerate deltas (spec says X, code does Y)
- [ ] 5. Collect motivations for each delta
- [ ] 6. Rewrite the spec in place
```

### 1. Identify the target doc

Use the branch-based inference above. If exactly one live doc under `docs/wu-json/` is touched on the branch, that's the target — don't ask.

### 2. Read the spec

Read the full doc. Note its structure (goals, non-goals, design, API, edge cases, etc.) — preserve that structure unless it actively misleads.

### 3. Inspect the code

Read the files, functions, configs, and tests touched on the branch (`git diff` against the merge base is the fastest path). Prefer reading current source over trusting the spec. If the spec mentions a module or symbol that no longer exists, search for the renamed/replaced version.

### 4. Enumerate deltas

For each section of the spec, decide:

| Spec vs. code | Action |
|---------------|--------|
| Matches | Leave unchanged |
| Minor drift (names, signatures, paths) | Update in place |
| Approach changed | Rewrite that section to describe the shipped approach |
| Feature dropped | Remove it from goals/design; mention briefly in a "Changes from original plan" section if motivation is non-obvious |
| Feature added post-spec | Add it as if it were part of the original design |

### 5. Collect motivations

From the conversation, pull the *reasons* behind each non-trivial delta: performance, API ergonomics, unexpected constraint, library limitation, user feedback, etc. These go into the rewritten prose — ideally inline where the decision lives, not as a separate changelog, so the doc still reads as a coherent spec.

For deltas whose motivation would surprise a future reader, add a short rationale sentence (e.g. "Uses a single queue rather than per-worker queues because ..."). For purely cosmetic drift (rename, path change), no rationale is needed.

### 6. Rewrite in place

Edit the existing file. Do not create a new doc.

Rules:

- **Voice:** the spec should read as if it were written *against the final implementation*. Past-tense "we decided to change X" narration is a smell; prefer present-tense design language ("X is a single queue because ...").
- **No changelog-as-spec:** do not turn the doc into a diff log. Fold deltas into the relevant section.
- **Preserve useful structure:** keep existing headings where they still apply.
- **Drop obsolete content:** remove goals, non-goals, open questions, and design alternatives that no longer reflect reality. If an alternative was explicitly rejected and the rejection is instructive, keep it under a "Considered alternatives" or similar section with the motivation.
- **Update code snippets:** any inline code, types, CLI invocations, or file paths must match the current code.
- **Don't invent motivations:** if the conversation doesn't explain *why* a delta happened and it is non-obvious, ask the user rather than guess.

## Anti-patterns

- **Appending a "Post-implementation notes" section** instead of editing the spec body. The whole point is that a future agent reads the spec as-is; appended notes get skimmed or missed.
- **Rewriting so aggressively that the original intent disappears.** If the original motivation still explains *why* the code looks the way it does, keep it.
- **Inventing rationale** to fill gaps. Ask the user instead.
- **Truing up against uncommitted or stale code.** Confirm you are reading the same state the user considers "done". Include uncommitted changes (`git status`, `git diff`) in the delta — they are part of the implemented reality.
- **Ignoring a branch/doc mismatch.** If the branch touches zero or multiple live docs, stop and confirm the target rather than guessing.
- **Moving, archiving, unarchiving, or renaming the doc.** True-up edits the file in place only, wherever it currently lives. If the target is already under `archived/`, edit it there — do not promote it back to the live category.

## Quick example

Before (spec):

> The worker spawns one queue per CPU and fans out tasks via round-robin.

Code actually ships a single shared queue with work-stealing because per-CPU queues caused starvation on uneven workloads (discussed in conversation).

After (trued-up spec):

> The worker uses a single shared queue with work-stealing across CPUs. A per-CPU queue design was considered but caused starvation under uneven workloads, so all workers pull from one queue.
