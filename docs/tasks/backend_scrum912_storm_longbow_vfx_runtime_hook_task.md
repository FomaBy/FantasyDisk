# Backend handoff: play SCRUM-912 Storm Longbow release VFX scene

Статус: done
Приоритет: p2
Роль: Back-end
Контур: Codex
Owner: `/root/scrum1037_storm_longbow`
Thread: `/root`
Версия: 0.2.1
Jira: SCRUM-1037
Источник: SCRUM-912

Locked paths after claim:
- `docs/tasks/backend_scrum912_storm_longbow_vfx_runtime_hook_task.md`
- `scripts/class_weapon.gd`
- `tests/scrum912_storm_longbow_vfx_runtime_hook_test.gd`
- SCRUM-1037-only current-state note after active documentation locks release

## Dependency gate — resolved 2026-07-10

Оба условия повторно проверены dispatcher-ом и выполнены:

1. SCRUM-912 asset/resource commit находится в `origin/dev`.
2. Все активные Claude/другие владельцы освободили dirty lock на
   `scripts/class_weapon.gd`.

SCRUM-912/1038 находятся в `origin/dev` и приняты независимым QA; все
зарегистрированные worktree показали чистый `scripts/class_weapon.gd` после
закрытия Priest/Sniper owner-ов. Jira label `blocked` снят. Задача остаётся
unassigned в `К выполнению` и готова к будущему single-owner Codex claim после
освобождения текущей root-задачи.

## Готовый Animator API

- Scene: `res://scenes/vfx/StormLongbowVolleyVfx.tscn`
- Script: `res://scripts/vfx/storm_longbow_volley_vfx.gd`
- SpriteFrames:
  `res://assets/sprites/effects/storm_longbow/storm_longbow_release_spriteframes.tres`
- Method:
  `configure(owner_origin: Vector2, direction: Vector2, attack_range: float)`
- Cleanup: one-shot `release`, `animation_finished -> queue_free`, group
  `player_weapon_effects`.
- Metadata: 5 arrows, 34°, offsets `[-17,-8.5,0,8.5,17]`, 30px corridors,
  980px range, +26px origin, pierce 4.

## Требуемая Back-end интеграция

В `storm_pierce_cone` attack path создать ровно один экземпляр сцены на один
залп, добавить его в projectile/effect parent, вызвать `configure()` живыми
origin/direction/attack_range и зарегистрировать существующим cleanup helper.

Не заменять и не менять:

- пять `AttackVfx.beam` коридоров SCRUM-911;
- hit queries, volley-wide dedup и pierce budget;
- damage/crit/knockback;
- charge/cooldown/balance;
- другие оружия или generic attack modes.

## Acceptance Criteria

- [x] Один release VFX scene на один `storm_pierce_cone` залп.
- [x] Aim rotation и range берутся из существующей атаки.
- [x] Gameplay geometry и пять live beam corridors не изменились.
- [x] Scene удаляется после 0.5s и при обычном weapon/world cleanup.
- [x] Новый focused hook test, `ranger_kit_test.gd`,
  `scrum912_storm_longbow_vfx_test.gd`, `animation_smoke_test.gd` и
  `runtime_smoke_test.gd` проходят через `tools/godot_gate.py`.
- [x] Jira/mirror/dev синхронизированы; cache/worktree очищены.

## Implementation result

`ClassWeapon._fire_storm_pierce_cone()` now calls one isolated helper before
building the existing gameplay corridors. The helper instantiates
`StormLongbowVolleyVfx.tscn`, configures it from the live owner origin, aim and
range, and registers it through `_register_effect()`. No gameplay geometry,
target query, damage, pierce/dedup, charge or cooldown code changed.

Green gates on the implementation tree:

- `tests/scrum912_storm_longbow_vfx_runtime_hook_test.gd` — one scene per
  volley, live aim/range, unchanged geometry, 0.5s self-cleanup and weapon
  cleanup;
- `tests/ranger_kit_test.gd`;
- `tests/scrum912_storm_longbow_vfx_test.gd`;
- `tests/animation_smoke_test.gd`.

Full `tests/runtime_smoke_test.gd` passed with a clean task-local user-data
directory. Implementation/docs landed as `b797c10d0` / `3c11b393b` and Jira
was routed to independent QA.

Disk cleanup: clean user-data directory and disposable `.godot/` removed;
clean task worktree scheduled for immediate removal after the routing push.
