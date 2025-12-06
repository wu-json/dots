# Graphite
alias gtss="gt sync && gt submit"
alias gtr="gt restack"
alias gtl="gt ls"
alias gtm="gt add -A && gt modify"
alias gta="gt absorb"
function gtc
    gt create $argv
end
function gtch
    gt checkout $argv
end

# Git
alias ghc="git reset --hard && git clean -fd"

# Eza
alias ls="eza"
alias tree="eza --tree"

# Claudius Codius
alias c="claude"

# Codex 
alias cx="codex"

# Cursor
alias cursor="cursor-agent"

# Nvim
alias v="nvim"

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
