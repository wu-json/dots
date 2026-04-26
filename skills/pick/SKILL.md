---
name: pick
description: Uses pickpocket vendored clones for external codebase context. Use when the task mentions pickpocket, `pick`, vendored repositories, repo context from `pickpocket.json`, or exploring cached external repos.
---

# Pick

This project uses **pickpocket** to manage vendored git clones as LLM context. Repositories are declared in `pickpocket.json` and installed into a global cache for fast local access.

## Discover picks

Start by listing available picks and tags:

```bash
pick tag list
pick list
pick list --tag <tag>
pick list --json
```

Use the **ID** column from `pick list` in later commands, for example `github.com/user/repo@main`.

## Open a pick for exploration

Use `pick open <id>` to create an ephemeral writable worktree in `/tmp/pickpocket/`:

```bash
pick open github.com/user/repo@main
```

Use that worktree to read, grep, build, and experiment without touching the shared cache. Worktrees auto-prune after 24 hours, or can be removed immediately with:

```bash
pick open --clean
```

Prefer `pick open` over `pick path`. Paths returned by `pick path` point at the shared cache and should be treated as read-only.

## Get cache paths

Use these commands when a read-only filesystem path is enough:

```bash
pick path
pick path <id>
pick path --tag <tag>
```

## Add new repos

Add a repository to the Pickfile and clone it:

```bash
pick <url> [--tag <tag>] [--branch <branch>]
```

`--tag` is repeatable and can be used for later filtering.

## Other useful commands

```bash
pick info <id>
pick update
```
