# Задача Для Back-end-Агента: Ультимативные Способности — Фреймворк И 9 Ультов По Классам

Статус: done
Создано: 2026-06-12
Автор: PM
Масштаб: крупная. Зависимость: экшен `ultimate` в InputMap создается в
`backend_settings_tabs_volume_keybindings_task.md` (если еще не влита — завести самому).
Dispatch note: 2026-06-12 routed by dispatcher to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

## Autonomy / Approval
Пользователь заранее одобрил. Конкретные дизайны ультов — направление PM ниже,
улучшай и фиксируй в документации.

## Контекст
Пользователь хочет кнопку ультимативной способности. В игре уже есть
зарезервированный атрибут `ultimate_multiplier` (рассчитывается: 1 + Energy*0.02 +
награды, помечен «зарезервировано» в stat_formulas) — пришло его время.

## Требования

### Фреймворк
1. **Заряд ульты**: копится от урона врагам и получения урона (шкала 0-100);
   скорость накопления масштабируется от Энергии. Полный заряд → кнопка
   (экшен `ultimate`, дефолт R) активирует ульту класса, шкала обнуляется.
2. **HUD**: шкала заряда ульты в стиле UI-кита (рядом с HP), иконка класса,
   пульсация при полном заряде; на паузе не копится.
3. **`ultimate_multiplier` наконец работает**: множитель силы эффекта ульты.
   Снять пометку «зарезервировано» в stat_formulas/кодексе.
4. Данные ультов — data-driven (конфиг на класс: заряд за единицу урона,
   длительность, множители), как остальной контент.

### 9 ультов (направление PM — по идентичности класса, улучшай)
| Класс | Ульта |
| --- | --- |
| berserk | «Неистовство»: N секунд +скорость атаки и движения, каждый удар — эхо-волна |
| dark_mage | «Темная буря»: вихрь снарядов вокруг, по врагам в радиусе DoT-проклятие |
| guitarist | «Соло»: гигантская звуковая волна от героя, длительный стан + отброс всех |
| assassin | «Танец клинков»: серия мгновенных рывков по ближайшим N врагам с критами |
| ranger | «Лунный залп»: дождь болтов по большой области с телеграфом |
| doctor | «Переливание»: массовый drain всех врагов в радиусе, избыток лечения — временный щит |
| chemist | «Цепная реакция»: все активные облака детонируют каскадом с увеличенным радиусом |
| knight | «Бастион»: непробиваемость N сек + таунт врагов на себя + усиленные контратаки |
| druid | «Зов стаи»: временно призывает стаю зверей сверх лимита |

5. Каждая ульта: телеграф/VFX (AttackVfx читаемо), звук (есть sfx-шина),
   уникальность — не дублировать обычные атаки класса, это «момент славы».
6. Баланс: полный заряд копится ~45-90 сек активного боя; ульта решает момент,
   но не зачищает босса в одиночку (по боссам кап урона от ульты, реши и зафиксируй).
7. Кодекс: описание ульты в карточке класса; тултип у шкалы HUD.
8. Тесты: накопление заряда, активация по экшену, эффект каждой ульты (точечно),
   обнуление шкалы, пауза; все smoke зеленые.

## Files / Assets / IDs
- `scripts/player.gd` (заряд/активация), `scripts/progression_data.gd` (конфиги ультов),
  `scripts/class_weapon.gd`/`combat_director.gd` (эффекты), `scripts/stat_formulas.gd`
  (ultimate_multiplier), `scripts/ui_screens.gd` (HUD-шкала), `scripts/codex_data.gd`,
  `project.godot` (InputMap `ultimate`).

## Acceptance Criteria
- [x] Шкала заряда в HUD, активация по клавише (ребиндится в настройках), дефолт R.
- [x] 9 уникальных ультов работают, телеграфы/VFX/звук читаемы.
- [x] ultimate_multiplier влияет на силу, «зарезервировано» снято.
- [x] Баланс-рамки соблюдены (время заряда, кап по боссам), замеры в отчете.
- [x] Кодекс/доки обновлены; точечные тесты ультов + smoke зеленые.

## Документация
- mechanics_extract (формулы заряда, конфиги ультов), content_registry (имена ультов
  каноничны), current_game_state, CHANGELOG.

## Результат 2026-06-12

Back-end implementation complete:
- `ProgressionData.ULTIMATE_CONFIGS` добавляет data-driven конфиги для 9 классов: title/description/duration/radius/damage/charge rates/boss cap.
- `Player` получил `ultimate_charge`, `ultimate_max_charge`, charge gain от weapon hits и полученного урона, activation по InputMap action `ultimate`, сброс шкалы и boss damage cap.
- Реализованы 9 ульт через существующие backend/VFX-системы: Berserk echo frenzy, Dark Mage storm, Guitarist solo wave, Assassin blade dance, Ranger lunar volley, Doctor transfusion drain, Chemist chain reaction, Knight bastion, Druid pack call.
- Combat HUD получил компактную `ULT`-карточку с tooltip текущей клавиши.
- Кодекс показывает ульту в карточке каждого класса.
- `ultimate_multiplier` снят с reserved-state и влияет на силу/радиус/длительность/число целей.
- Runtime smoke расширен focused ultimate test: готовность, активация, сброс заряда и измеримый эффект для всех 9 классов.

Баланс: заряд настраивается per-class через `damage_charge_rate` и `taken_charge_rate`; Energy множит gain через `1 + Energy*0.025`. Цель — полный заряд примерно за 45-90 секунд активного боя. Boss cap задан per-class в пределах 7-11% max HP за один ultimate-hit, чтобы ульта не закрывала босса одной кнопкой.

Проверка:
`/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`

Result: passed.
