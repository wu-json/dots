---
name: pr
description: Creates or updates a GitHub pull request title and description from the current branch changes. Use when the user asks to open, refresh, or rewrite a PR, or when gh-based PR metadata should match the branch diff.
---

# PR

Analyze the current branch and create or update a pull request.

## Gather context

Check whether a PR already exists and inspect the branch changes:

```bash
gh pr view --json title,body,headRefName,baseRefName 2>/dev/null || echo "NO_PR_EXISTS"
git log origin/main..HEAD --oneline
git diff origin/main..HEAD --stat
```

## Workflow

1. If the branch is not on the remote yet, push it first:

```bash
git push -u origin HEAD
```

2. If `gh pr view` returned `NO_PR_EXISTS`, create a PR with `gh pr create`.
3. Otherwise update the existing PR with `gh pr edit`.

## Title format

Use semantic commit style prefixes:

- `feat:` new features
- `fix:` bug fixes
- `refactor:` code refactoring
- `chore:` maintenance tasks
- `docs:` documentation
- `style:` formatting-only changes
- `test:` tests

## Body format

Use this structure:

```markdown
## Summary
1-2 sentence summary of what this PR does.

## Commentary
Brief additional context or implementation notes if needed. Omit if not necessary.
```

Use a HEREDOC for the body to preserve formatting.

If the user provides additional notes or context they want included in the PR body, append a `## Human Notes` section at the end with that content. Only include this section when explicitly requested — omit it by default.

Do not attribute the PR to Cursor, any other AI tool, or any assistant in the title or body. Omit footers and phrases like "Generated with Cursor", "Generated with Claude Code", Copilot, or similar.
