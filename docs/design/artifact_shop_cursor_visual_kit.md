# Artifact, Shop Item And Cursor Visual Kit

Обновлено: 2026-06-12

Этот документ фиксирует Design visual kit для артефактов, shop-only предметов, inline shop UI и игрового курсора FantasyDisk. Back-end интеграция описана в `docs/tasks/backend_shop_inline_artifact_icons_cursor_integration_task.md`.

Back-end audit follow-up resolved 2026-06-11: фактические PNG из разделов Artifact Icon Mapping, Shop-Only Icon Mapping, Shop Visual Assets и Cursor Assets добавлены в текущий checkout и импортированы в Godot. Fallback через `scripts/ui_icon_registry.gd` остается только fail-safe.

User feedback rework 2026-06-12: artifact icons поштучно перегенерированы как `256x256` RGBA transparent item icons: один цельный законченный предмет на каждый active artifact ID, без встроенной UI-рамки, пьедесталов, фона, осколков, частиц и текста. Предметы сохраняют dark fantasy lighting с источником сверху-слева и привязаны к названию/эффекту из `ProgressionData.ARTIFACTS`. Предыдущие generated/vector-like, glossy и concept-sheet tile направления superseded. Shop-only icons, frames and cursor variants keep the richer FantasyDisk fantasy-medallion / dagger-quill treatment.

## Summary

- Artifact icons: `53` unique PNG, `256x256`, transparent per-item dark fantasy item icons.
- Shop-only icons: `7` unique PNG, `128x128`, transparent background.
- Shop frame assets: slot, hover, price badge, purchased/unavailable overlay, tooltip frame.
- Cursor assets: normal, hover and attack variants, `48x48`, transparent background.
- Artifact pipeline: `tools/regenerate_artifact_icons_per_item.py`; technical validation and preview: `tools/validate_artifact_icons.py`; older deterministic/concept-sheet generators are superseded reference tooling.
- Shop/cursor generator: `tools/generate_artifact_shop_cursor_assets.py`.
- Preview: `assets/sprites/ui/icons/artifact_per_item_preview.png` with 256px and 40px samples for every active artifact.

## Artifact Icon Mapping

| Artifact ID | Name | Icon path |
| --- | --- | --- |
| `warrior_charm` | Warrior Charm | `assets/sprites/ui/icons/artifacts/artifact_warrior_charm.png` |
| `fox_boots` | Fox Boots | `assets/sprites/ui/icons/artifacts/artifact_fox_boots.png` |
| `glass_orb` | Glass Orb | `assets/sprites/ui/icons/artifacts/artifact_glass_orb.png` |
| `hawk_lens` | Hawk Lens | `assets/sprites/ui/icons/artifacts/artifact_hawk_lens.png` |
| `ember_core` | Ember Core | `assets/sprites/ui/icons/artifacts/artifact_ember_core.png` |
| `old_codex` | Old Codex | `assets/sprites/ui/icons/artifacts/artifact_old_codex.png` |
| `stone_heart` | Stone Heart | `assets/sprites/ui/icons/artifacts/artifact_stone_heart.png` |
| `banner_seed` | Banner Seed | `assets/sprites/ui/icons/artifacts/artifact_banner_seed.png` |
| `red_whetstone` | Red Whetstone | `assets/sprites/ui/icons/artifacts/artifact_red_whetstone.png` |
| `star_compass` | Star Compass | `assets/sprites/ui/icons/artifacts/artifact_star_compass.png` |
| `living_root` | Living Root | `assets/sprites/ui/icons/artifacts/artifact_living_root.png` |
| `captains_coin` | Captain's Coin | `assets/sprites/ui/icons/artifacts/artifact_captains_coin.png` |
| `quickstring` | Quickstring | `assets/sprites/ui/icons/artifacts/artifact_quickstring.png` |
| `heavy_totem` | Heavy Totem | `assets/sprites/ui/icons/artifacts/artifact_heavy_totem.png` |
| `splinter_gloves` | Splinter Gloves | `assets/sprites/ui/icons/artifacts/artifact_splinter_gloves.png` |
| `wide_sigil` | Wide Sigil | `assets/sprites/ui/icons/artifacts/artifact_wide_sigil.png` |
| `swift_ink` | Swift Ink | `assets/sprites/ui/icons/artifacts/artifact_swift_ink.png` |
| `summoners_bell` | Summoner's Bell | `assets/sprites/ui/icons/artifacts/artifact_summoners_bell.png` |
| `blood_sigil` | Кровавая печать | `assets/sprites/ui/icons/artifacts/artifact_blood_sigil.png` |
| `void_ink` | Чернила пустоты | `assets/sprites/ui/icons/artifacts/artifact_void_ink.png` |
| `echo_pick` | Медиатор эха | `assets/sprites/ui/icons/artifacts/artifact_echo_pick.png` |
| `sturdy_amulet` | Крепкий амулет | `assets/sprites/ui/icons/artifacts/artifact_sturdy_amulet.png` |
| `fast_boots` | Быстрые сапоги | `assets/sprites/ui/icons/artifacts/artifact_fast_boots.png` |
| `magnetic_buckle` | Магнитная пряжка | `assets/sprites/ui/icons/artifacts/artifact_magnetic_buckle.png` |
| `silver_coin` | Серебряная монета | `assets/sprites/ui/icons/artifacts/artifact_silver_coin.png` |
| `survival_manual` | Учебник выживания | `assets/sprites/ui/icons/artifacts/artifact_survival_manual.png` |
| `cracked_shield` | Треснувший щит | `assets/sprites/ui/icons/artifacts/artifact_cracked_shield.png` |
| `sharp_talisman` | Острый талисман | `assets/sprites/ui/icons/artifacts/artifact_sharp_talisman.png` |
| `jagged_blade` | Зазубренное лезвие | `assets/sprites/ui/icons/artifacts/artifact_jagged_blade.png` |
| `heavy_grip` | Тяжелая рукоять | `assets/sprites/ui/icons/artifacts/artifact_heavy_grip.png` |
| `war_belt` | Боевой ремень | `assets/sprites/ui/icons/artifacts/artifact_war_belt.png` |
| `warriors_rage` | Ярость воина | `assets/sprites/ui/icons/artifacts/artifact_warriors_rage.png` |
| `dark_crystal` | Темный кристалл | `assets/sprites/ui/icons/artifacts/artifact_dark_crystal.png` |
| `ash_page` | Пепельная страница | `assets/sprites/ui/icons/artifacts/artifact_ash_page.png` |
| `skull_resonator` | Черепной резонатор | `assets/sprites/ui/icons/artifacts/artifact_skull_resonator.png` |
| `ink_candle` | Чернильная свеча | `assets/sprites/ui/icons/artifacts/artifact_ink_candle.png` |
| `copper_string` | Медная струна | `assets/sprites/ui/icons/artifacts/artifact_copper_string.png` |
| `broken_pick` | Сломанный медиатор | `assets/sprites/ui/icons/artifacts/artifact_broken_pick.png` |
| `loud_amp` | Громкий усилитель | `assets/sprites/ui/icons/artifacts/artifact_loud_amp.png` |
| `bass_cable` | Басовый кабель | `assets/sprites/ui/icons/artifacts/artifact_bass_cable.png` |
| `cursed_crown` | Проклятая корона | `assets/sprites/ui/icons/artifacts/artifact_cursed_crown.png` |
| `fragile_heart` | Хрупкое сердце | `assets/sprites/ui/icons/artifacts/artifact_fragile_heart.png` |
| `greedy_purse` | Жадный кошелек | `assets/sprites/ui/icons/artifacts/artifact_greedy_purse.png` |
| `burning_shard` | Горящий осколок | `assets/sprites/ui/icons/artifacts/artifact_burning_shard.png` |
| `golden_route_mark` | Золотая метка пути | `assets/sprites/ui/icons/artifacts/artifact_golden_route_mark.png` |
| `glass_edge` | Стеклянная кромка | `assets/sprites/ui/icons/artifacts/artifact_glass_edge.png` |
| `echo_core` | Эхо Разлома | `assets/sprites/ui/icons/artifacts/artifact_echo_core.png` |
| `split_core` | Ядро Расщепления | `assets/sprites/ui/icons/artifacts/artifact_split_core.png` |
| `blood_pact` | Кровавый Рубеж | `assets/sprites/ui/icons/artifacts/artifact_blood_pact.png` |
| `leech_heart` | Сердце Пиявки | `assets/sprites/ui/icons/artifacts/artifact_leech_heart.png` |
| `thorn_pact` | Договор Шипов | `assets/sprites/ui/icons/artifacts/artifact_thorn_pact.png` |
| `phantom_step` | Призрачный Шаг | `assets/sprites/ui/icons/artifacts/artifact_phantom_step.png` |

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
| `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png` | `48x48` | `(5, 4)` | default cursor |
| `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png` | `48x48` | `(5, 4)` | hover/clickable cursor |
| `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png` | `48x48` | `(5, 4)` | optional combat/attack cursor |

The cursor uses a pale dagger/quill fantasy pointer, strong dark outline, gem detail and gold/cyan/red state accents. It is designed to remain visible on combat backgrounds, route map, menu panels and shop screens.

## Integration Notes

- Back-end should keep one centralized cache/mapping for artifact/shop item icon textures.
- Shop item IDs intentionally keep the requested filename pattern `shop_<shop_item_id>.png`, so paths are `shop_shop_damage.png`, `shop_shop_heal.png`, etc.
- Artifact icons should be usable both for level-up/reward UI and shop offers.
- Do not use emoji/default placeholders for any artifact or shop item after integration.
