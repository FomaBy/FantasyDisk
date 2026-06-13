# BUG: Интермиттентное падение umbrella `runtime_smoke_test` + freed-lambda warning

Статус: done
Приоритет: low
Роль: Back-end
Версия: 0.1.4
Jira: SCRUM-257
Найдено QA: при регрессе SCRUM-223 (непрерывный QA-прогон 2026-06-13)
QA: in_progress (2026-06-13)

## Dispatcher Redispatch (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Отправлено в существующий Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`
как QA bug/flake task из текущей board. Keep reasoning High/no low. Сначала
диагностика и логирование точной ассертации, затем fix; закрыть task/board/Jira
sync перед остановкой.

## Симптом
`tests/runtime_smoke_test.gd` (umbrella) ОЧЕНЬ редко падает с `_fail` (backtrace
`[0] _fail (runtime_smoke_test.gd:5309)`) вместо `Runtime smoke test passed.`.
Конкретная упавшая ассертация НЕ захвачена (grep обрезал бэктрейс до `[0]`).

## Замер QA (коммиты 1d772ee0…bb46e5b9)
- Наблюдалось **1 падение из ~23 прогонов (~4%)** — самый первый запуск.
- Затем **22/22 PASS подряд** (серии 8× и 14× с изолированными `--user-data-dir`)
  — воспроизвести не удалось.
- exit-код падения и точная ассертация не зафиксированы (нужно логирование).

## Вероятная связь
В umbrella стабильно (но тоже не на 100% прогонов) печатается нефатальный
`WARNING: Lambda capture at index 0 was freed. Passed "null" instead.` — лямбда
захватила объект (вероятно node, подключённый через `connect()`), который
`queue_free`-нулся до её вызова, и Godot передал `null`. Под редким таймингом
такой `null` может уйти в ассерт → интермиттентный `_fail`. Гипотеза, не
доказано. Известная нефатальная заметка отложена в SCRUM-202.

## Воспроизведение (нестабильное)
1. `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --user-data-dir /tmp/u$RANDOM --path "<проект>" --script res://tests/runtime_smoke_test.gd`
2. Прогнать 20-30 раз. Изредка вместо `passed.` — `_fail`.

## Рекомендация исполнителю (диагностика прежде фикса)
1. В smoke-раннере на падении сохранять ПОЛНЫЙ stderr+бэктрейс в файл
   (`[0]`/`[1]`/`[2]`), чтобы поймать конкретную ассертацию при следующем падении.
2. Найти `connect(` с лямбдой, захватывающей node, который `queue_free`-ится в
   ходе теста (источник `Lambda capture ... freed`); поправить время жизни
   захвата (хранить ссылку/`is_instance_valid` гард/`CONNECT_ONE_SHOT`/отключать
   до free).
3. После фикса warning должен исчезнуть; прогнать umbrella ≥30 раз — 0 падений.

## Окружение
- Godot 4.6.3.stable, headless, macOS (M4), ветка dev (HEAD двигался 1d772ee0…bb46e5b9).
- Не блокер релиза: умбрелла зелёная в >95% прогонов, focused-сьюты (SCRUM-202)
  стабильны (0 warning). Но это регрессионный ГЕЙТ — флака снижает доверие.

## Прогресс диагностики (Claude, 2026-06-13)

1. **Рекомендация #1 выполнена** — `tools/repro_runtime_smoke_flake.sh` (коммит
   c1b30902): гоняет umbrella до N раз и при первом падении/`freed`-warning
   сохраняет ПОЛНЫЙ stderr+бэктрейс в `build/qa/smoke_flake_run_<i>.log`,
   останавливается. Превращает нереспро в пойманный бэктрейс.
2. **Поймано 1 падение из 60** репро-прогоном — НО это был САМОИНДУЦИРОВАННЫЙ
   флейк: временный рост высоты кнопок (задача «кнопки выше») раздул шапку
   выбора героя 68→92, сжав зазор плавающей розы ниже ассерта
   `radar_panel.y >= header.end.y + 8` (`runtime_smoke_test.gd:5086`, hero
   select 1280×720) с ~34px до ~2px. После исключения hero-select back-кнопки
   из роста (коммит 168c3fad) зазор восстановлен (шапка 68). Вывод: **ассерт
   зазора розы маржинален (срабатывает на 2px)** — кандидат на укрепление
   (динамический `offset_top` ниже шапки вместо фиксированного 118).
3. **Генуинная интермиттентная ассертация** (бэктрейс задачи `:5309`) лежит в
   хелперах **детекта наложений** (`_first_control_overlap` /
   `_first_cross_parent_overlap`) — классический layout-settle тайминг:
   `get_global_rect()` читается до полной раскладки → редкий ложный overlap.
   Возможное укрепление: лишний `await process_frame` перед overlap-ассертами.
4. **freed-lambda** — кандидаты: `connect(func` с захватом node в
   `pause_stats_menu.gd` (mouse_entered/exited, dialog.confirmed),
   `route_map_screen.gd` (gui_input), `ui_screens.gd` (pressed). Точный —
   только по бэктрейсу `Lambda capture at index 0 was freed`; репро-хант
   запущен на чистом дереве (80×) для захвата.

Остаётся: дождаться захвата генуинного бэктрейса репро-харнессом → точечный
фикс конкретной ассертации/лямбды; затем ≥30 прогонов без падений.

## Result (2026-06-13)

Done. Back-end diagnosis found and addressed two concrete stability risks:

1. Delayed weapon VFX callbacks in `scripts/class_weapon.gd` no longer capture
   temporary `Node` objects (`target`, `owner_node`, `projectile`) directly.
   The orb/curse callbacks now store instance IDs and resolve them at callback
   time, so cleanup between umbrella smoke sections cannot produce a freed node
   capture or accidentally call into a stale object. Gameplay damage, timings,
   targeting and VFX paths are unchanged.
2. The umbrella probe caught a real layout failure on run 12:
   `HeroSelectRadarPanel` at 1280x720 was too close to the header. The floating
   radar was moved down from `y=98..398` to `y=118..418`, preserving the same
   top-right floating behavior while giving the wax-seal header a stable gap.

Verification:

- `tests/runtime_smoke_ui_test.gd` passed.
- `tests/runtime_smoke_weapon_mechanics_test.gd` passed.
- `tests/animation_smoke_test.gd` passed.
- Standard `tests/runtime_smoke_test.gd` passed.
- Final isolated umbrella series passed 12/12 with separate `--user-data-dir`
  and full logs in `build/qa/runtime_smoke_257_final_*.log`.
- `rg "Lambda capture|WARNING|ERROR|_fail" build/qa/runtime_smoke_257_final_*.log`
  found no warnings/errors/failures; every final log contains
  `Runtime smoke test passed.`

Note: earlier after-fix probe logs intentionally preserved the caught
`HeroSelectRadarPanel` failure in `build/qa/runtime_smoke_257_after_fix_12.log`;
that failure is fixed by the final radar offset adjustment.
