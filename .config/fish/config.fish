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
    gt create $argv
end

# Dotfiles
alias dc="dotfiles_config"

# Forge
alias fc="forge_code"
alias fl="forge_launch_v2"
alias fctl="forgectl"

# Eza
alias ls="eza"
alias tree="eza --tree"

# Claudius Codius
# alias c="claude"

# Cursor
alias c="cursor-agent"

# OrbStack
source ~/.orbstack/shell/init.fish 2>/dev/null || :

# Autojump
[ -f /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish

if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Used for Granted CLI:
# https://docs.commonfate.io/granted/troubleshooting#manually-configuring-your-shell-profile
alias assume="source ~/.config/fish/assume.fish"

# Load local machine-specific config (not committed)
if test -f ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end
