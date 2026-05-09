function gc
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
4. Pick ONE message: <type>: <lowercase summary>
   - Types: feat, fix, chore, docs, refactor, style, test, perf, build, ci
   - Under 60 chars. No trailing period. No body. No surrounding quotes.
5. Run: git commit -m "<your message>"

Do not push. Do not amend. Do not stage anything else. Print the message after committing and stop.'

    pi --no-session \
        --model ollama/gemma4:e2b \
        --tools read,grep,find,ls,bash \
        "$prompt"
end
