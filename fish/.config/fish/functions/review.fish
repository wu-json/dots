function review
     # Usage: review [1-4] [--model PATTERN] [--help]
     # Drives interactive `pi` (full TUI in each pane so you can watch
     # progress) with the no-edit review tool allowlist
     # (read,grep,find,ls,bash). Default model is anthropic/claude-opus-4-7
     # with --thinking high; --model overrides. Default: 1 reviewer (Evelyn).
    set -l num_panes 1
    set -l model_override ""
    set -l saw_panes false
    set -l show_help false

    set -l i 1
    set -l argc (count $argv)
    while test $i -le $argc
        switch $argv[$i]
            case '-h' '--help'
                set show_help true
            case '--model'
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


    # Resolve model aliases: opus, qwen, or pass through full provider strings
    switch $model_override
        case ''
            # Empty — no alias resolution needed, skip to assignment below
        case opus
            set model_override "anthropic/claude-opus-4-7"
        case qwen
            set model_override "ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8"
        case '*'
            # Not a recognized alias — check if it's a full provider string (contains '/')
            if not string match -q '*/*' -- $model_override
                echo "Unknown model alias: '$model_override'" >&2
                echo "Full provider strings (containing '/') are passed through as-is." >&2
                echo "Available aliases: opus, qwen" >&2
                return 1
            end
            # Full provider string — no conversion needed; fall through
    end

    if test $num_panes -lt 1 -o $num_panes -gt 4
        echo "Number of panes must be between 1 and 4"
        return 1
    end

    if test $show_help = true
        echo "Usage: review [1-4] [--model PATTERN] [--help]"
        echo ""
        echo "Drives interactive pi review in a Wezterm multi-pane layout."
        echo ""
        echo "Arguments:"
        echo "   1-4                 Number of reviewer panes (default: 1)"
        echo "   --model PATTERN     Provider/model id, e.g."
        echo "                         anthropic/claude-opus-4-7"
        echo "                         ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8"
        echo "   --help, -h          Show this help message"
        echo ""
        echo "Input configuration:"
        echo "   - model is set via --model (default: anthropic/claude-opus-4-7)."
        echo "   - agent count via positional arg 1-4 (default: 1)."
        echo ""
        echo "Aliases:"
        echo "   opus          → anthropic/claude-opus-4-7"
        echo "   qwen          → ollama-tailnet/qwen3.6:35b-a3b-coding-mxfp8"
        echo "   Full provider strings (e.g. openai/gpt-5.5-high) are passed through as-is."
        echo ""
        echo "Examples:"
        echo "  review                                   # 1 reviewer (Evelyn), default model"
        echo "  review 3 --model opus                    # 3 reviewers, Opus 4.7"
        echo "  review 3 --model qwen                    # 3 reviewers, Qwen 3.6 on tailnet"
        echo "  review 3 --model ollama-local/qwen3.6    # 3 reviewers, local model"
        return 0
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
