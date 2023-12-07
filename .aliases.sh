# GitHub Branch Clean
# Checks out mainline, deletes all other branches, and pulls maineline.
alias x-ghbc='(
    git checkout main
    git branch | grep -v "main" | xargs git branch -D
    git pull
)'
