# Artifact, Shop Item And Cursor Visual Kit

Обновлено: 2026-06-12

Этот документ фиксирует Design visual kit для артефактов, shop-only предметов, inline shop UI и игрового курсора FantasyDisk. Back-end интеграция описана в `docs/tasks/backend_shop_inline_artifact_icons_cursor_integration_task.md`.

Back-end audit follow-up resolved 2026-06-11: фактические PNG из разделов Artifact Icon Mapping, Shop-Only Icon Mapping, Shop Visual Assets и Cursor Assets добавлены в текущий checkout и импортированы в Godot. Fallback через `scripts/ui_icon_registry.gd` остается только fail-safe.

User feedback rework 2026-06-12: artifact icons заменены как `256x256` RGBA transparent realistic epic D&D/tabletop fantasy raster magic items. Это не пентаграммы, не плоские UI-symbols и не simple icon set: один красивый finished painted предмет на каждый active artifact ID, без встроенной UI-рамки, пьедесталов, фона, осколков, частиц и текста. Предметы сохраняют readable fantasy lighting/materials и привязаны к названию/эффекту из `ProgressionData.ARTIFACTS`. Предыдущие generated/vector-like, glossy, concept-sheet tile и per-item pictogram направления superseded. Shop-only icons and frames keep the richer FantasyDisk fantasy-medallion treatment. Cursor variants were reworked in SCRUM-223 into a dark steel dragon/clawed fire pointer.

## Summary

- Artifact icons: `154` unique PNG, `256x256`, transparent realistic D&D/tabletop fantasy raster magic item pictures (SCRUM-960/961/962: 32 семьи + 37 сохранённых + 85 классовых; 17 легаси-иконок удалены).
- Shop-only icons: `7` unique PNG, `128x128`, transparent background.
- Shop frame assets: slot, hover, price badge, purchased/unavailable overlay, tooltip frame.
- Cursor assets: normal, hover and attack variants, `48x48`, transparent background.
- Artifact pipeline: `tools/extract_realistic_dnd_artifact_icons.py`; older deterministic/per-item/concept-sheet generators are superseded reference tooling.
- Shop/cursor generator: `tools/generate_artifact_shop_cursor_assets.py`.
- Preview: `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` with large and 40px samples for every active artifact.
- SCRUM-606/SCRUM-609 integration adds 10 dedicated icons with source references
  under `docs/design/references/icons/artifacts/<id>/`, contact sheet
  `docs/design/previews/artifact_icons_606_609_contact.png`, and QA report
  `docs/design/reports/artifact_icons_606_609_qa.md`.

## Artifact Icon Mapping

| Artifact ID | Name | Icon path |
| --- | --- | --- |
| `warrior_charm` | Оберег воина | `assets/sprites/ui/icons/artifacts/artifact_warrior_charm.png` |
| `fox_boots` | Лисьи сапоги | `assets/sprites/ui/icons/artifacts/artifact_fox_boots.png` |
| `glass_orb` | Стеклянная сфера | `assets/sprites/ui/icons/artifacts/artifact_glass_orb.png` |
| `hawk_lens` | Линза ястреба | `assets/sprites/ui/icons/artifacts/artifact_hawk_lens.png` |
| `ember_core` | Тлеющее ядро | `assets/sprites/ui/icons/artifacts/artifact_ember_core.png` |
| `old_codex` | Ветхий кодекс | `assets/sprites/ui/icons/artifacts/artifact_old_codex.png` |
| `stone_heart` | Каменное сердце | `assets/sprites/ui/icons/artifacts/artifact_stone_heart.png` |
| `banner_seed` | Семя знамени | `assets/sprites/ui/icons/artifacts/artifact_banner_seed.png` |
| `red_whetstone` | Красный оселок | `assets/sprites/ui/icons/artifacts/artifact_red_whetstone.png` |
| `star_compass` | Звёздный компас | `assets/sprites/ui/icons/artifacts/artifact_star_compass.png` |
| `living_root` | Живой корень | `assets/sprites/ui/icons/artifacts/artifact_living_root.png` |
| `captains_coin` | Монета капитана | `assets/sprites/ui/icons/artifacts/artifact_captains_coin.png` |
| `quickstring` | Быстрая струна | `assets/sprites/ui/icons/artifacts/artifact_quickstring.png` |
| `heavy_totem` | Тяжёлый тотем | `assets/sprites/ui/icons/artifacts/artifact_heavy_totem.png` |
| `splinter_gloves` | Перчатки осколков | `assets/sprites/ui/icons/artifacts/artifact_splinter_gloves.png` |
| `wide_sigil` | Дальняя печать | `assets/sprites/ui/icons/artifacts/artifact_wide_sigil.png` |
| `summoners_bell` | Колокольчик призывателя | `assets/sprites/ui/icons/artifacts/artifact_summoners_bell.png` |
| `sturdy_amulet` | Крепкий амулет | `assets/sprites/ui/icons/artifacts/artifact_sturdy_amulet.png` |
| `fast_boots` | Быстрые сапоги | `assets/sprites/ui/icons/artifacts/artifact_fast_boots.png` |
| `magnetic_buckle` | Магнитная пряжка | `assets/sprites/ui/icons/artifacts/artifact_magnetic_buckle.png` |
| `silver_coin` | Серебряная монета | `assets/sprites/ui/icons/artifacts/artifact_silver_coin.png` |
| `survival_manual` | Учебник выживания | `assets/sprites/ui/icons/artifacts/artifact_survival_manual.png` |
| `cracked_shield` | Треснувший щит | `assets/sprites/ui/icons/artifacts/artifact_cracked_shield.png` |
| `sharp_talisman` | Острый талисман | `assets/sprites/ui/icons/artifacts/artifact_sharp_talisman.png` |
| `cursed_crown` | Проклятая корона | `assets/sprites/ui/icons/artifacts/artifact_cursed_crown.png` |
| `fragile_heart` | Хрупкое сердце | `assets/sprites/ui/icons/artifacts/artifact_fragile_heart.png` |
| `greedy_purse` | Жадный кошелек | `assets/sprites/ui/icons/artifacts/artifact_greedy_purse.png` |
| `burning_shard` | Горящий осколок | `assets/sprites/ui/icons/artifacts/artifact_burning_shard.png` |
| `golden_route_mark` | Золотая метка пути | `assets/sprites/ui/icons/artifacts/artifact_golden_route_mark.png` |
| `glass_edge` | Стеклянная кромка | `assets/sprites/ui/icons/artifacts/artifact_glass_edge.png` |
| `echo_core` | Эхо Разлома | `assets/sprites/ui/icons/artifacts/artifact_echo_core.png` |
| `blood_pact` | Кровавый Рубеж | `assets/sprites/ui/icons/artifacts/artifact_blood_pact.png` |
| `leech_heart` | Сердце Пиявки | `assets/sprites/ui/icons/artifacts/artifact_leech_heart.png` |
| `thorn_pact` | Договор Шипов | `assets/sprites/ui/icons/artifacts/artifact_thorn_pact.png` |
| `phantom_step` | Призрачный Шаг | `assets/sprites/ui/icons/artifacts/artifact_phantom_step.png` |
| `leech_fang` | Клык Пиявки | `assets/sprites/ui/icons/artifacts/artifact_leech_fang.png` |

### SCRUM-961 Class Artifact Icons (85)

Все классовые артефакты Возвышения-5 следуют единому пути
`assets/sprites/ui/icons/artifacts/artifact_<id>.png` (пак SCRUM-962,
референсы `docs/design/references/icons/artifacts/<id>/`). ID (по 5 на класс):
`perfect_edge, shadow_twin, venom_spool, evasion_shroud, return_arc_rune` (assassin);
`crimson_grip, spectral_axe, hammer_weight, blood_roar, last_onslaught` (berserk);
`spore_capacitor, sample_chain, symbiote_sheath, inhibitor_colony, split_analysis` (biologist);
`lucky_coin, magnetic_purse, paralyzing_blade, smoke_cache, stolen_crest` (thief);
`overdrive_pick, bass_resonator, stage_amplifier, feedback_loop, rhythm_counter` (guitarist);
`surgical_oath, bonesaw_teeth, plague_carrier, restorative_vapor, triage_protocol` (doctor);
`spirit_pack_banner, wolf_call, blue_totem, briar_seal, pack_alpha` (druid);
`turret_magazine, drone_gyroscope, mine_satchel, field_blueprint, salvage_core` (engineer);
`impact_string, moon_splitter, storm_piercer, root_snare, hunters_mark` (ranger);
`armor_protocol, anchor_core, press_calibrator, reactor_chronometer, repair_subroutine` (robot);
`rebound_plate, triple_thrust, tower_slam, holy_chain, vanguard_oath` (knight);
`prayer_beads, reliquary_salvo, censer_vow, twin_bell, martyr_shroud` (priest);
`longshot_scope, deadeye_round, spotter_mark, shatter_drum, clean_line` (sniper);
`second_volley, arquebus_shrapnel, long_fuse, bayonet_trigger, battle_doctrine` (soldier);
`chain_wand, curse_font, mirror_page, void_hunger, black_bargain` (dark_mage);
`volatile_dust, acid_catalyst, clear_acid, tank_homunculus, reactor_homunculus` (chemist);
`fourth_ring, prismatic_cross, meteor_heart, mana_overflow, elemental_recoil` (elementalist).

Легаси-иконки классовых (blood_sigil, void_ink, echo_pick, jagged_blade, heavy_grip,
war_belt, warriors_rage, dark_crystal, ash_page, skull_resonator, ink_candle,
copper_string, broken_pick, loud_amp, bass_cable, split_core) и swift_ink удалены
вместе с source-референсами и строками манифеста SCRUM-340.

### SCRUM-606 / SCRUM-609 Artifact Icons

| Artifact ID | Name | Icon path |
| --- | --- | --- |
| `field_kit` | Полевой набор | `assets/sprites/ui/icons/artifacts/artifact_field_kit.png` |
| `vital_siphon` | Живой сифон | `assets/sprites/ui/icons/artifacts/artifact_vital_siphon.png` |
| `powder_charge` | Пороховой заряд | `assets/sprites/ui/icons/artifacts/artifact_powder_charge.png` |
| `bulwark_echo` | Эхо бастиона | `assets/sprites/ui/icons/artifacts/artifact_bulwark_echo.png` |
| `duelist_spur` | Шпора дуэлянта | `assets/sprites/ui/icons/artifacts/artifact_duelist_spur.png` |
| `sacrifice_seal` | Печать жертвы | `assets/sprites/ui/icons/artifacts/artifact_sacrifice_seal.png` |
| `hungry_amulet` | Голодный амулет | `assets/sprites/ui/icons/artifacts/artifact_hungry_amulet.png` |
| `berserk_totem` | Тотем берсерка | `assets/sprites/ui/icons/artifacts/artifact_berserk_totem.png` |
| `focus_lens` | Линза фокуса | `assets/sprites/ui/icons/artifacts/artifact_focus_lens.png` |
| `stone_hide` | Каменная шкура | `assets/sprites/ui/icons/artifacts/artifact_stone_hide.png` |
| `rift_key` | Ключ Разлома | `assets/sprites/ui/icons/artifacts/artifact_rift_key.png` |

## Shop-Only Icon Mapping

| Shop item ID | Name | Icon path |
| --- | --- | --- |
| `shop_damage` | Точильный камень | `assets/sprites/ui/icons/shop/shop_shop_damage.png` |
| `shop_heal` | Полевой бинт | `assets/sprites/ui/icons/shop/shop_shop_heal.png` |
| `shop_pickup` | Магнитный талисман | `assets/sprites/ui/icons/shop/shop_shop_pickup.png` |
| `shop_speed` | Легкие сапоги | `assets/sprites/ui/icons/shop/shop_shop_speed.png` |
| `shop_weapon_cooldown` | Масло темпа | `assets/sprites/ui/icons/shop/shop_shop_weapon_cooldown.png` |
| `shop_range` | Линза охоты | `assets/sprites/ui/icons/shop/shop_shop_range.png` |
| `shop_artifact` | Пыльный артефакт | `assets/sprites/ui/icons/shop/shop_shop_artifact.png` |

## Shop Visual Assets

| Asset ID | File | Size | Runtime use |
| --- | --- | ---: | --- |
| `ui_shop_artifact_slot_frame` | `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` | `256x256` | normal item slot frame over shop background |
| `ui_shop_artifact_slot_hover` | `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png` | `256x256` | hover/selected state |
| `ui_shop_price_badge` | `assets/sprites/ui/shop/ui_shop_price_badge.png` | `256x96` | price badge with coin motif |
| `ui_shop_purchased_overlay` | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` | `256x256` | purchased/unavailable state overlay |
| `ui_shop_tooltip_frame` | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` | `640x320` | hover tooltip frame |

Recommended `1600x900` shop composition:

- Use central free area of `screen_shop_background.png`.
- Slot visual size: `118-136` px.
- Icon size inside slot: `76-88` px.
- Price badge: `92-112` wide, anchored at lower slot edge.
- Spacing: `18-24` px between slots.
- 4 offers can use a `2x2` grid or gentle arc on the counter.
- Description text should appear only in hover tooltip.

For `2560x1440`, keep the shop offer group max width around `960-1100`, with slot size `150-176`, not stretched to the whole screen.

## Cursor Assets

| Asset ID | File | Size | Hotspot | Use |
| --- | --- | ---: | --- | --- |
| `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png` | `48x48` | `(2, 2)` | default dragon claw fire cursor |
| `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png` | `48x48` | `(2, 2)` | hover/clickable dragon claw fire cursor |
| `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png` | `48x48` | `(2, 2)` | optional combat/attack dragon claw fire cursor |

The cursor uses a dark forged steel dragon/claw pointer with a precise upper-left tip, orange fire glow along the blade and a red gem/eye. Hover and attack variants keep the same silhouette and hotspot while increasing the warm glow so the cursor remains visible on combat backgrounds, route map, menu panels and shop screens. SCRUM-223 preview: `docs/design/previews/cursor_clawed_fire_before_after.png`.

## Integration Notes

- Back-end should keep one centralized cache/mapping for artifact/shop item icon textures.
- Shop item IDs intentionally keep the requested filename pattern `shop_<shop_item_id>.png`, so paths are `shop_shop_damage.png`, `shop_shop_heal.png`, etc.
- Artifact icons should be usable both for level-up/reward UI and shop offers.
- Do not use emoji/default placeholders for any artifact or shop item after integration.
