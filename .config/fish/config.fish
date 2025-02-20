# GitHub
alias ghcl="github_clean"
alias gtss="graphite_sync_and_submit"

# Eza
alias ls="eza"
alias tree="eza --tree"

if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.fish 2>/dev/null || :
