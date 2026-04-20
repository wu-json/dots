# latte: friendlier `caffeinate` wrapper that takes hours or minutes instead
# of seconds. Handy for keeping the Mac awake while long-running agents /
# background jobs do their thing.
function latte --description 'caffeinate with -h HOURS or -m MINUTES (default 1h)'
    argparse 'h/hours=' 'm/minutes=' -- $argv
    or return

    set -l seconds
    set -l label

    function __latte_plural -S -a n word
        if test "$n" = 1
            echo "$n $word"
        else
            echo "$n "$word"s"
        end
    end

    if set -q _flag_hours; and set -q _flag_minutes
        echo "latte: specify only one of -h/--hours or -m/--minutes" >&2
        return 1
    else if set -q _flag_hours
        set seconds (math -s0 "$_flag_hours * 3600")
        or begin
            echo "latte: invalid hours: $_flag_hours" >&2
            return 1
        end
        set label (__latte_plural $_flag_hours hour)
    else if set -q _flag_minutes
        set seconds (math -s0 "$_flag_minutes * 60")
        or begin
            echo "latte: invalid minutes: $_flag_minutes" >&2
            return 1
        end
        set label (__latte_plural $_flag_minutes minute)
    else
        set seconds 3600
        set label "1 hour"
    end

    echo "latte: keeping awake for $label"
    caffeinate -dimsu -t $seconds
end
