---
status: implemented
---

# DRY agent skills

**Date:** 2026-04-25
**Author:** Jason Wu
**Status:** Implemented

## Problem

This dotfiles repo carried the same skill content under four different
agent trees, one per tool:

```
claude/.claude/commands/                       # slash-command markdown (different format)
cursor/.cursor/skills/<name>/SKILL.md
pi/.pi/agent/skills/<name>/SKILL.md
opencode/.config/opencode/skills/<name>/SKILL.md
```

Five skills lived in each tree (`pr`, `review`, `pick`, `llm-docs`,
`llm-docs-true-up`), all with byte-identical bodies across cursor / pi /
opencode (confirmed via `diff` before the migration). Claude carried a
fourth, hand-maintained slash-command variant for two of them (`pick.md`,
`pr.md`) in a different format — `allowed-tools` frontmatter, `!`-prefixed
shell embeds, instruction-style prose — and had already drifted from the
skill bodies.

Editing a skill meant updating 3–4 files. Drift was a matter of when, not
if. The fix: one canonical file per skill, every agent reads it.

## Goals

- One canonical `SKILL.md` per skill, edited in one place.
- All four agents (Claude, cursor, pi, opencode) load the same canonical
  bodies.
- Adding, renaming, or deleting a skill is a single filesystem operation.
- `just stow` continues to install everything to the correct per-agent
  paths under `$HOME` with no extra steps.
- No build step, no generator, no sync recipe.

## Non-goals

- Reworking how any individual agent discovers or loads skills.
- Changing skill content during the migration. The diffs against the
  pre-existing `SKILL.md` files are exactly empty.
- Per-agent skill variants. If a skill needs to differ per agent, this
  design doesn't accommodate it.

## Design

All four agents expect skills under `<root>/skills/<name>/SKILL.md` with
`name` + `description` YAML frontmatter. Only the `<root>` differs:

| Agent    | Root                       |
|----------|----------------------------|
| Claude   | `~/.claude/skills/`        |
| Cursor   | `~/.cursor/skills/`        |
| Pi       | `~/.pi/agent/skills/`      |
| Opencode | `~/.config/opencode/skills/` |

The repo holds **one** canonical `skills/` directory and **four**
package-level symlinks — one per agent — that point the agent's expected
`skills/` location at the canonical tree:

```
skills/                              ← canonical, edit here
  README.md
  llm-docs/SKILL.md
  llm-docs-true-up/SKILL.md
  pick/SKILL.md
  pr/SKILL.md
  review/SKILL.md

claude/.claude/skills            -> ../../skills
cursor/.cursor/skills            -> ../../skills
pi/.pi/agent/skills              -> ../../../skills
opencode/.config/opencode/skills -> ../../../skills
```

That's the entire design. Four symlinks, total. They never change as
skills are added, renamed, or removed.

### How it resolves at read time

`just stow` creates the usual home-dir symlinks (e.g. `~/.claude/skills →
<repo>/claude/.claude/skills`). Each of those points at the package-level
symlink, which in turn points at the canonical `skills/` directory. Two
hops, transparent to the agent:

```
~/.claude/skills/pr/SKILL.md
   ↓ stow link
<repo>/claude/.claude/skills/pr/SKILL.md
   ↓ package-level symlink (claude/.claude/skills → ../../skills)
<repo>/skills/pr/SKILL.md     ← real file
```

No change to `justfile`'s `stow` target is required. The existing
`stow --ignore='cli-config\.json' -t ~ cursor` for cursor still applies.

### Workflow

| Action | Command |
|---|---|
| Add a skill | `mkdir skills/<name> && $EDITOR skills/<name>/SKILL.md` |
| Edit a skill | edit `skills/<name>/SKILL.md` |
| Rename | `mv skills/<old> skills/<new>` |
| Delete | `rm -rf skills/<name>` |

No `just` recipe, no sync step. Every agent picks up changes
instantly because they're all reading the same file through the same
symlink chain.

### Claude `commands/` retirement

Claude previously had hand-written slash commands at
`claude/.claude/commands/{pick,pr}.md`. Claude Code also supports
`~/.claude/skills/<name>/SKILL.md` with the same shape as the other three
agents, so the bespoke slash-command files are deleted. The typed `/pr`
and `/pick` shortcuts go away; the model picks the skills up
automatically by description. If a typed shortcut is missed in practice,
a one-liner `commands/<name>.md` shim that just invokes the skill can be
added later.

### `.gitignore` interaction

`claude/.claude/` is gated by an allowlist in `.gitignore` to keep
session/log/cache files from being committed:

```gitignore
claude/.claude/*
!claude/.claude/skills
!claude/.claude/settings.json
```

The `skills` exception has **no trailing slash** because
`claude/.claude/skills` is a symlink, not a directory. A trailing-slash
form (`!claude/.claude/skills/`) would only un-ignore the directory form
and silently drop the symlink. The other three agent trees have no
comparable allowlist, so their package-level symlinks track normally.

## Considered alternatives

### Per-skill symlinks (rejected)

The first cut of this work used one symlink per agent **per skill** — 20
total for the current 5 skills, growing linearly:

```
claude/.claude/skills/pr            -> ../../../skills/pr
claude/.claude/skills/review        -> ../../../skills/review
... × 4 agents × N skills
```

Adding a skill required four `ln -s` invocations (a `just new-skill`
recipe automated this). Renaming or deleting required updating the
canonical file *and* four symlinks. The whole-dir approach drops this to
zero maintenance: the four package-level symlinks never change.

### Copy-and-sync (`just sync-skills`)

A canonical `skills/` plus a `just sync-skills` recipe that `rsync`s
`SKILL.md` into each per-agent tree. Rejected because three byte-identical
copies still live in git — duplication is just policed by a recipe instead
of by hand. Forgetting to run the sync before committing reintroduces
drift, which is exactly the failure mode the refactor was eliminating.

### Generated per-agent variants

A script that emits each agent's expected format from a single source,
including reformatting Claude slash commands. Rejected because no
agent-specific format actually differs anymore (the Claude commands are
retired, and the remaining three already share the SKILL.md shape).
Symlinks are free; a generator is not.

### `shared/` stow package

A single `shared/` stow package containing all four per-agent subtrees
under one roof. Rejected because the duplication just moves under a
different directory — strictly worse than symlinks.

## Adding a fifth agent

If a new tool ever needs the same skills, drop one symlink under its stow
package pointing at the canonical `skills/` directory, with depth chosen
to match the agent's expected path. Pattern:

```
<tool>/<expected-path-to-skills> -> <relative-path-to-repo-root>/skills
```

For example:
- `claude/.claude/skills` is two dirs deep in the package, so `../../skills`.
- `pi/.pi/agent/skills` is three dirs deep, so `../../../skills`.

No changes to `justfile` or `.gitignore` are needed unless the new tool's
package needs an allowlist similar to Claude's.
