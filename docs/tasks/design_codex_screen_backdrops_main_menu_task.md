# Задача Для Design-Агента: Фоны-подложки для экранов с центральным окном + новый арт главного меню

Статус: done (Design review approved 2026-06-12)
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя)
Jira: SCRUM-158

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Владелец — Claude-Designer (спека, ревью, интеграция, коммиты). ЖЕЛЕЗНОЕ
ПРАВИЛО: генерация — Codex Design, к каждой генерации референсы-изображения.
Референсы стиля: `docs/design/references/ui_dark_fantasy_2026_06/` (новый
канон; для фонов особенно `screen_necromantic_lab_reference.png` — глубина
тёмного фона за интерфейсом) + спрайты боссов/персонажей проекта как
контент-референсы. Если для подключения нужен код — handoff в Back-end.

## Контекст (запрос пользователя, 2026-06-12)
«Сгенерировать задний фон для всех мест, где есть окно по центру (например,
настройки). И на главной странице немного изменить картинку — можно
использовать боссов и персонажей». Сейчас за центральными окнами — плоская
заливка/затемнение; главное меню использует старый фон.

Координация со SCRUM-147 (рестайл рамок/кнопок): фоны — ЧАСТЬ нового dark
fantasy канона, делать в нём же (тёмный собор/подземелье с дымкой, как в
референсах), НЕ в старом тавернном стиле. Если SCRUM-147 уже в работе у
Designer — задачи дополняют друг друга: 147 делает рамки/кнопки, эта — фоны
за ними.

## Требования
1. **Инвентаризация экранов с центральным окном:** настройки, кодекс, выбор
   героя/оружия, пауза-досье, level-up, докачка, магазин, события, награда
   элитки, экраны победы/поражения, мета-экраны (+ будущее древо умений
   SCRUM-150 — предусмотреть подложку). Список с текущим фоном каждого — в
   отчёт до генерации.
2. **Фоны-подложки (2560x1440)** в новом dark fantasy каноне: тёмная глубина
   (готический собор, подземелье, лаборатория — вариации по роли экрана),
   мягкая дымка, виньетка к краям, ЦЕНТР СПОКОЙНЫЙ и тёмный — окно поверх
   должно читаться идеально, фон не конкурирует с контентом (урок
   route_map_backdrop: low-contrast center). 3-5 вариаций на роли экранов
   (системные/торговля/смерть/награда/магия), не обязательно уникальный фон
   каждому экрану.
3. **Главное меню — новый арт** (2560x1440): обновлённая картина в dark
   fantasy каноне С ИСПОЛЬЗОВАНИЕМ боссов и персонажей игры (например, герои
   против силуэтов боссов: Страж Разлома / Пожиратель Дисков на заднем плане,
   узнаваемые классы на переднем). Спрайты боссов/персонажей прикладывать к
   генерации как контент-референсы, чтобы образы совпадали с игровыми.
   Зона кнопок меню остаётся читаемой (тёмная/спокойная область под колонку
   кнопок).
4. **Интеграция:** подключить фоны к экранам (через тему/хелпер фона — если
   нужен код, handoff Back-end со списком экран→фон), масштабирование под
   любые разрешения без растяжения-искажения (cover-режим).
5. Превью до/после ключевых экранов; content_registry; CHANGELOG; smoke.

## Files / Assets / IDs
- Новые: assets/backgrounds/ui/ (подложки экранов), главное меню
  (заменить текущий menu background ассет — найти точный путь при инвентаризации)
- Референсы: docs/design/references/ui_dark_fantasy_2026_06/,
  assets/sprites/bosses/*.png, assets/sprites/characters/*.png
- scripts/ui_screens.gd (подключение фонов; возможен Back-end handoff)

## Acceptance Criteria
- [ ] Инвентаризация экранов и карта экран→фон в отчёте.
- [ ] 3-5 фонов-подложек 2560x1440, спокойный центр, окна читаются.
- [ ] Главное меню — новый арт с узнаваемыми боссами/персонажами игры, зона кнопок читаема.
- [ ] Каждая генерация — Codex с референсами (команды в отчёте).
- [ ] Подключено к экранам (или Back-end handoff создан); превью до/после.
- [ ] content_registry/CHANGELOG; smoke зелёные.

## Документация
- content_registry.md, visual_style_assets.md (раздел фонов UI).

## Самопроверка
Превью каждого экрана с новым фоном (offscreen или дамп) на 1280x720 и
2560x1440; текст и кнопки читаемы.

## Dispatch
- 2026-06-12: Codex Documentation dispatcher отправил задачу в Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`; Jira `SCRUM-158` переведена в работу и добавлена в активный спринт 0.1.4. Координация: `SCRUM-147`.

## Progress Log

2026-06-12 — Design/Codex pass завершен, задача передана в review.

### Инвентаризация Экранов

| Экран / роль | Текущее состояние | SCRUM-158 mapping |
| --- | --- | --- |
| Main menu | `assets/backgrounds/main_menu_epic_battle.png` | Заменен новым main menu battle art с героями/боссами, левая зона спокойная под кнопки |
| Shop | `screen_shop_background.png` через `SCREEN_BACKGROUND_PATHS.shop` | Заменен копией `ui_backdrop_merchant_archive.png` |
| Event / upgrade / victory/death fallback | `screen_event_background.png` через `SCREEN_BACKGROUND_PATHS.event` | Заменен копией `ui_backdrop_arcane_lab.png`; role-specific victory/death mapping передан Back-end |
| Campfire/rest | `screen_campfire_background.png` через `SCREEN_BACKGROUND_PATHS.campfire` | Заменен копией `ui_backdrop_system_cathedral.png`; dedicated rest backdrop можно добавить позже |
| Settings | Сейчас отдельный UI path без role backdrop | Back-end handoff: `system_cathedral` |
| Hero / weapon select | Сейчас main/menu UI path | Back-end handoff: `system_cathedral` |
| Pause stats / Escape dossier | Сейчас отдельный pause overlay | Back-end handoff: `system_cathedral` |
| Level-up / attribute upgrade | Сейчас level-up menu box | Back-end handoff: `arcane_lab` |
| Elite reward / artifact reward | Центральная reward modal | Back-end handoff: `reward_hall` |
| Victory | Event fallback | Back-end handoff: `reward_hall` |
| Death / defeat / end-run danger | Event fallback | Back-end handoff: `defeat_crypt` |
| Future meta skill tree SCRUM-150 | Backend task in progress | Back-end handoff: `system_cathedral` or `arcane_lab` depending on layout |

### Сгенерированные Ассеты

- `assets/backgrounds/ui/ui_backdrop_system_cathedral.png` — system/settings/codex/hero/pause/meta;
- `assets/backgrounds/ui/ui_backdrop_merchant_archive.png` — shop/event merchant/archive mood;
- `assets/backgrounds/ui/ui_backdrop_arcane_lab.png` — level-up/upgrade/event magic/progression;
- `assets/backgrounds/ui/ui_backdrop_reward_hall.png` — victory/rewards/elite artifact reward;
- `assets/backgrounds/ui/ui_backdrop_defeat_crypt.png` — death/defeat/danger confirmation;
- `assets/backgrounds/main_menu_epic_battle.png` — active main menu art replaced in place.

Design-only active path replacements:

- `assets/sprites/ui/screens/screen_shop_background.png` <- merchant archive;
- `assets/sprites/ui/screens/screen_event_background.png` <- arcane lab;
- `assets/sprites/ui/screens/screen_campfire_background.png` <- system cathedral.

### Превью / QA

- Reference contact: `docs/design/previews/ui_dark_fantasy_reference_contact.png`;
- Hero/boss content reference: `docs/design/previews/ui_backdrops_hero_boss_references.png`;
- Result contact: `docs/design/previews/ui_screen_backdrops_dark_fantasy_contact.png`.

All generated backgrounds were resized to `2560x1440`, RGBA. Visual QA: calm low-contrast centers, richer edges, no text/watermark, no abstract junk UI marks.
Godot import: passed. Runtime smoke: blocked by unrelated current worktree HUD layout regression, not by SCRUM-158 assets. Current failure: `Expected no top HUD overlap at battle (1152, 648), got RunResourceHud ... intersects CombatTimerPanel ...` at `tests/runtime_smoke_test.gd:3801`.

### Handoff

Back-end mapping handoff: `docs/tasks/backend_ui_screen_backdrops_integration_task.md`.


## Design Review / 2026-06-12 — ПРИНЯТО (Claude-Designer)
- 5 UI-фонов (arcane_lab, defeat_crypt, merchant_archive, reward_hall,
  system_cathedral): все 2560x1440, dark fantasy канон, богатые края, БЕЗ
  абстрактного мусора. Объективно: центральный регион низкоконтрастный
  (2-5 против 16-21 по полному кадру) — центр спокойный под центральное окно.
- main_menu_epic_battle.png: 2560x1440, заменён на месте; равномерно насыщенный
  арт битвы с персонажами/боссами (центр-окна не требует — кнопки слева) — корректно.
- Без текста/watermark. Маппинг экран→фон — Back-end handoff
  `backend_ui_screen_backdrops_integration_task.md`.
Готово к QA/интеграции.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 168c3fad (ветка dev)

Проверено (фактически):
- **6 ассетов** существуют, все `2560x1440 RGBA8`: 5 оконных подложек
  (system_cathedral, merchant_archive, arcane_lab, reward_hall, defeat_crypt) +
  `main_menu_epic_battle`.
- **Спокойный центр** (численно, центральная зона 30-70%): подложки
  contrast = cathedral 0.24 / merchant 0.05 / arcane 0.06 / reward 0.15 /
  defeat 0.18 — низкий, окна читаемы. `main_menu_epic_battle` = 0.92 (насыщенный
  арт битвы; кнопки слева, центр-окна не требует — корректно).
- **Мапинг**: `SCREEN_BACKGROUND_PATHS` потребляется `ui_screens.gd:4019`
  (`screen_background_id → path`). Wiring подтверждён.
- **Визуал** (мои существующие QA-скрины): settings = cathedral, main_menu =
  epic battle, weapon_select = merchant archive, hero_select = cathedral — все
  рендерятся, центральные окна читаемы поверх подложки.
- **Превью**: result-contact + reference-contact на месте. CHANGELOG: 5 упоминаний.
- **Runtime smoke** сейчас зелёный (исторический HUD-overlap из заметки 2026-06-12
  уже устранён; перепроверено ×2 в этой сессии).

Acceptance:
- [x] 5 подложек 2560×1440, спокойный центр, окна читаются.
- [x] Главное меню — новый арт битвы с героями/боссами, левая зона под кнопки читаема.
- [x] Подключено к экранам (SCREEN_BACKGROUND_PATHS); превью; CHANGELOG.

Баги: нет.
