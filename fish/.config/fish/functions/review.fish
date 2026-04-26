function review
    # Usage: review [1-4] [--model PATTERN]
    # Drives interactive `pi` (full TUI in each pane so you can watch
    # progress) with the no-edit review tool allowlist
    # (read,grep,find,ls,bash). Default model is anthropic/claude-opus-4-7
    # with --thinking high; --model overrides.
    set -l num_panes 4
    set -l model_override ""
    set -l saw_panes false

    set -l i 1
    set -l argc (count $argv)
    while test $i -le $argc
        switch $argv[$i]
            case --model
                set i (math $i + 1)
                if test $i -gt $argc
                    echo "Missing value for --model"
                    return 1
                end
                # Charset guard: the override is concatenated into a string
                # that gets sent to the pane's fish via send-text, so a value
                # like `--model 'foo; rm -rf ~/x'` would be parsed as two
                # commands. Restrict to characters that appear in real model
                # ids (provider/id[:tag] for both anthropic and ollama).
                if not string match -rq '^[A-Za-z0-9._/:-]+$' -- $argv[$i]
                    echo "Invalid --model value: '$argv[$i]' (allowed: A-Z a-z 0-9 . _ / : -)"
                    return 1
                end
                set model_override $argv[$i]
            case '*'
                if string match -rq '^[1-4]$' -- $argv[$i]
                    if test "$saw_panes" = true
                        echo "Pane count specified more than once"
                        return 1
                    end
                    set num_panes $argv[$i]
                    set saw_panes true
                else
                    echo "Invalid argument: $argv[$i] (pane count 1-4 or --model PATTERN)"
                    return 1
                end
        end
        set i (math $i + 1)
    end

    if test $num_panes -lt 1 -o $num_panes -gt 4
        echo "Number of panes must be between 1 and 4"
        return 1
    end

    # get current PR number
    set -l pr_number (gh pr view --json number -q .number 2>/dev/null)
    if test -z "$pr_number"
        echo "No PR found for current branch"
        return 1
    end

    # Resolve model: default to anthropic/claude-opus-4-7, allow --model override.
    # Suppress explicit --thinking when the override encodes a :level suffix
    # matching pi's thinking vocabulary (off|minimal|low|medium|high|xhigh).
    # Last-:-suffix detection is required because ollama tags use ':' natively.
    set -l model anthropic/claude-opus-4-7
    if test -n "$model_override"
        set model $model_override
    end

    set -l thinking_levels off minimal low medium high xhigh
    set -l suffix (string match -rg '^.*:([^:]+)$' -- $model)
    set -l pi_base "pi --no-session"
    if not contains -- "$suffix" $thinking_levels
        set pi_base "$pi_base --thinking high"
    end
    set pi_base "$pi_base --model $model"

    set -l review_cmd "$pi_base --tools read,grep,find,ls,bash"

    # pane identities
    # 0 - top left
    # 1 - top right
    # 2 - bottom left
    # 3 - bottom right

    # launch panes based on num_panes
    set -l pane_0 $WEZTERM_PANE
    set -l pane_1
    set -l pane_2
    set -l pane_3

    if test $num_panes -ge 2
        set pane_1 (wezterm cli split-pane --pane-id $pane_0 --right)
    end

    if test $num_panes -ge 3
        set pane_2 (wezterm cli split-pane --pane-id $pane_0 --bottom)
    end

    if test $num_panes -ge 4
        set pane_3 (wezterm cli split-pane --pane-id $pane_1 --bottom)
    end

    # send review commands to each pane
    printf '%s\r' "$review_cmd \"You are Evelyn. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format.\"" | wezterm cli send-text --no-paste --pane-id $pane_0

    if test $num_panes -ge 2
        printf '%s\r' "$review_cmd \"You are Vivian. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format.\"" | wezterm cli send-text --no-paste --pane-id $pane_1
    end

    if test $num_panes -ge 3
        printf '%s\r' "$review_cmd \"You are Stella. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format. Focus on critical bugs, security vulnerabilities, and logic errors.\"" | wezterm cli send-text --no-paste --pane-id $pane_2
    end

    if test $num_panes -ge 4
        printf '%s\r' "$review_cmd \"You are Tiffany. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format. Focus on dead code, unused imports, and unreachable code paths.\"" | wezterm cli send-text --no-paste --pane-id $pane_3
    end
end
