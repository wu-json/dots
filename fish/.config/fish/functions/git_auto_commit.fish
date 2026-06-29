function git_auto_commit
    git add .

    # Empty-diff guard — qwen3.5:9b will happily hallucinate a message otherwise.
    if git diff --cached --quiet
        echo "Nothing to commit"
        return 0
    end

    set -l prompt 'You are running inside the user\'s shell. Staged changes are waiting to be committed.

Your task: execute `git commit -m "<message>"` via the bash tool, then confirm with `git log -1 --oneline` that the new commit sits on top of the branch. Success = that new commit exists in `git log` when you stop.

Orient yourself first — a good summary needs project context:
  - Project shape: ls the root, read README.md or CLAUDE.md if present.
  - Branch state: `git rev-parse --abbrev-ref HEAD`, `git status`, `git log main..HEAD --oneline` (or master..HEAD).
  - Larger goal: `gh pr view --json title,body,headRefName 2>/dev/null` if a PR is open.
  - Files touched by the diff when intent is unclear from the diff alone.

Then:
1. git diff --cached --stat
2. git diff --cached
3. git log --oneline -10  (match its terse tone)
4. Pick ONE message: <type>(<optional scope>): <summary>
   - Types: feat, fix, chore, docs, refactor, style, test, perf, build, ci
   - Summary starts lowercase (uppercase mid-sentence is fine for identifiers, acronyms, proper nouns).
   - Single line, bare text — keep it concise.
   - Name the concrete value, flag, identifier, file, or behavior that moved so a reader can match the summary to the diff at a glance. When the diff touches several things, lead with the single most distinctive sub-change.
   - Use a verb that names the operation: rename, drop, switch, add, remove, raise, lower, merge, split, inline, extract.
   - Examples:
     - "feat: add gc alias for auto commit messages via pi"
     - "refactor: rename gc function to git_auto_commit"
     - "fix: handle empty diff in git_auto_commit"
     - "docs(llm): archive pi auto-commit-message research"
     - "chore: remove jj, k9s from brew"
5. Execute `git commit -m "<your message>"` via the bash tool.
6. Run `git log -1 --oneline` — when your new commit sits on top, the task is complete.'

    pi --no-session \
        --model ollama/qwen3.5:9b \
        --tools read,grep,find,ls,bash \
        "$prompt"
end
