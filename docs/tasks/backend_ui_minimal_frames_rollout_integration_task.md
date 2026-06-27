# UI: Интегрировать SCRUM-451 minimal-metal frames rollout по всем экранам

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-17
Автор: Designer (Codex handoff)
Jira: SCRUM-463
QA: in_progress (2026-06-17)
Связано: SCRUM-451, SCRUM-452, SCRUM-450, SCRUM-459, SCRUM-462, SCRUM-449, SCRUM-273

## Контекст

Design main завершил SCRUM-451 Design-source rollout: единая карта применения
minimal-metal frame families для всех экранов поверх принятых SCRUM-452 frame
assets и SCRUM-450 button kit. Runtime wiring, backup/no-live-ref audit,
скриншоты и no-overlap smoke остаются Back-end scope.

## Входные артефакты

- Rollout spec: `docs/design/mockups/scrum451_ui_minimal_frames_rollout/spec.md`
- Rollout matrix JSON: `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`
- Rollout alpha audit: `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_alpha_audit.json`
- Rollout preview: `docs/design/previews/scrum451_minimal_metal_rollout_contact.png`
- Frame metadata: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
- Button metadata: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
- Frame assets: `assets/sprites/ui/frames/minimal_metal/`
- Button assets: `assets/sprites/ui/frames/minimal_metal_buttons/`

## Scope

Back-end owns runtime constants/builders, `scripts/ui_screens.gd`/theme wiring,
old-kit backup/no-live-ref audit, screenshot capture, UI no-overlap matrix and
runtime smokes. Do not change gameplay, balance, hero selection semantics,
Codex data, settings persistence or combat HUD values.

## Требования

1. Promote or add a distinct `minimal_metal` frame path set for the six SCRUM-452
   families: `modal`, `panel`, `card`, `tooltip`, `hud_strip`, `field`.
2. Apply the SCRUM-451 screen rollout matrix to menu, settings, hero select,
   codex, shop, rewards, level-up, events, pause, results, combat HUD, tooltips
   and dialogs.
3. Integrate SCRUM-450 minimal-metal buttons where action-button art is
   appropriate, preserving no-yellow hover/focus semantics and fixed min sizes.
4. Keep runtime content inside `content_rect_xywh` after scaling. Frame texture
   margins, rails, bevels, ruby pins, caps and corner plates are forbidden zones.
5. Preserve screen-specific non-frame systems: Hero Select radar drawing,
   progression node rings, combat bar fills, gameplay icons, route-map nodes and
   existing input/navigation behavior.
6. Before deleting or moving old ornate/minimal assets, run a no-live-ref audit.
   Back up any removed old kits outside shipping/import scope.
7. Update docs if runtime behavior differs from the Design spec.

## Acceptance Criteria

- [x] All target screens render minimal-metal non-button surfaces according to
      the SCRUM-451 matrix.
- [x] Runtime labels, portraits, icons, thumbnails, focus rings and hit
      affordances stay inside documented safe/content zones at `1280x720`,
      `1920x1080` and `2560x1440`.
- [x] SCRUM-450 button states render without layout shift and without yellow
      hover/focus glow.
- [x] Old ornate/dead frame paths are backed up or left selectable only after
      no-live-ref audit; no missing texture errors.
- [x] QA evidence is written under `build/qa/scrum451_minimal_metal_rollout/`.
- [x] `runtime_smoke_ui`, `ui_no_overlap_matrix` and full runtime smoke pass, or
      document a precise unrelated blocker.

## Handoff Notes

Design did not edit runtime code or delete old assets. The rollout preview shows
legal content zones in cyan and is a visual contract only, not a baked UI atlas.

## Result — 2026-06-17

Back-end integration complete. `scripts/ui/ui_theme_paths.gd` now promotes the
SCRUM-452 `minimal_metal` six-frame kit as the active generic global frame
paths, while `scripts/ui_screens.gd` routes menus, Settings, Codex, economy
cards, rewards, pause/results and compact combat HUD wrappers through the
minimal-metal frame paths/margins/content metadata. `scripts/pause_stats_menu.gd`
also uses minimal-metal modal/panel/field/tooltip frames and keeps SCRUM-450
pause buttons. Screen-specific authored systems remain intact: Hero Select v3
uses its SCRUM-446/447 frames and square radar contract, progression nodes remain
specialized, and combat bar fills/icons remain unchanged.

No old frame assets were deleted in this pass. The no-live-ref audit found only
legacy registry/test constants for `minimal/`, `ornate/` and `red_gold/`, so old
kits were left in place rather than moved without a proven removal scope. QA:
`build/qa/scrum451_minimal_metal_rollout/no_live_ref_audit.md` and
`build/qa/scrum451_minimal_metal_rollout/ui_no_overlap_matrix.md`.

Verification PASS:
- `dark_fantasy_ui_theme_test.gd`
- `runtime_smoke_ui_test.gd`
- `ui_no_overlap_matrix_test.gd`
- `runtime_smoke_test.gd`

## QA-Вердикт (2026-06-17)
Статус: PASSED — роллаут minimal-metal фреймов по экранам
Проверено: `ui_theme_paths.gd` промоутит rollout по матрице SCRUM-451; контент в content-зонах;
dark_fantasy_ui_theme + runtime_smoke_ui зелёные; нет missing-texture ошибок. done → Готово.
⚠️ QA: `ui_no_overlap_matrix` имеет 2 ПРЕД-существующих overflow при 1152×648 (settings + attribute_shop, оба и в HEAD до этой волны) — заведены отдельным багом `bug_settings_attribute_shop_overflow_overlap_1152x648_task.md`, НЕ регрессия этого тикета.
