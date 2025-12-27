---
allowed-tools: Bash(git diff:*), Read, Edit, Glob
description: Remove useless comments that just echo what the code already says
---

Find and remove comments in the codebase that add no semantic value - comments that merely restate what the code already clearly expresses.

Changed files in this branch:
!`git diff origin/main..HEAD --name-only`

## What to Remove

**Useless comments** that should be removed:
- Comments that just restate the code: `// increment counter` above `counter++`
- Obvious variable explanations: `// the user's name` above `const userName = ...`
- Function name echoing: `// gets the user` above `function getUser()`
- Redundant section markers: `// loop through items` above `for (item of items)`
- Trivial explanations: `// return the result` above `return result`
- Empty or placeholder comments: `// TODO` with no context, `// ...`

## What to Keep

**Valuable comments** that should be preserved:
- **Why** explanations: business logic reasoning, non-obvious decisions
- Workarounds with context: `// Safari doesn't support X, so we...`
- Complex algorithm explanations
- API documentation (JSDoc with meaningful descriptions)
- Legal/license headers
- Links to issues, specs, or documentation
- Performance notes: `// O(n) - acceptable for small lists`
- Security considerations
- Type annotations that add clarity beyond TypeScript types

## Instructions

1. Read each changed file
2. Identify comments that merely echo what the code already says
3. Remove only the useless comments using the Edit tool
4. Do NOT remove comments that explain "why" or provide context
5. Do NOT modify any actual code logic
6. Report what was removed

When in doubt, keep the comment. Only remove comments that are obviously redundant.
