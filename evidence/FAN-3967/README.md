# FAN-3967 evidence: Druid and Guitarist combat-primitive ratchet repair

Base: `e33bded444e301919dc93c8c9b9f0257e640a1ea` (pinned `dev`).
Code commit: `ee434eeba` on `agent/claude-dev-fable/9426dc35badb` (the exact
candidate SHA/tree is recorded on the Multica card).

## Rework after the first QA FAILED verdict (candidate `fe3cacb63`)

- F2: this folder carries a `.gdignore`, so Godot never imports the evidence
  PNGs and a Godot run leaves the tree clean.
- F1: the Druid certification suite rejects any change under `scenes/**`,
  `scripts/**` or `evidence/**` made after the committed package's
  `source.commit_sha`. Both class packages are therefore recaptured on this
  branch in the following commit order, so that every commit after a
  recorded source commit touches only that class's package paths:
  1. this evidence/ignore commit (last code-or-evidence change);
  2. the Guitarist package recapture, sourced from commit 1;
  3. the Druid package recapture, sourced from commit 2.
  The logs of the checks run on the final commit cannot be committed
  (they would count as a post-capture change), so they are attached to the
  Multica handoff comment instead. The earlier
  `candidate_druid_certification_capture_test.log` was taken before the
  first candidate commit and did not reproduce at that SHA; it is removed.

## What changed

- Six scene veils: `ColorRect` (Druid, screen-space `BackdropLayer`) and
  runtime-fitted `Polygon2D` (Guitarist) replaced by radial `GradientTexture2D`
  backed nodes. Druid keeps the same `BackdropLayer/BackdropVeil` path as a
  full-rect `TextureRect`; Guitarist uses the Berserk/Ranger/Thief `Sprite2D`
  veil that `ultimate_v2_presence_driver.gd` already fits to the viewport.
  Centre alpha equals the accepted flat value; edges darken by +0.08/+0.09.
- `druid_ultimate_v2_driver.gd`: the two `Polygon2D.new()` cast-pose halos are
  now `Sprite2D` nodes sharing two process-wide `GradientTexture2D` discs with
  the same colours, radii and z order. Node names, lifecycle and cleanup are
  unchanged.
- `tests/ultimates/presentation/druid_certification_capture_test.gd:518`
  (outside the declared write set, reported on the card): the backdrop is
  asserted as a `CanvasItem` instead of the banned `ColorRect` type.
- No new external asset, no PixelLab charge; the accepted flipbooks remain the
  only weapon art.

## Ratchet

`base_ratchet_findings_sorted.txt` (18) vs `candidate_ratchet_findings_sorted.txt`
(11); `ratchet_findings_sorted_diff.txt` shows only the seven owned removals and
no additions. The global test stays red (exit 1) on the eleven findings owned by
the other repair slices.

## Checks (all exit 0 unless noted)

Headless: Druid/Guitarist timelines, Guitarist certification capture suite
(the Druid one is re-run on the final commit, see above), presence driver, presentation budget, contact-sheet beats, migration
shards, Druid live/package and Guitarist live/mechanics suites.
Windowed: both certification live captures (144 samples each) and both
contact captures (648p/720p/1080p/2K). Static guard, `git diff --check` and a
secret grep on the diff are clean. Logs and their SHA-256 are listed in
`fan3967_summary.json`.

## Captures

`captures/<class>_live/`: normal-mode `active` beat frames at 648p, 720p,
1080p and 2K from the in-game certification capture (the cast pose is only
visible there). `captures/<class>/` and `captures/<class>_base/`: contact
sheets at the four resolutions for candidate and base. Both Druid sheets are
equally dark on base and candidate (mean luminance 12.4 vs 12.0) because that
capture path stacks the three screen-space veils; this is pre-existing.
`candidate_<class>_certification_capture_manifest.json` carries the 144
measured readability records per class; every floor of the certification
suites is met and every Druid sample reports `cast_pose_bound=true`.

## Rebase onto `dev` `f0e878356` (after the `a38a3bbcd` PASS)

FAN-3966 integrated the Elementalist and Knight veils while `a38a3bbcd` was in
review, and its PASS was conditioned on the old base. The branch is merged onto
the new `dev` with the merge commit `cf557fe4b` (no history rewrite, so both
reviewed candidates stay ancestors), then both certification packages are
recaptured again in the same source-ordered chain: this evidence commit, the
Guitarist package sourced from it, the Druid package sourced from the Guitarist
commit. `newbase_f0e878356/` holds the ratchet baseline measured on the new
`dev` in a fresh detached worktree (12 findings), the merged candidate run
(5 findings) and their sorted diff (the same 7 owned removals, 0 additions).
The remaining five findings belong to the Assassin, Doctor and Robot slices.

## Rebase onto `dev` `4dd28d94d` (FAN-3968/3969 integrated)

`dev` moved again while the card was blocked on the capture host. The branch is
merged onto `4dd28d94d` with merge commit `31e3d53f3` (no history rewrite).
`newbase_4dd28d94d/` holds the ratchet baseline measured on that `dev` in a
fresh detached worktree (7 findings, exactly this card's seven) and the merged
candidate run: the global `combat_primitive_ratchet_test` now PASSES with 0
violations outside the ratchet (sorted diff: 7 removed, 0 added). The
certification packages are recaptured after this commit in the same
source-ordered chain (Guitarist sourced from this commit, Druid from the
Guitarist commit).
