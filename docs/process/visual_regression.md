# Visual regression gate

The visual gate renders a fixed set of key screens and combat scenes and
compares each frame against a committed baseline PNG. It exists to catch
*noticeable* visual breakage — a black screen, a missing sprite, a HUD that
stopped laying out — not to police one-pixel noise.

- manifest: `tests/visual_regression/manifest.json`
- capture pass: `tests/visual_regression/capture.gd`
- baselines: `tests/visual_regression/baselines/<platform>/`
- comparison and CLI: `tools/visual_gate.py`
- contract tests: `tests/test_visual_gate.py`
- CI job: `visual-regression` in `.github/workflows/quality.yml`

## Why baselines are per platform

Capturing needs a real display. Godot's headless display server installs the
dummy rasterizer, which owns no SubViewport texture, so a headless readback is
always an empty image — the same reason every capture suite in
`tests/ultimates/presentation/` skips when `DisplayServer.get_name()` is
`headless`. The capture script refuses to run headless rather than write blank
baselines.

Pixels also depend on the renderer behind the display, so baselines live under
a platform key (`macos`, `linux`, `windows`) and `manifest.json` names the
`certified_platform` whose baselines are authoritative. The CI job runs on
Linux and therefore executes every display-independent part of the gate
(manifest integrity, baseline hash and geometry integrity, the comparison
maths, the negative probe); pixel capture and comparison are run on the
certified platform.

## Running the gate locally

Run from the repository root on the certified platform, in a windowed session:

```bash
python3 tools/visual_gate.py                      # capture and compare all cases
python3 tools/visual_gate.py --case main_menu_1280x720
python3 tools/visual_gate.py --validate-only      # no display needed
```

A failing case writes `expected.png`, `actual.png` and a red-overlay
`diff.png` under `build/visual_gate/<case-id>/`, and every run writes
`build/visual_gate/summary.json` with the measured ratio, the threshold and
the artifact path for each case.

Exit status: `0` pass, `1` comparison failed, `2` usage error, `3` capture
failed.

## Thresholds

A pixel counts as different when any channel differs by more than
`pixel_tolerance` (default 8). A case fails when the fraction of differing
pixels exceeds `max_diff_ratio` (default 0.004, i.e. 0.4% of the frame).
Both live in `defaults` and may be overridden per case:

```json
{ "id": "…", "pixel_tolerance": 12, "max_diff_ratio": 0.01 }
```

Raise a threshold only for a case with genuinely noisy output, and say why in
the review marker. A threshold loose enough to hide a missing sprite is worse
than no case at all.

## Adding a case

1. Add an entry to `cases` in `manifest.json`. The manifest must keep 8–12
   cases and must retain at least three `ultimate_v2`, two `flipbook`, one
   `main_menu` and one `hud_widget` case — `tests/test_visual_gate.py`
   enforces both.
2. Pick a `kind` and give it the fields it needs:
   - `ultimate_v2` — `scene`, `advance_seconds` (the timeline is stepped by
     this exact delta, so the captured beat is fixed)
   - `flipbook` — `pack`, `animation`, `frame` (the sprite is never played, it
     holds the pinned frame)
   - `main_menu`, `hud_widget` — `scene`
3. Give it a `viewport` `[width, height]`.
4. Confirm the case is deterministic, then record its baseline:

```bash
python3 tools/visual_gate.py --verify-determinism --runs 3
python3 tools/visual_gate.py --update-baselines --case <id> \
    --review "FAN-XXXX: new case, frames reviewed by <name>"
```

If a new case drifts, pin whatever is moving from the capture side rather than
editing production presentation code. `capture.gd` already pins the seed, the
locale, the settle-frame budget and `screen_shake` for this reason.

## Updating baselines

Normal runs never write baselines. An update needs both the explicit flag and
a review marker, and the marker is stored next to the hash in
`baselines/<platform>/index.json`:

```bash
python3 tools/visual_gate.py --update-baselines \
    --review "FAN-XXXX: new gold menu shell, reviewed by <name>"
```

`--update-baselines` without `--review` exits 2 and changes nothing.

Review the change before you commit it: open the `expected.png` /
`actual.png` / `diff.png` triplet from the failing run and confirm every red
region is a change you intended. Commit the updated PNGs together with
`index.json` — CI verifies that each baseline's bytes match its recorded
`sha256`, that its size matches the manifest viewport, and that it carries a
non-empty review marker.

## Negative probe

The probe copies each baseline into a temporary directory, paints a visible
magenta block over roughly 10% of the frame, and requires the comparison to
reject it:

```bash
python3 tools/visual_gate.py --negative-probe
```

By contract it **exits 1 when the mutation is detected** — that is the healthy
outcome — and exits 0 when the gate failed to notice, which means the
comparison has gone blind. It never touches the checkout, and both the CI job
and `tests/test_visual_gate.py` assert that.

## Scope

The gate reads production scenes and art; it never generates or edits them.
Do not "fix" a red case by regenerating source art or by editing presentation
runtime/scenes to match a baseline — diagnose the diff first, then either fix
the regression or update the baseline with a review marker.
