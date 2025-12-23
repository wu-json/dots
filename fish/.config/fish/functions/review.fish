function review
    # Define the 4 review prompts
    set -l prompt1 'Review the PR for the checked out branch. Focus on finding critical bugs, security vulnerabilities, and logic errors.'
    set -l prompt2 'Review the PR for the checked out branch. Focus on finding dead code, unused imports, and unreachable code paths.'
    set -l prompt3 'Review the PR for the checked out branch. Provide a general code review covering style, readability, and best practices.'
    set -l prompt4 'Review the PR for the checked out branch. Provide a general code review covering architecture, design patterns, and maintainability.'

    # Get current pane ID
    set -l current_pane (wezterm cli list --format json | jq -r '.[] | select(.is_active) | .pane_id')

    # Create 2x2 grid layout
    # Split right to create right column
    set -l right_pane (wezterm cli split-pane --pane-id $current_pane --right --percent 50 -- fish -c "claude /review $prompt2")

    # Split current (left) pane down to create bottom-left
    set -l bottom_left_pane (wezterm cli split-pane --pane-id $current_pane --bottom --percent 50 -- fish -c "claude /review $prompt3")

    # Split right pane down to create bottom-right
    set -l bottom_right_pane (wezterm cli split-pane --pane-id $right_pane --bottom --percent 50 -- fish -c "claude /review $prompt4")

    # Clear the current pane
    clear
    commandline -r ''
    commandline -f repaint

    # Run the first reviewer (critical bugs) in the current pane (top-left)
    claude /review $prompt1
end
