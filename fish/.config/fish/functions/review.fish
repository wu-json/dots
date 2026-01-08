function review
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

    # launch 4 panes
    set -l pane_0 $WEZTERM_PANE
    set -l pane_2 (wezterm cli split-pane --bottom)
    set -l pane_3 (wezterm cli split-pane --pane-id $pane_2 --right)
    set -l pane_1 (wezterm cli split-pane --pane-id $pane_0 --right)

    # send review commands to each pane
    echo -e "claude /review 'Review PR #$pr_number.'" | wezterm cli send-text --no-paste --pane-id $pane_0
    echo -e "claude /review 'Review PR #$pr_number.'" | wezterm cli send-text --no-paste --pane-id $pane_1
    echo -e "claude /review 'Review PR #$pr_number. Focus on critical bugs, security vulnerabilities, and logic errors.'" | wezterm cli send-text --no-paste --pane-id $pane_2
    echo -e "claude /review 'Review PR #$pr_number. Focus on dead code, unused imports, and unreachable code paths.'" | wezterm cli send-text --no-paste --pane-id $pane_3
end
