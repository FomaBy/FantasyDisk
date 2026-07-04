# SCRUM-869 QA Verdict

Date: 2026-07-04
Status: PASSED
Worker: `codex-qa-scrum869-20260704`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_20260704112741`

## Scope Verified

- `build/qa/pixellab_character_animation_refresh/report.json`
- `tools/update_pixellab_character_animations.py`
- `docs/tasks/animation_refresh_all_playable_pixellab_task.md`
- `docs/design/systems/animation.md`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- playable source/runtime/SpriteFrames assets under `assets/sprites/characters/`

## PixelLab Blocker Audit

Validated via PixelLab MCP `get_character`:

- `berserk` `8486ce45-f749-4c63-9a6d-f0477d619c2d`: 8 rotations present; complete 6f movement row missing for `south`.
- `soldier` `72b487d3-feea-4012-b39f-b59ba24f7f11`: 8 rotations present; complete 6f movement rows missing for `south`, `north-east`.
- `elementalist` accepted manifest ID `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`: MCP returns not found. Candidate `3068581d-2ff2-4203-ba5e-37c56edefdc6` is technically complete, but `assets/sprites/characters/pixellab/elementalist/manifest.json` marks it as rejected predecessor because of baked hand/orb props, so it is not a valid substitute.
- `sniper` `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`: 8 rotations present; complete 6f movement rows missing for `south`, `north-west`.
- `engineer` `c5bd9766-e7de-4316-ace6-e687c951e621`: 8 rotations present; complete 6f movement row missing for `north`.
- `doctor` `3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`: 8 rotations present; complete 6f movement row missing for `north`.

Verdict: blockers are valid for the accepted/current manifests. The Elementalist candidate should remain a separate design/animation decision, not a silent substitution in SCRUM-869.

## Static Audit

PASS: all 17 playable characters have source/runtime directional frames, `SpriteFrames` animation rows, and valid south `sprite_path`.

PASS: refreshed packs (`assassin`, `biologist`, `chemist`, `dark_mage`, `druid`, `guitarist`, `knight`, `priest`, `ranger`, `robot`, `thief`) have manifests and `alpha_bbox_report.json`.

PASS: blocked characters (`berserk`, `soldier`, `elementalist`, `sniper`, `engineer`, `doctor`) remain on existing valid runtime packs.

PASS: importer refuses partial packs, uses temp dirs, writes deterministic runtime/source names and `SpriteFrames`, and contains no token/Authorization secret markers. Implementation commit contains no `.godot`, zip/tmp/log, token, secret, or auth sidecars.

## Tests

- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/playable_character_directional_spriteframes_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_berserk_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_ranger_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

Note: `runtime_smoke_test.gd` emitted a non-fatal `texture_2d_get` warning in the Weapon Select screenshot helper and still exited 0 with `Runtime smoke test passed`.

## Cleanup

Removed local `.godot` import cache and generated untracked `.uid/.import` sidecars from the disposable QA worktree before commit.
