# ART: UI Overhaul (Магазин и узлы экономики) — D&D + Dark Fantasy Dragon, новым скиллом

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-332
Координация (НЕ блок, скилл задаёт критерии): SCRUM-327 (стайл-гайд + общие атомы)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
Кластер «Магазин и узлы экономики» инициативы «UI Overhaul: D&D + Dark Fantasy Dragon» (0.2.0).
Лавка торговца, лавка атрибутов, отдых/костёр, апгрейд, события-узлы карты.

Экраны кластера (scripts/ui_screens.gd): _show_shop_screen (2652), _show_attribute_shop (842), _show_rest_screen (3120), _show_upgrade_screen (3141), _show_event_screen (3152).

## ОБЯЗАТЕЛЬНО — новый графический скилл + конвенции ассетов (директива пользователя)
- Рисовать ВСЮ графику этого тикета СКИЛЛОМ `fantasydisk-asset-generator`
  (Codex skill, `~/.codex/skills/fantasydisk-asset-generator/`) через
  `scripts/generate_asset.py --prompt "<...>" --output <тема/файл> --size <WxH>
  --quality high` (OpenAI Images API, модель `gpt-image-2`, PNG). Он рисует кратно
  лучше прежнего пайплайна — НЕ использовать старый способ. См. SCRUM-324.
  Прозрачный фон обязателен (`background=transparent`/output_format png).
- Все ассеты — PNG на ПРОЗРАЧНОМ фоне (RGBA, без подложки/checkerboard).
- Сохранять файлы СРАЗУ в три места для единообразия на будущее:
  1) `assets/` — игровой ассет (по месту использования, напр. assets/sprites/ui/...),
  2) `docs/design/references/<тема>/` — референс-исходник (чтобы будущие правки шли
     в едином стиле),
  3) при необходимости — превью/контакт-лист в `docs/design/previews/`.
- Стиль: **D&D + Dark Fantasy Dragon** — тёмный металл/камень, драконьи мотивы,
  красные самоцветы, благородное золото-акцент; единый по всей игре.
- Соблюдать ГЛОБАЛЬНОЕ правило фреймов (AGENTS.md / qa_protocol): контент (кнопки,
  иконки, текст, портреты, области выбора) — ТОЛЬКО в пустой/прозрачной зоне рамки,
  НИКОГДА на орнамент; content margins ≥ окантовки.
- Старые ассеты, которые заменяются, — в бэкап, не удалять.


## Требования
1. Переоформить ВСЕ экраны кластера в единый стиль D&D + Dark Fantasy Dragon по
   style-guide и общим атомам из опорной задачи (SCRUM-327): рамки, панели,
   кнопки, иконки, заголовки, подложки.
2. Референсы для стиля — папки в `docs/design/references/`: Interface,
ui_dark_fantasy_2026_06, UiFrame, Buttons, cursor (и тематические herouiframe/
heroframe/carusel/windrose/DescriptionHS/settings_tab_switcher_frame). Брать как
ориентир стиля D&D + Dark Fantasy Dragon.
3. Глобальное правило фреймов: кнопки/иконки/текст/области выбора — только в
   пустой/прозрачной зоне рамок, не на орнаменте; content margins ≥ окантовки.
4. Все новые ассеты — новым скиллом, прозрачный фон, сохранить в assets/ +
   docs/design/references/<тема>/ (единообразие на будущее). Старые — в бэкап.
5. Не ломать логику/навигацию экранов (только визуал/стилизация); клавиатура+
   геймпад-фокус сохраняются.
6. Тест (smoke): все экраны кластера строятся без ошибок, no-overlap, контент в
   content-зоне рамок, на 1280×720 / 1920×1080 / 2560×1440. Скрины в build/qa/.
7. CHANGELOG; menus_ui; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (экраны кластера: _show_shop_screen (2652), _show_attribute_shop (842), _show_rest_screen (3120), _show_upgrade_screen (3141), _show_event_screen (3152))
- assets/ (игровые ассеты) + docs/design/references/ (исходники)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Все экраны кластера «Магазин и узлы экономики» в едином стиле D&D + Dark Fantasy Dragon (новым скиллом, прозрачный фон).
- [ ] Ассеты в assets/ + references/; глобальное правило фреймов соблюдено; навигация цела.
- [ ] no-overlap на 3 разрешениях; 6 smoke зелёные; скрины в build/qa/; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Progress Log

- 2026-06-14 — Designer 2 took SCRUM-332 after board check. Anchor SCRUM-327 is
  `done`/superseded and this task file marks SCRUM-327 as coordination, not a
  blocker. Jira moved to «В работе» via `tools/jira_board_sync.py`.
- 2026-06-14 — Generated OpenAI/API economy cluster mockup via
  `fantasydisk-asset-generator`:
  `docs/design/references/ui_overhaul_shop_economy/scrum332_economy_cluster_mockup.png`;
  copied into `docs/design/mockups/scrum332_shop_economy/`.
- 2026-06-14 — Generated OpenAI/API isolated frame source sheet:
  `docs/design/references/ui_overhaul_shop_economy/scrum332_economy_frame_asset_sheet.png`.
  Because gpt-image-2 baked a checkerboard, added deterministic alpha/crop
  builder `tools/build_scrum332_shop_economy_assets.py`.

## Result Summary — 2026-06-14

Design-scope complete and ready for QA / Back-end integration handoff.

Deliverables:
- Mockup/spec:
  - `docs/design/mockups/scrum332_shop_economy/scrum332_economy_cluster_mockup.png`
  - `docs/design/mockups/scrum332_shop_economy/spec.md`
- Runtime-ready frame kit:
  - `assets/sprites/ui/frames/economy/ui_frame_economy_panel.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_choice_card_hover.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_dragon_panel.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_price_badge.png`
  - `assets/sprites/ui/frames/economy/ui_frame_economy_tooltip.png`
- Reference copies:
  `docs/design/references/ui_overhaul_shop_economy/runtime_assets/`.
- Preview:
  `docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`.
- Back-end handoff:
  `docs/tasks/backend_ui_overhaul_shop_economy_integration_task.md`.

Design decision:
- SCRUM-332 does not wire `scripts/ui_screens.gd` in Design scope. Back-end owns
  live layout, focus, escape, shop purchase/reentry, route advancement and
  no-overlap runtime tests.
- The generated kit intentionally does not include a dedicated square shop-slot
  replacement. Back-end may keep current shop slots; if a new square slot is
  needed, create a small follow-up Design generation instead of squashing the
  tall `economy_choice_card`.

Validation:
- OpenAI mockup generated and preview shown in chat.
- Frame source sheet generated through `fantasydisk-asset-generator`.
- Alpha-cleaned runtime PNGs created from source sheet; dimensions verified by
  `file`.
- Godot headless `--import` exited 0 and created `.import` sidecars for all six
  `assets/sprites/ui/frames/economy/*.png` files.
- Geometry, safe zones, forbidden ornament zones and responsive rules recorded
  in `spec.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: economy frame kit + spec + Back-end handoff — теперь realized live)

Проверено (фактически):
- **6 economy-фреймов** (`assets/sprites/ui/frames/economy/`): panel 1024×640,
  choice_card + hover 512×768, dragon_panel 1024×512, price_badge 256×96, tooltip
  640×320 — все RGBA, прозрачные углы, контент+прозрачность; 6 `.import`, import чист.
- **Визуал** `scrum332_shop_economy_frame_kit_contact.png`: единый D&D Dark Fantasy
  Dragon стиль (тёмный металл/камень, золото-оранж окантовка, красные самоцветы),
  content-зоны — тёмные центры. Mockup + spec.md (safe zones/forbidden ornament).
- **Back-end handoff** реализован: SCRUM-406 (live-интеграция economy в shop/attribute/
  rest/upgrade/event) — мной QA PASSED + закоммичен (7e1b362d). No-overlap чист на 5
  разрешениях, рамки в рантайме.

Acceptance (Design+realized):
- [x] Economy-экраны в едином D&D dragon-стиле (kit скиллом, прозрачный фон).
- [x] Ассеты в assets/ + references/; правило фреймов (safe zones в spec); навигация цела (через 406).
- [x] no-overlap на 3 разрешениях + smoke зелёные (через 406); kit + контакт-лист.

Статус review→done. Баги: нет. Economy-петля закрыта: 332 (kit) + 406 (live).
