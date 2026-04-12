function review_auto
    # Usage: review_auto [--max-rounds N] [--provider openai|anthropic] [--panes 1-4] [--dry-run]
    set -l max_rounds 3
    set -l provider anthropic
    set -l num_panes 4
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
                echo "Usage: review_auto [--max-rounds N] [--provider openai|anthropic] [--panes 1-4] [--dry-run]"
                return 1
        end
        set i (math $i + 1)
    end

    if test $num_panes -lt 1 -o $num_panes -gt 4
        echo "Pane count must be between 1 and 4"
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
    set -l review_cmd "cursor-agent --yolo --print --trust --model $review_model -p"

    # reviewer identities and prompts
    set -l names Evelyn Vivian Stella Tiffany
    set -l prompts \
        "You are Evelyn. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format." \
        "You are Vivian. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format." \
        "You are Stella. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format. Focus on critical bugs, security vulnerabilities, and logic errors." \
        "You are Tiffany. Use the local review skill to review PR #$pr_number in read-only mode and follow its exact response format. Focus on dead code, unused imports, and unreachable code paths."

    echo "┌─────────────────────────────────────────────┐"
    echo "│  review_auto — PR #$pr_number"
    echo "│  provider: $provider | panes: $num_panes | max rounds: $max_rounds"
    echo "│  session: $session_dir"
    echo "└─────────────────────────────────────────────┘"

    # --- split panes: orchestrator on top, reviewers on bottom ---
    set -l pane_0 $WEZTERM_PANE
    set -l pane_ids

    set pane_ids (wezterm cli split-pane --pane-id $pane_0 --bottom --percent 70)
    if test $num_panes -ge 2
        set -a pane_ids (wezterm cli split-pane --pane-id $pane_ids[1] --right)
    end
    if test $num_panes -ge 3
        set -a pane_ids (wezterm cli split-pane --pane-id $pane_ids[1] --right)
    end
    if test $num_panes -ge 4
        set -a pane_ids (wezterm cli split-pane --pane-id $pane_ids[2] --right)
    end

    # pane_ids is now: [bottom-left, bottom-right, bottom-left-center, bottom-right-center]
    # reorder to match reviewer indices 1..num_panes
    switch $num_panes
        case 1
            # pane_ids = [p1]
        case 2
            # pane_ids = [p1, p2] — already correct
        case 3
            # splits: p1(left full), p2(right half of original), p3(right half of p1)
            # actual order left→right: p1-remaining, p3, p2
            set pane_ids $pane_ids[1] $pane_ids[3] $pane_ids[2]
        case 4
            # splits: p1(left half), p2(right half), p3(right of p1→center-left), p4(right of p2→center-right)
            # actual order left→right: p1-remaining, p3, p2-remaining, p4
            set pane_ids $pane_ids[1] $pane_ids[3] $pane_ids[2] $pane_ids[4]
    end

    # --- main loop ---
    set -l round 1
    while test $round -le $max_rounds
        set -l round_dir $session_dir/round_$round
        mkdir -p $round_dir

        echo ""
        echo "═══════════════════════════════════════════════"
        echo "  ROUND $round / $max_rounds — REVIEW PHASE"
        echo "═══════════════════════════════════════════════"

        # clean sentinel files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            rm -f $round_dir/.done_$name
        end

        # dispatch review agents to panes
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -l cmd "$review_cmd \"$prompts[$j]\" 2>&1 | tee $round_dir/review_$name.md; touch $round_dir/.done_$name"
            printf '%s\r' "$cmd" | wezterm cli send-text --no-paste --pane-id $pane_ids[$j]
        end

        # poll for all reviewers to finish
        echo "  Waiting for $num_panes reviewer(s)..."
        while true
            set -l done_count 0
            for j in (seq $num_panes)
                set -l name (string lower $names[$j])
                if test -f $round_dir/.done_$name
                    set done_count (math $done_count + 1)
                end
            end
            if test $done_count -ge $num_panes
                break
            end
            sleep 5
        end
        echo "  All reviewers finished."

        # --- triage phase ---
        echo ""
        echo "───────────────────────────────────────────────"
        echo "  ROUND $round / $max_rounds — TRIAGE PHASE"
        echo "───────────────────────────────────────────────"

        set -l review_files
        for j in (seq $num_panes)
            set -l name (string lower $names[$j])
            set -a review_files "$round_dir/review_$name.md"
        end
        set -l file_list (string join ", " $review_files)

        set -l triage_prompt "You are a senior code-review triage agent. Read the review output files at: $file_list

Your job:
- Read all review files using the Read tool
- Filter out nitpicks, style-only comments, and false positives
- Output ONLY the issues that are real bugs, logic errors, security vulnerabilities, or missing error handling
- If a review file is empty or contains an error, skip it
- If there are no real issues, output exactly the string: NO_ISSUES_FOUND
- Format each real issue as: file path, line number, severity (critical/high/medium), and description"

        cursor-agent --yolo --print --trust --model $triage_model -p "$triage_prompt" 2>&1 | tee $round_dir/triage.md

        # check triage result
        if grep -q "NO_ISSUES_FOUND" $round_dir/triage.md
            echo ""
            echo "┌─────────────────────────────────────────────┐"
            echo "│  CLEAN — no real issues found in round $round"
            echo "│  PR #$pr_number is good to go."
            echo "│  Session: $session_dir"
            echo "└─────────────────────────────────────────────┘"
            return 0
        end

        if test "$dry_run" = true
            echo ""
            echo "┌─────────────────────────────────────────────┐"
            echo "│  DRY RUN — issues found but skipping fix"
            echo "│  Triage output: $round_dir/triage.md"
            echo "│  Session: $session_dir"
            echo "└─────────────────────────────────────────────┘"
            return 0
        end

        # --- fix phase ---
        echo ""
        echo "───────────────────────────────────────────────"
        echo "  ROUND $round / $max_rounds — FIX PHASE"
        echo "───────────────────────────────────────────────"

        set -l fix_prompt "You are a senior engineer. Read the triaged code-review issues at $round_dir/triage.md using the Read tool. Fix every issue listed. Do not fix anything not listed. After fixing, commit your changes with a clear message referencing what was fixed."

        cursor-agent --yolo --print --trust --model $fix_model -p "$fix_prompt" 2>&1 | tee $round_dir/fix.md

        set round (math $round + 1)
    end

    echo ""
    echo "┌─────────────────────────────────────────────┐"
    echo "│  MAX ROUNDS ($max_rounds) reached for PR #$pr_number"
    echo "│  Review the last round's output manually."
    echo "│  Session: $session_dir"
    echo "└─────────────────────────────────────────────┘"
    return 1
end
