# Pickpocket — Vendored Clone Manager for LLM Context

This project uses **pickpocket** to manage vendored git clones as LLM context. Repositories are declared in a `pickpocket.json` file and installed into a global cache, giving you fast, local access to external codebases.

## Workflow

### 1. List picks to discover IDs

Run `pick list` to see all declared picks. The **ID** column (e.g. `github.com/user/repo@main`) is how you reference a pick in every other command.

- `pick tag list` — list all tags in use (run this first to discover available tags)
- `pick list --tag <tag>` — filter picks by tag
- `pick list --json` — machine-readable output with URL, branch, commit, and tags

### 2. Open a pick for exploration

`pick open <id>` creates an ephemeral writable worktree in `/tmp/pickpocket/` and prints the path to stdout. The `<id>` **must** be a value from the ID column of `pick list`.

Example: `pick open github.com/user/repo@main`

Use this worktree to freely read, grep, build, and experiment without touching the cached clone. Worktrees auto-prune after 24 hours, or run `pick open --clean` to remove them immediately.

**Prefer `pick open` over `pick path`** — paths from `pick path` point to the shared cache and should be treated as read-only.

### 3. Get filesystem paths (read-only)

- `pick path` — print absolute cache paths for all picks
- `pick path <id>` — print the cache path for a specific pick
- `pick path --tag <tag>` — print paths filtered by tag

## Add new repos

`pick <url>` adds a repo to the Pickfile and clones it. Optional flags:
- `--tag <tag>` (repeatable) — attach tags for filtering
- `--branch <branch>` — track a specific branch

## Other useful commands

- `pick info <id>` — detailed info about a specific pick
- `pick update` — fetch latest commits for all picks
