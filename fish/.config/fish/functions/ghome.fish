function ghome
    git fetch --all --prune
    or return

    set -l def (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace -r '^.*/' '')
    if test -z "$def"
        if git show-ref --verify --quiet refs/remotes/origin/main
            set def main
        else if git show-ref --verify --quiet refs/remotes/origin/master
            set def master
        else
            echo "ghome: could not determine default branch (set origin/HEAD or use main/master)" >&2
            return 1
        end
    end

    git checkout $def
    or return

    git pull
    or return

    set -l delim (printf '\t')
    git for-each-ref refs/heads/ --format "%(refname:short)$delim%(upstream:track)" | while read -l line
        set -l parts (string split -m 1 $delim -- $line)
        set -l branch $parts[1]
        set -l track (string trim -- $parts[2])
        switch "$track"
            case '[gone]'
                git branch -d $branch 2>/dev/null
                or echo "ghome: skipped $branch (not fully merged into $def)" >&2
        end
    end
    true
end
