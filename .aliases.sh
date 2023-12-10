# GitHub Branch Clean
# Checks out main, deletes all other branches, and pulls main.
alias x-ghbc='(
    git checkout main
    git branch | grep -v "main" | xargs git branch -D
    git pull
)'
