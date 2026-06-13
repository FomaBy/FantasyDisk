# Sprite Visual Audit 2026-06

Статус: review
Jira: SCRUM-177
Дата: 2026-06-13
Ветка: `dev`
Роль: Design audit/spec only

## Scope

Read-only visual audit for active FantasyDisk sprites and nearby sprite assets. No redraws were performed in this task.

Generated audit artifacts:

- `docs/design/previews/audit_characters_active.png`
- `docs/design/previews/audit_characters_legacy_placeholders.png`
- `docs/design/previews/audit_weapons_active.png`
- `docs/design/previews/audit_enemies_active.png`
- `docs/design/previews/audit_enemies_legacy_root.png`
- `docs/design/previews/audit_effects_projectiles_allies.png`
- `docs/design/previews/audit_backgrounds.png`
- `docs/design/previews/audit_map_cursor_hud_frames.png`
- `docs/design/previews/audit_ui_stat_shop_icons.png`
- `docs/design/previews/audit_artifact_icons_1.png`
- `docs/design/previews/audit_artifact_icons_2.png`
- `docs/design/reviews/sprite_visual_audit_inventory_2026_06.md`
- `docs/design/reviews/sprite_visual_audit_inventory_2026_06.json`

The raw filesystem has 457 image files under `assets/`, but most are cutout parts, UI kits, imported/generated packs, or legacy files. The primary active gameplay audit covers:

- 17 playable full-body character sprites.
- 51 weapon sprites.
- 11 standard enemy sprites, 4 elite sprites, 2 currently active final boss sprites.
- 19 VFX sprites, 2 projectile sprites, 6 ally/deploy sprites.
- Route/map icons, cursor, HUD/resource frames, stat/derived/shop icons, artifact icons, arena/UI backgrounds.

## Executive Summary

Overall art direction is strong after the recent class and monster passes. Active characters, weapons, core enemies, elites, bosses, backgrounds, map icons, artifact icons, and the latest Robot/Engineer/Biologist kits are broadly aligned with the D&D/dark-fantasy painterly canon.

The main visual consistency risks are:

1. **P0/P1: New roster bosses and mini-elites still use placeholder/tint identity.** SCRUM-155 added mechanics for 3 bosses and 6 mini-elites, but documentation and code still indicate placeholder/tint visual identity until the SCRUM-156 art pass.
2. **P1: VFX sprites are functionally readable but flatter than the character/monster canon.** Several effects still look like simple geometric rings, strips, or low-material painted shapes rather than high-quality D&D VFX.
3. **P1: UI stat/derived/shop-only icons are uneven.** Stat icons are decent, artifacts are strong, but shop-only and some derived icons read more vector/flat than current character/artifact art.
4. **P2: Legacy prototype/placeholder sprites remain in `assets/`.** They do not appear to be active in current scenes, but they are visually off-canon and easy for future code to accidentally reference.
5. **P2: Old character `_placeholder.png` files remain in `assets/sprites/characters/`.** They are candidate cleanup files; do not remove until a Back-end/file-cleanup pass confirms no hidden references.

## Inventory By Group

| Group | Contact sheet | Status | Notes |
| --- | --- | --- | --- |
| Playable characters | `audit_characters_active.png` | Final / minor monitor | 17 full-art classes are coherent. New Biologist, Robot, Engineer match recent D&D tabletop canon. Robot is bulkier, which is appropriate for role. |
| Character legacy placeholders | `audit_characters_legacy_placeholders.png` | Cleanup needed | `*_placeholder.png` files are visually obsolete. `berserk_walk_sheet_v2.png` is live and must not be deleted without animation replacement. Root `player_*.png` are prototype leftovers. |
| Weapons | `audit_weapons_active.png` | Mostly final | 51 weapons are readable and thematic. A few older items (`two_handed_sword`, `two_handed_hammer`, `tower_shield`, `venom_wire`) are simpler than newer Robot/Engineer/Biologist pieces but acceptable in active UI. |
| Standard enemies/elites/bosses | `audit_enemies_active.png` | Final for current active set | Core 11 enemies, 4 elites, and 2 original bosses are strong and coherent. Current boss/elite 512-ish style is close to user-approved monster reference. |
| Legacy root enemy sprites | `audit_enemies_legacy_root.png` | Cleanup needed | Root `assets/sprites/enemy_*.png` and `boss_warden.png` include old flat geometric/prototype visuals. Active scenes use `assets/sprites/enemies/*` and `assets/sprites/bosses/*` instead. |
| Effects/projectiles/allies | `audit_effects_projectiles_allies.png` | Fix needed | Allies/deploys are good. Projectiles are readable. Effects are the weakest group: rings/strips/pools are flatter and less material-rich than D&D canon. |
| Backgrounds | `audit_backgrounds.png` | Mostly final | Arena and UI backdrops are coherent. `field_meadow`/`field_marsh` remain lower-detail but intentionally low-contrast and readable. |
| Map/cursor/HUD/frames | `audit_map_cursor_hud_frames.png` | Mostly final | Map icons, cursor, HUD frames are readable and styled. Some global/escape frames are simpler but functionally acceptable. |
| Stat/shop icons | `audit_ui_stat_shop_icons.png` | Mixed | Basic stat icons are strong. Some derived icons and shop-only icons are more flat/vector than artifact icons and character art. |
| Artifact icons | `audit_artifact_icons_1.png`, `audit_artifact_icons_2.png` | Final / monitor | Artifact icons now look like finished raster items with strong material work and readable silhouettes. |

Full per-file inventory is in `docs/design/reviews/sprite_visual_audit_inventory_2026_06.md`.

## Prioritized Fix List

### P0: New Bosses And Mini-Elites Need Canonical Art

Affected content:

- Bosses added in SCRUM-155: `boss_bone_archon`, `boss_brood_mother`, `boss_ashen_colossus`.
- Mini-elites added in SCRUM-155: `mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`.

Current state: mechanics and codex are present, but visual identity is still documented as placeholder/tint until SCRUM-156. This is the highest art gap because these are high-impact enemy silhouettes and route rewards.

Child task:

- `docs/tasks/codex_design_new_bosses_mini_elites_redraw_task.md`

### P1: VFX Sprite Pack Needs A D&D/Painterly Pass

Affected examples:

- `beam_strip.png`
- `elite_shockwave_ring.png`
- `elite_telegraph_circle.png`
- `hazard_zone.png`
- `impact_ring.png`
- `slash_arc.png`
- `sound_wave.png`
- `void_orb.png`
- pool sprites: `poison_pool.png`, `spark_pool.png`, `briar_pool.png`

Current state: readable and usable, but several assets still look like clean UI primitives or semi-flat decals when placed beside painterly monsters/weapons.

Child task:

- `docs/tasks/codex_design_vfx_sprite_polish_task.md`

### P1: Derived/Shop UI Icons Need Style Unification

Affected examples:

- Shop-only icons in `assets/sprites/ui/icons/shop/` are functional but read flatter than realistic artifact icons.
- Some derived icons (`attr_aoe_radius`, `attr_dot_speed`, `attr_dodge`, `attr_health_point`, `attr_pickup_radius`, `attr_summon_amount`) vary in material depth and framing.
- Shop frame states are readable but more UI-flat than the current tavern/dark-fantasy kit.

Current state: no default emoji placeholders, but style quality is uneven.

Child task:

- `docs/tasks/codex_design_ui_icon_style_unification_task.md`

### P2: Legacy Placeholder/Prototype Assets Should Be Cleaned Or Archived

Candidates:

- `assets/sprites/characters/*_placeholder.png`
- `assets/sprites/player_berserk.png`
- `assets/sprites/player_ranger.png`
- `assets/sprites/player_summoner.png`
- root-level `assets/sprites/enemy_*.png`
- `assets/sprites/boss_warden.png`

Important exception:

- `assets/sprites/characters/berserk_walk_sheet_v2.png` is live according to `scripts/player.gd` and cleanup docs. It should not be removed until Animator/Back-end provide a replacement.

Child task:

- `docs/tasks/codex_design_legacy_sprite_cleanup_spec_task.md`

## Non-Issues / Keep

- Active 17 character full-art sprites: keep.
- Current 51 weapon sprites: keep; monitor older simple ones but do not block 0.1.4 quality.
- Active standard enemies, 4 elites, and 2 original bosses: keep.
- Artifact icons: keep current realistic D&D raster pass.
- Arena/UI backgrounds: keep; low-contrast arena floors are desirable for readability.
- Map icons: keep; boss icons remain specific for original bosses, and new boss map icon needs should be covered by the boss art task.

## Handoff Notes

- This audit did not redraw or overwrite any source PNG.
- Animation/cutout issues are not fixed here. Any rig/cutout mismatch found after new redraws should go to Animator.
- Cleanup/removal of legacy assets should be confirmed by Back-end/file-cleanup owner before deletion.
