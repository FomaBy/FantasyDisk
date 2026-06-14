# Feature: Автосохранение забега после элемента карты + предложение продолжить при старте

Статус: done
Приоритет: medium
Роль: Back-end (геймплей/персистентность)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-349
QA: in_progress (2026-06-14)
Связано: SCRUM-319 (диалог подтверждения — паттерн), SCRUM-339 (поток магазина/карты)

## Прогресс (2026-06-14, Claude Fable 5)
**Сделано (изолированно, без правки общих файлов):**
- `scripts/run_autosave.gd` (`class RunAutosave`) — самодостаточный модуль
  персистентности: `save_run(state)` (атомарно через .tmp+rename),
  `load_run()`/`has_run()` (повреждённый/несовместимый/отсутствующий → {} без
  крэша), `clear_run()`; версионирование схемы (`SCHEMA_VERSION`). Паттерн
  ConfigFile как у meta_progression.gd. State агностичен (любой run-Dictionary).
- `tests/run_autosave_persistence_test.gd` — гейт: round-trip разных типов,
  атомарность (нет остаточного .tmp), повреждённый файл, несовместимая схема,
  перезапись, очистка. PASS. Покрыт edge-case acceptance (п.5).

**Осталось (интеграция — требует общих файлов, сейчас заняты):**
- main.gd: собрать run-state в Dictionary + вызвать `RunAutosave.save_run` после
  элемента карты; `clear_run` при смерти/победе.
- route_map_screen.gd: триггер автосейва на завершении узла (`_open_route_node`).
- ui_screens.gd: на старте (`_show_main_menu`) при `RunAutosave.has_run()` —
  «Продолжить»/«Новая игра» (отказ → новый забег + clear).
Взять, как только main.gd/route_map_screen.gd/ui_screens.gd освободятся.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«В следующую версию надо добавить автосохранение игры после прохождения элемента
на карте. Перед запуском должно проверяться наличие автосохранения, и если оно
есть — предлагать запустить сохранение вместо старта новой игры (с возможностью
отказаться)».

Сейчас персистентность: настройки (game_settings.gd → user://settings.cfg) и
мета-прогресс (meta_progression.gd → user://fantasydisk_meta.cfg, ConfigFile).
Автосейва ТЕКУЩЕГО забега нет. Старт новой игры: main menu start_button →
_show_character_select (ui_screens.gd). Карта: route_map_screen.gd (route_stage,
route_selected_indices, _open_route_node, _advance_route_after_noncombat).

## Требования
1. **Автосохранение забега** в user:// (напр. user://fantasydisk_autosave.cfg,
   ConfigFile в стиле meta_progression) — записывается **после прохождения каждого
   элемента карты** (узла: бой/элитка/босс/событие/магазин/отдых/апгрейд),
   т.е. в точке возврата на карту, чтобы resume был на безопасном стыке (не
   посреди боя). Хук — продвижение маршрута (_advance_route_after_noncombat и
   завершение боевого узла перед показом карты).
2. **Снимок забега** (достаточно для возобновления на карте): выбранный персонаж
   (selected_character_id), возвышение (selected_ascension_level), route_stage,
   route_selected_indices, текущий layout/seed карты, деньги, уровень/опыт игрока,
   полученные награды/артефакты/оружие, непотраченные пики повышения, used_event_ids,
   состояние магазина (current_shop_*), и прочее run-состояние из main.gd/route.
   HP/ресурсы — по разумной модели (восстановить на стыке карты как при обычном
   переходе). Версионировать формат (save schema version) для будущей совместимости.
3. **Проверка при запуске**: на главном меню/перед стартом проверять наличие
   валидного автосейва. Если есть — показать предложение **«Продолжить»**
   (загрузить забег) ИЛИ **«Новая игра»** (отказаться) — диалог в стиле игры
   (паттерн SCRUM-319, рамки скиллом SCRUM-324), модальный, фокус осмысленный.
   - «Продолжить» → восстановить снимок и показать карту с текущего route_stage.
   - «Новая игра»/отказ → обычный старт (выбор героя); при фактическом старте
     новой игры старый автосейв перезаписывается/очищается (с подтверждением, если
     это затрёт незавершённый забег — на усмотрение, но без потери «по тихому»).
4. **Очистка автосейва** при завершении забега (смерть/победа) — чтобы законченный
   забег не предлагался к продолжению.
5. Edge-cases: повреждённый/несовместимый автосейв → игнорировать (как будто нет),
   не крашить; отсутствие файла → обычный старт; автосейв атомарен (не бьётся при
   выходе во время записи).
6. Тест (smoke/persistence): пройти элемент → автосейв создан; перезапуск → есть
   предложение продолжить → загрузка восстанавливает персонажа/этап/деньги/награды;
   «Новая игра» стартует с нуля; смерть/победа очищает автосейв. Зелёный прогон.
7. CHANGELOG; current_game_state; systems/persistence (или meta) доку.

## Files / Assets / IDs
- scripts/meta_progression.gd (паттерн ConfigFile save/load) — за образец
- scripts/main.gd (run-state переменные; _load_game_settings 432; save паттерн)
- scripts/route_map_screen.gd (route_stage; route_selected_indices; _open_route_node;
  _advance_route_after_noncombat — хук автосейва)
- scripts/ui_screens.gd (_show_main_menu / start_button; _show_quit_confirmation_dialog
  паттерн диалога; новый «Продолжить/Новая игра» диалог)
- tests/runtime_smoke_test.gd (+ новый persistence-тест)

## Acceptance Criteria
- [x] Забег автосохраняется после каждого пройденного элемента карты (безопасный стык).
- [x] При запуске при наличии валидного автосейва предлагается «Продолжить» или «Новая игра» (с отказом).
- [x] «Продолжить» восстанавливает забег (персонаж/этап/деньги/награды); смерть/победа очищает автосейв.
- [x] Повреждённый/несовместимый сейв не крашит; запись атомарна; persistence-тест + 6 smoke зелёные; CHANGELOG.

## Документация
docs/design/current_game_state.md, docs/design/systems/ (persistence/meta), content_registry при необходимости.

## Result (2026-06-14, Codex Back-end)

Готово. Интегрировал `RunAutosave` в runtime flow:
- `main.gd` собирает/восстанавливает route-safe snapshot: выбранный класс/оружие/Возвышение, route layout/stage/branches, player snapshot, pending rewards, event/shop state и shop reentry.
- `route_map_screen.gd` сохраняет safe checkpoint после non-combat nodes и после выхода из shop без продвижения stage, сохраняя node-bound stock/purchased state.
- `combat_director.gd` сохраняет после победы в обычном/элитном бою только после reward/attribute flow перед возвратом на карту.
- `ui_screens.gd` показывает modal prompt «Продолжить»/«Новая игра» при старте из главного меню, очищает autosave при новом забеге, смерти и победе.
- `run_autosave.gd` получил pre-parse validation, чтобы мусорный corrupted save игнорировался без красного ConfigFile parse spam.

Тесты:
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/run_autosave_persistence_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

Документация обновлена: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/systems/technical_architecture.md`, новый `docs/design/systems/persistence.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически):
- **Persistence-гейт** `run_autosave_persistence_test` — passed
  (round-trip/atomic/corrupt/version/clear): повреждённый/несовместимый сейв →
  игнор без краша, запись атомарна (.tmp+rename), очистка работает.
- **Save-хуки** (автосейв после каждого элемента карты, безопасный стык):
  `route_map_screen.gd:632` (noncombat_node), `:643` (shop_visit),
  `combat_director.gd:137` (combat_node) → `main.save_run_autosave()` →
  `RUN_AUTOSAVE.save_run(_run_autosave_state())`.
- **Clear-хуки** (завершение/новый забег): `ui_screens.gd:451/468` (новая игра),
  `:3600/:3632` (смерть/победа) → `main.clear_run_autosave()`.
- **Continue prompt** (визуал `build/qa/cap_continue_prompt.png`): модальный
  «Продолжить забег?» со сводкой «Берсерк : этап 1 · уровень 1 · золото 0» +
  кнопки «Продолжить»/«Новая игра» в красно-золотой рамке (паттерн SCRUM-319/344),
  центрирован, оверлей затемнён. При пустом автосейве → обычный выбор героя.
- **Восстановление**: `_run_autosave_state()`/`_apply_run_autosave_state()`
  (класс/оружие/Возвышение, route layout/stage/branches, player snapshot, rewards,
  event/shop state, shop reentry).
- **Регрессия**: `runtime_smoke_test` (incl. `_test_run_autosave_continue_prompt`)
  — passed.

Acceptance:
- [x] Автосейв после каждого пройденного элемента карты (safe checkpoint).
- [x] При старте с валидным автосейвом — «Продолжить»/«Новая игра» (с отказом).
- [x] «Продолжить» восстанавливает забег; смерть/победа/новая игра очищают автосейв.
- [x] Повреждённый/несовместимый сейв не крашит; запись атомарна; persistence +
  smoke зелёные; визуал диалога; доки.

Баги: нет.
