# ART/ТЕХ: Полный апдейт интерфейса в стиле D&D + Dark Fantasy Dragon — ОПОРНАЯ

Статус: new
Приоритет: high
Роль: Designer (Codex) + Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-327

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Появился новый скилл по созданию графики и интерфейсов. Надо пересмотреть весь
интерфейс игры и по референсам в папке references обновить ВСЕ интерфейсы в стиле
D&D + Dark Fantasy Dragon. Явно указать агентам использовать новый скилл (он
рисует в тысячу раз лучше) и сразу сохранять файлы на прозрачном фоне в документы
и ассеты (и референсы — для единообразия в будущем)».

Это ОПОРНАЯ задача инициативы «UI Overhaul: D&D + Dark Fantasy Dragon» (0.2.0).
Она задаёт единый стиль и общие UI-атомы ПЕРЕД кластерными задачами по экранам
(каждая блокируется этой). В игре ~26 экранов (`_show_*` в scripts/ui_screens.gd).
Экран выбора героя НЕ входит — он переделывается отдельной серией SCRUM-281/320/321/322/323.

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


## Требования — стайл-гайд + общие атомы
1. Зафиксировать единый UI style-guide D&D + Dark Fantasy Dragon (палитра, металл/
   камень, драконьи мотивы, самоцветы, золото-акцент, типографика, состояния
   hover/pressed/focus/disabled) — документ в docs/design/references/ +
   docs/design/systems/menus_ui.md.
2. Обновить общие UI-атомы (используются всеми экранами), новым скиллом, на
   прозрачном фоне, в assets/ + references/:
   - кнопки (по референсам Buttons), все размеры/состояния; согласовать с hover
     БЕЗ жёлтого свечения (SCRUM-318);
   - рамки/панели/тултипы (по UiFrame), 9-slice с content margins ≥ окантовки;
   - курсор (по cursor);
   - общие фоновые подложки экранов (ui_backdrop_* в main.gd) — единый стиль.
3. Референсы для стиля — папки в `docs/design/references/`: Interface,
ui_dark_fantasy_2026_06, UiFrame, Buttons, cursor (и тематические herouiframe/
heroframe/carusel/windrose/DescriptionHS/settings_tab_switcher_frame). Брать как
ориентир стиля D&D + Dark Fantasy Dragon.
4. Перечислить и закрепить кластерную разбивку экранов (см. парные тикеты) и
   единые пути/нейминг ассетов, чтобы кластеры были единообразны.
5. Тест (smoke): общие атомы грузятся, целевые экраны строятся без ошибок,
   no-overlap, контент в content-зоне рамок. Превью-контакт стиля в docs/design/previews/.
6. CHANGELOG; menus_ui; content_registry.

## Acceptance Criteria
- [ ] Style-guide D&D + Dark Fantasy Dragon + общие атомы (кнопки/рамки/курсор/подложки) обновлены новым скиллом, прозрачный фон, в assets/ + references/.
- [ ] Кластерная разбивка и конвенции путей зафиксированы; глобальное правило фреймов соблюдено.
- [ ] 6 smoke зелёные; превью-контакт стиля; CHANGELOG; menus_ui.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Blocker History — 2026-06-14
Опорная UI-overhaul задача требует рисовать все общие атомы через
`fantasydisk-asset-generator` (`gpt-image-2`) и запрещает старый pipeline. В
текущем окружении отсутствует `OPENAI_API_KEY`, Python `openai` также недоступен.
Без этого нельзя создать production-ready reference/assets для кнопок, рамок,
курсора и подложек, а зависимые кластеры должны оставаться gated. Задача
заблокирована до появления рабочего skill-доступа.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved; task is
eligible for Design/Codex execution after the currently active Design task.
