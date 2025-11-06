function review
    # Store the current pane ID
    set current_pane (wezterm cli get-pane-direction here)

    # Split the pane and run codex /review in the new pane
    wezterm cli split-pane --right -- fish -c 'codex /review'

    # Clear the current pane to align both panes vertically
    # The new pane starts fresh without a prompt, so we clear this pane too
    # to avoid height offset from the shell prompt appearing at the top
    clear
    # Clear any pending input in the command line buffer
    commandline -r ''
    commandline -f repaint
    codex /review
end
