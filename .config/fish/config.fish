# GitHub
alias gtc="github_clean"
alias gtss="gt sync && gt submit"
alias gtcr="gt create"
alias gtr="gt restack"

# Eza
alias ls="eza"
alias tree="eza --tree"

# OrbStack
source ~/.orbstack/shell/init.fish 2>/dev/null || :

if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
