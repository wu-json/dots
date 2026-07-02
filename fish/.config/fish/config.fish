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
function cftunnel
    cloudflared tunnel --url localhost:$argv[1]
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
