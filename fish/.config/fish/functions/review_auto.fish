function review_auto
    # Usage: review_auto [--max-iterations N] [--provider openai|anthropic] [--panes 1-3] [--timeout SECS] [--dry-run]
    # Uses --yolo so agents can run shell tools (gh cli, git, etc.) for PR inspection.
    # Default: 3 reviewers (Evelyn, Vivian, Stella) in 4-quadrant layout.
    set -l max_iters 3
    set -l provider anthropic
    set -l num_panes 3
    set -l phase_timeout 600
    set -l dry_run false

    set -l i 1
    set -l argc (count $argv)
    while test $i -le $argc
        switch $argv[$i]
            case --max-iterations
                set i (math $i + 1)
                if test $i -gt $argc
                    echo "Missing value for --max-iterations"
                    return 1
                end
                if not string match -qr '^\d+$' -- $argv[$i]; or test $argv[$i] -le 0
                    echo "Invalid --max-iterations value: '$argv[$i]' (must be a positive integer)"
                    return 1
                end
                set max_iters $argv[$i]
            case --provider
                set i (math $i + 1)
                if test $i -gt $argc
                    echo "Missing value for --provider"
                    return 1
                end
                set provider (string lower $argv[$i])
            case --panes
                set i (math $i + 1)
                if test $i -gt $argc
                    echo "Missing value for --panes"
                    return 1
                end
                if not string match -qr '^\d+$' -- $argv[$i]
                    echo "Invalid --panes value: '$argv[$i]' (must be a positive integer)"
                    return 1
                end
                set num_panes $argv[$i]
            case --timeout
                set i (math $i + 1)
                if test $i -gt $argc
                    echo "Missing value for --timeout"
                    return 1
                end
                if not string match -qr '^\d+$' -- $argv[$i]; or test $argv[$i] -le 0
                    echo "Invalid --timeout value: '$argv[$i]' (must be a positive integer in seconds)"
                    return 1
                end
                set phase_timeout $argv[$i]
            case --dry-run
                set dry_run true
            case '*'
                echo "Unknown argument: $argv[$i]"
                echo "Usage: review_auto [--max-iterations N] [--provider openai|anthropic] [--panes 1-3] [--timeout SECS] [--dry-run]"
                return 1
        end
        set i (math $i + 1)
    end

    if test $num_panes -lt 1 -o $num_panes -gt 3
        echo "Pane count must be between 1 and 3"
        return 1
    end

    set -l pr_number (gh pr view --json number --jq '.number' 2>/dev/null)
    set -l pr_url (gh pr view --json url --jq '.url' 2>/dev/null)
    set -l pr_title (gh pr view --json title --jq '.title' 2>/dev/null)
    if test -z "$pr_number"
        echo "No PR found for current branch"
        return 1
    end

    set -l review_model gpt-5.4-high
    set -l triage_model gpt-5.4-high
    set -l fix_model claude-4.6-opus-high
    switch $provider
        case anthropic
            set review_model claude-4.6-opus-high
            set triage_model claude-4.6-opus-high
        case openai
            set fix_model gpt-5.4-high
        case '*'
            echo "Invalid provider: $provider (must be 'anthropic' or 'openai')"
            return 1
    end

    set -l session_dir (mktemp -d /tmp/review_auto.XXXXXX)
    set -l review_cmd "cursor-agent --yolo --model $review_model -p"

    # reviewer identities and prompts
    set -l names Evelyn Vivian Stella
    set -l base_prompts \
        "You are Evelyn. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format." \
        "You are Vivian. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format." \
        "You are Stella. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format. Focus on dead code, unused imports, and unreachable code paths."

    # --- beautiful header ---
    set -l dim (set_color brblack)
    set -l reset (set_color normal)
    set -l green (set_color green)

    # --- split panes: 4 quadrants (orchestrator + 3 reviewers) ---
    # Layout:
    # ┌─────────────────────┬─────────────────────┐
    # │   ORCHESTRATOR      │      Evelyn         │
    # ├─────────────────────┼─────────────────────┤
    # │     Vivian          │      Stella         │
    # └─────────────────────┴─────────────────────┘
    # Split order matters: bottom first, then split each row
    set -l pane_0 $WEZTERM_PANE
    set -l pane_ids

    # Step 1: split horizontally to create bottom row
    set -l pane_bottom (wezterm cli split-pane --pane-id $pane_0 --bottom)
    if test -z "$pane_bottom"
        echo "Failed to create bottom pane (split-pane returned empty ID)"
        rm -rf $session_dir
        return 1
    end
    # Step 2: split top row to create Evelyn (top-right)
    set -l pane_evelyn (wezterm cli split-pane --pane-id $pane_0 --right)
    if test -z "$pane_evelyn"
        echo "Failed to create Evelyn pane (split-pane returned empty ID)"
        wezterm cli kill-pane --pane-id $pane_bottom &>/dev/null
        rm -rf $session_dir
        return 1
    end
    # Step 3: split bottom row to create Stella (bottom-right)
    set -l pane_stella (wezterm cli split-pane --pane-id $pane_bottom --right)
    if test -z "$pane_stella"
        echo "Failed to create Stella pane (split-pane returned empty ID)"
        wezterm cli kill-pane --pane-id $pane_evelyn &>/dev/null
        wezterm cli kill-pane --pane-id $pane_bottom &>/dev/null
        rm -rf $session_dir
        return 1
    end
    # pane_bottom is now Vivian (bottom-left)
    set -l pane_vivian $pane_bottom

    # pane_ids order: Evelyn, Vivian, Stella
    set pane_ids $pane_evelyn $pane_vivian $pane_stella

    # Kill unused panes if num_panes < 3
    if test $num_panes -lt 3
        wezterm cli kill-pane --pane-id $pane_stella &>/dev/null
        set pane_ids $pane_evelyn $pane_vivian
    end
    if test $num_panes -lt 2
        wezterm cli kill-pane --pane-id $pane_vivian &>/dev/null
        set pane_ids $pane_evelyn
    end

    # --- header (printed once) ---
    set -l session_start (date +%s)
    printf "\n\n"
    set -l pr_label "PR #$pr_number"
    if test -n "$pr_title"
        # " review_auto · " = 16 chars prefix, leave 2 for padding
        set -l max_len (math $COLUMNS - 18)
        if test $max_len -lt 20
            set max_len 20
        end
        if test (string length "$pr_title") -gt $max_len
            set pr_label (string sub -l $max_len "$pr_title")"…"
        else
            set pr_label $pr_title
        end
    end
    echo " "(set_color --bold)"review_auto"(set_color normal)" "(set_color brblack)"·"(set_color normal)" "\e]8\;\;$pr_url\e\\(set_color white)$pr_label(set_color normal)\e]8\;\;\e\\
    echo " "(set_color brblack)"$provider · $num_panes reviewers · $max_iters max iterations"(set_color normal)
    echo ""

    # --- main loop ---
    set -l iter 1
    while test $iter -le $max_iters
        set -l iter_dir $session_dir/iter_$iter
        mkdir -p $iter_dir

        # On iteration 2+, recreate reviewer panes (same quadrant layout as initial)
        if test $iter -gt 1
            set -l pb (wezterm cli split-pane --pane-id $pane_0 --bottom)
            if test -z "$pb"
                echo "Failed to recreate bottom pane in iteration $iter"
                rm -rf $session_dir
                return 1
            end
            set -l pe (wezterm cli split-pane --pane-id $pane_0 --right)
            if test -z "$pe"
                echo "Failed to recreate Evelyn pane in iteration $iter"
                wezterm cli kill-pane --pane-id $pb &>/dev/null
                rm -rf $session_dir
                return 1
            end
            set -l ps (wezterm cli split-pane --pane-id $pb --right)
            if test -z "$ps"
                echo "Failed to recreate Stella pane in iteration $iter"
                wezterm cli kill-pane --pane-id $pe &>/dev/null
                wezterm cli kill-pane --pane-id $pb &>/dev/null
                rm -rf $session_dir
                return 1
            end
            set pane_ids $pe $pb $ps
            if test $num_panes -lt 3
                wezterm cli kill-pane --pane-id $ps &>/dev/null
                set pane_ids $pe $pb
            end
            if test $num_panes -lt 2
                wezterm cli kill-pane --pane-id $pb &>/dev/null
                set pane_ids $pe
            end
        end

        # clean sentinel files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            rm -f $iter_dir/.done_$name
        end

        # dispatch review agents to panes (prompts written to temp files to avoid shell metacharacter issues)
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -l outfile "$iter_dir/review_$name.md"
            set -l sentinel "$iter_dir/.done_$name"
            set -l prompt "$base_prompts[$j] IMPORTANT: When done, write your complete review to $outfile using the Write tool. Then run this shell command: touch $sentinel"
            set -l prompt_file "$iter_dir/prompt_review_$name.txt"
            printf '%s' "$prompt" > $prompt_file
            set -l cmd "$review_cmd \"\$(cat $prompt_file)\""
            printf '%s\r' "$cmd" | wezterm cli send-text --no-paste --pane-id $pane_ids[$j]
            sleep 0.5 # stagger to avoid cli-config.json race condition
        end

        # poll for all reviewers to finish
        set -l review_start (date +%s)
        set -l dot_frames "." ".." "..."
        set -l dot_colors green white green
        set -l frame_idx 1
        while true
            set -l done_count 0
            set -l status_line ""
            for j in (seq $num_panes)
                set -l name $names[$j]
                set -l name_lower (string lower $name)
                if test -f $iter_dir/.done_$name_lower
                    set done_count (math $done_count + 1)
                    set status_line "$status_line$green$name$reset  "
                else
                    set status_line "$status_line$dim$name$reset  "
                end
            end

            set -l total_el (math (date +%s) - $session_start)
            set -l total_m (math "floor($total_el / 60)")
            set -l total_s (math "$total_el % 60")
            set -l total_ts (printf "%d:%02d" $total_m $total_s)
            set -l dots (printf "%-4s" $dot_frames[$frame_idx])
            printf "\r %s•%s Reviewing%s%s(%s/%s)%s  %s %s%s%s" (set_color $dot_colors[$frame_idx]) $reset "$dots" $dim $iter $max_iters $reset "$status_line" $dim $total_ts $reset

            if test $done_count -ge $num_panes
                break
            end

            set -l review_elapsed (math (date +%s) - $review_start)
            if test $review_elapsed -ge $phase_timeout
                printf "\r                                                           \r"
                echo " "(set_color red)"✗"(set_color normal)"  Review phase timed out after $phase_timeout seconds in iteration $iter"
                for pane in $pane_ids
                    wezterm cli kill-pane --pane-id $pane &>/dev/null
                end
                rm -rf $session_dir
                return 1
            end

            set frame_idx (math "$frame_idx % 3 + 1")
            sleep 0.15
        end
        # kill reviewer panes and create fresh work pane before printing final status
        # (pane resize happens here, before any output)
        for pane in $pane_ids
            wezterm cli kill-pane --pane-id $pane &>/dev/null
        end
        set -l work_pane (wezterm cli split-pane --pane-id $pane_0 --right)
        if test -z "$work_pane"
            echo "Failed to create work pane after review phase in iteration $iter"
            rm -rf $session_dir
            return 1
        end

        printf "\r                                                           \r"
        echo " "(set_color green)"✔"(set_color normal)" Reviewed "(set_color brblack)"($iter/$max_iters)"(set_color normal)

        # --- triage phase ---
        set -l review_files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -a review_files "$iter_dir/review_$name.md"
        end
        set -l file_list (string join ", " $review_files)

        set -l triage_sentinel "$iter_dir/.done_triage"
        set -l triage_prompt "You are a code-review triage agent. Read the review output files at: $file_list. Read all review files using the Read tool. Filter out nitpicks, style-only comments, and false positives. Identify ONLY real bugs, logic errors, security vulnerabilities, or missing error handling. If a review file is empty or contains an error, skip it. Write your verdict to $iter_dir/triage.md. If there are NO real issues: write ONLY the text NO_ISSUES_FOUND (nothing else, just that one line). If there ARE real issues: write each issue with file path, line number, severity (critical/high/medium), and description. Do NOT include the string NO_ISSUES_FOUND anywhere. When completely done, run this shell command: touch $triage_sentinel"

        set -l triage_prompt_file "$iter_dir/prompt_triage.txt"
        printf '%s' "$triage_prompt" > $triage_prompt_file
        set -l triage_cmd "cursor-agent --yolo --model $triage_model \"\$(cat $triage_prompt_file)\""
        printf '%s\r' "$triage_cmd" | wezterm cli send-text --no-paste --pane-id $work_pane

        set -l triage_start (date +%s)
        set frame_idx 1
        while not test -f $triage_sentinel
            set -l total_el (math (date +%s) - $session_start)
            set -l total_m (math "floor($total_el / 60)")
            set -l total_s (math "$total_el % 60")
            set -l total_ts (printf "%d:%02d" $total_m $total_s)
            set -l dots (printf "%-4s" $dot_frames[$frame_idx])
            printf "\r %s•%s Triaging%s %s%s%s" (set_color $dot_colors[$frame_idx]) $reset "$dots" $dim $total_ts $reset

            set -l phase_elapsed (math (date +%s) - $triage_start)
            if test $phase_elapsed -ge $phase_timeout
                printf "\r                                                           \r"
                echo " "(set_color red)"✗"(set_color normal)"  Triage phase timed out after $phase_timeout seconds in iteration $iter"
                wezterm cli kill-pane --pane-id $work_pane &>/dev/null
                rm -rf $session_dir
                return 1
            end

            set frame_idx (math "$frame_idx % 3 + 1")
            sleep 0.15
        end
        # kill triage pane before printing (pane resize happens here, before any output)
        wezterm cli kill-pane --pane-id $work_pane &>/dev/null

        printf "\r                                                           \r"
        echo " "(set_color green)"✔"(set_color normal)" Triaged"

        # guard: triage.md must exist and be non-empty before proceeding
        if not test -s $iter_dir/triage.md
            echo " "(set_color red)"✗"(set_color normal)"  Triage produced empty or missing triage.md in iteration $iter"
            rm -rf $session_dir
            return 1
        end

        # check triage result - collapse into a single string so multi-line files
        # are compared atomically instead of per-line via fish list semantics
        set -l _triage_content (cat $iter_dir/triage.md 2>/dev/null | string collect | string trim)
        if test "$_triage_content" = "NO_ISSUES_FOUND"
            echo " "(set_color green)"✔"(set_color normal)" No issues found"
            set -l total_dur (math (date +%s) - $session_start)
            set -l total_dur_m (math "floor($total_dur / 60)")
            set -l total_dur_s (math "$total_dur % 60")
            echo ""
            echo " "(set_color brblack)$pr_url" · "(printf "%dm %ds" $total_dur_m $total_dur_s)(set_color normal)
            echo ""
            rm -rf $session_dir
            return 0
        end

        if test "$dry_run" = true
            echo " "(set_color yellow)"⚠"(set_color normal)" Issues found "(set_color brblack)"(dry run)"(set_color normal)
            set -l total_dur (math (date +%s) - $session_start)
            set -l total_dur_m (math "floor($total_dur / 60)")
            set -l total_dur_s (math "$total_dur % 60")
            echo ""
            echo " "(set_color brblack)$pr_url" · "(printf "%dm %ds" $total_dur_m $total_dur_s)(set_color normal)
            echo ""
            rm -rf $session_dir
            return 0
        end

        # --- fix phase ---
        set -l work_pane (wezterm cli split-pane --pane-id $pane_0 --right)
        if test -z "$work_pane"
            echo "Failed to create work pane for fix phase in iteration $iter"
            rm -rf $session_dir
            return 1
        end

        set -l fix_sentinel "$iter_dir/.done_fix"
        set -l fix_prompt "Read the triaged code-review issues at $iter_dir/triage.md using the Read tool. Fix every issue listed. Do not fix anything not listed. After fixing, commit your changes with a clear message referencing what was fixed, then push to the remote branch with git push. Then use the /pr skill to update the PR title and description. When completely done, run this shell command: touch $fix_sentinel"

        set -l fix_prompt_file "$iter_dir/prompt_fix.txt"
        printf '%s' "$fix_prompt" > $fix_prompt_file
        set -l fix_cmd "cursor-agent --yolo --model $fix_model \"\$(cat $fix_prompt_file)\""
        printf '%s\r' "$fix_cmd" | wezterm cli send-text --no-paste --pane-id $work_pane

        set -l fix_start (date +%s)
        set frame_idx 1
        while not test -f $fix_sentinel
            set -l total_el (math (date +%s) - $session_start)
            set -l total_m (math "floor($total_el / 60)")
            set -l total_s (math "$total_el % 60")
            set -l total_ts (printf "%d:%02d" $total_m $total_s)
            set -l dots (printf "%-4s" $dot_frames[$frame_idx])
            printf "\r %s•%s Fixing%s %s%s%s" (set_color $dot_colors[$frame_idx]) $reset "$dots" $dim $total_ts $reset

            set -l phase_elapsed (math (date +%s) - $fix_start)
            if test $phase_elapsed -ge $phase_timeout
                printf "\r                                                           \r"
                echo " "(set_color red)"✗"(set_color normal)"  Fix phase timed out after $phase_timeout seconds in iteration $iter"
                wezterm cli kill-pane --pane-id $work_pane &>/dev/null
                rm -rf $session_dir
                return 1
            end

            set frame_idx (math "$frame_idx % 3 + 1")
            sleep 0.15
        end
        printf "\r                                                           \r"
        echo " "(set_color green)"✔"(set_color normal)" Fixed"

        # kill work pane before next iteration
        wezterm cli kill-pane --pane-id $work_pane &>/dev/null

        set iter (math $iter + 1)
    end

    echo ""
    echo " "(set_color red)"✗"(set_color normal)" Max iterations reached"
    set -l total_dur (math (date +%s) - $session_start)
    set -l total_dur_m (math "floor($total_dur / 60)")
    set -l total_dur_s (math "$total_dur % 60")
    echo ""
    echo " "(set_color brblack)$pr_url" · "(printf "%dm %ds" $total_dur_m $total_dur_s)(set_color normal)
    echo ""
    rm -rf $session_dir
    return 1
end
