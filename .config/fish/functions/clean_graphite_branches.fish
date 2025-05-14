function clean_graphite_branches
    git branch -l | grep graphite-base | xargs git branch -D
end
