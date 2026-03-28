---
name: review
description: Review GitHub pull requests and code changes with `gh` and Graphite CLI, producing findings-first feedback focused on correctness, regressions, security, performance, and test coverage. Use when the user asks for a review, PR review, code review, references a pull request, or mentions Graphite stacks or `gt parent`.
---

# Review

Review a GitHub pull request without mutating it.

## Scope

- Use this skill for review requests only.
- Do not submit a GitHub review, add comments, edit the PR, or push changes unless the user explicitly asks.
- Prioritize real risks over style nits.
- Understand Graphite stacks and prefer the incremental stacked diff when applicable.

## Gather context

1. Identify the target PR.

If the user gave a PR number, use it. Otherwise:

```bash
gh pr view --json number,title,body,headRefName,baseRefName,url 2>/dev/null || gh pr list
```

If there is no PR attached to the current branch, use `gh pr list` and ask the user which PR to review when needed.

2. Check whether the branch is part of a Graphite stack.

Use Graphite when available:

```bash
gt parent
```

If `gt parent` succeeds, the current branch is stacked. Treat that branch as the review base. Use `gt ls` if you need more stack context.

3. Inspect the PR metadata and choose the correct diff.

```bash
gh pr view <pr-number> --json number,title,body,headRefName,baseRefName,author,url
```

For a normal branch, review the PR diff:

```bash
gh pr diff <pr-number>
```

For a Graphite stacked branch, review the incremental diff against the parent branch instead of the full PR diff:

```bash
git diff "$(gt parent)"...HEAD
git log --oneline "$(gt parent)"..HEAD
```

4. If the diff is large, inspect the most relevant files directly before concluding.

## What to look for

Focus on:

- Correctness and logic bugs
- Behavioral regressions and edge cases
- Security and data exposure risks
- Performance and scalability implications
- Test coverage and validation gaps

Secondary concerns:

- Maintainability
- Readability when it affects correctness
- Dead code or unreachable paths

## Response format

Lead with findings. Order them by severity. Keep the overview brief.

Use this structure:

```markdown
## Findings
- High: `path/to/file` or `symbol` - issue, impact, and concrete fix
- Medium: ...

## Open Questions
- Anything ambiguous or worth confirming

## Merge Recommendation
Ready, Ready with follow-ups, or Needs changes.

## Summary
Short overview of what the PR does and any remaining risk areas.
```

## Review rules

- Be concise but specific.
- Respond with exactly these sections in this order: Findings, Open Questions, Merge Recommendation, Summary.
- Report only concrete, evidence-backed issues.
- Include file paths or symbols for each finding.
- Explain why the issue matters, not just what changed.
- Suggest a concrete fix or follow-up test when possible.
- If there are no concrete findings, write `None` under Findings.
- Use exactly one merge recommendation: `Ready`, `Ready with follow-ups`, or `Needs changes`.
