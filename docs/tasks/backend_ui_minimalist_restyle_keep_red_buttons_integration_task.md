# Back-end: Интегрировать минималистичный UI kit, красные кнопки оставить

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: Designer 2 handoff from SCRUM-448
Jira: SCRUM-449
Связано: SCRUM-448, SCRUM-384, SCRUM-273, SCRUM-447, SCRUM-439, SCRUM-438, SCRUM-437

## Контекст

SCRUM-448 подготовил Design-source пакет минималистичного UI-рестайла:
тонкие тёмные рамки, сдержанный aged-brass контур, маленькие ruby pin accents и
строгие content-зоны. Пользователь прямо попросил оставить текущие красные
кнопки: `assets/sprites/ui/frames/red_gold/` не заменять и не перегенерировать.

## Source / Spec

- Spec: `docs/design/mockups/scrum448_ui_minimalist/spec.md`
- Mirror spec: `docs/design/references/ui_minimal/scrum448_minimalist_ui_spec.md`
- Metadata: `docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`
- Style board: `docs/design/references/ui_minimal/scrum448_minimalist_ui_style_board.png`
- Frame source sheet: `docs/design/references/ui_minimal/scrum448_minimalist_frame_kit_source_sheet.png`
- Contact preview: `docs/design/previews/scrum448_minimal_ui_frame_contact.png`
- Alpha audit: `build/qa/scrum448_ui_minimalist/alpha_audit.md`

Runtime candidate assets:

- `assets/sprites/ui/frames/minimal/ui_frame_minimal_modal.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_panel.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_card.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_tooltip.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_hud_strip.png`
- `assets/sprites/ui/frames/minimal/ui_frame_minimal_field.png`

## Scope

1. Add a central minimal frame builder / path map in `scripts/ui_screens.gd` or
   the current UI theme module split, using `StyleBoxTexture` / `NinePatchRect`
   with the exact texture/content margins from SCRUM-448 metadata.
2. Replace non-button generic frame routing across main menu, settings, hero
   select, codex, shop/attribute/rest/event/upgrade, level-up/reward, pause/result,
   combat HUD, tooltips and dialogs where safe.
3. Preserve all SCRUM-273 Red & Gold button textures and `_make_button()` mappings.
   Do not modify `assets/sprites/ui/frames/red_gold/`.
4. Preserve existing runtime semantics: settings values/rebinds, codex navigation,
   hero selection/ascension, reward/event/shop actions, pause/back/escape flow,
   combat HUD updates and tooltips.
5. Archive superseded ornamental non-button frame assets outside the build scope
   only after verifying no live path still needs them. Do not delete red buttons.
6. Keep every label/icon/control/hit area inside the declared content rects.

## Validation

- Run `tests/runtime_smoke_ui_test.gd` if available.
- Run `tests/ui_no_overlap_matrix_test.gd`.
- Run full runtime smoke:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --script res://tests/runtime_smoke_test.gd`
- Capture QA evidence under `build/qa/scrum448_ui_minimalist/`:
  - key screen screenshots at 1280x720 / 1920x1080 / 2560x1440 where practical;
  - rect/no-overlap dumps confirming content stays inside SCRUM-448 safe zones;
  - confirmation that `assets/sprites/ui/frames/red_gold/` was not modified.

## Acceptance Criteria

- [x] All non-button frames/panels/tooltips/HUD surfaces use the minimalist kit
      or an explicitly documented screen-specific exception.
- [x] Red & Gold buttons remain visually and file-wise unchanged.
- [x] No content overlaps frame ornament/borders at 1280x720, 1920x1080, 2560x1440.
- [x] Old ornamental assets are backed up/removed from runtime only when no live
      reference remains.
- [x] Required smokes and no-overlap matrix pass.
- [x] CHANGELOG, `docs/design/systems/menus_ui.md`,
      `docs/design/systems/visual_style_assets.md` and
      `docs/design/content_registry.md` are updated with runtime results.

## Result — 2026-06-15

Back-end runtime integration complete.

- Added central minimal frame paths/margins in `scripts/ui/ui_theme_paths.gd`
  and a `StyleBoxTexture` builder in `scripts/ui_screens.gd`.
- Wired SCRUM-448 minimal frames into safe non-button runtime surfaces:
  generic panels/cards, Settings shell/switcher/content panel, Codex
  shell/list/detail/tooltip, economy choice cards/price badges, reward cards,
  pause/result shells and compact combat HUD wrappers.
- Preserved SCRUM-273 Red & Gold button paths and `_make_button()` mappings.
- Preserved screen-specific authored exceptions: Hero Select v3 frames/radar,
  progression node rings, combat bar fills/plus button, shop square item slots
  and other controls whose accepted frame kits remain live.
- Did not archive old ornamental assets in this pass: several still have live or
  historical/screen-specific references, and the shared worktree contains active
  unrelated Design/Animator files. Cleanup should only remove them after a fresh
  no-live-ref audit.
- QA evidence: `build/qa/scrum448_ui_minimalist/alpha_audit.md`,
  `build/qa/scrum448_ui_minimalist/ui_no_overlap_matrix.md`,
  `build/qa/scrum448_ui_minimalist/settings_minimal_runtime_rects.md`,
  `build/qa/scrum448_ui_minimalist/red_gold_preservation.md`.

Verification:

- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`
