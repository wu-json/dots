---
name: llm-docs
description: >-
  Workflow for bug reports, feature specs, research markdown, and learnings under
  docs/wu-json (wu-json). Covers directory layout, file naming,
  draft → review → implement → archive cycle, and optional status frontmatter.
  Use when creating or editing that llm-docs tree, moving docs to archive, or
  when the user mentions wu-json llm-docs, bug specs, research docs, or learnings there.
---

# wu-json llm-docs

Personal markdown for LLM-assisted bug reports, implementation specs, research notes, and learnings. Root:

`docs/wu-json`

## Layout

| Path | Use |
|------|-----|
| `bugs/` | Bug reports and repro notes |
| `specs/` | Feature / change specs (implementation intent) |
| `research/` | Exploration, comparisons, background (may or may not become a spec) |
| `learnings/` | Durable reference docs — protocols, patterns, domain knowledge discovered during investigations. |
| `bugs/archived/`, `specs/archived/`, `research/archived/`, `learnings/archived/` | Finished docs after implementation or when no longer active |

Keep a doc in the **category root** (`bugs/`, `specs/`, `research/`, or `learnings/`) while it is live. Move it into that category's `archived/` subdirectory when the cycle below is complete.

## Naming convention

**Filename:** `YYYY-MM-DD-short-kebab-title.md`

- **Date:** ISO date (creation or first serious draft — pick one doc and stay consistent).
- **Slug:** lowercase, hyphen-separated, no spaces; enough tokens to find the doc later (product area, component, gist of issue).

Examples (pattern only): `2026-03-27-pr-reviewer-auto-approve-authors.md`, `2026-03-23-sand-agent-stale-executor-after-disk-write.md`.

## Workflow

1. **Draft** — Have the coding agent write or extend a bug doc, spec, or research note under the right category (not in `archived/`).
2. **Review loop** — Read it, request revisions, repeat until the content matches intent. Body structure is intentionally freeform (headings, goals/non-goals, design, snippets, etc.).
3. **Rip** — When satisfied, have the agent **implement** the work described in the doc (the "rip through it" step).
4. **Archive** — Move the markdown file into the matching `archived/` folder (`specs/foo.md` → `specs/archived/foo.md`). Same filename; only the directory changes.

If a research doc spawns a spec, you can keep both or archive the research when the spec supersedes it — no strict rule.

## Optional status (recommended for new docs)

Older files have no standard status field; that is fine.

For **new** docs, add YAML frontmatter at the top so agents and greps know where the doc is in the cycle:

```yaml
---
status: draft
---
```

Suggested values:

| Value | Meaning |
|-------|---------|
| `draft` | Still iterating with the agent or editor |
| `ready` | Content is approved; safe to implement from this doc |
| `implemented` | Rip is done; file is about to move (or has just moved) to `archived/` |

Update `status` as the doc progresses. Archived files may keep `status: implemented` or drop frontmatter — either is fine.

## Agent behavior summary

- **New work:** create under `bugs/`, `specs/`, `research/`, or `learnings/` with the naming pattern; set `status: draft` if using frontmatter.
- **Edits:** prefer updating the existing file in place during review.
- **Done:** implement from the doc, then `git mv` (or move) the file into `.../archived/` preserving the basename.
- **Learnings:** durable knowledge docs (protocols, patterns, domain context) discovered during bug investigations or research. Same naming convention; archivable like all other categories.
