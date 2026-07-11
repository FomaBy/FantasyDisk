# SCRUM-1058 — Двухактовая прогрессия забега

Статус: done
Контур: Codex
Owner: Back-end /root/scrum1058_two_acts
Thread: /root/scrum1058_two_acts
Locked paths: `scripts/main.gd`, `scripts/combat_director.gd`, `scripts/route_map_screen.gd` (final-act semantics), `scripts/audio_manager.gd` (act-aware music), focused/runtime tests, progression/route/combat/audio docs
Jira: SCRUM-1058

## Решение

- Канонический `Main.ACT_COUNT` сокращён до `2`; production UI, continue preview,
  debug и result-flow уже читают его динамически.
- Длина каждой карты сохраняется: `ROUTE_STEPS_TO_BOSS=8`. Компенсационного
  удлинения карт или боёв нет.
- `ACT_SCALING_STAGE_OFFSET=ROUTE_STEPS_TO_BOSS`: Act 1 boss stage 8 → Act 2
  start stage 8 без провала/скачка, Act 2 boss stage 16 достигает прежнего
  финального budget.
- Act 1 boss оставляет существующий единичный reward/heal flow, сохраняет билд и
  открывает Act 2 `route_stage=0`. На Act 2 `advance_to_next_act()` возвращает
  `false`, поэтому третья карта и повторный heal невозможны.
- Secret-boss API переименован в final-act terminology; обычный boss Act 2
  завершается victory ниже max Ascension либо запускает secret boss на max.
- Legacy autosave `current_act=3` мигрируется в финальный Act 2 checkpoint с
  сохранением route position, route history, shop/build/player snapshot и
  повторной записью нормализованного `run_act_count=2`.
- Act-3-only music preference деактивирован; boss music выбирается относительно
  динамического `ACT_COUNT`.

## Balance Result

- Scope: run pacing/scaling only; class/weapon mechanics and three-weapon kit
  budgets не менялись.
- Baseline: `tools/balance_harness.gd` PASS; формульные class-trio/per-weapon
  таблицы не изменились до/после.
- Progression before: Act 1 `0..8`, Act 2 `4..12`, Act 3 `8..16`.
- Progression after: Act 1 `0..8`, Act 2 `8..16`; monotonic boundary, тот же
  финальный stage 16, на 9 route nodes и один акт меньше.
- Remaining risk: player-feel финального Act 2 проверяется QA/playtest; automated
  damage/class corridors должны остаться byte-equivalent по формулам оружия.

## Verification

- Baseline PASS: `boss_act_reward_heal_test`, `run_autosave_persistence_test`,
  `balance_harness`.
- Post-fix PASS: `tests/two_act_run_progression_scrum1058_test.gd` (включая
  фактический normal final boss → reward → secret boss → victory → autosave clear).
- PASS: `boss_act_reward_heal_test`, `audio_qa_969_test`,
  `runtime_smoke_progression_economy_test`, `monster_xp_pressure_pacing_test`,
  `runtime_smoke_boss_elite_test`, `route_generation_reachability_test`,
  `run_autosave_persistence_test`.
- PASS: `tools/balance_harness.gd`; `global_damage_balance_smoke_test` — 51 пар,
  combined/solo/CCT corridors green, worst CCT +21%.
- PASS: полный `tests/runtime_smoke_test.gd`; единственный вывод до PASS — известный
  dummy-renderer null-texture diagnostic в screenshot helper.
- Independent review round 1 нашёл stale user-facing Act-3 строки и узкие scan/docs;
  исправлены production content/enemy/meta строки, расширен source-scan, исправлены
  8-row/music docs и добавлен end-to-end secret completion gate.
- Disk cleanup: `.godot`, generated `.gd.uid` и `/tmp/fsd-scrum1058-*` удалены;
  tracked `build/` evidence оставлен byte-identical.
- Independent re-review round 2: **PASS**, все P1/P2 закрыты; focused gate и
  `git diff --check` подтверждены независимо.
- Jira routing target: `Контроль качества`; QA `Готово` требует отдельного verdict.
