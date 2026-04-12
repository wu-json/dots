function review_auto
    # Usage: review_auto [--max-rounds N] [--provider openai|anthropic] [--panes 1-3] [--dry-run]
    # Uses --yolo so agents can run shell tools (gh cli, git, etc.) for PR inspection.
    # Default: 3 reviewers (Evelyn, Vivian, Stella) in 4-quadrant layout.
    set -l max_rounds 3
    set -l provider anthropic
    set -l num_panes 3
    set -l dry_run false

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --max-rounds
                set i (math $i + 1)
                set max_rounds $argv[$i]
            case --provider
                set i (math $i + 1)
                set provider (string lower $argv[$i])
            case --panes
                set i (math $i + 1)
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
    set -l bold (set_color --bold)
    set -l cyan (set_color cyan)
    set -l green (set_color green)
    set -l yellow (set_color yellow)
    set -l magenta (set_color magenta)
    set -l red (set_color red)

    set -l white (set_color white)
    
    echo ""
    echo "   $bold review_auto$reset  $dim·$reset  PR #$cyan$pr_number$reset"
    echo "   $dim$provider · $num_panes reviewers · $max_rounds rounds max$reset"
    echo ""

    # --- split panes: 4 quadrants (orchestrator + 3 reviewers) ---
    # Layout:
    # ┌─────────────────────┬─────────────────────┐
    # │   ORCHESTRATOR      │      Evelyn         │
    # ├─────────────────────┼─────────────────────┤
    # │     Vivian          │      Stella         │
    # └─────────────────────┴─────────────────────┘
    set -l pane_0 $WEZTERM_PANE
    set -l pane_ids

    # Create quadrants (same pattern as wez_quadrants.example.fish)
    set -l pane_bottom_left (wezterm cli split-pane --pane-id $pane_0 --bottom)
    set -l pane_bottom_right (wezterm cli split-pane --pane-id $pane_bottom_left --right)
    set -l pane_top_right (wezterm cli split-pane --pane-id $pane_0 --right)

    # pane_ids: [Evelyn (top-right), Vivian (bottom-left), Stella (bottom-right)]
    set pane_ids $pane_top_right $pane_bottom_left $pane_bottom_right

    # For fewer panes, kill unused ones
    if test $num_panes -lt 3
        wezterm cli kill-pane --pane-id $pane_bottom_right
    end
    if test $num_panes -lt 2
        wezterm cli kill-pane --pane-id $pane_bottom_left
    end

    # Trim pane_ids to match num_panes
    set pane_ids $pane_ids[1..$num_panes]

    # --- main loop ---
    set -l round 1
    while test $round -le $max_rounds
        set -l round_dir $session_dir/round_$round
        mkdir -p $round_dir

        echo ""
        echo "   $bold round $round$reset$dim / $max_rounds$reset"
        echo ""
        echo "   $white●$reset  review"

        # clean sentinel files and kill any lingering agents from previous round
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            rm -f $round_dir/.done_$name
            if test $round -gt 1
                printf '\x03' | wezterm cli send-text --no-paste --pane-id $pane_ids[$j]
                sleep 1
            end
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
            
            printf "\r   $dim$spinner_frames[$frame_idx]$reset  $status_line"
            
            if test $done_count -ge $num_panes
                break
            end
            
            set frame_idx (math "$frame_idx % 10 + 1")
            sleep 0.05
        end
        echo ""
        echo ""
        echo "   $white●$reset  triage"

        set -l review_files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -a review_files "$round_dir/review_$name.md"
        end
        set -l file_list (string join ", " $review_files)

        set -l triage_sentinel "$round_dir/.done_triage"
        set -l triage_prompt "You are a senior code-review triage agent. Read the review output files at: $file_list

Your job:
- Read all review files using the Read tool
- Filter out nitpicks, style-only comments, and false positives
- Output ONLY the issues that are real bugs, logic errors, security vulnerabilities, or missing error handling
- If a review file is empty or contains an error, skip it
- If there are no real issues, output exactly the string: NO_ISSUES_FOUND
- Format each real issue as: file path, line number, severity (critical/high/medium), and description
- IMPORTANT: Write your final verdict to $round_dir/triage.md using the Write tool. Include NO_ISSUES_FOUND in that file if there are none.
- When completely done, run: touch $triage_sentinel"

        set -l triage_cmd "cursor-agent --yolo --model $triage_model \"$triage_prompt\""
        printf '%s\r' "$triage_cmd" | wezterm cli send-text --no-paste --pane-id $pane_ids[1]

        set frame_idx 1
        while not test -f $triage_sentinel
            printf "\r   $dim$spinner_frames[$frame_idx]$reset  triaging..."
            set frame_idx (math "$frame_idx % 10 + 1")
            sleep 0.05
        end
        echo ""

        # check triage result
        if grep -q "NO_ISSUES_FOUND" $round_dir/triage.md
            echo ""
            echo "   $green●$reset  $bold clean$reset $dim— no issues found$reset"
            echo ""
            return 0
        end

        if test "$dry_run" = true
            echo ""
            echo "   $yellow●$reset  $bold dry run$reset $dim— issues found, skipping fix$reset"
            echo ""
            return 0
        end

        # --- fix phase (runs in Evelyn's pane) ---
        echo ""
        echo "   $white●$reset  fix"

        set -l fix_sentinel "$round_dir/.done_fix"
        set -l fix_prompt "You are a senior engineer. Read the triaged code-review issues at $round_dir/triage.md using the Read tool. Fix every issue listed. Do not fix anything not listed. After fixing, commit your changes with a clear message referencing what was fixed. When completely done, run: touch $fix_sentinel"

        set -l fix_cmd "cursor-agent --yolo --model $fix_model \"$fix_prompt\""
        printf '%s\r' "$fix_cmd" | wezterm cli send-text --no-paste --pane-id $pane_ids[1]

        set frame_idx 1
        while not test -f $fix_sentinel
            printf "\r   $dim$spinner_frames[$frame_idx]$reset  fixing..."
            set frame_idx (math "$frame_idx % 10 + 1")
            sleep 0.05
        end
        echo ""

        set round (math $round + 1)
    end

    echo ""
    echo "   $red●$reset  $bold max rounds$reset $dim— review manually$reset"
    echo ""
    return 1
end
