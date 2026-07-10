# SCRUM-968 — хвост интеграции аудио: scripts/ui_screens.gd

Статус: in_progress
Jira: SCRUM-968
Контур: Claude
Owner: Claude orchestrator tail worker (dispatcher-observed live work)
Thread/Worker: `/private/tmp/fsd_wt/wqa`
Locked paths: `scripts/ui_screens.gd` — только audio/UI SFX + credits tail
Ветка/worktree: detached task worktree `/private/tmp/fsd_wt/wqa`

Dispatcher heartbeat 2026-07-10 15:31 EEST: physical Claude-lane work is
active; `scripts/ui_screens.gd` contains the first `artifact_reveal` tail edit.
Codex shared-UI work excludes this file until the owner lands or releases it.

## Контекст

SCRUM-968 интегрировал бардовский аудио-пак (SCRUM-966/967): AudioManager v2
(MUSIC_META, shuffle-bag ротация боя, round-timed outro, стингеры,
set_sfx_loop), триггеры в main.gd / combat_director.gd / route_map_screen.gd /
player.gd / enemy.gd / boss.gd. Файл `scripts/ui_screens.gd` на момент
выполнения был ЗАЛОЧЕН другим воркером (codex, SCRUM-955), поэтому SFX-вызовы
внутри него отложены сюда. Всё ниже — ДОБАВЛЕНИЕ вызовов `game._play_sfx(...)`
/ `AudioManager.play_sfx(...)`; id уже существуют в SFX_PATHS и лежат в
`assets/audio/sfx/*.ogg`. Спека: docs/design/systems/audio.md §5.

Уже РАБОТАЕТ без правок ui_screens.gd (не дублировать):

- `_show_main_menu` (ui_screens.gd:503) зовёт `_play_music("menu")` — alias
  ведёт на `music_menu_tavern_warm`;
- музыка safe-узлов (shop/rest/event/chest) ставится в
  route_map_screen.gd `_open_route_node`, возврат к теме карты — в
  `_show_battle_map`;
- стингеры победы/поражения и снятие low-HP лупа — combat_director.gd
  `_play_combat_result_audio` (death screen отдельного стингера НЕ требует);
- low-HP пульс — player.gd (гистерезис 30/34%, зеркалит виньетку), сам
  вижнетт-код ui_screens.gd:13341+ трогать не нужно.

## Требуемые правки (строки на момент коммита c4349b57)

1. **`purchase` / `ui_error` в обработчиках покупки** — успешная покупка →
   `game._play_sfx("purchase")`, ветка отказа (не хватает золота / слот
   заблокирован) → `game._play_sfx("ui_error")`. Точки:
   - магазин узла: `_show_shop_screen` — обработчик кнопки покупки предмета;
   - докачка атрибутов: `_show_attribute_shop` — покупка атрибута + reroll;
   - атлас/мета-прокачка: обработчики трат meta_points (`_show_upgrade_screen`);
   - событийные траты золота (варианты событий с ценой), если проходят через
     ui_screens-обработчик.

2. **`artifact_reveal` вместо `level_up`** в наградных показах артефактов:
   ~:2221 (акцент victory banner), ~:7197 и ~:7306 (выдача/выбор артефакта
   элитки/босса — сейчас переиспользуют `level_up`).

3. **Централизованный `ui_click`/`ui_back` хелпер**: общий помощник подключения
   кнопок (подтверждение → `ui_click`, назад/отмена/закрытие экрана →
   `ui_back`). Рекомендация спеки — один хелпер (например, обёртка вокруг
   `pressed.connect`) вместо рассыпанных вызовов; троттлинг-группа `ui` уже
   настроена в AudioManager (`ui_click`/`ui_back` дефолт 0.05 c, `ui_error`
   0.08 c).

4. **Credits/«Об игре»**: player-facing блок атрибуций CC BY из
   `docs/CREDITS.md` (Kevin MacLeod, CC BY 4.0 — ОБЯЗАТЕЛЬНАЯ атрибуция при
   дистрибуции). Минимум: пункт «Благодарности» в главном меню или разделе
   настроек, показывающий текст из docs/CREDITS.md.

5. **(Опционально, SHOULD)** музыка `route_map` при открытии атласа/кодекса из
   меню (спека §2 №2): сейчас там остаётся `menu` — допустимо, но путевые
   мета-экраны звучат роднее с `music_route_map_bard_journey`.

## Acceptance

- Покупка в магазине/докачке звучит `purchase`, отказ — `ui_error`.
- Артефакт-награды звучат `artifact_reveal` (не `level_up`).
- Кнопки кликают `ui_click`/`ui_back` через общий хелпер (без спама: троттлинг).
- Игровой экран показывает атрибуции из docs/CREDITS.md.
- runtime_smoke зелёный; headless — все вызовы no-op.
