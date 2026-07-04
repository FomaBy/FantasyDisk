# SCRUM-869 Final QA Recheck RED

Date: 2026-07-04
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050`
Commit under test: `e9e7e5f4b9b3` (`origin/dev`)

## Verdict

RED. Do not move SCRUM-869 to `Готово`.

## Passing Checks

- Static report/manifest/path audit: PASS. `report.json` covers 17 playable characters, 11 refreshed packs, 6 blocked packs with exact PixelLab reasons, and valid runtime/SpriteFrames/south portrait paths.
- `tests/animation_smoke_test.gd`: PASS.
- `tests/playable_character_directional_spriteframes_test.gd`: PASS.
- `tests/character_sprite_registry_alignment_test.gd`: PASS.
- `tests/hero_select_pixellab_layout_test.gd`: PASS.
- `tests/hero_select_berserk_preview_test.gd`: PASS.
- `tests/hero_select_dark_mage_pixellab_preview_test.gd`: PASS.
- `tests/hero_select_guitarist_pixellab_preview_test.gd`: PASS.
- `tests/hero_select_ranger_pixellab_preview_test.gd`: PASS.
- `tests/hero_select_biologist_pixellab_preview_test.gd`: PASS.
- `tests/ranger_pixellab_pack_test.gd`: PASS.
- `tests/runtime_smoke_test.gd`: PASS, with non-fatal existing dummy-renderer `texture_2d_get` warning in Weapon Select screenshot helper.

## Failing Checks

- `tests/biologist_pixellab_pack_test.gd`: FAIL.
  - Error: `Expected res://assets/sprites/characters/full_frame/biologist_pixellab/biologist_idle_south.png visible height to be normalized to 245 px, got 244.`
- `tests/dark_mage_pixellab_pack_test.gd`: FAIL.
  - Error: `Expected primary south idle bbox near 240..250 px footprint, got (228, 244).`

## Notes

Hero Select rotation, directional SpriteFrames rows, registry paths and runtime smoke are green. The RED is limited to PixelLab pack bbox normalization gates for Biologist and Dark Mage. No implementation assets/code were changed during this QA pass.
