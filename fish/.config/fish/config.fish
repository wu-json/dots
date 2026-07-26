# Brew
function b
    brew update && brew upgrade
end

# Git
alias ghc="git reset --hard && git clean -fd"
alias gho="ghome"
alias gc="git_auto_commit"
alias gp="git push"
alias gpr="gh pr view --web"

# Eza
alias ls="eza"
alias tree="eza --tree"

# Yazi
alias y="yazi"

# Obsidian
alias o="obsidian"
alias od="obsidian daily"
alias p="pi"

# Claudius Codius
alias cl="env TZ=America/Los_Angeles claude --dangerously-skip-permissions"

# OpenCode
alias oc="opencode"

# Cloudflared
function cftunnel --description 'Start a Cloudflare quick tunnel to a local port, then show and copy its URL'
    set -l port $argv[1]
    if test -z "$port"
        echo "Usage: cftunnel <port>" >&2
        return 1
    end

    set -l url
    set -l announced 0
    cloudflared tunnel --url localhost:$port 2>&1 | while read -l line
        echo $line
        if test -z "$url"
            set url (string match -r -- 'https://[-a-z0-9]+\.trycloudflare\.com' $line)[1]
            __cftunnel_banner $port $url
        else if test $announced -eq 0 && string match -q '*Registered tunnel connection*' -- $line
            # Repeat it once the tunnel is live, so it sits below the startup noise.
            set announced 1
            __cftunnel_banner $port $url
        end
    end

    __cftunnel_banner $port $url
end

function __cftunnel_banner --description 'Print a cftunnel URL loudly and copy it to the clipboard'
    set -l port $argv[1]
    set -l url $argv[2]
    test -n "$url" || return 1

    set -l copied 0
    if command -q pbcopy
        printf %s $url | pbcopy
        set copied 1
    end

    echo
    set_color -o f38020
    printf '  ◆'
    set_color normal
    set_color -o
    printf '  cloudflare tunnel\n'
    set_color normal
    echo
    __cftunnel_row local "http://localhost:$port" normal
    __cftunnel_row public $url -o green
    if test $copied -eq 1
        echo
        set_color --dim
        printf '     ✓ copied public url to clipboard\n'
        set_color normal
    end
    echo
end

function __cftunnel_row --description 'Print one aligned label/value row for cftunnel'
    set -l label $argv[1]
    set -l value $argv[2]
    set -l color $argv[3..-1]

    set -l cols 80
    if string match -qr '^\d+$' -- "$COLUMNS" && test $COLUMNS -gt 20
        set cols $COLUMNS
    end

    set -l prefix (printf '     %-7s ' $label)
    set_color --dim
    printf '%s' $prefix
    set_color normal
    # On a narrow terminal, drop the value to its own line instead of wrapping it
    # around the label.
    if test (math (string length -- $prefix) + (string length -- $value)) -gt $cols
        printf '\n       '
    end
    set_color $color
    printf '%s\n' $value
    set_color normal
end

# Nvim
alias v="nvim"

# Lazygit
alias lg="lazygit"

# Source fish config
alias sf="source ~/.config/fish/config.fish"

# Working dir copy
function wdc
    pwd | pbcopy
    echo "Copied working directory to clipboard: "(pwd)
end

# Review fish function
alias r="review"
alias ra="review_auto"

# OrbStack
source ~/.orbstack/shell/init.fish 2>/dev/null || :

# Zoxide
zoxide init fish | source
alias j="z"

# Added by OrbStack: command-line tools and integration
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Used for Granted CLI:
# https://docs.commonfate.io/granted/troubleshooting#manually-configuring-your-shell-profile
alias assume="source ~/.config/fish/assume.fish"

set fish_greeting ""

# Turn on vi mode by default
fish_vi_key_bindings

# Custom key bindings for word-by-word completion
function fish_user_key_bindings
    # Alt-q to accept one word from autosuggestion
    bind -M insert \eq forward-word
    bind -M default \eq forward-word
end

# No fish theme because I like monochrome
yes | fish_config theme save None

# FNM cleanup on exit
function fnm_clean_up --on-event fish_exit
    rm -r $FNM_MULTISHELL_PATH
end

# Auto-source local config files
function __source_local_config --on-variable PWD --description 'Source config.local.fish if present in current directory'
    if test -f config.local.fish
        source config.local.fish
    end
end

# Run once on shell startup
__source_local_config

# Add local bin to path
export PATH="$HOME/.local/bin:$PATH"
