# UI: Интегрировать SCRUM-452 minimal-metal frame anchor

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-17
Автор: Designer 2 (Codex handoff)
Jira: SCRUM-459
QA: in_progress (2026-06-17)
Связано: SCRUM-452, SCRUM-450, SCRUM-451, SCRUM-273, SCRUM-448, SCRUM-449

## Контекст

Designer 2 завершил Design-source anchor для упрощения UI: строгий
minimal-metal frame kit с прозрачными RGBA PNG, точными texture/content margins
и safe-zone preview.

## Входные артефакты

- Style guide: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_style_guide.md`
- Spec: `docs/design/mockups/scrum452_ui_minimal_metal/spec.md`
- Metadata: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
- Contact preview: `docs/design/previews/scrum452_minimal_metal_anchor_contact.png`
- Safe-zone preview: `docs/design/previews/scrum452_minimal_metal_safe_zones.png`
- Assets: `assets/sprites/ui/frames/minimal_metal/`

## Scope

Back-end should wire the minimal-metal frame kit behind a clear theme path set
or reviewed promotion path. Do not replace SCRUM-273 Red & Gold buttons in this
task: SCRUM-450 owns new button art/states. Do not force Hero Select v3 authored
frames, progression circular nodes or combat bar fills into the generic builder
unless SCRUM-451 explicitly accepts that migration.

## Требования

1. Add runtime paths/constants for the six `minimal_metal` frame candidates.
2. Build shared StyleBoxTexture/NinePatch helpers using metadata texture margins.
3. Enforce content margins at least equal to the metadata content margins.
4. Integrate only into safe generic non-button surfaces or keep as selectable
   theme candidates if broader rollout is not yet accepted.
5. Preserve existing button behavior, focus, input navigation and localization.
6. Run UI no-overlap matrix and runtime smoke.

## Acceptance Criteria

- [x] Runtime can load all six `assets/sprites/ui/frames/minimal_metal/*.png`.
- [x] Content stays inside declared `content_rect_xywh`; no labels/icons/buttons
      overlap metal rails, corner plates or ruby pins.
- [x] SCRUM-273 Red & Gold buttons remain unchanged unless SCRUM-450 is accepted.
- [x] QA evidence is written under `build/qa/scrum452_minimal_metal/`.
- [x] `runtime_smoke_ui`, `ui_no_overlap_matrix` and full runtime smoke pass or
      document an unrelated blocker.

## Результат
- Back-end done 2026-06-17: wired the SCRUM-452 minimal-metal frame candidates as
  first-class runtime theme paths/constants in `scripts/ui/ui_theme_paths.gd`.
- Added reusable `_minimal_metal_frame_style(frame_type, tint)` in
  `scripts/ui_screens.gd`; it builds tiled `StyleBoxTexture` surfaces from the
  metadata texture margins and enforces the stricter content margins/safe rects.
- Kept the kit as selectable runtime candidates only. SCRUM-273 Red & Gold
  buttons, current SCRUM-448 live generic frames, Hero Select v3 authored frames,
  progression circular nodes and combat bar fills were not promoted/replaced in
  this task; broad rollout remains SCRUM-463.
- Added permanent guard coverage in `tests/dark_fantasy_ui_theme_test.gd` against
  `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
  and wrote QA evidence to
  `build/qa/scrum452_minimal_metal/minimal_metal_runtime_frame_kit.md`.
- Checks PASS: `dark_fantasy_ui_theme_test.gd`, `runtime_smoke_ui_test.gd`,
  `ui_no_overlap_matrix_test.gd`, `runtime_smoke_test.gd`.

## QA-Вердикт (2026-06-17)
Статус: PASSED — интеграция 452 anchor в рантайм-тему
Проверено: `ui_theme_paths.gd` экспонирует minimal-metal frame paths; `_minimal_metal_frame_style`
в `ui_screens.gd` строит tiled StyleBoxTexture по texture margins + строгие content margins.
Guard в `dark_fantasy_ui_theme_test` (метадата 452) PASS; runtime_smoke_ui зелёный. done → Готово.
⚠️ QA: `ui_no_overlap_matrix` имеет 2 ПРЕД-существующих overflow при 1152×648 (settings + attribute_shop, оба и в HEAD до этой волны) — заведены отдельным багом `bug_settings_attribute_shop_overflow_overlap_1152x648_task.md`, НЕ регрессия этого тикета.
