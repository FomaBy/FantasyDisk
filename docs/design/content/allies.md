<!-- content-registry-section -->

# FantasyDisk Content Registry — Призывные Союзники И Deployables

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## Призывные Союзники И Deployables

SCRUM-152 Design pass 2026-06-12 добавил канонический raster-набор союзных summon/deployable ассетов в `assets/sprites/allies/`. SCRUM-399 (2026-06-14) заменил четыре мобильных summon visuals на эфирный союзный стиль: голубой/циановый ghost tint, прозрачность, мягкое внутреннее свечение и дымчатые края, чтобы призывы мгновенно отличались от плотных темных монстров. Все PNG RGBA/transparent; runtime IDs, SpriteFrames paths, counts and timings сохранены.

| ID | Игровая роль | Ассет | Runtime status |
| --- | --- | --- | --- |
| `ally_druid_beast` | Базовый питомец Друида / fallback `AllyMinion` | `assets/sprites/allies/ally_druid_beast.png`; `assets/sprites/allies/ally_druid_wolf_spriteframes.tres` + `assets/sprites/allies/druid_wolf/ally_druid_wolf_{move,attack,death}_*.png` | Full-frame SpriteFrames через `FullFrameAnimationRegistry`: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, safe 256x256 wolf canvas, scale `0.37`, position `(0,-37)`, flip вправо по движению/атаке |
| `ally_druid_pack_spirit` | Вариант стаи Друида / ultimate pack visual | `assets/sprites/allies/ally_druid_pack_spirit.png`; `assets/sprites/allies/ally_pack_spirit_spriteframes.tres` + `assets/sprites/allies/pack_spirit/ally_pack_spirit_{move,attack,death}_*.png` | Full-frame SpriteFrames: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, scale `0.34`, position `(0,-10)` |
| `ally_homunculus` | Химикский гомункул от `homunculus_vial` | `assets/sprites/allies/ally_homunculus.png`; `assets/sprites/allies/ally_homunculus_spriteframes.tres` + `assets/sprites/allies/homunculus/ally_homunculus_{move,attack,death}_*.png` | Full-frame SpriteFrames: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, scale `0.34`, position `(0,-10)` |
| `ally_leadership_echo` | Зарезервированный арт эхо-союзника; runtime-потребителя НЕТ (универсальный Leadership-echo удалён FAN-1893, summoner_weapon больше не мапит id) | `assets/sprites/allies/ally_leadership_echo.png`; `assets/sprites/allies/ally_leadership_echo_spriteframes.tres` + `assets/sprites/allies/leadership_echo/ally_leadership_echo_{move,attack,death}_*.png` | Full-frame SpriteFrames: `move` 8f/12fps loop, runtime `attack` 6f/14fps no-loop (`attack_primary` в manifest), SCRUM-370 `death` 6f/10fps no-loop, scale `0.34`, position `(0,-10)` |
| `druid_ghost_wolf` | Дух-волк Друида; physical melee AoE animation identity | `assets/sprites/allies/druid_ghost_wolf/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_wolf_spriteframes.tres`; PixelLab `8d473df8-9bc2-481c-ad58-b69cfecc5d33` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + claw/body-sweep `attack_left/right` 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `druid_ghost_bear` | Дух-медведь Друида; physical melee AoE animation identity | `assets/sprites/allies/druid_ghost_bear/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_bear_spriteframes.tres`; PixelLab `6805608a-b64a-471c-a1d9-9601a3062e2f` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + ground-slam `attack_left/right` 6f one-shot, transparent 256x256, no flip; SCRUM-1020 replaces `move_right` with coherent same-UUID job `1585ff64-f3e8-4db7-aa8b-fd7631a40bae` pending independent re-QA; roster/gameplay pending SCRUM-902 |
| `druid_ghost_panther` | Дух-пантера Друида; physical melee AoE animation identity | `assets/sprites/allies/druid_ghost_panther/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_panther_spriteframes.tres`; PixelLab `b2d06d20-aabb-48e2-9d8a-5053daa03e8e` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + pounce/rake `attack_left/right` 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `druid_ghost_stag` | Дух-олень Друида; magical ranged caster animation identity | `assets/sprites/allies/druid_ghost_stag/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_stag_spriteframes.tres`; PixelLab `f17948e2-8e1d-44f2-93f1-8f8593ae01fe` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + spirit-lance `attack_left/right` cast 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `druid_ghost_lion` | Дух-лев Друида; magical ranged caster animation identity | `assets/sprites/allies/druid_ghost_lion/{pixellab_source,runtime}/`; `assets/sprites/allies/ally_druid_ghost_lion_spriteframes.tres`; PixelLab `48d76788-eeba-4a9f-a36f-bd40a8f42e07` | SCRUM-1016 visual pack: explicit `move_left/right` 6f loop + spectral-roar `attack_left/right` cast 6f one-shot, transparent 256x256, no flip; roster/gameplay pending SCRUM-902 |
| `deploy_sound_amp_field` | Полевой объект ампа Гитариста | `assets/sprites/allies/deploy_sound_amp_field.png` | Подключен как `deploy_texture_path` для `sound_amp` |
| `deploy_raven_totem_field` | Полевой объект Вороньего тотема Друида | `assets/sprites/allies/deploy_raven_totem_field.png` | Подключен как `deploy_texture_path` для `raven_totem` |

Preview QA:

- `docs/design/previews/summon_allies_style_references.png` - project style references used for Codex Design generation;
- `docs/design/previews/summon_allies_asset_contact.png` - transparent asset contact sheet;
- `docs/design/previews/summon_allies_scale_meadow_preview.png` - scale/readability check on arena background;
- `docs/design/previews/summons_ethereal_redraw_contact.png` - SCRUM-399 ethereal summon static/frame contact sheet;
- `docs/design/previews/summons_ethereal_readability_meadow.png` - SCRUM-399 meadow readability preview against current arena colors.
- `docs/design/previews/druid_summons_ghost_animation_pack_contact.png` - SCRUM-1016 west/east movement/action contact sheet for all five ghost summons.

Back-end source-specific integration complete in SCRUM-157: runtime selectors preserve cleanup groups and gameplay balance.
