# SCRUM-831: Дев-консоль (~) — оверлей + 20 команд управления игрой

Статус: done
Контур: Claude
Owner: claude-backend (оркестратор, прямой запрос пользователя)
Thread: n/a
Locked paths: `scripts/dev_console.gd` (новый), `scripts/main.gd` (точечные правки), `scripts/player.gd` (godmode-гард), `tests/dev_console_smoke_test.gd`
Версия: 0.2.0
Приоритет: P2
Создано: 2026-07-02
Автор: PM (прямой запрос пользователя)
Jira: SCRUM-831
Labels: claude, foma

## Что и зачем
Внутриигровая консоль разработчика в стиле Slay the Spire 2 (референс:
slaythespire.wiki.gg/wiki/Slay_the_Spire_2:Console — команды act/card/damage/die/
draw/energy/fight/godmode/gold/instant/kill/relic/room/unlock/win, тоггл по `~`,
help + Tab-автодополнение). Нужна для быстрых QA-прогонов, отладки баланса и
воспроизведения багов без прохождения забега руками.

## Реализация (итог)
- **`scripts/dev_console.gd` (новый)** — CanvasLayer (layer 130, поверх паузы 120 и
  фидбека 127), `PROCESS_MODE_ALWAYS`. Создаётся в `Main._ready` как делегат
  (`dev_console = DEV_CONSOLE_SCRIPT.new(self)`), в стиле ui/route/combat.
- **Тоггл**: физическая клавиша слева от «1» — `` ` ``/`~` (ANSI), `§` (Mac ISO),
  `Ё` (русская раскладка): `physical_keycode` KEY_QUOTELEFT|KEY_SECTION. Esc —
  закрыть, Tab — автодополнение по префиксу, Up/Down — история (64 записи).
- **Пауза**: открытая консоль держит `push_pause("dev_console")`; закрытие —
  `pop_pause` (reason-механика, совместима с пауза-меню/level-up).
- **Изоляция ввода**: ранний return в `Main._input` при открытой консоли — буквы
  команд не дёргают хоткеи (P-фидбек, Space-докачка, F12); полноэкранный
  mouse-blocker не даёт кликать меню под консолью.
- **Годмод**: новый флаг `debug_godmode` в `player.gd` + первый гард в
  `take_damage`. «Липкий»: консоль ре-применяет флаг новому игроку каждого боя.
- Команды идут через штатные пути геймплея (`apply_reward`/`gain_xp`/
  `take_damage`/`_start_combat`/`_end_combat`/`_spawn_random_enemy`) — без
  параллельной логики. `win` сначала убивает врагов (смерть элитки честно взводит
  `_elite_defeated` → награда элитного узла), потом `_end_combat(true)`.

## Команды (20 игровых + help/clear)
| Команда | Аналог StS2 | Что делает |
|---|---|---|
| `help [cmd]` | help | список/справка |
| `clear` | — | очистить лог |
| `stats` | — | класс/HP/золото/уровень/бой/timescale |
| `gold <±n>` | gold | золото (в бою — игроку, на карте — снапшоту забега) |
| `xp <n>` | — | опыт (через gain_xp, с множителем) |
| `levelup [n]` | — | +n уровней |
| `heal [pct]` | heal-подобные | лечение % от max HP |
| `hp <v>` | — | установить HP (0 = смерть) |
| `maxhp <±v>` | — | плоская прибавка max HP |
| `godmode` | godmode | неуязвимость-тумблер, липкая между боями |
| `die` | die | честное поражение |
| `kill [all\|bosses\|elites]` | kill | зачистка арены |
| `win` | win | мгновенная победа боя |
| `spawn <тип> [n]` | fight-подобные | 11 типов врагов из пула волн |
| `artifact <add\|list> [id\|random]` | relic | выдать артефакт |
| `ult` | energy | зарядить ультимейт |
| `timer <сек>` | — | остаток таймера боя |
| `timescale [x]` | instant | скорость игры 0.05–20 |
| `act <1-3>` | act | прыжок в начало акта |
| `fight <battle\|elite\|boss>` | fight | старт боя нужного типа |
| `mod <ключ> <знач> \| mod list` | power-подобные | run_modifiers напрямую |
| `debug` | — | тумблер debug_mode (телепорт мышью в бою) |

## Acceptance
1. `~` открывает/закрывает консоль в любом состоянии игры; открытая консоль
   ставит игру на паузу и полностью забирает ввод. ✅
2. `help` перечисляет все команды; неизвестная команда — внятная ошибка с
   подсказкой похожих. ✅
3. Команды без игрока/боя вежливо отказывают (не крашат). ✅
4. gold/godmode/spawn/kill/timer/timescale/win работают в живом бою. ✅
5. Смоук `tests/dev_console_smoke_test.gd` зелёный (2 прогона), регрессия
   `tests/gamepad_full_flow_smoke_test.gd` зелёная. ✅

## Файлы
- `scripts/dev_console.gd` — новый, консоль целиком.
- `scripts/main.gd` — preload+var, создание в `_ready`, ранний return в `_input`.
- `scripts/player.gd` — `debug_godmode` + гард в `take_damage`.
- `tests/dev_console_smoke_test.gd` — новый смоук (тоггл/пауза/команды/бой).

## QA-подсказка
Headless: `GODOT_BIN=... python3 tools/godot_gate.py --headless -s tests/dev_console_smoke_test.gd`.
Руками: старт боя → `~` → `godmode`, `spawn shaman 5`, `kill all`, `timescale 3`,
`win`; на карте — `gold 500`, `act 3`, `fight boss`.

## QA-Вердикт
Статус: PASSED
Проверил: claude-qa | Дата: 2026-07-02

- Мерж в origin/dev подтверждён (коммит 21ee4d91 — ancestor origin/dev).
- Ревью кода: `player.gd` godmode-гард (`if debug_godmode: return false` в начале take_damage) — неинвазивно, при флаге false поведение не меняется; `main.gd` ранний return в `_input` сгейчен строго `dev_console.is_console_open()` — при закрытой консоли ввод (Esc/quit/хоткеи) не трогается, регресса SCRUM-830 нет.
- Тесты (изолированный worktree, gate/fdengine): `dev_console_smoke_test.gd` → PASS ×2; регрессия `gamepad_full_flow_smoke_test.gd` → PASS (SOFT-DEFECT D1 = пред-существующий SCRUM-824, не от этой правки); `runtime_smoke_test.gd` с активной консолью → PASS (duplicate-artifact guard OK).
- Acceptance 1-5 покрыты: тоггл/пауза/захват ввода, help+подсказки, вежливый отказ без игрока/боя, боевые команды (gold/godmode/spawn/kill/timer/timescale/win), смоук 2× + gamepad-регрессия зелёные.
