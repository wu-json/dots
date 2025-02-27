function github_clean
    set -l default_branch_name $(git remote show origin | awk '/HEAD branch/ {print $NF}')
    git checkout $default_branch_name
    git branch | grep -v $default_branch_name | xargs git branch -D
    git pull
    git reset --hard
    git clean -fd
end
