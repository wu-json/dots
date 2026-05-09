function git_auto_commit
    git add .

    # Empty-diff guard — gemma4:e2b will happily hallucinate a message otherwise.
    if git diff --cached --quiet
        echo "Nothing to commit"
        return 0
    end

    set -l prompt 'Write a one-line conventional-commit message for the changes already staged.

Orient yourself before writing the message. You will write a far better summary if you understand the project, what branch you are on, and what work this commit fits into. Explore freely with the tools you have — read, grep, find, ls, bash — and use as many or as few of these as you need:
  - Check what kind of repo this is: ls the root, read README.md or CLAUDE.md if present.
  - Find your bearings on the branch: `git rev-parse --abbrev-ref HEAD`, `git status`, `git log main..HEAD --oneline` (or master..HEAD) to see commits unique to this branch.
  - If there is an open PR, peek at it: `gh pr view --json title,body,headRefName 2>/dev/null` — the PR title/description tells you the larger goal this commit is part of.
  - Read any files touched by the staged diff if the change is unclear from the diff alone — context from neighboring code often clarifies intent.

Then produce the commit:
1. Run: git diff --cached --stat
2. Run: git diff --cached
3. Run: git log --oneline -10  (match its terse tone)
4. Pick ONE message: <type>(<optional scope>): <summary>
   - Types: feat, fix, chore, docs, refactor, style, test, perf, build, ci
   - The summary MUST start with a lowercase letter. Uppercase is fine mid-sentence for identifiers, acronyms, or proper nouns.
   - Under 60 chars. No trailing period. No body. No surrounding quotes.
   - Examples:
     - "feat: add gc alias for auto commit messages via pi"
     - "refactor: rename gc function to git_auto_commit"
     - "fix: handle empty diff in git_auto_commit"
     - "docs(llm): archive pi auto-commit-message research"
     - "chore: remove graphite, jj, k9s from brew"
5. Run: git commit -m "<your message>"

Do not push. Do not amend. Do not stage anything else. Print the message after committing and stop.'

    pi --no-session \
        --model ollama/gemma4:e2b \
        --tools read,grep,find,ls,bash \
        "$prompt"
end
