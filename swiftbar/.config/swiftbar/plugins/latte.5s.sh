#!/bin/bash
# <xbar.title>Latte</xbar.title>
# <xbar.desc>Toggle macOS sleep prevention.</xbar.desc>

pid_file="$HOME/Library/Caches/latte/caffeinate.pid"

running_pid() {
    local command
    [[ -f "$pid_file" ]] || return 1
    read -r pid < "$pid_file"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    command=$(ps -p "$pid" -o command= 2>/dev/null) || return 1
    [[ "$command" == "/usr/bin/caffeinate -dimsu" ]] && kill -0 "$pid" 2>/dev/null
}

if [[ "${1:-}" == toggle ]]; then
    if running_pid; then
        kill "$pid"
        rm -f "$pid_file"
    else
        mkdir -p "${pid_file%/*}"
        nohup /usr/bin/caffeinate -dimsu </dev/null >/dev/null 2>&1 &
        printf '%s\n' "$!" > "$pid_file"
    fi
    exit
fi

if running_pid; then
    echo '☕ Latte: On'
    label='Turn Off'
else
    echo '☕ Latte: Off'
    label='Turn On'
fi
echo '---'
printf '%s | bash="%s" param1=toggle terminal=false refresh=true shortcut=CTRL+OPTION+CMD+L\n' "$label" "$0"
