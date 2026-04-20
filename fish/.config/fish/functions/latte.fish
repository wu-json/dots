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

    function __latte_brew -S -a msg
        set_color -o magenta
        echo -n "☕ latte"
        set_color normal
        echo " · $msg"
    end

    if set -q _flag_hours; and set -q _flag_minutes
        set_color -o red
        echo -n "☕ latte"
        set_color normal
        echo " · pick one: -h/--hours or -m/--minutes (not both)" >&2
        return 1
    else if set -q _flag_hours
        set seconds (math -s0 "$_flag_hours * 3600")
        or begin
            __latte_brew "invalid hours: $_flag_hours" >&2
            return 1
        end
        set label (__latte_plural $_flag_hours hour)
    else if set -q _flag_minutes
        set seconds (math -s0 "$_flag_minutes * 60")
        or begin
            __latte_brew "invalid minutes: $_flag_minutes" >&2
            return 1
        end
        set label (__latte_plural $_flag_minutes minute)
    else
        __latte_brew "bottomless cup — keeping macOS awake until ctrl-c"
        caffeinate -dimsu
        return
    end

    __latte_brew "keeping macOS awake for $label — sip slow"
    caffeinate -dimsu -t $seconds
end
