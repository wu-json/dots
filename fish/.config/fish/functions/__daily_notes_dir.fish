function __daily_notes_dir --description 'Find the daily notes repository'
    if set -q DAILY_NOTES_DIR; and test -n "$DAILY_NOTES_DIR"
        if not test -d "$DAILY_NOTES_DIR"; or not test -f "$DAILY_NOTES_DIR/justfile"
            echo 'DAILY_NOTES_DIR must point to a directory containing a justfile.' >&2
            return 1
        end
        path resolve -- "$DAILY_NOTES_DIR"
        return
    end

    set -l source_file (path resolve -- (status filename))
    set -l parent (path resolve -- (path dirname -- "$source_file")/../../../../..)
    set -l matches
    for justfile in "$parent"/*/justfile
        set -l recipes (command just --justfile "$justfile" --summary 2>/dev/null | string split ' ')
        if contains -- daily $recipes
            set -a matches (path dirname -- "$justfile")
        end
    end

    if test (count $matches) -ne 1
        echo 'Expected one sibling directory with a daily recipe. Set DAILY_NOTES_DIR to choose explicitly.' >&2
        return 1
    end
    printf '%s\n' "$matches[1]"
end
