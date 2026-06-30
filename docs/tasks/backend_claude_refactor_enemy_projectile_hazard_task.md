# Refactor Wave: Enemy, Projectile And Hazard Runtime Cleanup

Jira: SCRUM-712
Статус: done
Приоритет: P1
Роль: Back-end / enemy quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-enemies, area-projectiles
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task owns normal enemy runtime, projectiles, hazards and enemy HP bars. Boss and elite pattern logic has a separate task.

## Scope / Locked Paths

- `scripts/enemy.gd`
- `scripts/enemy_projectile.gd`
- `scripts/projectile.gd`
- `scripts/hazard_vfx.gd`
- `scripts/enemy_health_bar.gd`
- Enemy/projectile scenes only if needed
- `docs/design/systems/enemies_bosses.md`
- `docs/design/systems/combat.md`

## Required Change

Audit and safely refactor normal enemy runtime, player/enemy projectiles, hazard VFX and health bars: contact damage, movement animation cache, status effects, damage feedback labels, projectile bounds cleanup, pause/death behavior and resource loading. Preserve enemy roster and tuning unless a bug is proven.

## Acceptance Criteria

- Enemy/projectile/hazard lifecycle audit is recorded.
- No stale projectile/hazard/feedback nodes remain after cleanup paths.
- HP bar and damage feedback behavior remain correct for normal enemies, summoned enemies and scaled enemies.
- Resource loading in hot paths is removed or justified.
- Focused tests cover any fixed contract.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_projectile_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/projectile_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/hazard_vfx_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/enemy_content_integrity_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## Результат (Claude backend, 2026-06-30)

Ветка/коммит: `dev` @ `f304a801` (origin/dev, ancestor подтверждён).

### Lifecycle-аудит (5 locked-файлов, записан)
- **Ресурсы:** `enemy.gd`, `enemy_projectile.gd`, `projectile.gd`, `hazard_vfx.gd`,
  `enemy_health_bar.gd` — ВСЁ через `preload` (compile-time const). `load()` в
  хот-путях НЕТ → AC «resource loading in hot paths removed/justified» выполнен.
- **Хот-путь:** `enemy.gd::_physics_process` без поко-кадровых аллокаций
  (нет `.new()`/`create_tween`/`get_nodes_in_group`/`instantiate`).
- **Cleanup надёжен:** снаряды self-free по lifetime/вылету (`_is_outside_arena`)
  и по попаданию; трейл — child снаряда (гибнет вместе). Impact-VFX
  (`EnemyProjectileImpactVfx`) — прямой child сцены, реапается двойным контуром
  `game._clear_world` (по группам + `for child in get_children()`-свип). Эффекты
  оружия — группа `player_weapon_effects`. Stale-нод после очистки не остаётся.
- **HP-бар/фидбек:** структура корректна для обычных/суммон/масштабированных
  врагов (покрыто `enemy_projectile_smoke`/`enemy_content_integrity`).

### Concrete-баг (в ТЕСТЕ, не в коде снаряда) — найден и исправлен
- `tests/projectile_smoke_test.gd` был **RED на origin/dev**: проверка правой
  границы арены захардкожена под старый `ARENA_SIZE.x = 2560`; после бампа до
  4096 (SCRUM-518 ×1.6) тестовая точка (2860) попала ВНУТРЬ арены →
  `_is_outside_arena` честно вернул false → ассерт падал (RC=1).
- Фикс: границы выводим из `Projectile.ARENA_SIZE`/`CLEANUP_MARGIN` (не устареет
  при будущем ребалансе). Добавлено покрытие **Y-оси** (верх/низ) и **despawn по
  вылету** за арену при НЕ-истёкшем lifetime (раньше despawn проверялся только по
  истечению lifetime). Код снаряда не менялся — он был корректен.

### Проверки (semaphore, GODOT_BIN=fdengine, slots=1) — все RC=0
- `tests/projectile_smoke_test.gd` → passed (XY±/despawn lifetime+вылет) [был RED].
- `tests/enemy_projectile_smoke_test.gd` → passed.
- `tests/hazard_vfx_smoke_test.gd` → passed.
- `tests/enemy_content_integrity_test.gd` → passed (10 мини-элиток, 10 энкаунтеров).

Disk cleanup: рабочий worktree `/private/tmp/fsd_wt_scrum712` удалён после пуша;
временных артефактов не оставлено.

## QA-Вердикт

Статус: PASSED

claude-qa, изолир. worktree от origin/dev (коммиты f304a801+b757e67a — ancestor). Аудит-онли по 5 locked code-файлам подтверждён (git stat: production-код не менялся). Тест-фикс projectile_smoke (устаревшая граница арены 2560→выводится из ARENA_SIZE/CLEANUP_MARGIN, +Y-ось, +despawn-по-вылету) корректен и усиливает тест. Гейты RC=0: projectile_smoke, enemy_projectile_smoke, hazard_vfx_smoke, enemy_content_integrity (10 мини-элиток/10 энкаунтеров). → PASSED.
