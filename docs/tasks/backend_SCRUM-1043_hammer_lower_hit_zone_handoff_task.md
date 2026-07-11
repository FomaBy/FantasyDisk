# Backend handoff: fix Berserk hammer lower-side hit zone for SCRUM-895

Статус: done
Приоритет: medium
Роль: Back-end
Исполнитель: Codex
Контур: Codex
Owner: Back-end `/root/animator_loop_924/backend_scrum1043`
Thread/Worker: `/root/animator_loop_924/backend_scrum1043`
Locked paths: `scripts/berserk_weapon.gd`, `tests/scrum1043_hammer_lower_hit_zone_test.gd`, scoped SCRUM-1043 paragraphs in `docs/design/current_game_state.md` and `docs/design/systems/characters_weapons.md`
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

## Backend Result

Implemented a Hammer-only footline ellipse in `BerserkWeapon`. The shared
damage/VFX center moves down by `Vector2(0, 16)` and the shared shape scale is
`Vector2(1.0, 1.12)`. With the unchanged base radius `150`, deterministic
owner-space probes prove: top `150` remains inside, bottom `180` is inside and
`185` is outside, left/right `149` are inside and `151` are outside. The
SCRUM-895 scene bridge consumes the same two protected hooks, so its PixelLab
slam follows the real zone without copying geometry constants.

No damage, cooldown, radius growth, target diminishing, progression data,
Sword/Axe behavior or Holy Flail circle behavior changed.

### Balance result

Budget scores remain numerically identical because SCRUM-1043 changes ground
membership alignment, not damage/cadence/radius progression. The live ellipse
has `1.12x` the nominal circle area, isolated to the lower-contact fairness
axis; the anti-runaway live gate remains below both caps.

| State | Berserk weapons | Solo | AoE | Crowd | Defense | Total |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Before | sword / axe / hammer | 1.000 | 1.000 | 0.935 | 1.000 | 0.984 |
| After | sword / axe / hammer | 1.000 | 1.000 | 0.935 | 1.000 | 0.984 |

| Weapon | Numeric budget before/after | Geometry result | Identity |
| --- | --- | --- | --- |
| sword | unchanged | unchanged | long narrow sector |
| axe | unchanged | unchanged | broad sweep |
| hammer | unchanged | upper/horizontal reach preserved; lower reach ~150 -> ~184 | close circular crowd slam |

### Verification

- `tests/scrum1043_hammer_lower_hit_zone_test.gd` — PASS (cardinal membership,
  shared VFX transform, Holy Flail isolation).
- `tests/scrum895_berserk_axe_hammer_vfx_test.gd` — PASS after integration with
  the Animator bridge.
- `tests/runtime_smoke_weapon_mechanics_test.gd` — PASS.
- `tests/berserk_dps_runaway_gate.gd` — PASS after final SCRUM-895 rebase:
  `20t=3207 <= 3600`, `1t=330 <= 650`.
- `tests/global_damage_balance_smoke_test.gd` — PASS, all 51 pairs.
- `tools/balance_harness.gd` — PASS; reports generated in ignored `build/`.
- `tests/runtime_smoke_test.gd` — PASS.

Commit: `c66f50970` (rebased implementation commit; final pushed hash recorded in
Jira). Disk cleanup: `.godot` and generated untracked `.uid` sidecars removed;
task worktree removed after push. Remaining risk: normal combat-scale QA should
confirm that the 16px/1.12 ellipse reads naturally with enemy clutter; backend
geometry and the VFX transform are deterministic and covered.
