# latte: friendlier `caffeinate` wrapper that takes hours or minutes instead
# of seconds. Handy for keeping the Mac awake while long-running agents /
# background jobs do their thing. `latte -a` stays awake only as long as
# coding agents (claude, opencode, codex, pi) are running, then exits.
function latte --description 'caffeinate with -h HOURS, -m MINUTES, or -a until coding agents finish'
    argparse 'h/hours=' 'm/minutes=' 'a/agents' -- $argv
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

    # Coding agents watched by -a/--agents. pi execs a node script, so its
    # process name is `node` — match its command line instead. claude is
    # lowercase so this won't match the Claude desktop app (capital C).
    function __latte_agents_running -S
        pgrep -qx claude; and echo claude
        pgrep -qx opencode; and echo opencode
        pgrep -qx codex; and echo codex
        pgrep -qf pi-coding-agent; and echo pi
    end

    # Run caffeinate with the TTY in no-echo, non-canonical mode so stray
    # keystrokes in the pane don't corrupt the display or leak into the next
    # prompt. isig stays on so Ctrl-C still terminates caffeinate normally.
    # Restored via a SIGINT handler so interrupts can't leave the TTY broken.
    function __latte_run -S -a mode seconds
        set -l tty_saved ""
        set -l tty_active false
        if isatty stdin
            set tty_saved (stty -g 2>/dev/null)
            if test -n "$tty_saved"
                stty -echo -icanon 2>/dev/null
                printf '\e[?25l'
                set tty_active true
            end
        end
        function __latte_restore_tty --inherit-variable tty_saved --inherit-variable tty_active
            if test "$tty_active" = true
                command -q python3; and python3 -c 'import termios,sys; termios.tcflush(sys.stdin, termios.TCIFLUSH)' 2>/dev/null
                stty "$tty_saved" 2>/dev/null
                printf '\e[?25h'
                set tty_active false
            end
            functions -q __latte_sigint_handler; and functions -e __latte_sigint_handler
        end
        function __latte_sigint_handler --on-signal SIGINT
            __latte_restore_tty
        end
        switch $mode
            case timed
                caffeinate -dimsu -t $seconds
            case agents
                # Poll for agents every 30s; caffeinate -t doubles as the
                # sleep so the wake assertion is held between checks.
                while test (count (__latte_agents_running)) -gt 0
                    caffeinate -dimsu -t 30
                    if test $status -gt 128
                        break
                    end
                end
            case '*'
                caffeinate -dimsu
        end
        set -l rc $status
        __latte_restore_tty
        return $rc
    end

    set -l flag_count 0
    set -q _flag_hours; and set flag_count (math $flag_count + 1)
    set -q _flag_minutes; and set flag_count (math $flag_count + 1)
    set -q _flag_agents; and set flag_count (math $flag_count + 1)
    if test $flag_count -gt 1
        set_color -o red
        echo -n "☕ latte"
        set_color normal
        echo " · pick one: -h/--hours, -m/--minutes, or -a/--agents" >&2
        return 1
    end

    if set -q _flag_agents
        set -l running (__latte_agents_running)
        if test (count $running) -eq 0
            __latte_brew "no coding agents running — nothing to babysit"
            return 0
        end
        __latte_brew "keeping macOS awake while agents run: "(string join ', ' $running)
        __latte_run agents
        set -l rc $status
        __latte_brew "all agents done — macOS can nap now"
        return $rc
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
        __latte_run forever
        return
    end

    __latte_brew "keeping macOS awake for $label — sip slow"
    __latte_run timed $seconds
end
