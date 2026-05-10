function git_auto_commit
    git add .

    # Empty-diff guard — qwen3.5:9b will happily hallucinate a message otherwise.
    if git diff --cached --quiet
        echo "Nothing to commit"
        return 0
    end

    set -l prompt 'You are running inside the user\'s shell. The user has staged changes and is waiting for you to commit them.

YOU MUST EXECUTE THE COMMIT. The one action that completes this task is invoking the bash tool to actually run `git commit -m "<message>"`, and then confirming with `git log -1 --oneline` that your new commit sits on top of the branch. Success means the new commit exists in `git log` after this run finishes.

The staged changes have already been verified to exist — there is real work to commit, and an actual `git commit` execution via the bash tool is required before you stop.

Orient yourself first. You will write a far better summary if you understand the project, what branch you are on, and what work this commit fits into. Explore freely with the tools you have — read, grep, find, ls, bash:
  - Check what kind of repo this is: ls the root, read README.md or CLAUDE.md if present.
  - Find your bearings on the branch: `git rev-parse --abbrev-ref HEAD`, `git status`, `git log main..HEAD --oneline` (or master..HEAD) to see commits unique to this branch.
  - If there is an open PR, peek at it: `gh pr view --json title,body,headRefName 2>/dev/null` — the PR title/description tells you the larger goal this commit is part of.
  - Read any files touched by the staged diff if the change is unclear from the diff alone — context from neighboring code often clarifies intent.

Then produce the commit:
1. git diff --cached --stat
2. git diff --cached
3. git log --oneline -10  (match its terse tone)
4. Pick ONE message: <type>(<optional scope>): <summary>
   - Types: feat, fix, chore, docs, refactor, style, test, perf, build, ci
   - The summary MUST start with a lowercase letter. Uppercase is fine mid-sentence for identifiers, acronyms, or proper nouns.
   - Length: 60 chars or fewer. End with a letter. Single line only. Bare text only — the message stands on its own.
   - Be specific about the actual change: name the concrete value, flag, identifier, file, or behavior that moved, so a reader could match the summary to the diff at a glance. Pull the most identifying detail from the diff into the summary.
   - When the diff touches several things, lead with the single most distinctive sub-change. The summary names the headline; the diff carries the rest.
   - Use a verb that already names the operation itself — rename, drop, switch, add, remove, raise, lower, merge, split, inline, extract — so the verb alone narrows what changed.
   - Examples:
     - "feat: add gc alias for auto commit messages via pi"
     - "refactor: rename gc function to git_auto_commit"
     - "fix: handle empty diff in git_auto_commit"
     - "docs(llm): archive pi auto-commit-message research"
     - "chore: remove graphite, jj, k9s from brew"
5. EXECUTE `git commit -m "<your message>"` via the bash tool right now. Make an actual bash tool call so the commit lands on the branch. This step is the whole point of the run.
6. git log -1 --oneline  ← when the new commit is on top, the task is complete. If it is not yet on top, return to step 5 and execute `git commit` again until it lands.

The changes are already staged. Run the inspection commands in steps 1-3, EXECUTE the commit in step 5 (actual bash tool call), and verify in step 6. Finish only after step 5 has executed and step 6 confirms the new commit is on top.'

    pi --no-session \
        --model ollama-local/qwen3.5:9b \
        --tools read,grep,find,ls,bash \
        "$prompt"
end
