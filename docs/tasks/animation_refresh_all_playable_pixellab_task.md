# Refresh All Playable Character Animations From PixelLab

Jira: SCRUM-869
Статус: done (RED fix ready for QA 2026-07-04)
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

## QA-Вердикт Final Recheck (2026-07-04 10:50)

Статус: RED

Проверено на `origin/dev` / `e9e7e5f4b9b3` в чистом worktree
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050`.

Что прошло:

- PASS static report/manifest/path audit: 17 playable characters covered; 11
  refreshed, 6 blocked with precise PixelLab source/package reasons; all south
  `sprite_path`, runtime frames and `SpriteFrames` resources exist.
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/animation_smoke_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/playable_character_directional_spriteframes_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/character_sprite_registry_alignment_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/hero_select_pixellab_layout_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/hero_select_berserk_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/hero_select_dark_mage_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/hero_select_guitarist_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/hero_select_ranger_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/hero_select_biologist_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/ranger_pixellab_pack_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/runtime_smoke_test.gd` (`texture_2d_get` in Weapon Select screenshot helper is non-fatal; test exits 0 with `Runtime smoke test passed`).

Блокеры:

- FAIL `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/biologist_pixellab_pack_test.gd`
  - `Expected res://assets/sprites/characters/full_frame/biologist_pixellab/biologist_idle_south.png visible height to be normalized to 245 px, got 244.`
- FAIL `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/qa_scrum869_final_20260704_1050 --script res://tests/dark_mage_pixellab_pack_test.gd`
  - `Expected primary south idle bbox near 240..250 px footprint, got (228, 244).`

Вердикт: не переводить SCRUM-869 в `Готово`. Требуется fix/review для
PixelLab pack bbox normalization или явное обновление устаревшего test contract,
если product owner решит, что эти exact bbox gates больше не являются
acceptance. Evidence: `build/qa/pixellab_character_animation_refresh/qa_red_scrum869_final_20260704.md`.

## RED Fix — 2026-07-04

Статус: READY FOR QA / `Контроль качества`.

Исполнитель: `codex-anim-fix-scrum869-bbox-20260704` в worktree
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704`.

Что исправлено:

- `tools/update_pixellab_character_animations.py` теперь нормализует runtime
  full-frame PNG по фактическому PixelLab alpha bbox, масштабируя только
  видимую область исходного PixelLab кадра и вставляя её в `512x512` canvas с
  заданным bottom padding. Видимый арт не дорисовывался и не заменялся.
- Импортёр читает вложенные параметры `manifest.normalization.*`, включая
  `target_visible_height`, `bottom_padding` и `alpha_threshold`.
- Добавлен режим `--normalize-existing` для точечной пересборки runtime frames
  из уже принятых PixelLab source frames без нового download/refresh.
- Пересобраны только runtime/full-frame PNG и `alpha_bbox_report.json` для
  `biologist` и `dark_mage`; PixelLab source frames остались source of truth.

Проверка bbox после фикса:

- `biologist_idle_south.png`: было `244`, стало `159x245`; все 56 Biologist
  runtime frames имеют height `245`.
- `dark_mage_idle_south.png`: было `(228,244)`, стало `230x246`; все 56 Dark
  Mage runtime frames имеют height `246`.

Tests:

- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/biologist_pixellab_pack_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/dark_mage_pixellab_pack_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/animation_smoke_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/playable_character_directional_spriteframes_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/hero_select_biologist_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/hero_select_dark_mage_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path /Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum869_bbox_fix_20260704 --script res://tests/runtime_smoke_test.gd` (`texture_2d_get` warning in Weapon Select screenshot helper is non-fatal; exit code 0 and `Runtime smoke test passed`).

Legacy/manual fallback: not used.

Jira target: return SCRUM-869 to `Контроль качества` for separate QA verdict,
not `Готово`.

## QA-Вердикт (2026-07-04, superseded by RED final recheck above)

Статус: PASSED

Проверено:

- Live Jira перед стартом: `SCRUM-869` был в `Контроль качества`; QA claim добавлен в Jira с owner/worker/lane/worktree/locked paths.
- PixelLab MCP blocker audit:
  - `berserk` `8486ce45-f749-4c63-9a6d-f0477d619c2d`: 8 rotations есть, 6f movement rows есть для 7 направлений; `south` отсутствует.
  - `soldier` `72b487d3-feea-4012-b39f-b59ba24f7f11`: 8 rotations есть, 6f movement rows отсутствуют для `south`, `north-east`.
  - `elementalist` accepted manifest ID `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`: PixelLab MCP `get_character` returns not found. Candidate `3068581d-2ff2-4203-ba5e-37c56edefdc6` is technically complete but local manifest explicitly marks it as rejected predecessor due baked hand/orb props, so it is not a valid substitute for this refresh.
  - `sniper` `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`: 8 rotations есть, 6f movement rows отсутствуют для `south`, `north-west`.
  - `engineer` `c5bd9766-e7de-4316-ace6-e687c951e621`: 8 rotations есть, 6f movement row отсутствует для `north`.
  - `doctor` `3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`: 8 rotations есть, 6f movement row отсутствует для `north`.
- Static pack audit: all 17 playable characters have source/runtime directional frame files, `SpriteFrames` animation rows, and valid south `sprite_path`; 11 refreshed packs have manifest + `alpha_bbox_report.json`; blocked characters' existing runtime packs remain valid.
- Importer safety audit: `tools/update_pixellab_character_animations.py` refuses partial packs before touching assets, uses temp dirs, writes deterministic filenames/resources, and contains no token/Authorization secret markers. The implementation commit contains no `.godot`, zip/tmp/log, token, secret, or auth sidecars.

Tests:

- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/playable_character_directional_spriteframes_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_berserk_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_ranger_pixellab_preview_test.gd`
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` (`texture_2d_get` warning in Weapon Select screenshot helper is non-fatal; exit code 0 and `Runtime smoke test passed`).

Краевые случаи:

- Rejected Elementalist predecessor was verified as complete but intentionally not accepted because the repo manifest records a visual rejection.
- Blocked characters were checked as current-valid runtime packs, not as newly refreshed packs.
- First Godot run generated local import cache/sidecars in the disposable QA worktree; `.godot` and generated untracked `.uid/.import` files were removed before verdict/commit.

Баги: нет.

Evidence: `build/qa/pixellab_character_animation_refresh/qa_verdict_scrum869_20260704.md`.
