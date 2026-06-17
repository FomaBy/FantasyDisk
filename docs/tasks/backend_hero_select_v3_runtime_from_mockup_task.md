# Back-end UI: Hero Select v3 runtime rebuild from accepted mockup/spec

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: Designer 2 handoff from SCRUM-446
Jira: SCRUM-447
QA: in_progress (2026-06-17)
Связано: SCRUM-446, SCRUM-436 (superseded v2), ui-director

## Autonomy / Approval
Пользователь заранее одобрил всё. Работать автономно, без вопросов.

## Контекст
Design phases 1-3 для Hero Select v3 завершены в SCRUM-446. Нужно выполнить только
Back-end runtime phase 4: пересобрать live Hero Select с нуля по принятому макапу,
зонам и production frame assets. Не использовать старые hero-select v2 layout/frames
как основу; v2 считается superseded.

## Source Of Truth
- Mockup: `docs/design/references/hero_select_v3/mockup.png`
- Annotated zones: `docs/design/references/hero_select_v3/mockup_zones_annotated.png`
- Raw Vision bboxes: `docs/design/references/hero_select_v3/zones_vision_raw.json`
- Corrected runtime zones: `docs/design/references/hero_select_v3/zones.json`
- Corrected normalized zones: `docs/design/references/hero_select_v3/zones_normalized.json`
- Frame/content margins: `docs/design/references/hero_select_v3/frames_spec.json`
- Design spec: `docs/design/references/hero_select_v3/hero_select_v3_mockup_spec.md`
- Frame contact preview: `docs/design/previews/hero_select_v3_frames_contact.png`
- Runtime assets: `assets/sprites/ui/frames/hero_select_v3/`

## Runtime Scope
Rebuild `_show_character_select` from scratch around the v3 zones:
- `hero_preview` → live large selected hero portrait inside `frame_preview` content rect.
- `dossier` → live hero name/description/traits/weapons, ascension stepper, and select
  action inside `frame_dossier` content rect.
- `radar` → existing `HeroStatRadar` logic inside square `frame_radar` content rect.
- `carousel` → live hero card rail, arrows, hover highlight and tooltip inside
  `frame_carousel` content rect.
- `title` and `back_button` → runtime title/back controls matching normalized zones.
- Optional background: `assets/sprites/ui/frames/hero_select_v3/background.png`.

## Hard Rules
- Global frame rule: runtime content only in the empty content zones from
  `frames_spec.json`; never on claws, gems, borders, corners, metal ornaments or
  frame texture.
- Preserve gameplay semantics: hero selection, ascension +/- behavior, start/select,
  back/Escape, keyboard/gamepad focus, tooltip behavior and existing radar data.
- `frame_radar` must stay square and must not be non-uniformly stretched.
- `frame_preview`, `frame_dossier`, and `frame_carousel` may use 9-slice with the
  texture margins declared in `frames_spec.json`.

## Verification
- Screenshot comparison against `mockup.png` at least at 1536x864 or 1920x1080.
- UI no-overlap matrix at 1280x720, 1920x1080, 2560x1440.
- Runtime UI smoke and full runtime smoke.
- QA evidence under `build/qa/scrum446_hero_select_v3/`.
- Update `CHANGELOG.md`, `docs/design/systems/menus_ui.md`, and
  `docs/design/current_game_state.md` after integration.

## Acceptance Criteria
- [x] `_show_character_select` uses v3 normalized zones and v3 frame assets.
- [x] Old Hero Select v2 layout/frame assumptions are no longer the runtime basis.
- [x] All runtime content stays inside the corresponding frame content rects.
- [x] Existing hero selection/ascension/start/back/focus/radar behavior is preserved.
- [x] Screenshot composition matches the v3 mockup closely enough for QA sign-off.
- [x] UI no-overlap matrix, runtime UI smoke and full runtime smoke pass.
- [x] Jira/task board/docs are synced after completion.

## Dispatcher Handoff To Back-end (2026-06-15)
Передано в Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.
Причина: SCRUM-446 Design-source package завершён и принят как source of truth;
runtime phase 4 является Back-end UI scope. Работать с reasoning High/no low,
без low, только в рамках Back-end UI integration and tests.

## Back-end Result (2026-06-15)
SCRUM-447 complete. `_show_character_select()` now builds the live Hero Select
from the SCRUM-446 `1536x864` v3 zones and frame/content rects: preview,
dossier, square radar, carousel, title and Back button all scale from
`zones.json` / `frames_spec.json`. Runtime uses the accepted v3 background and
frame PNGs under `assets/sprites/ui/frames/hero_select_v3/`; Godot import
sidecars were added for the runtime assets so the screen cannot silently fall
back to generic panel borders.

Preserved behavior: hero selection, ascension `-`/`+`, Select, Back/Escape,
keyboard/gamepad focus, tooltip-safe carousel behavior, SCRUM-416 portrait
routing, SCRUM-417 portrait scaling, and existing `HeroStatRadar` data. The
radar frame is kept square and is not stretched non-uniformly.

QA evidence:
- `build/qa/scrum446_hero_select_v3/hero_select_v3_runtime_1536x864.png`
- `build/qa/scrum446_hero_select_v3/hero_select_v3_mockup_vs_runtime_1536x864.png`
- `build/qa/scrum446_hero_select_v3/hero_select_v3_diff_x3_1536x864.png`
- `build/qa/scrum446_hero_select_v3/hero_select_v3_runtime_rects.md`
- `build/qa/scrum446_hero_select_v3/hero_select_v3_no_overlap_matrix.md`

Verification:
- PASS: `runtime_smoke_ui_test.gd`
- PASS: `ui_no_overlap_matrix_test.gd`
- PASS: `runtime_smoke_test.gd`

## QA-Вердикт (2026-06-17)
Статус: PASSED — Hero Select v3 пересобран с нуля по макапу (Фаза 4)
Проверено: `_show_character_select` строит экран из SCRUM-446 v3 zones/frames (preview/dossier/
radar/carousel/title/back из zones.json+frames_spec.json, фоны/рамки `hero_select_v3/*.png` +
import-сайдкары). runtime_smoke (HERO_SELECT_V3_* ассерты) + runtime_smoke_ui зелёные.
Заменяет провалившийся SCRUM-436. done → Готово.
⚠️ QA: `ui_no_overlap_matrix` имеет 2 ПРЕД-существующих overflow при 1152×648 (settings + attribute_shop, оба и в HEAD до этой волны) — заведены отдельным багом `bug_settings_attribute_shop_overflow_overlap_1152x648_task.md`, НЕ регрессия этого тикета.
