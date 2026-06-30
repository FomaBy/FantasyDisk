# Refactor Wave: Melee, Summons And Deployable Lifecycle Cleanup

Jira: SCRUM-711
Статус: done
Приоритет: P1
Роль: Back-end / combat quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-summons, area-melee
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task covers the dedicated melee/summon/deployable layer. It must preserve the class identity and balance contracts already documented in mechanics and combat docs.

## Scope / Locked Paths

- `scripts/berserk_weapon.gd`
- `scripts/summoner_weapon.gd`
- `scripts/ally_minion.gd`
- `scenes/AllyMinion.tscn`
- Focused summon/melee tests
- `docs/design/systems/combat.md`

## Required Change

Audit and safely refactor Berserk shapes, SummonerWeapon commands, AllyMinion movement/attack/death lifecycle, deployable cleanup groups, leash behavior, delayed `queue_free` and pause-aware tweens. Do not change final class balance without harness evidence.

## Acceptance Criteria

- Melee and summon lifecycle audit is recorded.
- Summons/deployables do not leave stale nodes across weapon swap, death, route transition, return to menu or new run.
- Delayed death playback and pause-aware cleanup remain correct.
- Behavior changes are covered by focused tests and documented when relevant.
- Risky balance/mechanic findings become separate Jira issues.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/summoner_strengthening_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/summon_weapon_crowd_floor_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_weapon_mechanics_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## QA-Вердикт

Статус: PASSED

Проверял claude-qa на чистом изолированном worktree от origin/dev (коммит SCRUM-711 a9043d53 — ancestor подтверждён), fdengine-семафор slots=1.

- Code review scripts/ally_minion.gd: не-анимированный death-путь теперь зовёт _disable_dead_ally_runtime() перед queue_free() (как и анимированный) — мёртвый ally убирается из группы "allies" и гасит физику сразу, без лишнего кадра движения/атаки. _exit_tree гасит death-твин, _finish_death_lifecycle guard'ит is_queued_for_deletion. Баланс/идентичность не тронуты.
- Гейты (все RC=0): ally_minion_lifecycle_test, summoner_strengthening_test, summon_weapon_crowd_floor_test, runtime_smoke_weapon_mechanics_test.
- Внешний блокер (НЕ из 711) заведён багом SCRUM-788: melee_weapon_targeting_test устарел (ждёт 145, SCRUM-602 перебалансил hammer max_aoe_radius на 115); не meta-save bleed — перепроверено с нейтрализованным мета.
