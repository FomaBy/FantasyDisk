# Backend handoff: fix Berserk hammer lower-side hit zone for SCRUM-895

Статус: new
Приоритет: medium
Роль: Back-end
Исполнитель: Codex
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Jira: SCRUM-1043
Версия: 0.2.1

## Scope

Fix only the Berserk two-handed Hammer close-AoE membership so enemies
approaching from below enter the damage zone at the same practical contact point
as enemies above. Preserve Sword/Axe behavior and Hammer damage, cooldown,
growth caps, target diminishing and close-range identity.

Preferred implementation is a small footline/downward center offset or a
carefully tested vertical ellipse. Expose the exact visual contract to the
scene-specific SCRUM-895 Hammer bridge through protected methods:

- `_circle_attack_center(owner_node: Node2D) -> Vector2`;
- `_circle_attack_visual_scale() -> Vector2`.

The existing owner center / `Vector2.ONE` remain defaults for other circle
weapons. Do not edit Animator-owned SCRUM-895 PixelLab frames, VFX scenes or
scene-specific visual scripts.

## Acceptance

- Deterministic top/bottom/left/right contact test proves no lower dead zone.
- Damage query and visible center/scale are identical.
- Hammer remains small/capped; Berserk runaway and runtime smokes pass.
- Sword geometry and animation are unchanged.
