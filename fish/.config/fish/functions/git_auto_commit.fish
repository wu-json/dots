function git_auto_commit
    git add .

    # Empty-diff guard — gemma4:e2b will happily hallucinate a message otherwise.
    if git diff --cached --quiet
        echo "Nothing to commit"
        return 0
    end

    set -l prompt 'You are running inside the user\'s shell. The user has staged changes and is waiting for you to commit them. Your job is to create a real new git commit on this branch by invoking the bash tool to run `git commit`. The task is complete only when a new commit object exists in the repo, verified by `git log -1`.

Every git command below must be executed by calling the bash tool with that command as its argument. The bash tool is the only mechanism that produces a real commit; treat it as the sole way to act.

Orient yourself first. You will write a far better summary if you understand the project, what branch you are on, and what work this commit fits into. Explore freely with the tools you have — read, grep, find, ls, bash — and use as many or as few of these as you need:
  - Check what kind of repo this is: ls the root, read README.md or CLAUDE.md if present.
  - Find your bearings on the branch: `git rev-parse --abbrev-ref HEAD`, `git status`, `git log main..HEAD --oneline` (or master..HEAD) to see commits unique to this branch.
  - If there is an open PR, peek at it: `gh pr view --json title,body,headRefName 2>/dev/null` — the PR title/description tells you the larger goal this commit is part of.
  - Read any files touched by the staged diff if the change is unclear from the diff alone — context from neighboring code often clarifies intent.

Then produce the commit. Each numbered step is one bash tool invocation that you must perform yourself:
1. Invoke bash: git diff --cached --stat
2. Invoke bash: git diff --cached
3. Invoke bash: git log --oneline -10  (match its terse tone)
4. Pick ONE message: <type>(<optional scope>): <summary>
   - Types: feat, fix, chore, docs, refactor, style, test, perf, build, ci
   - The summary MUST start with a lowercase letter. Uppercase is fine mid-sentence for identifiers, acronyms, or proper nouns.
   - Length: 60 chars or fewer. End with a letter. Single line only. Bare text only — the message stands on its own.
   - Examples:
     - "feat: add gc alias for auto commit messages via pi"
     - "refactor: rename gc function to git_auto_commit"
     - "fix: handle empty diff in git_auto_commit"
     - "docs(llm): archive pi auto-commit-message research"
     - "chore: remove graphite, jj, k9s from brew"
5. Invoke bash: git commit -m "<your message>"  ← this is the commit. The user is waiting for this exact bash call to run.
6. Invoke bash: git log -1 --oneline  ← if the new commit is on top, the task is complete. Otherwise return to step 5 and run the commit again.

Scope of allowed actions: stage is already done by the wrapper, so you only need to run the inspection commands in steps 1-3, the commit in step 5, and the verification in step 6. Once step 6 shows your commit on top, print the message you used and stop.'

    pi --no-session \
        --model ollama-local/gemma4:e2b \
        --tools read,grep,find,ls,bash \
        "$prompt"
end
