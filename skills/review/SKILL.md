---
name: review
description: Review GitHub pull requests and code changes with `gh`, producing findings-first feedback focused on correctness, regressions, security, performance, and test coverage. Use when the user asks for a review, PR review, code review, or references a pull request.
---

# Review

Review a GitHub pull request without mutating it.

## Scope

- Use this skill for review requests only.
- Do not submit a GitHub review, add comments, edit the PR, or push changes unless the user explicitly asks.
- Prioritize real risks over style nits.

## Gather context

1. Identify the target PR.

If the user gave a PR number, use it. Otherwise:

```bash
gh pr view --json number,title,body,headRefName,baseRefName,url 2>/dev/null || gh pr list
```

If there is no PR attached to the current branch, use `gh pr list` and ask the user which PR to review when needed.

2. Inspect the PR metadata and pull the diff.

```bash
gh pr view <pr-number> --json number,title,body,headRefName,baseRefName,author,url
gh pr diff <pr-number>
```

3. If the diff is large, inspect the most relevant files directly before concluding.

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

**Outcome tags (pick exactly one line; ASCII brackets, no emoji):** `[+]` Ready · `[~]` Ready with follow-ups · `[!]` Needs changes

**`[!]` Needs changes:** Only when you have **verified** a real issue (not a misread or guess). One line each: what breaks / risk, **why merge should wait**. Nits, prefs, or unconfirmed items → findings (lower severity), Open Questions, or omit—not `[!]`.

**`[~]` Ready with follow-ups:** Safe to merge now. Under the outcome line, list each follow-up the same way as `[!]` blockers—**one concise line each**: what to do next and **why it matters** (debt, test gap, perf, etc.). Skip vague bullets.

Use this structure:

```markdown
## Findings
- High: `path/to/file` or `symbol` - issue, impact, and concrete fix
- Medium: ...

## Open Questions
- Anything ambiguous or worth confirming

## Summary
Short overview of what the PR does and any remaining risk areas.

## Outcome
`[+]` Ready
```

**Outcome with bullets** (only for `[~]` or `[!]`—one concise line per item):

`[~]` example:

```markdown
## Outcome
`[~]` Ready with follow-ups
- Add regression test for empty `items`—behavior is correct but easy to break silently later
- Document the new env var in `README`—ops will misconfigure deploys without it
```

`[!]` example:

```markdown
## Outcome
`[!]` Needs changes
- `api/handlers.go` `Submit` ignores `ctx.Err()`—in-flight requests can write after cancel; data race / duplicate rows
- Migration drops `legacy_id` with no backfill—existing rows become unreadable; merge would strand prod data
```

## Review rules

- Be concise but specific.
- Respond with exactly these sections in this order: Findings, Open Questions, Summary, Outcome.
- Report only concrete, evidence-backed issues.
- Include file paths or symbols for each finding.
- Explain why the issue matters, not just what changed.
- Suggest a concrete fix or follow-up test when possible.
- If there are no concrete findings, write `None` under Findings.
- Use exactly one outcome line with the matching tag: `[+]` Ready, `[~]` Ready with follow-ups, or `[!]` Needs changes.
- For `[!]`, bullets = verified blockers (what + why merge waits). For `[~]`, bullets = follow-ups in the **same shape** (what + why it matters). One concise line per bullet.
