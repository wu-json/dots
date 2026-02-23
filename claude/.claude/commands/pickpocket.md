# Pickpocket — Vendored Clone Manager for LLM Context

This project uses **pickpocket** to manage vendored git clones as LLM context. Repositories are declared in a `pickpocket.json` file and cloned into a local `.picks/` directory, giving you fast, local access to external codebases.

## Discover available picks

Run `pick list --json` to see all declared picks with their URL, branch, commit, and tags.

## Get filesystem paths

- `pick path` — print absolute paths to all vendored repos, one per line
- `pick path <id>` — print the absolute path to a specific repo
- `pick path --tag <tag>` — print paths filtered by tag

Use these paths to read files and grep through vendored code directly on the filesystem.

## Explore vendored code

**Always use `pick open <id>` to create a temporary worktree before exploring vendored code.** This gives you a writable copy in `/tmp/pickpocket/` where you can freely read, grep, build, and experiment without touching the cached clone. Worktrees auto-prune after 24 hours, or you can run `pick open --clean` to remove them immediately.

Prefer `pick open` over reading directly from `pick path` paths, which point to the shared cache and should be treated as read-only.

## Add new repos

`pick <url>` adds a repo to the Pickfile and clones it. Optional flags:
- `--tag <tag>` (repeatable) — attach tags for filtering
- `--branch <branch>` — track a specific branch

## Other useful commands

- `pick info <id>` — detailed info about a specific pick
- `pick update` — fetch latest commits for all picks
