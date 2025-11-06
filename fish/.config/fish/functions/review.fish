function review
    # Split the pane vertically and run codex /review in the new pane
    wezterm cli split-pane --right -- fish -c 'codex /review'

    # Split again and run codex /review in another new pane
    wezterm cli split-pane --right -- fish -c 'codex /review'
end
