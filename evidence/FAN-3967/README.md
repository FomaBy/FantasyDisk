# FAN-3967 evidence: Druid and Guitarist combat-primitive ratchet repair

Base: `e33bded444e301919dc93c8c9b9f0257e640a1ea` (pinned `dev`).
Code commit: `ee434eeba` on `agent/claude-dev-fable/9426dc35badb` (the exact
candidate SHA/tree is recorded on the Multica card).

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

Headless: Druid/Guitarist timelines, Druid/Guitarist certification capture
suites, presence driver, presentation budget, contact-sheet beats, migration
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
