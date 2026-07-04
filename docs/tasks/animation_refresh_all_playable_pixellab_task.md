# Refresh All Playable Character Animations From PixelLab

Jira: SCRUM-869
Статус: done
Контур: Codex
Исполнитель: Codex
Owner: Animator/Codex
Thread: codex-anim-refresh-scrum869
Locked paths: assets/sprites/characters/pixellab/; assets/sprites/characters/full_frame/*_pixellab/; assets/sprites/characters/*_spriteframes.tres; scripts/progression_data_characters.gd; scripts/player.gd; scripts/ui_screens.gd; tests/*animation*.gd; tests/*hero_select*pixellab*.gd; docs/design/systems/animation.md; docs/design/current_game_state.md; docs/design/content_registry.md; CHANGELOG.md

Claim: 2026-07-04 11:10 Europe/Vilnius via Jira-pull by `codex-anim-refresh-scrum869`.
Branch/worktree: `codex/scrum869-pixellab-animation-refresh` at `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_pixellab_animation_refresh_20260704_110228`.
Next verification step: inventory `ProgressionData.character_ids()` and existing PixelLab manifests, then use PixelLab MCP `get_character` for every manifest id before importer/rebuild. PixelLab-only source; no legacy/manual fallback.

## Source Request

Пользователь: "И ещё нужно пересмотреть всех персонажей и обновить анимацию с Pixel Lab. Там уже на всех персонажах есть анимация, вот её нужно взять и обновить."

## Scope

- Review every playable character in `ProgressionData.character_ids()`.
- Use PixelLab MCP as the source of truth for existing playable character animation packs.
- Re-download/update the current PixelLab source rotations and movement animations for all playable characters where PixelLab has completed animation data.
- Rebuild normalized `512x512` runtime frames and Godot `SpriteFrames` resources.
- Preserve the current 8-direction idle + 6-frame directional move/walk contract.
- Do not use legacy/manual/non-PixelLab art fallback for refreshed source frames.
- Update manifests, PixelLab metadata, alpha-bbox reports, docs, and QA evidence.

## Acceptance Criteria

- [x] `tools/update_pixellab_character_animations.py` refreshes all available playable PixelLab packs or records precise blockers for any missing/incomplete pack.
- [x] Every refreshed character has 8 idle directions and directional move/walk rows that satisfy the current Godot tests.
- [x] `scripts/progression_data_characters.gd` sprite paths still point to valid south idle runtime frames.
- [x] Hero Select previews keep directional rotation for refreshed characters.
- [x] Focused animation/Hero Select tests pass; broader runtime smoke is attempted and result recorded.
- [x] Jira/local mirror include PixelLab source IDs, changed files, tests, commit/push evidence, and disk cleanup.

## Result — 2026-07-04

Imported from completed PixelLab packages and rebuilt source/runtime/SpriteFrames
for:

- `assassin` — `ec73da27-b704-4336-9275-74c8e3e578df`
- `biologist` — `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`
- `chemist` — `c7fe44d3-1f15-45a1-b762-b2862833b151`
- `dark_mage` — `9bb0eca8-5afe-49d4-8e56-7115a45efdcc`
- `druid` — `4078113b-fece-4087-a035-9ed3714a6514`
- `guitarist` — `d278e753-9885-4550-82ff-81ee3bef297d`
- `knight` — `c1a7d633-7353-4861-aea3-8d937b601cba`
- `priest` — `ed7db59e-0845-4218-b178-a56f948254b5`
- `ranger` — `1646d83c-f570-4bdd-9065-cb1b46bf13f7`
- `robot` — `37c6ccf2-ab40-4c89-83a3-db8365f85257`
- `thief` — `02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f`

Blocked by current PixelLab source/package completeness and left on existing
valid runtime packs:

- `berserk` — `8486ce45-f749-4c63-9a6d-f0477d619c2d`: missing complete 6-frame movement row for `south`.
- `soldier` — `72b487d3-feea-4012-b39f-b59ba24f7f11`: missing complete 6-frame movement rows for `south`, `north-east`.
- `elementalist` — manifest `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`: PixelLab `get_character`/download returns not found / HTTP 404; completed list candidate `3068581d-2ff2-4203-ba5e-37c56edefdc6` remains marked as rejected predecessor in the repo manifest, so it was not substituted.
- `sniper` — `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`: missing complete 6-frame movement rows for `south`, `north-west`.
- `engineer` — `c5bd9766-e7de-4316-ace6-e687c951e621`: missing complete 6-frame movement row for `north`.
- `doctor` — `3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`: missing complete 6-frame movement row for `north`.

Evidence:

- Import report: `build/qa/pixellab_character_animation_refresh/report.json`.
- Refreshed paths: `assets/sprites/characters/pixellab/<character>/`,
  `assets/sprites/characters/full_frame/<character>_pixellab/`,
  `assets/sprites/characters/<character>_spriteframes.tres`, plus updated
  per-character manifests and alpha-bbox reports.
- PixelLab-only source used for refreshed characters; no legacy/manual fallback
  imported into refreshed packs.

Tests:

- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/playable_character_directional_spriteframes_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_berserk_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_ranger_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` (non-fatal existing `texture_2d_get` warning in Weapon Select screenshot helper; test exits passed).

Git/Jira:

- Branch: `codex/scrum869-pixellab-animation-refresh`.
- Commit/push evidence: final Jira comment records the pushed commit hash after
  the commit is created.
- Jira target status after push: `Контроль качества`.
- Disk cleanup: remove task `.godot`, temporary download probes and Python
  caches before final report.
