# ART: UI Overhaul (Прогрессия и кодекс) — D&D + Dark Fantasy Dragon, новым скиллом

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-331
Координация (НЕ блок, скилл задаёт критерии): SCRUM-327 (стайл-гайд + общие атомы)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
Кластер «Прогрессия и кодекс» инициативы «UI Overhaul: D&D + Dark Fantasy Dragon» (0.2.0).
Древо навыков/возвышений, кодекс (персонажи/монстры/артефакты/характеристики/глоссарий), тултипы глоссария.

Экраны кластера (scripts/ui_screens.gd): _show_skill_tree_screen (1010), _show_codex_screen (1192), _show_codex_section (1254), _show_glossary_tooltip (1373).

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
- scripts/ui_screens.gd (экраны кластера: _show_skill_tree_screen (1010), _show_codex_screen (1192), _show_codex_section (1254), _show_glossary_tooltip (1373))
- assets/ (игровые ассеты) + docs/design/references/ (исходники)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Все экраны кластера «Прогрессия и кодекс» в едином стиле D&D + Dark Fantasy Dragon (новым скиллом, прозрачный фон).
- [ ] Ассеты в assets/ + references/; глобальное правило фреймов соблюдено; навигация цела.
- [ ] no-overlap на 3 разрешениях; 6 smoke зелёные; скрины в build/qa/; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Progress Log

- 2026-06-14 — Designer 2 took SCRUM-331 after SCRUM-332 Design handoff. Anchor
  SCRUM-327 is `done`/superseded and this task file marks it as coordination,
  not a blocker. Jira moved to «В работе» via `tools/jira_board_sync.py`.
- 2026-06-14 — Generated OpenAI/API progression+codex mockup via
  `fantasydisk-asset-generator`:
  `docs/design/references/ui_overhaul_progression_codex/scrum331_progression_codex_mockup.png`;
  copied into `docs/design/mockups/scrum331_progression_codex/`.
- 2026-06-14 — Generated OpenAI/API isolated progression frame source sheet:
  `docs/design/references/ui_overhaul_progression_codex/scrum331_progression_frame_asset_sheet.png`;
  added deterministic alpha/crop builder
  `tools/build_scrum331_progression_codex_assets.py`.

## Result Summary — 2026-06-14

Design-scope complete and ready for QA / Back-end integration handoff.

Deliverables:
- Mockup/spec:
  - `docs/design/mockups/scrum331_progression_codex/scrum331_progression_codex_mockup.png`
  - `docs/design/mockups/scrum331_progression_codex/spec.md`
- Runtime-ready progression frame kit:
  - `assets/sprites/ui/frames/progression/ui_frame_progression_main_panel.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_branch_panel.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_available.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_locked.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_purchased.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_node_focus.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_class_panel.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_points_badge.png`
  - `assets/sprites/ui/frames/progression/ui_frame_progression_tooltip.png`
- Reference copies:
  `docs/design/references/ui_overhaul_progression_codex/runtime_assets/`.
- Preview:
  `docs/design/previews/scrum331_progression_frame_kit_contact.png`.
- Back-end handoff:
  `docs/tasks/backend_ui_overhaul_progression_codex_integration_task.md`.

Design decision:
- SCRUM-331 preserves the existing SCRUM-345/SCRUM-403 Codex texture kit as
  accepted baseline. This pass adds progression/skill-tree assets and a unified
  spec, rather than replacing Codex frames again.
- Runtime wiring is intentionally handed off. Back-end owns skill purchase state,
  lazy Codex section construction, glossary popup placement, focus, and escape
  behavior.

Validation:
- OpenAI mockup generated and preview shown in chat.
- Progression frame source sheet generated through `fantasydisk-asset-generator`.
- Alpha-cleaned runtime PNGs created from source sheet; dimensions and alpha
  verified by PIL.
- Godot headless import completed; progression frame `.import` sidecars are
  present.
- Geometry, safe zones, forbidden ornament zones and responsive rules recorded
  in `spec.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: progression/codex frame kit + Back-end handoff)

Проверено (фактически):
- **9 progression-фреймов** (`assets/sprites/ui/frames/progression/`): main/branch/class
  панели + 4 состояния узлов (available/focus/locked/purchased) + points_badge + tooltip
  — все RGBA, прозрачные углы (corner=0), контент+прозрачность (bad=0); 9 `.import`.
- **Визуал** `scrum331_progression_frame_kit_contact.png`: единый D&D Dark Fantasy
  Dragon стиль (тёмный металл/камень, золото/красная окантовка, самоцветы); состояния
  узлов визуально различимы (кольца available/focus/locked/purchased); content-зоны —
  тёмные центры.
- **Back-end handoff** `backend_ui_overhaul_progression_codex_integration_task.md`
  создан (статус **«blocked»**).

⚠️ **Видимая замена UI прогрессии/кодекса ещё НЕ в рантайме**: требует интеграции
`scripts/ui_screens.gd` — Back-end задача SCRUM-408, статус **«blocked»**. Проверю
live-no-overlap на 3 разрешениях при разблокировке и готовности интеграции.

Acceptance (Design-scope):
- [x] Progression/codex фреймы созданы скиллом в едином D&D dragon-стиле (9 PNG).
- [x] Ассеты в assets/ + references; content-зоны/safe margins; import чист.
- [~] Live-замена + no-overlap на 3 разрешениях — Back-end SCRUM-408 (blocked).

Статус review→done (Design-source). Баги: нет (видимая интеграция — delegated Back-end 408, blocked).
