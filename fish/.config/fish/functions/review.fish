function review
    # Default to claude if no argument provided
    set -l tool claude
    set -l command 'claude /review Review the PR for the checked out branch'

    # Check if an argument was provided
    if test (count $argv) -gt 0
        set tool $argv[1]
        if test "$tool" = "claude"
            set command 'claude /review Review the PR for the checked out branch'
        else if test "$tool" = "codex"
            set command 'codex /review'
        else
            echo "Unknown tool: $tool. Use 'codex' or 'claude'."
            return 1
        end
    end

    # Store the current pane ID
    set current_pane (wezterm cli get-pane-direction here)

    # Split the pane and run the appropriate command in the new pane
    wezterm cli split-pane --right -- fish -c "$command"

    # Clear the current pane to align both panes vertically
    # The new pane starts fresh without a prompt, so we clear this pane too
    # to avoid height offset from the shell prompt appearing at the top
    clear
    # Clear any pending input in the command line buffer
    commandline -r ''
    commandline -f repaint

    # Run the appropriate command in the current pane
    if test "$tool" = "claude"
        claude /review Review the PR for the checked out branch
    else
        codex /review
    end
end
