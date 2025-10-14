# Graphite
alias gtss="gt sync && gt submit"
alias gtr="gt restack"
alias gtl="gt ls"
alias gtm="gt add -A && gt modify"
alias gta="gt absorb"
function gtc
    gt create $argv
end

# Eza
alias ls="eza"
alias tree="eza --tree"

# Claudius Codius
alias c="claude"

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
