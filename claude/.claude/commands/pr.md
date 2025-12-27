---
allowed-tools: Bash(gh pr view:*), Bash(gh pr edit:*), Bash(gh pr create:*), Bash(git log:*), Bash(git diff:*), Bash(git push:*)
description: Create or update PR title and description based on changes
---

Analyze the current branch and create or update a PR.

Current PR info:
!`gh pr view --json title,body,headRefName,baseRefName 2>/dev/null || echo "NO_PR_EXISTS"`

Commits in this PR:
!`git log origin/main..HEAD --oneline`

Diff summary:
!`git diff origin/main..HEAD --stat`

## Instructions

If no PR exists (`NO_PR_EXISTS`), create one with `gh pr create`. Otherwise update with `gh pr edit`.

Push the branch first if needed with `git push -u origin HEAD`.

**Title format**: Use semantic commit style:
- `feat:` new features
- `fix:` bug fixes
- `refactor:` code refactoring
- `chore:` maintenance tasks
- `docs:` documentation
- `style:` formatting
- `test:` tests

**Description format**:
```
## Summary
1-2 sentence summary of what this PR does.

## Commentary
Brief additional context or implementation notes if needed. Omit if not necessary.
```

Use HEREDOC for the body to preserve formatting.

**Do NOT include any "Generated with Claude Code" attribution or similar footer.**
