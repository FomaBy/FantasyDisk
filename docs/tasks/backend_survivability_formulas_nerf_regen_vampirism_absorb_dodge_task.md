# Формулы выживаемости — сильно ослабить реген и вампиризм, отбалансить абсорб и уворот

Статус: done
Приоритет: high
Роль: Back-end (баланс)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-255
QA: in_progress (2026-06-14)
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## Dispatcher Dispatch (2026-06-14)

Queued to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after
SCRUM-259 close-out. Keep reasoning High/no low. Scope is Back-end
survivability formulas/balance only: nerf regeneration and vampirism, rebalance
defense/absorb and dodge, update harness/report/tests/docs, and avoid art/VFX/
animation ownership.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Сильно ослабить регенерацию и вампиризм, отбалансить абсорб и уворот».
Патч про формулы выживаемости. Прошлый ребаланс (SCRUM-149) уже закапал вампиризм
и усилил реген — теперь курс ОБРАТНЫЙ для выживаемости: реген и вампиризм должны
быть слабее, абсорб и уворот — сбалансированы (не доминируют, но полезны).

## Требования
1. **Реген — сильный нерф**: пересмотреть коэффициенты `regeneration` в
   stat_formulas.gd / derived_parameters; HP-в-секунду заметно ниже; не должен
   перекрывать боевой урон в затяжных боях.
2. **Вампиризм — сильный нерф**: ещё снизить долю урона/шанс/кап лечения
   (player.gd on_weapon_hit, vampiric_*); вампиризм — нишевая поддержка, не
   основной саслейн.
3. **Абсорб (defense/absorb)** — отбалансить: полезен, но с убывающей отдачей,
   без неуязвимости; пересмотреть кап defense.
4. **Уворот (dodge)** — отбалансить: пересмотреть формулу/кап (сейчас clamp 0.8),
   снизить потолок и/или кривую, чтобы 100%-уклон не достигался; стохастика
   честная.
5. Все правки — через `tools/balance_harness.gd`; целевые сценарии выживаемости
   (fragile/steady/sturdy/tank) и TTD в коридорах из глобального balance smoke.
6. Отчёт «было/стало» по каждому слою (build/balance_report.md / survivability).
7. CHANGELOG; mechanics_extract (формулы); docs баланса.

## Files / Assets / IDs
- scripts/stat_formulas.gd (regeneration/dodge/defense/absorb/vampiric)
- scripts/player.gd (on_weapon_hit вампиризм), scripts/progression_data.gd
- tools/balance_harness.gd, tests/
- Согласование: backend_crit_formula_rebalance, attribute synergy (один патч)

## Acceptance Criteria
- [x] Реген и вампиризм заметно ослаблены (числа в отчёте).
- [x] Абсорб/уворот сбалансированы (убывающая отдача, разумные капы).
- [x] Сценарии выживаемости в целевых коридорах; глобальный survivability smoke зелёный.
- [x] CHANGELOG/доки/отчёт обновлены.

## Result Summary (2026-06-14)

Back-end scope complete. Survivability formulas now use shared SCRUM-255 constants
in `ProgressionData`:
- defense: diminishing returns, cap 62%;
- dodge: diminishing returns, cap 55%;
- absorb: `Endurance*0.16 + softened flat`, min-through 35%;
- regeneration: `(0.22 + positive_flat*0.45) * (0.45 + Knowledge/12)`;
- vampirism: chance cap 22%, heal `vampiric_amount*0.55 + 3.5% damage`,
  default cap 1.4/s and hard cap 2.6/s;
- direct weapon drain heal is multiplied by 0.45.

Before/after highlights are recorded in
`build/survivability_rebalance_scrum255_report.md`: synthetic
`tank/contact_swarm` TTD dropped from 321.0s to 38.5s, and tank regen dropped
from 1.57/s to 0.30/s. `build/survivability_report.md`,
`build/survivability_scenarios_report.md`, and `build/balance_report.md` were
regenerated. Docs updated: `CHANGELOG.md`,
`docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Проверено (фактически):
- **Формулы (нерф)**: shared-константы — defense diminishing cap 62%, dodge cap
  55%, absorb min-through 35%, regen `(0.22+flat*0.45)*(0.45+Knowledge/12)`,
  vampirism chance cap 22% + heal cap 1.4/2.6/s, weapon drain ×0.45. Числа в
  отчёте (tank/contact_swarm TTD 321→38.5с, tank regen 1.57→0.30/с).
- **Целевые тесты**: `survivability_scenario_test` — passed (монотонность TTD по
  стойкости, вклад слоёв, absorb, **якорь к реальному `Player.take_damage`**);
  `stat_formulas` — passed.
- **Гейты**: `global_survivability` — passed (**TTD≤600с, митигация<98%,
  бессмертие недостижимо** — нерф достиг цели, нет инвинсибл-билдов);
  `global_damage` (51 пара коридор) + runtime — зелёные.

Acceptance:
- [x] Реген/вампиризм заметно ослаблены (числа в отчёте).
- [x] Абсорб/уворот — убывающая отдача, разумные капы.
- [x] Сценарии выживаемости в коридорах; global survivability smoke зелёный.
- [x] CHANGELOG/доки/отчёт.

Баги: нет.

Verification:
- `tests/stat_formulas_smoke_test.gd` passed.
- `tests/survivability_scenario_test.gd` passed, including real
  `Player.take_damage` parity.
- `tests/progression_data_api_surface_test.gd` passed.
- `tests/global_survivability_balance_smoke_test.gd` passed.
- `tests/global_damage_balance_smoke_test.gd` passed.
- `tools/survivability_harness.gd`, `tools/survivability_scenarios.gd`, and
  `tools/balance_harness.gd` regenerated reports successfully.
- `tests/runtime_smoke_test.gd` passed after fixing stale duplicate
  `class_name` registrations from tracked `* 2.gd` legacy copies and refreshing
  local `.godot/global_script_class_cache.cfg`.
