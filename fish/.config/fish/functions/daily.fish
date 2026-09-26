function daily --description 'Open today’s note using the configured daily recipe'
    set -l directory (__daily_notes_dir); or return 1
    DAILY_NOTE_PROSE=1 command just --justfile "$directory/justfile" --working-directory "$directory" daily $argv
end
