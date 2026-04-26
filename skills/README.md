# skills

Canonical agent skills. One copy, four agents.

## Layout

```
skills/<name>/SKILL.md      <-- the only thing you ever edit

claude/.claude/skills            -> ../../skills
cursor/.cursor/skills            -> ../../skills
pi/.pi/agent/skills              -> ../../../skills
opencode/.config/opencode/skills -> ../../../skills
```

Each agent's `skills/` directory is a symlink to *this* directory. Every
skill in here is automatically visible to Claude, cursor, pi, and
opencode. There are no per-skill symlinks and no generated state.

## Workflow

| Action | Command |
|---|---|
| Add a skill | `mkdir skills/<name> && $EDITOR skills/<name>/SKILL.md` |
| Edit a skill | edit `skills/<name>/SKILL.md` |
| Rename | `mv skills/<old> skills/<new>` |
| Delete | `rm -rf skills/<name>` |

That's it. No `just` recipe, no sync step.

## SKILL.md format

```yaml
---
name: <name>
description: One-line trigger blurb. "Use when the user asks for X."
---

# <name>

Body of the skill.
```
