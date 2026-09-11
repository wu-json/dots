---
name: evals-consensus-resolve
description: Resolve tools/evals consensus-lint findings (cases where the models agree with each other and disagree with the gold) by reading each frame and applying a verdict to the fixture files. Use when asked to run the consensus lint, resolve consensus findings, audit eval golds against model agreement, or clear a suite's gold disagreements. Runs no model; edits fixtures and writes a rationale log for PR review.
---

# evals-consensus-resolve

Spec: `docs/wu-json/specs/archived/2026-09-09-evals-gold-audit-and-scorer-normalization.md` §3.

The lint reads committed baselines only. It decides nothing. You decide, per case, by looking at the frame.

## Run

```
cd tools/evals
bun run evals:consensus camera ja --models gemma4-31b-qat,gemma4-26b-a4b-qat,gemma4-12b-qat --json > work/consensus/camera-ja.json
```

- Restrict `--models` to the strongest models that have a baseline for the suite. Two small models agreeing (e2b + e4b) share blind spots; that is not a second opinion. For ko / zh-Hans there is no big-model baseline yet — run `evals:baseline camera ko --model gemma4-31b-qat` first (by hand, ~3 h), then lint.
- `--min-models 2` (default) with three big models is the right bar. Raise to 3 to see only unanimous disagreements.
- One suite per run, so the diff stays reviewable.
- A second source of candidates, for the rich fields the lint cannot see:
  `bun run evals:judge <feature> <lang> --model <id> --baseline --low 2`
  lists cases whose judged translation accuracy or grammar-note correctness
  medians ≤ 2, with the judge's rationale. Every model scoring low on the same
  case with agreeing rationales is usually a wrong reference `translation` /
  `grammarNotes`; fix the reference the same way (edit, or stamp
  `consensusChecked` if the reference is right and the judge is wrong).
  Needs a judged baseline (see the `eval-baselines` skill, "Judge pass").

## Resolve each finding

Open the frame with the `Read` tool (it renders images) and read the text region yourself. Never edit a gold to match the consensus without looking at the frame. Pick one verdict:

| verdict | action |
|---|---|
| gold wrong | Edit `originalText` in `fixtures/<feature>/<lang>/<id>.gold.json` to what the frame shows. Update `subtext` to match (full hiragana; `bun run evals:fold-subtext` afterwards folds any katakana you leave). Leave `translation`/`breakdown` alone if present. |
| gold right | Add `"consensusChecked": { "at": "<YYYY-MM-DD>", "text": "<the originalText as it stands>" }` inside the gold's `source` block. The lint skips the case only while `originalText` still matches `text`, so a later re-label reopens it. Hand-authored golds (no `source`) get a `source: { labeler: { provider: "manual", model: "manual" }, labeledAt, reviewed: true, consensusChecked }`. |
| scope | A `[scope]` tag means one text is a substring of the other: a subtitle plus a persistent corner label, a name plate plus dialogue. No fixed rule. Keep the gold if it is what someone pointing the camera here would want translated (name plate with its dialogue, a two-line title card). Trim it if the extra region is noise (channel watermark, price sticker). Then stamp `consensusChecked`. When the strongest model agrees with the gold and only the smaller ones add the overlay, keep and stamp without opening the frame. |
| unreadable | Occluded, mid-animation, too small to read: `bun run evals:demote <feature> <lang> --case <id> --reject`. Deletes the case and records the frame hash as rejected so the harvest never re-accepts it. |
| unsure | Small text, low contrast, you cannot tell: leave the gold alone and log it. |

Models correcting an on-screen typo is a "gold right" (the frame really says 統しました). Models reading リ as り in a rounded font is "gold right".

## Log

Append one line per case to `work/consensus/<suite>.resolved.md`:

```
- <id> · <verdict> · <what the frame shows, one clause>
```

`work/` is gitignored; paste the log into the PR description. The PR diff is the review: gold edits show as text changes, retirements as deletions.

## Finish

```
bun run evals:consensus camera ja --models ...      # should list only `unsure` cases
bun run fmt
```

Do not run any eval. Edited golds re-run under `--incremental` at the next top-up — but a top-up is refused when the committed baseline's `scorerVersion` differs from the harness (`src/scoring/version.ts`); then the suite needs a full `evals:baseline` regen first.
