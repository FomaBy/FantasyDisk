# ART: UI Overhaul (Пауза и финальные экраны) — D&D + Dark Fantasy Dragon, новым скиллом

Статус: review
Приоритет: medium
Роль: Designer (Claude-Designer; генерация — fantasydisk-asset-generator)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-330
Координация (НЕ блок, скилл задаёт критерии): SCRUM-327 (стайл-гайд + общие атомы)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
Кластер «Пауза и финальные экраны» инициативы «UI Overhaul: D&D + Dark Fantasy Dragon» (0.2.0).
Меню паузы, досье паузы (статы), экран победы, экран смерти.

Экраны кластера (scripts/ui_screens.gd): _show_pause_menu (1853), _show_pause_dossier_menu (1945), _show_victory_screen (3200), _show_death_screen (3231).

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
- scripts/ui_screens.gd (экраны кластера: _show_pause_menu (1853), _show_pause_dossier_menu (1945), _show_victory_screen (3200), _show_death_screen (3231))
- assets/ (игровые ассеты) + docs/design/references/ (исходники)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Design mockup/asset package для кластера «Пауза и финальные экраны» подготовлен в стиле D&D + Dark Fantasy Dragon через `fantasydisk-asset-generator`.
- [x] Ассеты в `assets/` + references/metadata/previews; глобальное правило фреймов зафиксировано через content-zone/safe margins.
- [ ] Runtime no-overlap/smoke на 3 разрешениях требует Back-end integration handoff: `docs/tasks/backend_pause_end_ui_overhaul_integration_task.md`.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Result Summary (2026-06-14)

Design scope completed and ready for Back-end integration:

- Generated OpenAI/skill mockup:
  `docs/design/references/ui_overhaul_pause_end/pause_end_cluster_mockup.png`.
- Added UI mockup/spec:
  `docs/design/mockups/ui_overhaul_pause_end/scrum330_pause_end_mockup_spec.md`.
- Added production runtime frame candidate:
  `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png`
  (`1280x1024`, RGBA transparent).
- Accepted existing runtime result crests:
  `assets/sprites/ui/result_crests/ui_crest_victory.png`,
  `assets/sprites/ui/result_crests/ui_crest_defeat.png`.
- Added metadata and previews:
  `docs/design/references/ui_overhaul_pause_end/scrum330_pause_end_metadata.json`,
  `docs/design/previews/ui_overhaul_pause_end_contact.png`,
  `docs/design/previews/ui_overhaul_pause_end_safe_zones.png`,
  `docs/design/previews/ui_overhaul_pause_end_mockup_1920x1080.png`.
- Modal frame safe zone: source size `1280x1024`, safe rect
  `Rect2(170, 180, 940, 670)`, content margins
  `Vector4(170, 180, 170, 174)`.
- Validation artifact:
  `build/qa/scrum330/pause_end_asset_validation.json`
  (`magenta_visible_pixels: 0`, alpha present).
- Runtime wiring intentionally not done in Design; Back-end handoff created:
  `docs/tasks/backend_pause_end_ui_overhaul_integration_task.md`.

## Прогресс 2026-06-14 (Claude-Designer, параллельно Codex)
Сгенерировано скиллом fantasydisk-asset-generator (gpt-image-2, прозрачный фон через
chroma-key): modal-рамка + кресты победы/поражения. Сохранено в
`docs/design/references/ui_overhaul_pause_end/` (исходники) + `assets/sprites/ui/result_crests/`.
ИНТЕГРИРОВАНО: геральдические кресты (венок победы / череп-драконы поражения) добавлены
АДДИТИВНО над заголовком экранов `_show_victory_screen` / `_show_death_screen` (хелпер
`_add_result_crest`). Безопасно: `_create_menu_box`/`_panel_style` — ОБЩИЙ билдер многих
экранов, его не трогал (иначе заденет настройки/награды/костёр вне scope).
Тесты: runtime_smoke + runtime_smoke_ui — зелёные.
ОСТАЁТСЯ: scoped modal-рамка для паузы/финала (через opt-in параметр _create_menu_box),
рестайл _show_pause_menu / _show_pause_dossier_menu, скрины build/qa, CHANGELOG.

## Прогресс 2026-06-14 (часть 2) — пауза
Сгенерил скиллом тонкую menu-рамку `ui_frame_dark_menu.png` (без гребня, под плотное меню)
и героическую `ui_frame_dark_modal.png`. Меню паузы (`_build_run_pause_menu`) переведено на
тонкую рамку (Control + TextureRect STRETCH + MarginContainer, scoped — общий _panel_style не
тронут). ВНИМАНИЕ: код-правка `ui_screens.gd` лежит в рабочем дереве НЕзакоммиченной, т.к.
параллельная сессия (Codex shop/economy) временно сломала тот же файл (вызовы
`_economy_panel_style`/`_make_economy_choice_card` без определений). Коммит ui_screens.gd —
как только их правка достроится и файл начнёт парситься. Моя секция парсится чисто.
