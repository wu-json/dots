function git_auto_commit
    git add .

    # Empty-diff guard — gemma4:e2b will happily hallucinate a message otherwise.
    if git diff --cached --quiet
        echo "Nothing to commit"
        return 0
    end

    set -l prompt 'Write a one-line conventional-commit message for the changes already staged.

Steps:
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
