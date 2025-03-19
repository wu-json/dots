# splits the terminal into 4 equal parts
function terminal_cross
    set -l pane_2 $(wezterm cli split-pane --bottom)
    set -l pane_1 $(wezterm cli split-pane --right)
    wezterm cli split-pane --pane-id $pane_2 --right
end
