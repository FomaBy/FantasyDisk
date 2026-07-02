# Refactor Wave: Boss And Elite Runtime Patterns Audit

Jira: SCRUM-713
Статус: done
Приоритет: P1
Роль: Back-end / boss quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.2.0
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-boss, area-elite
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task isolates boss and elite runtime patterns from normal enemy/projectile cleanup. It should improve reliability without changing boss fantasy or encounter design.

## Scope / Locked Paths

- `scripts/boss.gd`
- Boss/elite scenes `scenes/Boss*.tscn`, `scenes/Elite*.tscn` only if needed
- `tests/runtime_smoke_boss_elite_test.gd`
- `docs/design/systems/enemies_bosses.md`

## Required Change

Audit and safely refactor boss/elite runtime patterns: phase transitions, hazard ownership, boss HUD/HP bar sync, summon caps, route elite vs mini-elite config, victory/death signaling and cleanup. Keep boss identities and visible mechanics intact unless fixing a verified defect.

## Acceptance Criteria

- Boss/elite pattern audit is recorded.
- Phase transitions, summon caps and cleanup are covered by focused tests.
- Victory/death signaling does not double-fire or leave stale nodes.
- Boss/elite identity, hazards and tuning remain stable unless fixing a proven defect.
- Docs update only if runtime contract changes.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_boss_elite_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/boss_summon_cap_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/mini_elite_roster_spawn_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/boss_elite_ttk_gate.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## Результат (Claude backend, 2026-06-30)

Ветка/коммит: `dev` @ `4cfb99c9` (origin/dev, ancestor подтверждён).

### Boss/elite pattern-аудит (записан)
- **Death/victory-сигналинг:** `boss.gd::take_damage` делегирует урон/смерть в
  `enemy.gd` через `super()` — единый источник `died`-сигнала, boss не
  переопределяет смерть → double-fire невозможен.
- **Summon-кап:** `_summon_riftlings` спавнит ровно `riftling_summon_count(phase,
  active)`, которая top-up'ит до `MAX_SUMMONED_RIFTLINGS=8` (учитывая живых) —
  исчерпывающе покрыта `boss_summon_cap_test` (SCRUM-596).
- **Фаза:** `_update_boss_phase` монотонна (возвращалась при `next<=boss_phase`),
  enrage one-shot (guard `_enraged`). Cleanup призывов — группа `summoned_enemies`,
  hazards — `enemy_hazards` (реапятся `game._clear_world`).
- **Concrete-багов нет → идентичность/тюнинг боссов сохранены** (per AC).

### Изменения (locked path, поведение идентично)
- `scripts/boss.gd` — пороговая логика фаз вынесена в чистую static
  `phase_for_ratio(behavior, ratio, current_phase, has_extra_phase)`.
  `maxi(next, current)` делает прежнюю монотонность явной и тестируемой;
  `_update_boss_phase` теперь зовёт хелпер (side-effects фаз не тронуты).
- `tests/boss_phase_progression_test.gd` (+`.uid`) — фокус-тест контракта фаз:
  пороги обычный (0.66/0.33) vs секретный (0.50/0.25), семантика границ `<=`,
  extra-фаза 4 только при `ratio<=0.15`, монотонность при росте HP.

### Проверки (semaphore, GODOT_BIN=fdengine, slots=1) — все RC=0
- `tests/boss_phase_progression_test.gd` → passed (NEW).
- `tests/runtime_smoke_boss_elite_test.gd` → passed.
- `tests/boss_summon_cap_test.gd` → passed.
- `tests/mini_elite_roster_spawn_test.gd` → passed (10 видов, +4 новых, tint).
- `tests/boss_elite_ttk_gate.gd` → passed (boss TTK >= 1.35x elite, стадии 0..10).

Disk cleanup: рабочий worktree `/private/tmp/fsd_wt_scrum713` удалён после пуша;
временных артефактов не оставлено.

## QA-Вердикт

Статус: PASSED

claude-qa, изолир. worktree от origin/dev (коммиты 4cfb99c9+f4ba9e7b — ancestor). Code review boss.gd: phase_for_ratio вынесена в чистую static, behavior-neutral (тело ниже гварда не менялось; maxi избыточен с гвардом next_phase<=boss_phase). Гейты RC=0: boss_phase_progression(NEW), runtime_smoke_boss_elite, boss_summon_cap, mini_elite_roster_spawn, boss_elite_ttk_gate (ratio≥1.35x на стадиях 0..10). → PASSED.
