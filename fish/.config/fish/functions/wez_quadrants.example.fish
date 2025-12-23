# Example of creating 4 equally sized quadrants using Wezterm pane API
function wez_quadrants
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

    # send text to each pane
    echo -e "echo 'top-left'" | wezterm cli send-text --no-paste --pane-id $pane_0
    echo -e "echo 'top-right'" | wezterm cli send-text --no-paste --pane-id $pane_1
    echo -e "echo 'bottom-left'" | wezterm cli send-text --no-paste --pane-id $pane_2
    echo -e "echo 'bottom-right'" | wezterm cli send-text --no-paste --pane-id $pane_3
end
