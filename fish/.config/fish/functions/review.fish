function review
    # get number of panes (default 4)
    set -l num_panes 4
    if test (count $argv) -ge 1
        set num_panes $argv[1]
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
    echo -e "claude 'Use /review to review PR #$pr_number. Do not mutate the PR in any way, just provide a review.'" | wezterm cli send-text --no-paste --pane-id $pane_0

    if test $num_panes -ge 2
        echo -e "claude 'Use /review to review PR #$pr_number. Do not mutate the PR in any way, just provide a review.'" | wezterm cli send-text --no-paste --pane-id $pane_1
    end

    if test $num_panes -ge 3
        echo -e "claude 'Use /review to review PR #$pr_number. Focus on critical bugs, security vulnerabilities, and logic errors. Do not mutate the PR in any way, just provide a review.'" | wezterm cli send-text --no-paste --pane-id $pane_2
    end

    if test $num_panes -ge 4
        echo -e "claude 'Use /review to review PR #$pr_number. Focus on dead code, unused imports, and unreachable code paths. Do not mutate the PR in any way, just provide a review.'" | wezterm cli send-text --no-paste --pane-id $pane_3
    end
end
