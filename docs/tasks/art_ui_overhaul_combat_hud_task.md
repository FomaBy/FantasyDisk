# ART: UI Overhaul (Боевой HUD, баннеры и тосты) — D&D + Dark Fantasy Dragon, новым скиллом

Статус: blocked
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.2.0
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-326
Блокируется: SCRUM-327 (стайл-гайд + общие атомы)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
Кластер «Боевой HUD, баннеры и тосты» инициативы «UI Overhaul: D&D + Dark Fantasy Dragon» (0.2.0).
Внутриигровой HUD и всплывашки боя. Согласовать с SCRUM-278 (кнопка повышения вправо-вниз, непрозрачная).

Экраны кластера (scripts/ui_screens.gd): _show_combat_title_banner (3556), _show_level_up_toast (3521), _show_victory_banner (773), in-run HUD (полоски HP/опыта, миникарта/таймер, кнопка повышения SCRUM-278, FAB докачки).

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
- scripts/ui_screens.gd (экраны кластера: _show_combat_title_banner (3556), _show_level_up_toast (3521), _show_victory_banner (773), in-run HUD (полоски HP/опыта, миникарта/таймер, кнопка повышения SCRUM-278, FAB докачки))
- assets/ (игровые ассеты) + docs/design/references/ (исходники)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Все экраны кластера «Боевой HUD, баннеры и тосты» в едином стиле D&D + Dark Fantasy Dragon (новым скиллом, прозрачный фон).
- [ ] Ассеты в assets/ + references/; глобальное правило фреймов соблюдено; навигация цела.
- [ ] no-overlap на 3 разрешениях; 6 smoke зелёные; скрины в build/qa/; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.
