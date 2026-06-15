# BUG/ART: Рамки наград/событий слишком узкие — текст не влезает, сделать ШИРЕ

Статус: review
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-437
QA: in_progress (2026-06-15)
Связано: SCRUM-415 (текст событий), SCRUM-384 (фрейм), asset-generator

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Улучшения по завершению уровня или при эвентах — рамки очень узкие, текст не
помещается. Надо перерисовать рамку и сделать ещё пошире, места дофига — не экономь».

Карточки опций — `_make_economy_choice_card` (ui_screens.gd:5966), сейчас ширина
~250px (события 4071, награды/апгрейд 4037, отдых 4015). Длинные описания не влезают.

## Требования
1. **Перерисовать рамку карточки опции ШИРЕ** (новый широкий ассет, скиллом
   asset-generator, прозрачный фон, единый стиль) — существенно увеличить ширину
   (напр. 250 → ~360-420px) и при необходимости высоту; на экране места достаточно,
   НЕ экономить.
2. Текст опции (заголовок/описание/«Выбрать») целиком в content-зоне новой рамки,
   автоперенос, без обрезки/упирания в орнамент (глоб. правило фреймов).
3. Применить ко ВСЕМ использованиям карточки: события, награды за уровень/элитку,
   апгрейд, отдых. Ряд карточек не выходит за экран на 1280×720 (адаптивно).
4. Старый узкий ассет — в бэкап.
5. Тест (smoke+no-overlap): события/награды строятся; длинные описания влезают в
   широкую рамку, no-overlap на 1280×720/1920×1080/2560×1440. Скрин в build/qa/.
6. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_economy_choice_card 5966; display_size; вызовы 4015/4037/4071;
  ECONOMY_CHOICE_CARD_PATH; _make_economy_choice_row)
- assets/sprites/ui/frames/ (новая широкая карточка) + бэкап
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Рамка карточки опции существенно шире; текст (заголовок/описание/кнопка) целиком влезает, без обрезки/упирания.
- [ ] Применено ко всем (события/награды/апгрейд/отдых); ряд влезает на 1280×720; no-overlap на 3 разрешениях.
- [ ] Старое в бэкап; smoke+matrix зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Dispatcher Dispatch (2026-06-15)
Передано Designer 2 (`019ec7a6-55a5-7bc3-a397-606ce046308d`) как 0.1.6 bug/UI-visual row.

Design scope first: prepare a wider transparent option-card frame/source, safe content
margins, previews/spec, and handoff notes using the required UI/asset skills. Back-end
runtime/layout integration and tests remain a follow-up handoff after the Design asset/spec
is accepted. Keep reasoning High/no low.

## Design Result (Designer 2, 2026-06-15)

Design first pass complete; status set to `review` because the full bug still needs
Back-end runtime integration/tests before `done`.

- OpenAI/API mockup: `docs/design/mockups/scrum437_wide_economy_choice_card/scrum437_wide_option_card_mockup.png`.
- Wide frame source: `docs/design/references/scrum437_wide_economy_choice_card/scrum437_wide_option_card_frame_source.png`.
- Runtime-ready Design candidates:
  - `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide.png`;
  - `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_wide_hover.png`.
- Spec/handoff: `docs/design/mockups/scrum437_wide_economy_choice_card/spec.md`.
- Metadata: `docs/design/references/scrum437_wide_economy_choice_card/scrum437_wide_economy_choice_card_metadata.json`.
- Previews:
  - `docs/design/previews/scrum437_wide_economy_choice_card_safe_zone.png`;
  - `docs/design/previews/scrum437_wide_economy_choice_card_1280_layout_preview.png`.
- Design QA: `build/qa/scrum437/scrum437_asset_validation.md`.
- Old narrow PNG backup: `docs/design/backups/scrum437_economy_choice_card/`
  (`.gdignore`, PNG-only, no `.import` sidecars).

Safe-zone contract for Back-end:

- source size: `Vector2(960.0, 640.0)`;
- base texture margins: `Vector4(96.0, 88.0, 96.0, 96.0)`;
- base content margins: `Vector4(132.0, 118.0, 132.0, 128.0)`;
- hover texture margins: `Vector4(104.0, 96.0, 104.0, 104.0)`;
- hover content margins: `Vector4(140.0, 126.0, 140.0, 136.0)`;
- safe rect: `Rect2(132, 118, 696, 394)`.

Back-end follow-up:

- integrate these wide paths in `scripts/ui_screens.gd` or replace the old
  path only after updating `ECONOMY_CHOICE_SOURCE_SIZE`, margins and display sizes;
- use responsive display targets from the spec (`360x240` at 1280x720,
  `420x300` at 1920x1080, `480x340` at 2560x1440);
- apply to rest, upgrade, event and attribute/economy choice cards;
- run `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd` and
  `tests/runtime_smoke_test.gd` with screenshots/dumps under `build/qa/scrum437/`.

No runtime scripts, gameplay logic, reward logic, layout code or tests were edited
in this Design pass.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-scope: широкий option-card фрейм + спека); Back-end интеграция — pending

Проверено (фактически):
- **Wide-фрейм существенно шире**: `ui_frame_economy_choice_card_wide.png` +
  `_wide_hover` = **960×640** vs оригинал 512×768 (+87% по ширине) — «места дофига».
  Все RGBA, corner_alpha=0, прозрачные + opaque. Mockup/spec/source/metadata
  (`scrum437_wide_economy_choice_card/`).
- **Визуал** mockup: 3 широкие option-карты в едином D&D dragon-фрейме, content-зоны
  с запасом под заголовок/описание/кнопку (без упирания).

⚠️ **Видимый фикс ещё НЕ в рантайме**: `_make_economy_choice_card`/`_show_*`
не подключены к wide-фрейму (grep ui_screens.gd пусто) — требуется **Back-end
runtime-интеграция + тесты** (ширина карточки, текст без обрезки, no-overlap на 3
разрешениях). Это остаточная фаза тикета — НЕ промоутил в Готово.

Acceptance:
- [x] Design: широкий прозрачный option-card фрейм (960×640) + safe margins + mockup/spec.
- [ ] Back-end: wide-фрейм в рантайме, текст целиком влезает, no-overlap, smoke зелёные — pending.

Статус: Design-source PASS, ждёт Back-end integration. Баги: нет (Design-scope).
