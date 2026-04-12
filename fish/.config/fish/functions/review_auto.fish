function review_auto
    # Usage: review_auto [--max-rounds N] [--provider openai|anthropic] [--panes 1-3] [--dry-run]
    # Uses --yolo so agents can run shell tools (gh cli, git, etc.) for PR inspection.
    # Default: 3 reviewers (Evelyn, Vivian, Stella) in 4-quadrant layout.
    set -l max_rounds 3
    set -l provider anthropic
    set -l num_panes 3
    set -l dry_run false

    set -l i 1
    set -l argc (count $argv)
    while test $i -le $argc
        switch $argv[$i]
            case --max-rounds
                set i (math $i + 1)
                if test $i -gt $argc
                    echo "Missing value for --max-rounds"
                    return 1
                end
                set max_rounds $argv[$i]
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
                set num_panes $argv[$i]
            case --dry-run
                set dry_run true
            case '*'
                echo "Unknown argument: $argv[$i]"
                echo "Usage: review_auto [--max-rounds N] [--provider openai|anthropic] [--panes 1-3] [--dry-run]"
                return 1
        end
        set i (math $i + 1)
    end

    if test $num_panes -lt 1 -o $num_panes -gt 3
        echo "Pane count must be between 1 and 3"
        return 1
    end

    set -l pr_number (gh pr view --json number -q .number 2>/dev/null)
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
    set -l review_cmd "cursor-agent --yolo --model $review_model"

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
    # Step 2: split top row to create Evelyn (top-right)
    set -l pane_evelyn (wezterm cli split-pane --pane-id $pane_0 --right)
    # Step 3: split bottom row to create Stella (bottom-right)
    set -l pane_stella (wezterm cli split-pane --pane-id $pane_bottom --right)
    # pane_bottom is now Vivian (bottom-left)
    set -l pane_vivian $pane_bottom

    # pane_ids order: Evelyn, Vivian, Stella
    set pane_ids $pane_evelyn $pane_vivian $pane_stella

    # Kill unused panes if num_panes < 3
    if test $num_panes -lt 3
        wezterm cli kill-pane --pane-id $pane_stella 2>/dev/null
        set pane_ids $pane_evelyn $pane_vivian
    end
    if test $num_panes -lt 2
        wezterm cli kill-pane --pane-id $pane_vivian 2>/dev/null
        set pane_ids $pane_evelyn
    end

    # --- main loop ---
    set -l round 1
    while test $round -le $max_rounds
        set -l round_dir $session_dir/round_$round
        mkdir -p $round_dir

        printf "\n\n"
        echo "   "(set_color --bold)"review_auto"(set_color normal)"  "(set_color brblack)"·"(set_color normal)"  PR #"(set_color cyan)$pr_number(set_color normal)
        echo "   "(set_color brblack)"$provider · $num_panes reviewers · round $round/$max_rounds"(set_color normal)
        echo ""
        set -l round_start (date +%s)

        # On round 2+, recreate reviewer panes (they were killed after the previous review phase)
        if test $round -gt 1
            set pane_ids
            if test $num_panes -ge 1
                set -a pane_ids (wezterm cli split-pane --pane-id $pane_0 --right)
            end
            if test $num_panes -ge 2
                set -a pane_ids (wezterm cli split-pane --pane-id $pane_0 --bottom)
            end
            if test $num_panes -ge 3
                set -a pane_ids (wezterm cli split-pane --pane-id $pane_ids[2] --right)
            end
        end

        # clean sentinel files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            rm -f $round_dir/.done_$name
        end

        # dispatch review agents to panes
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -l outfile "$round_dir/review_$name.md"
            set -l sentinel "$round_dir/.done_$name"
            set -l prompt "$base_prompts[$j] IMPORTANT: When done, write your complete review to $outfile using the Write tool. Then run this shell command: touch $sentinel"
            set -l cmd "$review_cmd \"$prompt\""
            printf '%s\r' "$cmd" | wezterm cli send-text --no-paste --pane-id $pane_ids[$j]
        end

        # poll for all reviewers to finish with animated spinner
        set -l spinner_frames "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"
        set -l frame_idx 1
        while true
            set -l done_count 0
            set -l status_line ""
            for j in (seq $num_panes)
                set -l name $names[$j]
                set -l name_lower (string lower $name)
                if test -f $round_dir/.done_$name_lower
                    set done_count (math $done_count + 1)
                    set status_line "$status_line$green$name$reset  "
                else
                    set status_line "$status_line$dim$name$reset  "
                end
            end

            set -l elapsed (math (date +%s) - $round_start)
            set -l mins (math "floor($elapsed / 60)")
            set -l secs (math "$elapsed % 60")
            set -l time_str (printf "%d:%02d" $mins $secs)
            printf "\r   %s%s%s  review  %s %s%s%s" $dim $spinner_frames[$frame_idx] $reset "$status_line" $dim $time_str $reset

            if test $done_count -ge $num_panes
                break
            end

            set frame_idx (math "$frame_idx % 10 + 1")
            sleep 0.05
        end
        set -l elapsed (math (date +%s) - $round_start)
        set -l mins (math "floor($elapsed / 60)")
        set -l secs (math "$elapsed % 60")
        set -l time_str (printf "%d:%02d" $mins $secs)
        printf "\r                                                           \r"
        echo "   "(set_color white)"●"(set_color normal)"  review  $status_line"(set_color brblack)"$time_str"(set_color normal)
        echo ""

        # kill reviewer panes and create fresh pane for triage/fix
        for pane in $pane_ids
            wezterm cli kill-pane --pane-id $pane 2>/dev/null
        end
        set -l work_pane (wezterm cli split-pane --pane-id $pane_0 --right)

        # --- triage phase ---
        set -l review_files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -a review_files "$round_dir/review_$name.md"
        end
        set -l file_list (string join ", " $review_files)

        set -l triage_sentinel "$round_dir/.done_triage"
        set -l triage_prompt_file "$round_dir/triage_prompt.txt"
        echo "You are a senior code-review triage agent. Read the review output files at: $file_list

Your job:
- Read all review files using the Read tool
- Filter out nitpicks, style-only comments, and false positives
- Identify ONLY real bugs, logic errors, security vulnerabilities, or missing error handling
- If a review file is empty or contains an error, skip it

IMPORTANT - Write your verdict to $round_dir/triage.md:
- If there are NO real issues: write ONLY the text 'NO_ISSUES_FOUND' (nothing else, just that one line)
- If there ARE real issues: write each issue with file path, line number, severity (critical/high/medium), and description. Do NOT include the string NO_ISSUES_FOUND anywhere." >$triage_prompt_file

        set -l triage_cmd "cursor-agent --yolo --model $triage_model -p \"(cat $triage_prompt_file)\" && touch $triage_sentinel"
        printf '%s\r' "$triage_cmd" | wezterm cli send-text --no-paste --pane-id $work_pane

        set frame_idx 1
        while not test -f $triage_sentinel
            set -l elapsed (math (date +%s) - $round_start)
            set -l mins (math "floor($elapsed / 60)")
            set -l secs (math "$elapsed % 60")
            set -l time_str (printf "%d:%02d" $mins $secs)
            printf "\r   %s%s%s  triage  %s%s%s" $dim $spinner_frames[$frame_idx] $reset $dim $time_str $reset
            set frame_idx (math "$frame_idx % 10 + 1")
            sleep 0.05
        end
        set -l elapsed (math (date +%s) - $round_start)
        set -l mins (math "floor($elapsed / 60)")
        set -l secs (math "$elapsed % 60")
        set -l time_str (printf "%d:%02d" $mins $secs)
        printf "\r                                                           \r"
        echo "   "(set_color white)"●"(set_color normal)"  triage  "(set_color brblack)"$time_str"(set_color normal)
        echo ""

        # check triage result - must be on its own line to avoid false matches
        if grep -qx NO_ISSUES_FOUND $round_dir/triage.md 2>/dev/null
            echo "   "(set_color green)"●"(set_color normal)"  "(set_color --bold)"clean"(set_color normal)" "(set_color brblack)"— no issues found"(set_color normal)
            echo ""
            return 0
        end

        if test "$dry_run" = true
            echo "   "(set_color yellow)"●"(set_color normal)"  "(set_color --bold)"dry run"(set_color normal)" "(set_color brblack)"— issues found, skipping fix"(set_color normal)
            echo ""
            return 0
        end

        # --- fix phase ---
        # kill triage pane and create fresh one for fix
        wezterm cli kill-pane --pane-id $work_pane 2>/dev/null
        set work_pane (wezterm cli split-pane --pane-id $pane_0 --right)

        set -l fix_sentinel "$round_dir/.done_fix"
        set -l fix_prompt_file "$round_dir/fix_prompt.txt"
        echo "You are a senior engineer. Read the triaged code-review issues at $round_dir/triage.md using the Read tool. Fix every issue listed. Do not fix anything not listed. After fixing, commit your changes with a clear message referencing what was fixed, then push to the remote branch (git push)." >$fix_prompt_file

        set -l fix_cmd "cursor-agent --yolo --model $fix_model -p \"(cat $fix_prompt_file)\" && touch $fix_sentinel"
        printf '%s\r' "$fix_cmd" | wezterm cli send-text --no-paste --pane-id $work_pane

        set frame_idx 1
        while not test -f $fix_sentinel
            set -l elapsed (math (date +%s) - $round_start)
            set -l mins (math "floor($elapsed / 60)")
            set -l secs (math "$elapsed % 60")
            set -l time_str (printf "%d:%02d" $mins $secs)
            printf "\r   %s%s%s  fix  %s%s%s" $dim $spinner_frames[$frame_idx] $reset $dim $time_str $reset
            set frame_idx (math "$frame_idx % 10 + 1")
            sleep 0.05
        end
        set -l elapsed (math (date +%s) - $round_start)
        set -l mins (math "floor($elapsed / 60)")
        set -l secs (math "$elapsed % 60")
        set -l time_str (printf "%d:%02d" $mins $secs)
        printf "\r                                                           \r"
        echo "   "(set_color white)"●"(set_color normal)"  fix  "(set_color brblack)"$time_str"(set_color normal)

        # kill work pane before next round
        wezterm cli kill-pane --pane-id $work_pane 2>/dev/null

        set round (math $round + 1)
    end

    echo ""
    echo "   "(set_color red)"●"(set_color normal)"  "(set_color --bold)"max rounds"(set_color normal)" "(set_color brblack)"— review manually"(set_color normal)
    echo ""
    return 1
end
