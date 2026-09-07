<!-- content-registry-section -->

# FantasyDisk Content Registry — UI Иконки, Киты И Глифы

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## UI Иконки Характеристик

Все иконки подключаются через `scripts/ui_icon_registry.gd`; это единая backend-точка для Escape stats menu, level-up reward cards, tooltips, shop/reward descriptions и HUD. Иконки должны оставаться polished stylized fantasy cartoon PNG, без emoji/default placeholders.

### Базовые Характеристики

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `strength` | Сила | `assets/sprites/ui/icons/stats/stat_strength.png` |
| `agility` | Ловкость | `assets/sprites/ui/icons/stats/stat_agility.png` |
| `intelligence` | Интеллект | `assets/sprites/ui/icons/stats/stat_intelligence.png` |
| `perception` | Восприятие | `assets/sprites/ui/icons/stats/stat_perception.png` |
| `energy` | Энергия | `assets/sprites/ui/icons/stats/stat_energy.png` |
| `knowledge` | Знание | `assets/sprites/ui/icons/stats/stat_knowledge.png` |
| `endurance` | Выносливость | `assets/sprites/ui/icons/stats/stat_endurance.png` |
| `leadership` | Лидерство | `assets/sprites/ui/icons/stats/stat_leadership.png` |

### Производные Атрибуты

FAN-1887: канонический player-facing реестр прокачки — 16 осей
(`CharacterData.ATTRIBUTE_REGISTRY`); плоская ось «Добавление урона»
(`damage_flat`) использует иконку `attr_damage.png`. Иконки внутренних
параметров (absorb, knockback, attack_range, range_multiplier, dot_speed,
aura_radius, buff_power, projectile_speed, vampiric_chance) сохранены как
ассеты для артефактных превью и legacy-редов, но эти параметры больше не
являются самостоятельными выборами level-up/Shop/Codex/Hero Select. Пять
player-facing defensive choices: max_health, defense, dodge, regeneration и
vampiric. Absorb и vampiric_chance — внутренние параметры: absorb пропускает
≥42% удара, а сила вампиризма масштабируется Knowledge и общим
heal-per-second budget.

Обычный dodge остаётся строго ниже 0.55; smoke bomb Вора — отдельное
достижимое исключение с суммарным пределом 0.90 только внутри живого облака.

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `damage` | Урон | `assets/sprites/ui/icons/derived/attr_damage.png` |
| `magic_damage` | Магический урон | `assets/sprites/ui/icons/derived/attr_magic_damage.png` |
| `attack_speed` | Скорость атаки | `assets/sprites/ui/icons/derived/attr_attack_speed.png` |
| `crit_chance` | Шанс крита | `assets/sprites/ui/icons/derived/attr_crit_chance.png` |
| `crit_damage_multiplier` | Сила крита | `assets/sprites/ui/icons/derived/attr_crit_damage_multiplier.png` |
| `move_speed` | Скорость движения | `assets/sprites/ui/icons/derived/attr_move_speed.png` |
| `dodge` | Уклонение | `assets/sprites/ui/icons/derived/attr_dodge.png` |
| `defense` | Защита | `assets/sprites/ui/icons/derived/attr_defense.png` |
| `absorb` | Поглощение | `assets/sprites/ui/icons/derived/attr_absorb.png` |
| `health_point` | Максимальное здоровье | `assets/sprites/ui/icons/derived/attr_health_point.png` |
| `knockback_distance` | Дистанция отталкивания | `assets/sprites/ui/icons/derived/attr_knockback_distance.png` |
| `summon_amount` | Сила призыва | `assets/sprites/ui/icons/derived/attr_summon_amount.png` |
| `attack_range` | Дальность атаки | `assets/sprites/ui/icons/derived/attr_attack_range.png` |
| `range_multiplier` | Множитель дальности | `assets/sprites/ui/icons/derived/attr_range_multiplier.png` |
| `regeneration` | Регенерация | `assets/sprites/ui/icons/derived/attr_regeneration.png` |
| `vampiric_amount` | Вампиризм | `assets/sprites/ui/icons/derived/attr_vampiric_amount.png` |
| `vampiric_chance` | Шанс вампиризма | `assets/sprites/ui/icons/derived/attr_vampiric_chance.png` |
| `dot_damage` | Периодический урон | `assets/sprites/ui/icons/derived/attr_dot_damage.png` |
| `dot_speed` | Частота периодического урона | `assets/sprites/ui/icons/derived/attr_dot_speed.png` |
| `aoe_radius` | Увеличение области атаки | `assets/sprites/ui/icons/derived/attr_aoe_radius.png` |
| `aura_radius` | Радиус ауры | `assets/sprites/ui/icons/derived/attr_aura_radius.png` |
| `buff_power` | Сила баффов | `assets/sprites/ui/icons/derived/attr_buff_power.png` |
| `knockback_power` | Сила отталкивания | `assets/sprites/ui/icons/derived/attr_knockback_power.png` |
| `projectile_speed` | Скорость снарядов | `assets/sprites/ui/icons/derived/attr_projectile_speed.png` |
| `ultimate_multiplier` | Сила ультимейта | `assets/sprites/ui/icons/derived/attr_ultimate_multiplier.png` |
| `pickup_radius` | Радиус подбора | `assets/sprites/ui/icons/derived/attr_pickup_radius.png` |

### HUD Ресурсы

| ID | Игровое имя | Ассет |
| --- | --- | --- |
| `hp` | HP | `assets/sprites/ui/hud/hud_hp.png` |
| `xp` | Опыт | `assets/sprites/ui/hud/hud_xp.png` |
| `money` | Деньги | `assets/sprites/ui/hud/hud_money.png` |
| `ultimate_multiplier` | Сила ультимейта | `assets/sprites/ui/icons/derived/attr_ultimate_multiplier.png` via `UIIconRegistry` |

`scripts/ui_icon_registry.gd` кэширует загруженные Texture2D по пути; новые UI места должны брать иконки через registry, а не делать отдельный `load()`.

## UI Visual Kit 2026-06-14

SCRUM-273 заменяет button-канон SCRUM-147 на Red & Gold Dragon kit из `docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`. Live-кнопки лежат в `assets/sprites/ui/frames/red_gold/`: 15 типов, каждый с idle/base, hover, pressed и disabled. Старый Parchment & Wax Seal button kit скопирован в backup `build/cleanup_backup_red_gold_buttons_2026_06_14/` и больше не является runtime-каноном. SCRUM-274 заменяет non-button panel/frame канон SCRUM-229 на Ornate Dark / Red kit из `docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png`. Live-панели/HUD/tooltips/pause frames лежат в `assets/sprites/ui/frames/ornate/`, а прежний leather+gold/dark_fantasy/escape panel kit скопирован в backup `build/cleanup_backup_ornate_frames_2026_06_14/`. No-junk rule: без бессмысленных линий/кружков/квадратиков/дефолтного Godot-декора.

SCRUM-448/SCRUM-449 делают **Minimalist UI restyle** активным non-button frame
направлением: `assets/sprites/ui/frames/minimal/` содержит
`ui_frame_minimal_modal`, `panel`, `card`, `tooltip`, `hud_strip` и `field`.
Spec/metadata: `docs/design/mockups/scrum448_ui_minimalist/spec.md` и
`docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`;
preview: `docs/design/previews/scrum448_minimal_ui_frame_contact.png`.
Все PNG прозрачные (`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`).
Live runtime uses this kit for safe non-button panels/cards/tooltips/HUD wrappers;
SCRUM-273 Red & Gold buttons остаются каноном и не заменяются этим набором.

SCRUM-452 добавляет Design-ready **Minimal Metal UI anchor** для следующего
упрощения интерфейса: `assets/sprites/ui/frames/minimal_metal/` содержит
`ui_frame_minimal_metal_modal`, `panel`, `card`, `tooltip`, `hud_strip` и
`field`. Spec/metadata:
`docs/design/mockups/scrum452_ui_minimal_metal/spec.md` и
`docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`;
previews: `docs/design/previews/scrum452_minimal_metal_anchor_contact.png`,
`docs/design/previews/scrum452_minimal_metal_safe_zones.png`. Все production PNG
прозрачные (`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`).
Набор не live до Back-end integration handoff; SCRUM-273 buttons остаются
каноном до SCRUM-450.

SCRUM-450 добавляет Design-ready **Minimal Metal button kit**:
`assets/sprites/ui/frames/minimal_metal_buttons/` содержит 15 button types x 5
states (`normal`, `hover`, `pressed`, `focus`, `disabled`). Metadata:
`docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`;
spec: `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`;
previews: `docs/design/previews/scrum450_minimal_metal_button_contact.png`,
`docs/design/previews/scrum450_minimal_metal_button_safe_zones.png`. Все 75 PNG
прозрачные (`white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`).
Набор не live до Back-end integration; SCRUM-273 Red & Gold buttons остаются
активным runtime-каноном.

SCRUM-451 добавляет Design-source **Minimal Metal rollout contract**: все
целевые UI surfaces по экранам сведены к шести frame families SCRUM-452
(`modal`, `panel`, `card`, `tooltip`, `hud_strip`, `field`) с отдельным
подключением SCRUM-450 button kit. Source of truth:
`docs/design/mockups/scrum451_ui_minimal_frames_rollout/spec.md` и
`docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`;
preview: `docs/design/previews/scrum451_minimal_metal_rollout_contact.png`.
Контракт не live до Back-end integration; старые frame assets удалять/бэкапить
можно только после no-live-ref audit.

| ID | Ассет | Роль |
| --- | --- | --- |
| `ui_panel_frame` | `assets/sprites/ui/frames/global/ui_panel_frame.png` | Базовые большие панели меню/событий/кодекса |
| `ui_button_frame` | `assets/sprites/ui/frames/global/ui_button_frame.png` | Legacy/fallback frame; runtime buttons use SCRUM-273 `ui_btn_red_gold_*` 4-state textures |
| `ui_card_frame` | `assets/sprites/ui/frames/global/ui_card_frame.png` | Карточки персонажей, route node buttons, compact panels |
| `ui_level_panel_frame` | `assets/sprites/ui/frames/global/ui_level_panel_frame.png` | Level-up / reward panel |
| `ui_hud_panel_frame` | `assets/sprites/ui/frames/global/ui_hud_panel_frame.png` | Боевой HUD panel |
| `ui_hud_card_frame` | `assets/sprites/ui/frames/global/ui_hud_card_frame.png` | HP/XP/money HUD cards |
| `ui_tooltip_frame` | `assets/sprites/ui/frames/global/ui_tooltip_frame.png` | Generic tooltip/system panel frame |
| `ui_frame_unified_master` | `assets/sprites/ui/frames/unified/ui_frame_unified_master.png` | SCRUM-384 active thin metallic projectwide master frame border, `1024x1024` RGBA, transparent center; use 9-slice tile margins `72/72/72/72`, content margins `88/88/88/88`, strict safe rect `[88,88,848,848]`; paths preserved from SCRUM-373/SCRUM-382 |
| `ui_gold_menu_shell` | `assets/sprites/ui/meta40/frame_border.png` | SCRUM-981 canonical hollow outer shell for Main Menu, Route Map, Rest, Upgrade, Battle Reward, Victory and Defeat; source `1536x1024`, texture/content rails `160/160/160/160`, `draw_center=false`; safe rects `[133,113,1014,494]` @1280×720, `[200,169,1520,742]` @1920×1080, `[267,225,2026,990]` @2560×1440. Codex/Level Up/Combat and specialist child screens are explicit exceptions. |
| `ui_frame_unified_master_fill` | `assets/sprites/ui/frames/unified/ui_frame_unified_master_fill.png` | SCRUM-384 full panel-fill variant for rectangular surfaces where a quiet dark fill is acceptable |
| `ui_frame_unified_inner_fill` | `assets/sprites/ui/frames/unified/ui_frame_unified_inner_fill.png` | SCRUM-384 `1024x1024` inner fill asset with alpha outside strict content zone |
| `ui_frame_unified_ornament_top_bottom` | `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_top.png`, `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_bottom.png` | SCRUM-384 optional dragon overlays for large-window ornaments only; do not bake into 9-slice stretch zones and do not use on compact HUD, tooltip, chip or button surfaces |
| `ui_frame_unified_hover_overlay` | `assets/sprites/ui/frames/unified/ui_frame_unified_hover_overlay.png` | SCRUM-384 subtle red/gold hover overlay fallback; preferred runtime hover is neutral modulate/contrast, not yellow glow |
| `ui_frame_minimal_modal` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_modal.png` | SCRUM-448/SCRUM-449 live minimalist modal/window frame, `986x900` RGBA, content rect `[74,94,838,720]`; used for Settings/Codex/pause/result shells where safe |
| `ui_frame_minimal_panel` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_panel.png` | SCRUM-448/SCRUM-449 live generic minimal panel, `782x716` RGBA, content rect `[59,75,664,573]`; used for inner panels and large sections where safe |
| `ui_frame_minimal_card` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_card.png` | SCRUM-448/SCRUM-449 live minimal card, `426x486` RGBA, content rect `[45,58,336,372]`; used for reward/economy/Codex cards where safe |
| `ui_frame_minimal_tooltip` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_tooltip.png` | SCRUM-448/SCRUM-449 live minimal tooltip, `760x242` RGBA, content rect `[68,46,624,155]`; used for glossary/tooltips where safe |
| `ui_frame_minimal_hud_strip` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_hud_strip.png` | SCRUM-448/SCRUM-449 live minimal HUD/resource strip, `1122x288` RGBA, content rect `[107,65,908,164]`; used for compact resource HUD wrapper |
| `ui_frame_minimal_field` | `assets/sprites/ui/frames/minimal/ui_frame_minimal_field.png` | SCRUM-448/SCRUM-449 live minimal input/field/tab frame, `616x286` RGBA, content rect `[59,53,498,183]`; used for Settings switcher, HUD cards and compact price badges |
| `ui_frame_minimal_metal_modal` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_modal.png` | SCRUM-452 Design-ready strict minimal-metal modal/window frame, `986x900` RGBA, content rect `[72,92,842,724]`; not live until Back-end integration |
| `ui_frame_minimal_metal_panel` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png` | SCRUM-452 Design-ready strict minimal-metal generic panel, `782x716` RGBA, content rect `[58,72,666,578]`; not live until Back-end integration |
| `ui_frame_minimal_metal_card` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png` | SCRUM-452 Design-ready strict minimal-metal card, `426x486` RGBA, content rect `[46,58,334,374]`; not live until Back-end integration |
| `ui_frame_minimal_metal_tooltip` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png` | SCRUM-452 Design-ready strict minimal-metal tooltip, `760x242` RGBA, content rect `[66,44,628,158]`; not live until Back-end integration |
| `ui_frame_minimal_metal_hud_strip` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_hud_strip.png` | SCRUM-452 Design-ready strict minimal-metal HUD/status strip, `1122x288` RGBA, content rect `[104,62,914,170]`; not live until Back-end integration |
| `ui_frame_minimal_metal_field` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png` | SCRUM-452 Design-ready strict minimal-metal input/field frame, `616x286` RGBA, content rect `[58,52,500,186]`; not live until Back-end integration |
| `ui_btn_minimal_metal_standard` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_standard*.png` | SCRUM-450 Design-ready standard action button family, `420x104` RGBA, 5 states, content rect `[64,32,292,40]`; not live until Back-end integration |
| `ui_btn_minimal_metal_max` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_max*.png` | SCRUM-450 Design-ready maximum action button family, `560x104` RGBA, 5 states, content rect `[72,32,416,40]`; not live until Back-end integration |
| `ui_btn_minimal_metal_main_menu` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_main_menu*.png` | SCRUM-450 Design-ready main-menu button family, `380x104` RGBA, 5 states, content rect `[62,32,256,40]`; not live until Back-end integration |
| `ui_btn_minimal_metal_back_s_m_l` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_back_*.png` | SCRUM-450 Design-ready back/action variants S/M/L, 5 states each; see metadata for exact content rects; not live until Back-end integration |
| `ui_btn_minimal_metal_compact` | `assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab*.png`, `ui_btn_minimal_metal_utility*.png`, `ui_btn_minimal_metal_pause*.png`, `ui_btn_minimal_metal_rebind*.png` | SCRUM-450 Design-ready compact/slim button families, 5 states each; fixed or 9-slice per metadata; not live until Back-end integration |
| `ui_btn_text_unique_scrum657` | `assets/sprites/ui/frames/text_buttons_unique/ui_btn_text_unique_<group>_<state>.png` | SCRUM-657 Design-ready text-button audit/redraw package, 15 size groups including 2 expanded long-label variants, 5 states each, transparent PNG, no baked text; source/audit/fit reports live in `docs/design/references/ui_text_buttons_unique_size_redraw/`, with one OpenAI source PNG per size in `per_size_sources/`. Runtime labels must fit inside `content_rect_xywh` between decorative end shutters/caps; increase width when localized text does not fit. Left/right caps are fixed-size ornaments and must not be scaled horizontally; only the center rail may stretch. |
| `ui_frame_settings_tab_switcher_3slot` | `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png` | SCRUM-391 Design-ready Settings tab switcher candidate, `1280x256` RGBA, exactly 3 slots; safe rects `[160,88,270,82]`, `[506,88,270,82]`, `[852,88,270,82]`; runtime activation handed off to `backend_settings_menu_unified_restyle_integration_task.md` |
| `ui_frame_settings_v2_main_modal` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png` | SCRUM-439 Design-ready Settings v2 modal candidate, `1536x1024` RGBA; texture margins `96/118/96/96`, content margins `144/192/144/128`; not live until Back-end integration |
| `ui_frame_settings_v2_tab_switcher_3slot` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_tab_switcher_3slot.png` | SCRUM-439 Design-ready Settings v2 switcher candidate, `1280x256` RGBA, exactly 3 slots; safe rects `[150,78,275,92]`, `[502,78,275,92]`, `[854,78,275,92]`; not live until Back-end integration |
| `ui_frame_settings_v2_section_panel` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_section_panel.png` | SCRUM-439 Design-ready nested Settings section panel, `1024x384` RGBA; content margins `104/96/104/92`; optional Back-end use |
| `ui_frame_settings_v2_control_row` | `assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_control_row.png` | SCRUM-439 Design-ready Settings row frame, `1536x192` RGBA; content margins `96/54/96/54`; optional Back-end use for dropdown/rebind/slider rows |
| `ui_frame_combat_hud_resource_panel` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_resource_panel.png` | SCRUM-390 Design-ready combat HUD resource strip, `1024x144` RGBA; texture margins `[96,44,96,44]`, content margins `[92,30,92,30]`, safe rect `[92,30,840,84]`; runtime activation handed off to `backend_combat_hud_redraw_integration_task.md` |
| `ui_frame_combat_hud_card_*` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_hp.png`, `_xp.png`, `_gold.png`, `_ult.png` | SCRUM-390 Design-ready resource card frames, `256x144` RGBA; texture margins `[48,42,48,38]`, content margins `[32,24,32,22]`, safe rect `[32,24,192,98]` |
| `ui_frame_combat_hud_timer` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_timer.png` | SCRUM-390 Design-ready combat timer frame, `384x128` RGBA; texture margins `[92,42,92,38]`, content margins `[82,32,82,28]`, safe rect `[82,32,220,68]` |
| `ui_frame_combat_hud_ascension_badge` | `assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_ascension_badge.png` | SCRUM-390 Design-ready ascension badge, `128x128` RGBA; content margins `[40,34,40,34]`, safe rect `[40,34,48,60]` |
| `ui_btn_combat_level_up_plus_*` | `assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png` + hover/pressed/disabled | SCRUM-390 opaque bottom-right level-up plus button kit, `128x128` RGBA; safe rect `[36,34,56,58]`; no yellow hover glow |
| `ui_hud_bar_fill_*` | `assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_hp.png`, `_xp.png`, `_ult.png`, `_gold.png` | SCRUM-390 painterly resource fill textures, `512x32` RGBA, optional Back-end use for HP/XP/ULT/gold bars |
| `ui_frame_pause_end_modal` | `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` | SCRUM-330 Design-ready pause/victory/death modal frame, `1280x1024` RGBA transparent. Source safe rect `[170,180,940,670]`, content margins `[170,180,170,174]`; use proportional whole-image frame or verified 9-slice only; runtime content must not overlap dragon heads, side columns, gems, bottom crest or metal border. Metadata: `docs/design/references/ui_overhaul_pause_end/scrum330_pause_end_metadata.json`; Back-end integration handoff: `backend_pause_end_ui_overhaul_integration_task.md` |
| `ui_result_crest_victory_defeat` | `assets/sprites/ui/result_crests/ui_crest_victory.png`, `assets/sprites/ui/result_crests/ui_crest_defeat.png` | SCRUM-330 result-screen decorative crests accepted for victory/death headers; decorative only in this pass, not content containers |
| `ui_frame_codex_*` | `assets/sprites/ui/frames/codex/ui_frame_codex_main_panel.png`, `_section_panel.png`, `_entry_card.png`, `_entry_card_hover.png`, `_portrait_slot.png`, `_tooltip.png`, `_tab.png`, `_tab_hover.png`, `_tab_pressed.png`, `_tab_disabled.png` | SCRUM-345 Design-ready historical Codex texture kit generated through `fantasydisk-asset-generator`; metadata and safe-zones in `docs/design/references/codex/codex_ui_texture_kit_metadata.json`; superseded for live Codex shell/list/detail/cards/tabs by SCRUM-574 2K frames, but still retained as reference/component history |
| `ui_frame_2k_codex_*` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_codex_main.png`, `_nav.png`, `_list.png`, `_detail.png`, `_entry_card.png`, `_tab_btn.png`, `_back_btn.png` | SCRUM-574 live Codex v2 2K frame family generated by `tools/build_ui_2k_frame_kit.py`; source/mockup at `docs/design/references/scrum574_codex_2k/codex_2k_mockup.png`, contract at `docs/design/mockups/scrum574_codex_2k/spec.md`; runtime uses these exact slots for `CodexMainPanel`, `CodexNavPanel`, `CodexContent`, `CodexDetailPanel`, `CodexEntryCard`, `CodexTab_*` and `CodexBackButton` |
| `ui_frame_2k_rc_*` | `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_rc_panel.png`, `ui_frame_2k_rc_btn.png` | SCRUM-584 live rebind-conflict dialog frame pair generated by `tools/build_ui_2k_frame_kit.py`; accepted textless OpenAI mockup at `docs/design/references/scrum584_rebind_conflict_2k/rebind_conflict_2k_mockup_reference_v2.png`, safe-zone preview at `docs/design/previews/scrum584_rebind_conflict_2k_safe_zones.png`, contract at `docs/design/mockups/scrum584_rebind_conflict_2k/spec.md`; runtime uses these slots for `RebindConflictPanel`, `RebindConflictRetryButton`, and `RebindConflictBackButton` |
| `ui_codex_v2_mockup_spec` | `docs/design/mockups/scrum438_codex_v2/spec.md`, `codex_v2_mockup_1920x1080.png`, `codex_v2_layout_metadata.json`; SCRUM-574 addendum `docs/design/mockups/scrum574_codex_2k/spec.md` | SCRUM-438 Design/runtime contract for the full Codex window rebuild; SCRUM-574 keeps the Control layout and replaces the live shell/list/detail/cards/tabs/back material with slot-exact 2K frames |
| `ui_frame_ornate_global_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_global_panel.png` | Live global/menu/event/codex panel frame |
| `ui_frame_ornate_level_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_level_panel.png` | Live level-up/reward main panel |
| `ui_frame_ornate_card_frame` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_card_frame.png` | Live list/card frame |
| `ui_frame_ornate_hero_card` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_hero_card.png` | Live hero portrait/card frame |
| `ui_frame_ornate_card_hover` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_card_hover.png` | Live hover/selected card frame |
| `ui_frame_ornate_tooltip` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_tooltip.png` | Live generic tooltip frame |
| `ui_frame_ornate_hud_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_hud_panel.png` | Live combat HUD panel |
| `ui_frame_ornate_hud_card` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_hud_card.png` | Live HP/XP/money/ultimate HUD cards |
| `ui_frame_ornate_timer_panel` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_timer_panel.png` | Live combat timer/ascension timer panel |
| `ui_frame_ornate_pause_main` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_main.png` | Live Escape stats main panel |
| `ui_frame_ornate_pause_stat_group` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_group.png` | Live Escape derived stat group |
| `ui_frame_ornate_pause_stat_chip` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_chip.png` | Live Escape base row / derived chip |
| `ui_frame_ornate_pause_stat_tooltip` | `assets/sprites/ui/frames/ornate/ui_frame_ornate_pause_stat_tooltip.png` | Live Escape stat tooltip |
| `ui_frame_hero_select_portrait` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_portrait.png` | Live Hero Select large portrait frame; SCRUM-321 accepted as production heroframe-style PNG and rendered as whole-image proportional `TextureRect` inside `HeroSelectPortraitFrame` (safe content margins `Vector4(128, 230, 128, 330)`, backup in `build/cleanup_backup_hero_select_portrait_2026_06_14/`) |
| `ui_frame_hero_select_dossier` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png` | Live Hero Select dossier frame; SCRUM-355 thin DescriptionHS recomposition, `1120x1140` RGBA, rendered as whole-image proportional `TextureRect` inside `HeroSelectDossierFrame` (base frame `387x394`; strict Design safe margins `Vector4(126, 160, 126, 172)`; backup in `build/qa/scrum355/hero_select_pre_scrum355_frame_assets.zip`; Back-end SCRUM-354 must integrate the new runtime margins) |
| `ui_frame_hero_select_unified_panel` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_unified_panel.png` | SCRUM-356 Design-ready unified portrait+description frame, `1536x1024` RGBA, generated through OpenAI Images/`fantasydisk-asset-generator` workflow and postprocessed to alpha. Intended to replace separate portrait+dossier runtime frames after Back-end integration; whole-image proportional scaling only. Content zones: portrait `[130,145,420,560]`, description `[610,145,786,500]`, bottom controls `[570,705,660,178]`; metadata in `docs/design/references/hero_select_unified_panel/scrum356_unified_panel_metadata.json` |
| `ui_frame_hero_select_radar` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png` | Live Hero Select floating stat radar frame; SCRUM-322 windrose compass frame, 1024x1024 RGBA, rendered as square whole-image proportional `TextureRect` (safe margins `Vector4(245, 245, 245, 235)`, backup in `build/cleanup_backup_hero_select_windrose_2026_06_14/`) |
| `ui_frame_hero_select_pixellab_parts` | `assets/sprites/ui/frames/hero_select_pixellab/` (`background.png`, `frame_title.png`, `button_back.png`, `frame_portrait.png`, `frame_dossier.png`, `frame_radar.png`, `frame_ascension.png`, `button_asc_minus.png`, `button_asc_plus.png`, `button_choose.png`, `frame_carousel.png`, `button_carousel_left.png`, `button_carousel_right.png`, `frame_hero_slot.png`) | SCRUM-687 live Hero Select PixelLab rebuild kit. Runtime scales the `2560x1440` source-space layout uniformly, keeps all labels/buttons/radar/portraits inside per-part content rects, uses framed carousel slots with child portrait textures, and preserves directional `512x512` PixelLab preview rotation for Berserk, Dark Mage, Guitarist and Doctor. |
| `hero_select_v2_mockup_spec` | `docs/design/mockups/scrum436_hero_select_v2/spec.md` | SCRUM-436 Design-ready Hero Select v2 rebuild package, not a runtime texture. OpenAI mockup, annotated safe-zones and `hero_select_v2_layout_metadata.json` preserve the existing live `HeroSelectRadarPanel` / `HeroStatRadar` while respecing hero preview, dossier/traits/weapons, ascension controls, Select/Back buttons, wide carousel and tooltip zones for 1280x720 / 1920x1080 / 2560x1440. Back-end must rebuild live Controls from this spec rather than displaying the mockup image. |
| `ui_frame_hero_select_thumbnail_strip` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png` | Live Hero Select bottom thumbnail strip frame; SCRUM-355 thin Carusel recomposition, `1536x255` RGBA, rendered as whole-image proportional `TextureRect` (no 9-slice/one-axis stretch; strict Design safe margins `Vector4(132, 62, 132, 62)`; backup in `build/qa/scrum355/hero_select_pre_scrum355_frame_assets.zip`; Back-end SCRUM-354 must integrate the new runtime margins) |
| `ui_frame_hero_select_thumbnail` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail.png` | Live Hero Select adaptive hero thumbnail button frame |
| `ui_frame_hero_select_asc_button` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button.png` | Live Hero Select ascension +/- frame |
| `ui_frame_hero_select_asc_button_small` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button_small.png` | SCRUM-356 Design-ready compact ascension +/- button frame, `256x256` RGBA, generated through OpenAI Images/`fantasydisk-asset-generator` workflow and postprocessed to alpha; use for both minus/plus signs with runtime glyph centered inside content margins `[76,74,76,76]` |
| `ui_frame_hero_select_asc_label` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_label.png` | Live Hero Select ascension level label frame |
| `ui_frame_hero_select_asc_mods` | `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_mods.png` | Live Hero Select ascension modifier line frame |
| `ui_frame_settings_tab_switcher` | `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png` | Design-ready Settings tab switcher frame; SCRUM-325, `1280x256` RGBA, content-zone rects in `docs/tasks/backend_integrate_settings_tab_switcher_frame_task.md`; Back-end runtime integration SCRUM-334 |
| `ui_btn_red_gold_standard_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_standard.png` + hover/pressed/disabled | Standard 420x104 action buttons |
| `ui_btn_red_gold_max_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_max.png` + hover/pressed/disabled | Wide 560x104 action buttons |
| `ui_btn_red_gold_main_menu_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_main_menu.png` + hover/pressed/disabled | Main menu 380x104 buttons |
| `ui_btn_red_gold_hero_confirm_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_hero_confirm.png` + hover/pressed/disabled | Hero confirm 320x104 buttons |
| `ui_btn_red_gold_reset_audio_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_reset_audio.png` + hover/pressed/disabled | Settings reset audio 420x104 buttons |
| `ui_btn_red_gold_reset_bindings_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_reset_bindings.png` + hover/pressed/disabled | Settings reset bindings 440x104 buttons |
| `ui_btn_red_gold_codex_tab_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_codex_tab.png` + hover/pressed/disabled | Historical Codex tab family; superseded in live runtime by FAN-1047 `text/main_menu_380x104` |
| `ui_btn_red_gold_back_s/m/l_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_back_s.png` / `back_m.png` / `back_l.png` + states | Navigation/back buttons by width |
| `ui_btn_red_gold_attr_selector_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_attr_selector.png` + hover/pressed/disabled | Attribute selector 560x104 buttons |
| `ui_btn_red_gold_fab_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_fab.png` + hover/pressed/disabled | Upgrade FAB 50x50 |
| `ui_btn_red_gold_utility_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_utility.png` + hover/pressed/disabled | Compact utility 54x42 |
| `ui_btn_red_gold_pause_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_pause.png` + hover/pressed/disabled | Pause menu 280x60 |
| `ui_btn_red_gold_rebind_*` | `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_rebind.png` + hover/pressed/disabled | Keybinding/dropdown-style 420x62 controls |
| `main_menu_title_fantasy_disk` | `assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` | SCRUM-680 release refresh main menu logo/title, `960x360` RGBA transparent. PixelLab textless crest source and manifest live in `docs/design/references/main_menu_logo_release_fix/`; generator `tools/build_main_menu_title_logo.py` renders exact `Fantasy Disk` text and runtime displays the asset as `MainMenuTitleLabel` at `Rect2(56,44,720,270)`. |
| `ui_df_button_primary/secondary/danger_*` | `assets/sprites/ui/frames/dark_fantasy/ui_df_button_*` | Superseded SCRUM-147 parchment/wax buttons; retained only as legacy/reference fallback |
| `ui_df_panel_frame` | `assets/sprites/ui/frames/dark_fantasy/ui_df_panel_frame.png` | Superseded SCRUM-229 panel fallback/reference |
| `ui_df_shop_frame` | `assets/sprites/ui/frames/dark_fantasy/ui_df_shop_frame.png` | Superseded merchant/shop frame fallback/reference |
| `ui_panel_leather_gold_square` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_square.png` | Superseded SCRUM-229 source square/card frame, removed from runtime assets |
| `ui_panel_leather_gold_wide` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_panel_leather_gold_wide.png` | Superseded SCRUM-229 source wide panel/frame, removed from runtime assets |
| `ui_bar_leather_gold_thin` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_bar_leather_gold_thin.png` | Superseded SCRUM-229 source bar/label/divider frame, removed from runtime assets |
| `ui_window_leather_gold_main` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_window_leather_gold_main.png` | Superseded SCRUM-229 source large window panel, removed from runtime assets |
| `ui_check_leather_gold` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/leather_gold/ui_check_leather_gold.png` | Superseded SCRUM-229 source checked state frame, removed from runtime assets |

Pipeline/preview: `tools/build_red_gold_button_kit.py` (SCRUM-273 buttons), `tools/build_ornate_ui_frame_kit.py` (SCRUM-274 panels), `tools/build_hero_select_frame_kit.py` (SCRUM-281 Hero Select frames), `tools/build_hero_select_windrose_frame.py` (SCRUM-322 radar), `tools/build_hero_select_dossier_frame.py` (SCRUM-323 dossier), `tools/build_hero_select_thin_frames.py` (SCRUM-355 dossier/carousel thinning), active previews `docs/design/previews/red_gold_button_kit_contact.png`, `docs/design/previews/ornate_dark_frame_kit_contact.png`, `docs/design/previews/hero_select_frame_kit_contact.png`, `docs/design/previews/hero_select_portrait_frame_content_zone.png`, `docs/design/previews/hero_select_windrose_radar_content_zone.png`, `docs/design/previews/hero_select_dossier_frame_content_zone.png`, `docs/design/previews/hero_select_thin_frames_content_zones.png` and `docs/design/previews/settings_tab_switcher_frame_content_zone.png`. Historical: `tools/apply_button_only_ui_revert.py` (SCRUM-147 buttons/legacy correction), `tools/build_leather_gold_ui_kit.py` (SCRUM-229 panels), `docs/design/previews/interface_leather_gold_panel_kit_contact.png`.

Системные иконки зарегистрированы в `scripts/ui_icon_registry.gd` как `system_close`, `system_back`, `system_settings`, `system_arrow_left/right/up/down`, `system_checkbox_unchecked`, `system_checkbox_checked`, `system_slider_track`, `system_slider_grabber`. Файлы лежат в `assets/sprites/ui/icons/system/`.

Contextual UI direction 2026-06-12 is superseded by SCRUM-147. SCRUM-418 confirmed no live runtime references and removed the contextual frame PNGs from `assets/sprites/ui/frames/contextual/`; historical backup lives under `build/qa/scrum418/removed_assets_backup/`. New context decisions should use the SCRUM-147 dark fantasy role system instead.

| ID | Ассет | Роль | Статус |
| --- | --- | --- | --- |
| `ui_wild_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_wild_panel_frame.png`, `ui_wild_button_frame.png`, `ui_wild_card_frame.png`, `ui_wild_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |
| `ui_grave_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_grave_panel_frame.png`, `ui_grave_button_frame.png`, `ui_grave_card_frame.png`, `ui_grave_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |
| `ui_laurel_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_laurel_panel_frame.png`, `ui_laurel_button_frame.png`, `ui_laurel_card_frame.png`, `ui_laurel_tooltip_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |
| `ui_parchment_*_frame` | `build/qa/scrum418/removed_assets_backup/assets/sprites/ui/frames/contextual/ui_parchment_panel_frame.png`, `ui_parchment_button_frame.png`, `ui_parchment_card_frame.png`, `ui_parchment_tooltip_frame.png`, `ui_parchment_tab_frame.png` | Historical context kit, superseded by SCRUM-147, removed from runtime assets | Superseded |

## UI Иконки И HUD

Централизованный mapping: `scripts/ui_icon_registry.gd`.

| Группа | ID | Каноническая папка | Статус |
| --- | --- | --- | --- |
| Базовые характеристики | `strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership` | `assets/sprites/ui/icons/stats/` | Реализовано |
| Производные параметры | `damage`, `magic_damage`, `crit_chance`, `crit_damage_multiplier`, `attack_speed`, `dodge`, `move_speed`, `defense`, `absorb`, `health_point`, `summon_amount`, `regeneration`, `vampiric_amount`, `vampiric_chance`, `dot_damage`, `dot_speed`, `aoe_radius`, `knockback_power`, `ultimate_multiplier`, `pickup_radius` | `assets/sprites/ui/icons/derived/` | Реализовано; retired range/projectile-speed/buff axes остаются только legacy assets |
| HUD ресурсы | `hp`, `xp`, `money` | `assets/sprites/ui/hud/` | Реализовано |
| Кодекс: непрочитанное | `ui_badge_codex_unread` | `assets/sprites/ui/icons/codex/ui_badge_codex_unread.png` | Реализовано (FAN-1077) |

Escape stats menu, level-up reward cards и combat HUD должны брать иконки только через этот registry. Финальный PNG asset pack реализован; code-native fallback не является целевым визуальным состоянием.

## UI Frames / Escape Stats Visual Kit

Каноническая спецификация: `docs/design/escape_stats_visual_kit.md`.

| ID | Игровое имя | Ассет | Роль | Статус |
| --- | --- | --- | --- | --- |
| `ui_escape_panel_frame` | Рамка Escape меню | `assets/sprites/ui/frames/escape/ui_escape_panel_frame.png` | Общий frame для `EscapeStatsPanelFrame` | Реализовано |
| `ui_escape_button_frame` | Рамка кнопки Escape меню | `assets/sprites/ui/frames/escape/ui_escape_button_frame.png` | Кнопки `PauseControlButtons` | Реализовано |
| `ui_stat_basic_row_frame` | Рамка базовой характеристики | `assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png` | `BaseStatRow_<stat_id>` | Реализовано |
| `ui_stat_group_frame` | Рамка группы параметров | `assets/sprites/ui/frames/escape/ui_stat_group_frame.png` | `DerivedStatGroup_<group_id>` | Реализовано |
| `ui_stat_chip_frame` | Рамка stat chip | `assets/sprites/ui/frames/escape/ui_stat_chip_frame.png` | `DerivedStatChip_<stat_id>` | Реализовано |
| `ui_stat_tooltip_frame` | Рамка tooltip характеристик | `assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png` | Tooltip с описанием/формулой/влияниями | Реализовано |
| `ui_stat_section_divider` | Разделитель stat section | `assets/sprites/ui/frames/escape/ui_stat_section_divider.png` | Опциональный разделитель групп/заголовков | Реализовано |
| `ui_stat_value_state_swatches` | Цветовые состояния статов | `assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png` | Design reference для high/low/neutral/effective | Реализовано |
| `escape_stats_visual_kit_preview` | Preview Escape stats visual kit | `assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png` | Design reference, не runtime UI | Реализовано |

## SCRUM-478 Bright Minimalist UI Source Package

This is a Design-source package, not live runtime content yet.

| Группа | ID / naming | Каноническая папка / файл | Статус |
| --- | --- | --- | --- |
| Bright minimalist button anchor | `scrum478_bright_minimal_button_anchor_sheet_transparent` | `docs/design/references/minimalist_full_ui_redesign/scrum478_bright_minimal_button_anchor_sheet_transparent.png` | Design-source review |
| Exact-size frame source | `scrum478_exact_size_frame_source_sheet_transparent` | `docs/design/references/minimalist_full_ui_redesign/scrum478_exact_size_frame_source_sheet_transparent.png` | Design-source review |
| Full-screen mockup board | `scrum478_full_screen_mockup_board` | `docs/design/references/minimalist_full_ui_redesign/scrum478_full_screen_mockup_board.png` | Design-source review |
| Exact-size metadata | `scrum478_minimalist_full_ui_metadata` | `docs/design/references/minimalist_full_ui_redesign/scrum478_minimalist_full_ui_metadata.json` | Source of truth for 1280/1600/1920 content zones |
| UI-director spec | `scrum478_minimalist_full_ui_spec` | `docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md` | Design-source review |

Runtime asset IDs/paths must be assigned by the Back-end handoff after slicing
or importing final exact-size PNGs. Until then, existing live UI registries stay
authoritative for runtime.

## SCRUM-666 Combat HUD 2K Source Package

This is a Design-source package for a future clean combat HUD integration, not
live runtime content yet.

| Group | ID / naming | Canonical folder / file | Status |
| --- | --- | --- | --- |
| Combat HUD 2K spec | `scrum666_combat_hud_2k_spec` | `docs/design/mockups/scrum666_combat_hud_2k/spec.md` | Design-source review |
| Combat HUD 2K plan | `scrum666_combat_hud_2k_ui_plan` | `docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json` | Authoritative QA-red revised geometry: content zones inside generated dark interiors |
| Combat HUD 2K layout | `scrum666_combat_hud_2k_layout` | `docs/design/mockups/scrum666_combat_hud_2k/layout.json` | Authoritative content zones; level plus/count zones separated |
| Combat HUD 2K visual audit | `scrum666_combat_hud_2k_visual_frame_zone_audit` | `docs/design/mockups/scrum666_combat_hud_2k/visual_frame_zone_audit.md` | Human QA-red note for clean interior placement |
| Combat HUD 2K OpenAI mockup | `scrum666_combat_hud_2k_mockup_base` | `docs/design/references/scrum666_combat_hud_2k/combat_hud_2k_mockup_base.png` | Visual source only |
| Combat HUD 2K safe-zone previews | `scrum666_combat_hud_2k_previews` | `docs/design/previews/scrum666_combat_hud_2k_*` | QA evidence; accepted overlay demonstrates zones avoid rails/ornament |

Runtime asset IDs/paths must be assigned by a Back-end integration task after
slot-exact slicing or redraw. Until then, existing live combat HUD registries
remain authoritative.

## Иконки Артефактов, Shop UI И Курсор

Каноническая спецификация и полный mapping `artifact_id -> icon_path`, `shop_item_id -> icon_path`: `docs/design/artifact_shop_cursor_visual_kit.md`.

| Группа | ID / naming | Каноническая папка / файл | Статус |
| --- | --- | --- | --- |
| Artifact icons | `artifact_<artifact_id>.png` для всех `ProgressionData.ARTIFACTS`; 71 шт., 256x256 RGBA, transparent realistic epic D&D/tabletop fantasy raster magic items; QA preview `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`, SCRUM-606/609 contact `docs/design/previews/artifact_icons_606_609_contact.png` | `assets/sprites/ui/icons/artifacts/` | Реализовано (realistic D&D raster redraw 2026-06-12; SCRUM-606/609 icon integration 2026-06-28; `rift_key` documented SCRUM-844) |
| Shop-only item icons | `shop_<shop_item_id>.png` для всех `ProgressionData.SHOP_ITEMS` | `assets/sprites/ui/icons/shop/` | Реализовано |
| Shop slot normal | `ui_shop_artifact_slot_frame` | `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png` | Реализовано |
| Shop slot hover | `ui_shop_artifact_slot_hover` | `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png` | Реализовано |
| Shop price badge | `ui_shop_price_badge` | `assets/sprites/ui/shop/ui_shop_price_badge.png` | Реализовано |
| Shop purchased/unavailable overlay | `ui_shop_purchased_overlay` | `assets/sprites/ui/shop/ui_shop_purchased_overlay.png` | Реализовано |
| Shop tooltip frame | `ui_shop_tooltip_frame` | `assets/sprites/ui/shop/ui_shop_tooltip_frame.png` | Реализовано |
| Game cursor | `ui_game_cursor` | `assets/sprites/ui/cursor/game_cursor.png`, hotspot `(2, 2)` | Реализовано (SCRUM-223 dragon claw fire cursor) |
| Game cursor hover | `ui_game_cursor_hover` | `assets/sprites/ui/cursor/game_cursor_hover.png`, hotspot `(2, 2)` | Реализовано (SCRUM-223 dragon claw fire cursor) |
| Game cursor attack | `ui_game_cursor_attack` | `assets/sprites/ui/cursor/game_cursor_attack.png`, hotspot `(2, 2)` | Реализовано (SCRUM-223 dragon claw fire cursor) |

Shop-only icons имеют прозрачный фон, размер `128x128`, stylized fantasy cartoon style и не используют текст/emoji/default placeholders. Artifact icons находятся в realistic D&D raster redraw pass 2026-06-12: каждый активный артефакт — отдельная законченная painted magic item-картинка без фона, пьедестала, текста и мусора, с технической проверкой размера, alpha, bbox и 40px-читаемости. Shop item filenames намеренно следуют схеме `shop_<shop_item_id>.png`, поэтому для `shop_damage` путь выглядит как `assets/sprites/ui/icons/shop/shop_shop_damage.png`. Фактические PNG и `.import` файлы готовы в текущем checkout; backend hooks могут подхватывать эти файлы вместо fallback.

## SCRUM-810 Input Glyphs (Gamepad + Keyboard) — 0.2.0

Пиксель-арт глифы ввода для UI-подсказок пакета полной поддержки геймпада
(подсказки «какая кнопка за что», ребинд в настройках, контекстные хинты).

**Метод генерации:** программная (PIL, `scratchpad/gen_glyphs.py` — не в репо),
НЕ PixelLab MCP. Обоснование: глифы ввода — геометрические UI-примитивы с
точными буквами/стрелками (A/B/X/Y, ESC, WASD, направления), а канон PixelLab —
«no text» (нечитаемый текст на 64px, запекаемый фон — частый QA-FAIL). PIL даёт
гарантированно прозрачный фон (углы alpha=0), читаемые на 32px буквы, единый
стиль и не грузит перегруженный Godot-флот / PixelLab-биллинг. Стиль кита выдержан:
тёмная кожаная основа + светлый латунный контур; лицевые кнопки — узнаваемая
generic Xbox-раскладка (A зелёная / B красная / X синяя / Y жёлтая).

**Размеры:** два нативных — `32×32` и `64×64` (каждый растеризован под свой
масштаб, не даунскейл). `size` в аксессорах реестра выбирает ближайший.

**Пути:** `assets/sprites/ui/input_glyphs/<name>_<32|64>.png` (+ парный `.import`).

**Реестр:** `scripts/ui/input_glyph_registry.gd` — `ALL_GLYPHS`, словари
`JOY_BUTTON_TO_GLYPH` / `JOY_AXIS_TO_GLYPH` / `KEY_TO_GLYPH`; API (все null-safe):
`path_for`, `has_glyph`, `texture_for`, `texture_for_joy_button(idx,size)`,
`texture_for_axis(axis,size)`, `texture_for_key(name,size)`. Экраны НЕ трогает —
интеграцию делают UI-задачи пакета.

**Гейт:** `tests/input_glyph_assets_test.gd` (существование ресурсов, загрузка
текстур, размер PNG, прозрачность углов, покрытие JOY_BUTTON/JOY_AXIS/клавиш,
null-safety). Контакт-лист QA: `build/qa/scrum810/glyphs_contact_sheet.png`.

| Группа | Глифы (name) | Маппинг |
| --- | --- | --- |
| Лицевые | `btn_a` `btn_b` `btn_x` `btn_y` | JOY_BUTTON_A/B/X/Y |
| D-pad | `dpad` `dpad_up` `dpad_down` `dpad_left` `dpad_right` | JOY_BUTTON_DPAD_UP..RIGHT (11-14) |
| Плечи/курки | `lb` `rb` `lt` `rt` | LEFT/RIGHT_SHOULDER; JOY_AXIS_TRIGGER_LEFT/RIGHT |
| Меню | `start` `select` | JOY_BUTTON_START / JOY_BUTTON_BACK |
| Стики | `stick_l` `stick_r` `stick_l_press` `stick_r_press` `stick_move` | LEFT/RIGHT_STICK (нажатие); оси LEFT_*→stick_move, RIGHT_*→stick_r |
| Клавиатура | `key_generic` `key_esc` `key_enter` `key_space` `key_wasd` `key_arrows` | KEY_TO_GLYPH |

`docs/design/systems/input_controls.md` на момент SCRUM-810 не создан (core-задача
пакета); при его появлении сослаться на этот блок и реестр.
