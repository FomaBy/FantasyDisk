# Арт/VFX уникального оружия и атак всех классов (патч 0.1.5)

Статус: review
Приоритет: normal
Роль: Design (Codex генерация) → Claude-Designer
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-258
Эпик-патч: 0.1.5 Бой и баланс (overhaul)

## Dispatcher Dispatch (2026-06-14)

Sent to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after mechanics
SCRUM-256/251/254/245 were completed and the dependency gate was resolved.
Keep reasoning High/no low. Scope is Design/Codex VFX generation for unique
weapon/class mechanics only: preserve Back-end damage, timings, formulas and
runtime behavior. If motion-state, rig/pivot, AnimationPlayer/AnimationTree or
timing polish is uncovered, create/update an Animator handoff instead of doing
animation work in Design.

## Dependency Gate 0.1.5
Фича-фриз снят, механики SCRUM-256/251/254/245 готовы, задача разблокирована для
Design. Арт/VFX подгоняются под реальные атаки, ауры, статусы и class identities.

## Parked Draft (2026-06-13)

По superseded dispatcher handoff Design успел сгенерировать черновой VFX-kit до
коррекции фриза. Черновики убраны из live assets и припаркованы для будущей
версии `0.1.5`:

- `docs/design/backlog/vfx_015/effects/`
- `docs/design/backlog/vfx_015/previews/`
- `docs/design/backlog/vfx_015/vfx_unique_weapon_enemy_kit.md`
- `docs/design/backlog/vfx_015/generate_unique_weapon_enemy_vfx.py`

Это не active 0.1.4 content, не runtime wiring и не основание переводить задачу
в `in_progress`.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Переделать оружие» под уникальные механики; новым атакам/аурам/статусам нужен
читаемый VFX.

## Требования
1. По итогам механик-задач: дорисовать/обновить спрайты оружия и VFX-кадры для
   новых уникальных атак, аур, баффов/дебаффов — в D&D-каноне, читаемо (telegraph
   там, где задержка/зона), без неона.
2. Генерация — Codex с референсами; Claude-Designer ревью/интеграция.
3. content_registry; превью; smoke (attack_vfx/hazard_vfx/runtime).
4. CHANGELOG.

## Files / Assets / IDs
- assets/sprites/weapons/, assets/sprites/effects/, docs/design/previews/
- content_registry.md

## Acceptance Criteria
- [x] Оружие/VFX новых механик в каноне, читаемы; превью.
- [x] content_registry/CHANGELOG; smoke зелёные.

## Результат (2026-06-14)

Статус: review

Design/Codex VFX pass завершён для SCRUM-258:

- добавлен reproducible generator `tools/generate_unique_weapon_vfx_015.py`;
- сгенерированы 51 live PNG `assets/sprites/effects/vfx_weapon_<weapon_id>.png` под все текущие weapon IDs из `ProgressionData.WEAPONS_BY_CLASS`;
- Godot import создан для всех новых PNG;
- добавлены preview/contact sheets:
  - `docs/design/previews/scrum258_unique_weapon_vfx_contact.png`;
  - `docs/design/previews/scrum258_unique_weapon_vfx_readability.png`;
- `scripts/attack_vfx.gd` получил visual-only helper `AttackVfx.weapon_signature()`;
- `scripts/class_weapon.gd` вызывает `_spawn_weapon_signature()` перед текущим attack executor, чтобы каждый unique weapon/class identity имел читаемую D&D/painterly VFX-пластину по `weapon_id`;
- gameplay scope не менялся: damage, formulas, targeting, cooldowns, radii, status mechanics, delays и balance не тронуты;
- animation/motion scope не брался: attack poses, timing sync, rig/cutout pivots и AnimationPlayer остаются за Animator при будущей необходимости.

Документация обновлена:

- `CHANGELOG.md`;
- `docs/design/content_registry.md`;
- `docs/design/current_game_state.md`;
- `docs/design/systems/visual_style_assets.md`;
- `docs/process/task_board.md`.

Validation:

- `python3 tools/generate_unique_weapon_vfx_015.py` — PASS, generated 51 assets + 2 previews;
- PNG validation — PASS, 51/51 assets are `256x256` RGBA with non-empty alpha;
- Godot import — PASS;
- `res://tests/unique_weapon_vfx_assets_test.gd` — PASS, 51 plates;
- `res://tests/attack_vfx_smoke_test.gd` — PASS;
- `res://tests/hazard_vfx_smoke_test.gd` — PASS;
- `res://tests/status_effects_aura_test.gd` — PASS;
- `res://tests/melee_unique_mechanics_test.gd` — PASS;
- `res://tests/summoner_strengthening_test.gd` — PASS;
- `res://tests/weapon_identity_diversity_test.gd` — PASS;
- `res://tests/runtime_smoke_test.gd` — PASS.
