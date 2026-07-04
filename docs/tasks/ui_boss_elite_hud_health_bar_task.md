# HUD-полоса здоровья босса/элитки сверху экрана (вместо полосы над мобом)

Статус: new
Приоритет: P1
Роль: Back-end
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Locked paths: `scripts/ui_screens.gd` (HUD: `_create_hud`, `_layout_combat_hud`, `_update_hud`), `scripts/enemy.gd` (гейт `_create_health_bar` для bosses/elite), `scripts/combat_director.gd` (проброс ссылки на босса/элитку в HUD, `_spawn_boss`/`_spawn_elite_enemy`/`_on_enemy_died`), `tests/runtime_smoke_ui_test.gd`, `tests/ui_no_overlap_matrix_test.gd`
Jira: SCRUM-874
Версия: 0.2.1
Создано: 2026-07-04
Автор: PM (прямой запрос пользователя)
Labels: backend, claude, fantasydisk, foma, p1

## Autonomy / Approval
Пользователь заранее одобрил. Не останавливаться для подтверждений, вести полностью автономно.

## Source Request

> «Надо переделать health bar боссов и элиток, который встречается на карте. Health bar должен
> быть где-то в интерфейсе игры, а не над самим монстром, боссом, элиткой. Лучше где-нибудь
> сверху, чтобы был просто house[boss] bar боссом.»

## Контекст (Что и Зачем)

Сейчас у ВСЕХ врагов, включая боссов и элиток, полоса здоровья рисуется плавающей над самим
спрайтом:
- `scripts/enemy_health_bar.gd` — Node2D-полоса (z_index 30), спавнится в `scripts/enemy.gd`
  через `_create_health_bar()` в `_ready()`, `preload("res://scripts/enemy_health_bar.gd")`
  (`scripts/enemy.gd:78`).
- Боссы помечены группой `bosses` (`scripts/boss.gd:70`, `add_to_group("bosses")`), элитки —
  группой `elite_enemies` + `elite_behavior` (`scripts/combat_director.gd:419/758`,
  `scripts/enemy.gd:136-139`).

Для боссов/элиток плавающая полоса над спрайтом плохо читается (крупный спрайт, полоса узкая,
теряется в бою). Нужен отдельный крупный HUD-боссбар в интерфейсе игры — сверху экрана — как в
жанре (Vampire Survivors / Souls-подобные): имя цели + большая полоса HP по центру сверху.

## Требования

1. **Общий HUD-боссбар сверху.** Добавить в боевой HUD отдельную панель боссбара (условно
   `BossHealthPanel`), закреплённую по верхнему центру экрана (`PRESET_CENTER_TOP` / top-anchor).
   Создаётся в `_create_hud()` (`scripts/ui_screens.gd:11742`), раскладывается в
   `_layout_combat_hud()` (~`scripts/ui_screens.gd:11881`). Стиль согласован с существующими
   HUD-панелями (рамки `COMBAT_HUD_FRAME_DIR`, филлы `COMBAT_HUD_BAR_FILL_PATHS`); полоса
   заметно шире и выше, чем полоски обычных мобов.
2. **Содержимое панели:** имя цели (напр. «Rift Warden» / имя элитки), крупная полоса HP с
   плавным изменением, опционально числовой `текущее/макс`. Красно-зелёный градиент допустим,
   но по умолчанию — контрастный «боссовый» фолл (тёмный фон + яркий филл), читаемый на любом
   фоне арены.
3. **Появление/скрытие.** Панель видима ТОЛЬКО когда активна цель-босс или цель-элитка
   (`game.boss_combat_active` или `current_combat_type == "elite"` с живой элиткой). В обычном
   бою скрыта. При смерти цели (`_on_enemy_died`, группа `bosses`/`elite_enemies`) — скрыть с
   короткой доводкой полосы в ноль.
4. **Убрать плавающую полосу у боссов/элиток.** В `scripts/enemy.gd` гейтить создание
   `enemy_health_bar` так, чтобы у врагов из групп `bosses`/`elite_enemies` (или с
   `elite_behavior != ""`) плавающая полоса над спрайтом НЕ создавалась (её роль берёт
   HUD-боссбар). У обычных мобов плавающая полоса остаётся как есть — не трогать.
5. **Обновление.** HUD-боссбар обновляется в `_update_hud()` каждый кадр от текущей цели
   (health/max_health босса/элитки). Ссылку на активную цель прокидывать из
   `combat_director._spawn_boss()` / `_spawn_elite_enemy()` (например через поле `game`), чтобы
   HUD знал, чью полосу показывать. Мульти-элитки одного узла: показывать активную/последнюю
   заспавненную (уточнить в реализации, задокументировать выбор).
6. **Без регрессий:** обычные мобы, ресурс-панель (HP/XP/ульта слева), таймер боя — работают
   как раньше. Ничего не наезжает на рамку/орнамент (safe-area), полоса внутри пустой зоны
   панели.

## Acceptance Criteria

- [ ] В боссовом бою и в элитном узле сверху экрана виден крупный HUD-боссбар с именем цели и
      полосой HP; значение полосы совпадает с фактическим HP цели и плавно убывает.
- [ ] У боссов и элиток НЕТ плавающей полосы `enemy_health_bar` над спрайтом.
- [ ] У обычных мобов плавающая полоса над спрайтом сохранена без изменений.
- [ ] Вне боссового/элитного боя HUD-боссбар скрыт; при смерти цели скрывается с доводкой в ноль.
- [ ] Контент панели строго внутри safe-area рамки (нет наезда на орнамент/бордюр/самоцветы),
      читаемо на 1280×720, 1920×1080, 2560×1440.
- [ ] Ресурс-HUD (HP/XP/ульта) и таймер боя не сдвинуты/не сломаны.
- [ ] `runtime_smoke_ui_test.gd`, `ui_no_overlap_matrix_test.gd` и полный `runtime_smoke_test.gd`
      зелёные из чистого worktree.

## Заметки для исполнителя

- `ui_screens.gd` — за Claude-контуром (изоляция файла). Codex этот файл не трогает.
- Не плодить новый спрайт-арт без необходимости: переиспользовать существующие HUD-рамки/филлы
  (`COMBAT_HUD_FRAME_DIR`, `COMBAT_HUD_BAR_FILL_PATHS`), а «боссовый» вид собрать из имеющихся
  ассетов/StyleBox. Если нужен новый арт полосы — вынести в отдельную design-задачу, не блокируя
  функциональную часть.
- Держать panel-margins ≥ наконечника рамки (правило frame-content-safe-area).

## Файлы

- Изменить: `scripts/ui_screens.gd` (новая панель боссбара + layout + update + show/hide),
  `scripts/enemy.gd` (гейт плавающей полосы для bosses/elite), `scripts/combat_director.gd`
  (проброс активной цели в HUD, скрытие на смерти).
- Тесты: `tests/runtime_smoke_ui_test.gd`, `tests/ui_no_overlap_matrix_test.gd`.
- Docs: `docs/design/systems/menus_ui.md` / `docs/design/current_game_state.md` — записать
  контракт HUD-боссбара.

## Валидация

- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- Живой прогон: зайти в элитный узел и в боссовый бой (dev-консоль `~`: spawn/fight), убедиться
  что боссбар сверху и над мобом полосы нет.

## Result

Pending.
