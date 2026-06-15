# Back-end UI: Hero Select v3 runtime rebuild from accepted mockup/spec

Статус: new
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: Designer 2 handoff from SCRUM-446
Jira: SCRUM-447
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
- [ ] `_show_character_select` uses v3 normalized zones and v3 frame assets.
- [ ] Old Hero Select v2 layout/frame assumptions are no longer the runtime basis.
- [ ] All runtime content stays inside the corresponding frame content rects.
- [ ] Existing hero selection/ascension/start/back/focus/radar behavior is preserved.
- [ ] Screenshot composition matches the v3 mockup closely enough for QA sign-off.
- [ ] UI no-overlap matrix, runtime UI smoke and full runtime smoke pass.
- [ ] Jira/task board/docs are synced after completion.
