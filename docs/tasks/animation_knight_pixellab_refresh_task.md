# ANIM: Обновить PixelLab-анимации рыцаря

- Статус: review
- Jira: SCRUM-885
- Контур: Codex
- Owner: Codex Animator
- Thread/Worker: codex-knight-pixellab-refresh-20260708
- Worktree: `/private/tmp/fsd_wt_knight_anim_codex`
- Branch: `codex/knight-pixellab-refresh` -> `dev`
- Locked paths: `assets/sprites/characters/pixellab/knight/`,
  `assets/sprites/characters/full_frame/knight_pixellab/`,
  `assets/sprites/characters/knight_spriteframes.tres`,
  `build/qa/pixellab_character_animation_refresh/`,
  `tests/hero_select_pixellab_layout_test.gd`,
  `docs/design/current_game_state.md`, `docs/design/content_registry.md`,
  `docs/design/systems/animation.md`, `CHANGELOG.md`

## Source Request

Прямая директива пользователя, 2026-07-08: «Надо обновить анимации рыцаря, возьми
из с pixellab».

## Scope

- Обновить только playable character `knight` из PixelLab.
- Использовать PixelLab MCP / repo importer; не использовать legacy/manual art
  fallback для новых source frames.
- Сохранить текущий 8-direction contract: idle по всем направлениям и 6 кадров
  `move`/`walk` на направление.
- Не менять gameplay, баланс, оружие, UI-layout и другие классы.

## Acceptance Criteria

- [x] `knight` source pack под `assets/sprites/characters/pixellab/knight/`
      обновлён из PixelLab и содержит manifest/provenance.
- [x] Runtime full-frame PNG под
      `assets/sprites/characters/full_frame/knight_pixellab/` пересобраны как
      прозрачные `512x512`.
- [x] `assets/sprites/characters/knight_spriteframes.tres` содержит generic
      `idle`/`move`/`walk` и directional `idle_*`, `move_*`, `walk_*` для всех 8
      направлений.
- [x] Документация обновлена: `CHANGELOG.md`,
      `docs/design/current_game_state.md`, `docs/design/content_registry.md`,
      `docs/design/systems/animation.md`.
- [x] Зелёные focused checks: `playable_character_directional_spriteframes`,
      `animation_smoke`, relevant Hero Select preview smoke.
- [x] Результат закоммичен и запушен в `origin/dev`; temporary worktree cleaned.

## Progress

- 2026-07-08: task mirror создан для Jira sync; работа ведётся Codex в отдельном
  clean worktree, потому что основной checkout содержит чужой UI WIP.
- 2026-07-08: PixelLab MCP character
  `c1a7d633-7353-4861-aea3-8d937b601cba` verified as complete; dry-run and real
  import refreshed only `knight` with 8 idle directions and 6-frame directional
  move rows. Runtime export date: `2026-07-08T15:55:39.543782`.

## Result

- PixelLab source: `FantasyDisk Knight PixelLab SCRUM-430 no-shield 2026-06-30`
  (`c1a7d633-7353-4861-aea3-8d937b601cba`).
- Updated source/runtime evidence:
  `assets/sprites/characters/pixellab/knight/manifest.json`,
  `assets/sprites/characters/pixellab/knight/alpha_bbox_report.json`,
  `build/qa/pixellab_character_animation_refresh/knight_dry_run_report.json`,
  and `build/qa/pixellab_character_animation_refresh/scrum885_knight_report.json`.
- Runtime frames regenerated under
  `assets/sprites/characters/full_frame/knight_pixellab/` as 56 transparent
  `512x512` PNGs.
- No gameplay, balance, UI layout, weapon visuals, or non-Knight character packs
  changed.
- Verification:
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/playable_character_directional_spriteframes_test.gd`
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd`
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` (exit 0; dummy renderer emitted a non-fatal screenshot warning before `Runtime smoke test passed`).
- GitHub sync: prepared for task commit and immediate `HEAD:dev` push; Jira final
  comment records the pushed commit.
- Disk cleanup: disposable `.godot/` cache and worktree removed after push; no
  task-owned temporary checkout retained.
