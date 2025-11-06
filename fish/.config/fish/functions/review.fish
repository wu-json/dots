function review
    # Split the pane and run codex /review in the new pane
    wezterm cli split-pane --right -- fish -c 'codex /review'

    # Run codex /review in the current pane
    codex /review
end
