function review
    # Usage: review [1-4] [openai|anthropic] — args can be in any order.
    # Default: 4 panes, anthropic (claude-4.6-opus-high). openai → gpt-5.4-high.
    # Uses --yolo so agents can run shell tools (gh cli, git, etc.) for PR inspection.
    set -l num_panes 4
    set -l provider anthropic
    set -l saw_panes false

    for token in $argv
        set -l t (string lower $token)
        if contains -- $t openai anthropic
            set provider $t
        else if string match -rq '^[1-4]$' -- $token
            if test "$saw_panes" = true
                echo "Pane count specified more than once"
                return 1
            end
            set num_panes $token
            set saw_panes true
        else
            echo "Invalid argument: $token (pane count 1-4, provider openai or anthropic)"
            return 1
        end
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

    set -l review_model gpt-5.4-high
    switch $provider
        case anthropic
            set review_model claude-4.6-opus-high
    end

    set -l review_cmd "cursor-agent --yolo --model $review_model -p"

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
