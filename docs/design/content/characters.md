<!-- content-registry-section -->

# FantasyDisk Content Registry — Персонажи И Ростер

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## Персонажи

<!-- canonical-ids: class -->

| ID | Игровое имя | Роль | Источник | Ассет | Статус |
| --- | --- | --- | --- | --- | --- |
| `berserk` | Берсерк | Ближний бой, физический урон, конусы и AoE | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/berserk_spriteframes.tres`, `assets/sprites/characters/full_frame/berserk_pixellab/`, `assets/sprites/characters/pixellab/berserk/`, legacy `assets/sprites/characters/full_frame/berserk/`, `assets/sprites/characters/cutout/berserk_*.png` | Реализовано; SCRUM-703 live runtime uses a new unarmed PixelLab v3 8-direction pack (`8486ce45-f749-4c63-9a6d-f0477d619c2d`) with 6f move/walk rows, directional idle fallbacks, and normalized `245 px` alpha-bbox height on `512x512` frames; legacy art remains fallback/history |
| `soldier` | Солдат | Тактический физический класс: залпы, гранаты и удержание линии | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/soldier_spriteframes.tres`, `assets/sprites/characters/full_frame/soldier_pixellab/`, `assets/sprites/characters/pixellab/soldier/`, legacy `assets/sprites/characters/soldier.png`, `assets/sprites/characters/cutout/soldier_*.png` | Реализовано; SCRUM-434 live runtime uses PixelLab character `72b487d3-feea-4012-b39f-b59ba24f7f11` with 8-direction idle rotations and 6-frame directional move/walk rows, normalized to 245 px visible height on `512x512` runtime frames; legacy art remains fallback/history |
| `thief` | Вор | Уловки, рикошет монет, backstab и дымовое уклонение | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/thief_spriteframes.tres`, `assets/sprites/characters/full_frame/thief_pixellab/`, `assets/sprites/characters/pixellab/thief/`, legacy `assets/sprites/characters/full_frame/thief/`, `assets/sprites/characters/thief.png`, `assets/sprites/characters/thief_sheet.png`, `assets/sprites/characters/cutout/thief_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/thief/` | Реализовано; SCRUM-800 live runtime uses PixelLab character `02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f` with 8-direction idle rotations and 6-frame directional move/walk rows; SCRUM-435 v2 assets remain fallback/history |
| `elementalist` | Элементалист | Стихийный AoE-контроль: орбиты, призмы и метеорные осколки | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/elementalist_spriteframes.tres`, `assets/sprites/characters/full_frame/elementalist_pixellab/`, `assets/sprites/characters/pixellab/elementalist/`, legacy `assets/sprites/characters/full_frame/elementalist/`, `assets/sprites/characters/elementalist.png`, `assets/sprites/characters/elementalist_sheet.png`, `assets/sprites/characters/cutout/elementalist_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/elementalist/` | Реализовано; FAN-3868 live runtime uses new PixelLab character `0644c584-d0bf-4b3d-94e0-0371da886ed7` with 8 idle rotations, 6-frame directional move/walk rows, 512×512 normalization, 246px visible height, blue unarmed cloak silhouette and no baked green glow; prior `7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`/`4b01496c-09c9-4cc8-8913-a9feee4e3a69` packs remain history only; SCRUM-427 v2 assets remain fallback/history |
| `sniper` | Снайпер | Дальний точный класс: lockshot, kill-zone и split rounds | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd` | `assets/sprites/characters/sniper_spriteframes.tres`, `assets/sprites/characters/full_frame/sniper_pixellab/`, `assets/sprites/characters/pixellab/sniper/`, legacy `assets/sprites/characters/full_frame/sniper/`, `assets/sprites/characters/sniper.png`, `assets/sprites/characters/sniper_sheet.png`, `assets/sprites/characters/cutout/sniper_*.png`, v2 source handoff `assets/sprites/characters/v2/sniper/sniper_v2_idle_source.png` | Реализовано; SCRUM-433 live runtime uses PixelLab character `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c` with 8-direction idle rotations and 6-frame directional move/walk rows, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-296 full-frame art remains fallback/history |
| `priest` | Священник | Священный sustain: sanctify, ward-пульсы и молитвенная цепь | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/priest_spriteframes.tres`, `assets/sprites/characters/full_frame/priest_pixellab/`, `assets/sprites/characters/pixellab/priest/`, legacy `assets/sprites/characters/full_frame/priest/`, `assets/sprites/characters/priest.png`, `assets/sprites/characters/cutout/priest_*.png`, v2 source handoff `assets/sprites/characters/v2/priest/priest_v2_idle_source.png` | Реализовано; SCRUM-431 live Hero Select/runtime SpriteFrames use PixelLab v3 8-direction static rotations + 6-frame directional walk (`walking-6-frames`); legacy full-frame art remains history/fallback |
| `biologist` | Биолог | Биореакции: spore bloom, sample analysis и symbiote web | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/biologist_spriteframes.tres`, `assets/sprites/characters/full_frame/biologist_pixellab/`, `assets/sprites/characters/pixellab/biologist/`, legacy `assets/sprites/characters/full_frame/biologist/`, `assets/sprites/characters/biologist.png`, `assets/sprites/characters/biologist_sheet.png`, `assets/sprites/characters/cutout/biologist_*.png`, v2 source handoff `assets/sprites/characters/v2/biologist/biologist_v2_idle_source.png` | Реализовано; SCRUM-421 live Hero Select/runtime SpriteFrames use PixelLab source `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4` with 8 idle directions and 6-frame directional `move`/`walk`, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-284 full-frame art remains history/fallback |
| `robot` | Робот | Тяжелый tank-control: magnetic anchor, compression line и reactor vent | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/robot_spriteframes.tres`, `assets/sprites/characters/full_frame/robot_pixellab/`, `assets/sprites/characters/pixellab/robot/`, legacy `assets/sprites/characters/robot.png`, `assets/sprites/characters/cutout/robot_*.png` | Реализовано; SCRUM-802 live runtime uses PixelLab character `37c6ccf2-ab40-4c89-83a3-db8365f85257` with 8-direction idle rotations and 6-frame directional move/walk rows, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-432/v2 scope remains history/fallback |
| `engineer` | Инженер | Механический summoner/support: sentry link, repair drone и pressure mines | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd`, `scripts/cutout_rig_2d.gd`, `scripts/sliced_rig_manifest.gd` | `assets/sprites/characters/engineer_spriteframes.tres`, `assets/sprites/characters/full_frame/engineer_pixellab/`, `assets/sprites/characters/pixellab/engineer/`, legacy `assets/sprites/characters/full_frame/engineer/`, `assets/sprites/characters/engineer.png`, `assets/sprites/characters/cutout/engineer_*.png` | Реализовано; SCRUM-428 live runtime uses PixelLab character `c5bd9766-e7de-4316-ace6-e687c951e621` with 8-direction idle rotations and 6-frame directional move/walk rows; legacy art remains fallback/history |
| `dark_mage` | Темный маг | Магический урон, AoE, DoT, лучи | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/dark_mage_spriteframes.tres`, `assets/sprites/characters/full_frame/dark_mage_pixellab/`, `assets/sprites/characters/pixellab/dark_mage/`, legacy `assets/sprites/characters/full_frame/dark_mage/`, `assets/sprites/characters/dark_mage.png`, `assets/sprites/characters/dark_mage_sheet.png`, `assets/sprites/characters/cartoon2/dark_mage/dark_mage_cartoon2_anim_sheet.png`, `assets/sprites/characters/cutout/dark_mage_*.png`, v2 source/runtime assets under `assets/sprites/characters/v2/dark_mage/`, skeleton-source package `docs/design/references/chars_cartoon/skeleton_parts/dark_mage/skeleton_source_manifest.json` | Реализовано; SCRUM-704 live Hero Select/runtime SpriteFrames use a new PixelLab v3 8-direction 240-250px full redraw with 6-frame directional move/walk rows and empty hands; legacy SCRUM-473 cartoon2 and skeleton assets remain history/fallback |
| `guitarist` | Гитарист | Звуковые волны, импульсы, ауры, отталкивание | `scripts/progression_data.gd` | `assets/sprites/characters/guitarist_spriteframes.tres`, `assets/sprites/characters/full_frame/guitarist_pixellab/`, `assets/sprites/characters/pixellab/guitarist/`, legacy `assets/sprites/characters/full_frame/guitarist/`, `assets/sprites/characters/guitarist.png`, `assets/sprites/characters/guitarist_sheet.png`, `assets/sprites/characters/cutout/guitarist_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/guitarist/` | Реализовано; SCRUM-797 live Hero Select/runtime SpriteFrames use PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d` with a held-guitar silhouette by direct user override, 8 idle directions and 6-frame directional `move`/`walk`, normalized to 245 px visible height on `512x512` runtime frames; legacy SCRUM-706 empty-hands pack and SCRUM-429 v2 full-frame assets remain history/fallback |
| `assassin` | Ассасин | Возвращающиеся чакрамы, крит-мили, яд и рывки к цели на критах | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd` | `assets/sprites/characters/assassin_spriteframes.tres`, `assets/sprites/characters/full_frame/assassin_pixellab/`, `assets/sprites/characters/pixellab/assassin/`, legacy `assets/sprites/characters/full_frame/assassin/`, `assets/sprites/characters/assassin.png`, `assets/sprites/characters/assassin_sheet.png`, `assets/sprites/characters/cutout/assassin_*.png`, v2 runtime/source assets under `assets/sprites/characters/v2/assassin/` | Реализовано; SCRUM-803 live runtime uses PixelLab character `ec73da27-b704-4336-9275-74c8e3e578df` with empty open hands, 8-direction idle rotations and 6-frame directional move/walk rows normalized to 245 px visible height on `512x512` runtime frames; SCRUM-419 v2 art remains fallback/history |
| `ranger` | Рейнджер | Дальний контроль через заряжаемые стойкой выстрелы, арбалет, ловушки | `scripts/progression_data.gd`, `scripts/class_weapon.gd`, `scripts/player.gd` | `assets/sprites/characters/ranger_spriteframes.tres`, `assets/sprites/characters/full_frame/ranger_pixellab/`, `assets/sprites/characters/pixellab/ranger/`, legacy `assets/sprites/characters/full_frame/ranger/`, `assets/sprites/characters/ranger.png`, `assets/sprites/characters/ranger_sheet.png`, `assets/sprites/characters/cutout/ranger_*.png` | Реализовано; SCRUM-804 live runtime uses PixelLab character `1646d83c-f570-4bdd-9065-cb1b46bf13f7` with empty hands, 8-direction idle rotations and 6-frame directional move/walk rows normalized to 245 px visible height on `512x512` frames; legacy SCRUM-294 art remains fallback/history |
| `doctor` | Доктор | Выживание через drain/lifesteal-связи, чума и ближний sustain | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/doctor_spriteframes.tres`, `assets/sprites/characters/full_frame/doctor_pixellab/`, `assets/sprites/characters/pixellab/doctor/`, legacy `assets/sprites/characters/full_frame/doctor/`, `assets/sprites/characters/doctor.png`, `assets/sprites/characters/cutout/doctor_*.png` | Реализовано; SCRUM-705 live Hero Select/runtime SpriteFrames use fresh PixelLab v3 full redraw (`3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`) with 8-direction idle + 6-frame directional move/walk, normalized to 244 px visible height in `512x512`; empty hands, no baked potion/syringe/saw; legacy full-frame art and SCRUM-425 pack remain history/fallback |
| `chemist` | Химик | Газовые/кислотные DoT-зоны и combo explosions от разных облаков | `scripts/progression_data.gd`, `scripts/class_weapon.gd` | `assets/sprites/characters/chemist_spriteframes.tres`, `assets/sprites/characters/full_frame/chemist_pixellab/`, `assets/sprites/characters/pixellab/chemist/`, legacy `assets/sprites/characters/chemist.png`, `assets/sprites/characters/cutout/chemist_*.png` | Реализовано; SCRUM-423 live Hero Select/runtime SpriteFrames use PixelLab v3 8-direction static rotations + 6-frame directional walk (`walking-6-frames`); legacy art remains fallback/history |
| `knight` | Рыцарь | Танк и тяжелый контроль: копье/щит плюс block/counter | `scripts/progression_data.gd`, `scripts/player.gd` | `assets/sprites/characters/knight_spriteframes.tres`, `assets/sprites/characters/full_frame/knight_pixellab/`, `assets/sprites/characters/pixellab/knight/`, legacy `assets/sprites/characters/full_frame/knight/`, `assets/sprites/characters/knight.png`, `assets/sprites/characters/cartoon2/knight/knight_cartoon2_anim_sheet.png`, `assets/sprites/characters/cutout/knight_*.png`, skeleton-source package `docs/design/references/chars_cartoon/skeleton_parts/knight/skeleton_source_manifest.json` | Реализовано; SCRUM-885 refreshed the SCRUM-430 PixelLab no-shield character `c1a7d633-7353-4861-aea3-8d937b601cba` on 2026-07-08 with 8-direction idle rotations plus 6-frame directional walk/move rows; legacy SCRUM-473 cartoon2 frames remain history/fallback; SCRUM-475 skeleton-source parts package delivered for Animator rig work; SCRUM-919 routes the combat runtime (`scripts/player.gd`) through the accepted PixelLab `knight_spriteframes.tres` full-frame path — the legacy runtime skeletal rig (`scenes/characters/KnightSkeletonRig.tscn` + `assets/sprites/characters/skeleton_parts/knight/`) is detached from combat and kept as history/fallback |
| `druid` | Друид | Командуемые питомцы, природные зоны, тотемы; scaling от Лидерства | `scripts/progression_data.gd`, `scripts/summoner_weapon.gd`, `scripts/ally_minion.gd` | `assets/sprites/characters/druid_spriteframes.tres`, `assets/sprites/characters/full_frame/druid_pixellab/`, `assets/sprites/characters/pixellab/druid/`, legacy `assets/sprites/characters/full_frame/druid/`, `assets/sprites/characters/druid.png`, `assets/sprites/characters/cutout/druid_*.png` | Реализовано; live runtime uses PixelLab 8-direction idle rotations and 6-frame move/walk rows; legacy art remains fallback/history |

SCRUM-416 runtime portrait rule: for most playable classes,
`scripts/progression_data_characters.gd` uses the accepted cleaned full-frame
idle frame as the canonical static UI portrait path:
`assets/sprites/characters/full_frame/<class>/<class>_idle_00.png`. PixelLab
directional classes (`assassin`, `berserk`, `biologist`, `dark_mage`,
`guitarist`, `doctor`, `chemist`, `engineer`, `knight`, `priest`, `druid`,
`elementalist`, `ranger`, `robot`, `sniper`, `soldier`, `thief`) use
`assets/sprites/characters/full_frame/<class>_pixellab/<class>_idle_south.png`
instead.
Hero Select, hero thumbnails, Codex and level-up portrait surfaces read this
single `sprite_path`; legacy `assets/sprites/characters/<class>.png` files remain
historical/fallback asset references and are not the live static portrait source.
Regression coverage: `tests/character_sprite_registry_alignment_test.gd` and
`tests/runtime_smoke_test.gd`; QA dumps under `build/qa/scrum416/`.

FAN-1071 adds one roster-wide runtime placement contract without changing these
canonical IDs or asset paths: every playable SpriteFrames idle/move/walk texture
is grounded from its own visible alpha bottom onto the `Player` gameplay origin.
Legacy `sliced_rig_manifest.foot_y` is now fallback-only for cutout/skeletal
visuals and must not be treated as the footline of a PixelLab runtime pack.
Focused coverage: `tests/feet_anchor_ground_circle_test.gd` iterates all 17
classes, all directional locomotion rows and every frame.

SCRUM-869 refreshes the playable PixelLab source/runtime packs from the live
PixelLab manifests without changing canonical character IDs or portrait paths.
The refreshed complete packs are `assassin`
(`ec73da27-b704-4336-9275-74c8e3e578df`), `biologist`
(`cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`), `chemist`
(`c7fe44d3-1f15-45a1-b762-b2862833b151`), `dark_mage`
(`9bb0eca8-5afe-49d4-8e56-7115a45efdcc`), `druid`
(`4078113b-fece-4087-a035-9ed3714a6514`), `guitarist`
(`d278e753-9885-4550-82ff-81ee3bef297d`), `knight`
(`c1a7d633-7353-4861-aea3-8d937b601cba`), `priest`
(`ed7db59e-0845-4218-b178-a56f948254b5`), `ranger`
(`1646d83c-f570-4bdd-9065-cb1b46bf13f7`), `robot`
(`37c6ccf2-ab40-4c89-83a3-db8365f85257`) and `thief`
(`02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f`). `berserk`, `soldier`,
`elementalist`, `sniper`, `engineer` and `doctor` remain on their existing live
runtime packs because the SCRUM-869 PixelLab audit found incomplete/404 source
packages; exact blockers are recorded in
`build/qa/pixellab_character_animation_refresh/report.json` and the task mirror.

SCRUM-423 promotes Chemist to the PixelLab directional runtime contract:
PixelLab character `c7fe44d3-1f15-45a1-b762-b2862833b151` provides 8 static
idle rotations and `walking-6-frames` movement rows for all directions. Source
PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/chemist/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/chemist_pixellab/`, and
`assets/sprites/characters/chemist_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract.

SCRUM-428 promotes Engineer to the same PixelLab directional runtime contract:
PixelLab character `c5bd9766-e7de-4316-ace6-e687c951e621` provides 8 static
idle rotations and `walking-6-frames` movement rows for all directions. Source
PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/engineer/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/engineer_pixellab/`, and
`assets/sprites/characters/engineer_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract.

SCRUM-433 promotes Sniper to the same PixelLab directional runtime contract:
PixelLab character `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c` provides 8 static
idle rotations and `walking-6-frames` movement rows for all directions. Source
PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/sniper/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/sniper_pixellab/`, and
`assets/sprites/characters/sniper_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract.

SCRUM-803 promotes Assassin to the same PixelLab directional runtime contract:
PixelLab character `ec73da27-b704-4336-9275-74c8e3e578df` provides empty-handed
8-direction idle rotations and `walking-6-frames` movement rows for all
directions. Source PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/assassin/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/assassin_pixellab/`, and
`assets/sprites/characters/assassin_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract. PixelLab
candidate `cdee7e9a-1d04-430e-8fc9-60fafc2cd4a8` was rejected/deleted before
import because it baked a held blade into the body art.

SCRUM-804 promotes Ranger to the same PixelLab directional runtime contract:
PixelLab character `1646d83c-f570-4bdd-9065-cb1b46bf13f7` provides empty-handed
8-direction idle rotations and `walking-6-frames` movement rows for all
directions. Source PNGs, manifest and PixelLab evidence live under
`assets/sprites/characters/pixellab/ranger/`; normalized runtime frames live
under `assets/sprites/characters/full_frame/ranger_pixellab/`, and
`assets/sprites/characters/ranger_spriteframes.tres` exposes generic
idle/move/walk fallbacks plus `idle_<direction>`, `move_<direction>` and
`walk_<direction>` rows for the 8-direction runtime/preview contract. Bow,
crossbow, trap and projectile visuals remain separate weapon-owned assets.

SCRUM-422 adds the first 0.1.6 character redraw v2 Design source anchor. The
accepted exemplar for the future per-class v2 rows is Berserk, using a bright,
epic, class-readable unarmed style and transparent RGBA source under
`docs/design/references/characters_v2/bright_epic_anchor/`; the asset-side
accepted source copy is
`assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`. This does not
replace live runtime portraits or combat SpriteFrames yet; it defines the
source-art, size, pivot and handoff contract for the 16 blocked v2 character
tasks.

SCRUM-456 replaces the future character-restyle direction with a cartoon/anime
source anchor after the broad v2 approach was cancelled. The package is
Design-source only and does not replace live portraits or combat SpriteFrames:
style sheet `docs/design/references/chars_cartoon/character_cartoon_anime_style_sheet.md`,
Berserk handoff
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_design_handoff.md`,
transparent source/cell
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_clean.png`
and `docs/design/references/chars_cartoon/berserk_cartoon_anchor_idle_cell_512.png`,
safe-gutter source sheet
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`,
and QA report
`build/qa/scrum456_chars_cartoon/scrum456_chars_cartoon_alpha_motion_report.json`.
The contract covers all active registry classes with strongly different
silhouette/palette/identity directions, `512x512` cells, pivot `(256,470)`,
`idle` + `walk/move` only, and no attack row. Animator handoff is tracked in
`docs/tasks/animation_chars_cartoon_anime_berserk_anchor_task.md`; SCRUM-456 QA
PASSED on 2026-06-17, so SCRUM-461 may consume the accepted source.

SCRUM-420 adds the first per-class v2 Design-source handoff for `berserk` under
`docs/design/references/characters_v2/berserk/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout and QA report. Asset-side handoff copies live in
`assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png` and
`assets/sprites/characters/v2/berserk/berserk_v2_sheet_source_handoff.png`.
Animator integration now replaces the live Berserk full-frame runtime resource
with v2 `idle` / `walk` / `move` loops in
`assets/sprites/characters/berserk_spriteframes.tres` and per-frame PNGs under
`assets/sprites/characters/full_frame/berserk/`. The derived safe sheet is
`assets/sprites/characters/v2/berserk/berserk_v2_anim_sheet.png`; previous live
frames are backed up under `docs/design/backups/scrum420_berserk_v2_pre_anim/`.
Attack animation remains absent by SCRUM-420 scope.

SCRUM-531 adds a new dark-fantasy / D&D dragon Berserk v2 Design-source pack
under `docs/design/references/berserk_v2/` (note: a different folder from the
SCRUM-420 `characters_v2/berserk/`): raw `gpt-image-2` source, alpha-clean RGBA
source, normalized `512x512` idle cell (pivot `256,470`, visible height
`408 px`), `2848x1168` idle/walk×5 placeholder source-sheet handoff (48px
gutters, attack row excluded), and an alpha/size/pivot QA report under
`build/qa/scrum531_berserk_v2/`. Asset-side candidate exports live under
`assets/sprites/characters/berserk_v2/`; Animator handoff is
`docs/design/references/berserk_v2/berserk_v2_design_handoff.md`. The new look is
a brutal painterly dragonslayer (dragon-skull pauldron, horns, scale armor, fur
cloak, oxblood/charcoal palette), intentionally distinct from the live
cartoon-anchor; hands are empty with no weapon baked. This is Design-source only
and is NOT the live runtime — the live Berserk still renders the SCRUM-461
cartoon-anchor SpriteFrames. Animation is the follow-up Animator ticket
SCRUM-532.

SCRUM-461 replaces the live Berserk full-frame runtime resource with the
accepted SCRUM-456 cartoon/anime anchor: `assets/sprites/characters/berserk_spriteframes.tres`
now exposes `idle` (5f, 7fps), `walk` (5f, 9fps), and `move` (walk alias, 5f,
9fps) only. Runtime PNGs remain under
`assets/sprites/characters/full_frame/berserk/`, sliced from
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
with `512x512` cells, `48 px` gutters, transparent RGBA and pivot `(256,470)`.
Previous live Berserk frames are backed up under
`docs/design/backups/scrum461_berserk_cartoon_pre_anim/`. Attack animation
remains absent by SCRUM-461 scope.

SCRUM-473 replaces the Dark Mage/Knight temporary cartoon-trial legacy rig with
live cartoon2 full-frame SpriteFrames. `assets/sprites/characters/dark_mage_spriteframes.tres`
and `assets/sprites/characters/knight_spriteframes.tres` now expose 5-frame
looping `idle`, `walk`, and `move` only, with runtime PNGs under
`assets/sprites/characters/full_frame/dark_mage/` and
`assets/sprites/characters/full_frame/knight/`. Safe-gutter sheets live under
`assets/sprites/characters/cartoon2/{dark_mage,knight}/`; QA artifacts live
under `build/qa/scrum473_cartoon2_dark_mage_knight_anim/`. Attack animation
remains absent by SCRUM-473 scope because weapon visuals own attacks.

SCRUM-430 replaces the live Knight SpriteFrames/portrait source with PixelLab.
Source downloads live under `assets/sprites/characters/pixellab/knight/`,
normalized 512x512 runtime frames under
`assets/sprites/characters/full_frame/knight_pixellab/`, and
`assets/sprites/characters/knight_spriteframes.tres` exposes one-frame
`idle_<direction>` rows plus 6-frame `move_<direction>` / `walk_<direction>` rows
for all 8 directions. The accepted PixelLab pass is explicitly no-shield/no-weapon;
Knight weapons and shield visuals remain separate weapon assets. SCRUM-885
refreshed that same PixelLab character on 2026-07-08, updating the source
manifest, alpha-bbox report and normalized runtime frames while keeping the
canonical SpriteFrames path unchanged. SCRUM-919 (2026-07-09) detaches the
legacy skeletal combat rig from `scripts/player.gd`: Knight combat now renders
the same accepted PixelLab `knight_spriteframes.tres` directional idle/move
loops as Hero Select, while `scenes/characters/KnightSkeletonRig.tscn` and the
`skeleton_parts/knight/` package stay in the repo as history/emergency fallback.

SCRUM-475 adds Design-source skeleton packages for Dark Mage and Knight under
`docs/design/references/chars_cartoon/skeleton_parts/`. Each character has a
transparent accepted source copy, 19 separated PNG parts, documented local
pivots, a `skeleton_source_manifest.json`, alpha report, contact sheet and
dark-background source preview. Both manifests pass
`validate_skeleton_source_manifest.py`. These packages are Animator handoff
sources only; no runtime rig, SpriteFrames or gameplay wiring changed.

SCRUM-424 adds the Dark Mage v2 Design-source handoff under
`docs/design/references/characters_v2/dark_mage/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, handoff note and QA report. Asset-side handoff copies live
in `assets/sprites/characters/v2/dark_mage/dark_mage_v2_idle_source.png` and
`assets/sprites/characters/v2/dark_mage/dark_mage_v2_sheet_source_handoff.png`.
Animator integration now replaces the live Dark Mage full-frame runtime resource
with v2 `idle` / `walk` / `move` loops in
`assets/sprites/characters/dark_mage_spriteframes.tres` and per-frame PNGs under
`assets/sprites/characters/full_frame/dark_mage/`. The derived safe sheet is
`assets/sprites/characters/v2/dark_mage/dark_mage_v2_anim_sheet.png`; previous
live frames are backed up under `docs/design/backups/scrum424_dark_mage_v2_pre_anim/`.

SCRUM-419 adds the per-class v2 Design-source handoff for `assassin` under
`docs/design/references/characters_v2/assassin/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, handoff note and QA report. Animator integration now
replaces the live Assassin full-frame runtime resource with v2 `idle` / `walk`
/ `move` loops in `assets/sprites/characters/assassin_spriteframes.tres` and
per-frame PNGs under `assets/sprites/characters/full_frame/assassin/`. The
derived safe sheet is
`assets/sprites/characters/v2/assassin/assassin_v2_anim_sheet.png`; previous
live frames are backed up under
`docs/design/backups/scrum419_assassin_v2_pre_anim/`. Attack animation remains
absent by SCRUM-419 scope; animation/runtime smokes PASS.

SCRUM-429 adds the Guitarist v2 Design-source handoff under
`docs/design/references/characters_v2/guitarist/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Animator integration now replaces the live Guitarist full-frame runtime resource
with v2 `idle` / `walk` / `move` loops in
`assets/sprites/characters/guitarist_spriteframes.tres` and per-frame PNGs under
`assets/sprites/characters/full_frame/guitarist/`. The derived safe sheet is
`assets/sprites/characters/v2/guitarist/guitarist_v2_anim_sheet.png`; previous
live frames are backed up under
`docs/design/backups/scrum429_guitarist_v2_pre_anim/`. Attack animation remains
absent by SCRUM-429 scope; animation/runtime smokes PASS.

SCRUM-706 first replaced the live Guitarist PixelLab static placeholder with an
empty-hands production pack. SCRUM-797 then applies a direct user override:
PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d` is now the live
Guitarist body because its held-guitar silhouette reads stronger and cooler in
Hero Select/combat. Live source rotations and six-frame movement are stored
under `assets/sprites/characters/pixellab/guitarist/`, normalized runtime frames
under `assets/sprites/characters/full_frame/guitarist_pixellab/` keep every
visible alpha bbox at `245 px` height, and
`assets/sprites/characters/guitarist_spriteframes.tres` exposes `idle`, `move`,
`walk`, plus directional `idle/move/walk_<direction>` rows for all eight
directions. The previous SCRUM-706 empty-hands pack is backed up under
`docs/design/backups/scrum797_guitarist_instrument_pack_pre_swap/`.

SCRUM-435 adds the Thief v2 Design-source handoff under
`docs/design/references/characters_v2/thief/` and promotes the accepted source
into live `assets/sprites/characters/thief_spriteframes.tres` with v2 `idle` /
`walk` / `move` loops, 5 frames each, no attack by scope. Runtime frames live
under `assets/sprites/characters/full_frame/thief/`, the derived safe sheet is
`assets/sprites/characters/v2/thief/thief_v2_anim_sheet.png`, previous live
frames are backed up under `docs/design/backups/scrum435_thief_v2_pre_anim/`,
and QA artifacts live under `build/qa/scrum435_thief_v2_anim/`; animation and
runtime smokes PASS.

SCRUM-427 adds the Elementalist v2 Design-source handoff under
`docs/design/references/characters_v2/elementalist/` and promotes the accepted
source into live `assets/sprites/characters/elementalist_spriteframes.tres` with
v2 `idle` / `walk` / `move` loops, 5 frames each, no attack by scope. Runtime
frames live under `assets/sprites/characters/full_frame/elementalist/`, the
derived safe sheet is
`assets/sprites/characters/v2/elementalist/elementalist_v2_anim_sheet.png`,
previous live frames are backed up under
`docs/design/backups/scrum427_elementalist_v2_pre_anim/`, and QA artifacts live
under `build/qa/scrum427_elementalist_v2_anim/`; animation and runtime smokes
PASS.

Historical Sniper v2 Design-source handoff: SCRUM-433 originally added
`docs/design/references/characters_v2/sniper/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Asset-side handoff copies live in
`assets/sprites/characters/v2/sniper/sniper_v2_idle_source.png`,
`assets/sprites/characters/v2/sniper/sniper_v2_sheet_source_handoff.png` and
`assets/sprites/characters/v2/sniper/sniper_v2_sheet.png`. These source-handoff
assets are historical now; live Sniper runtime/portrait uses the PixelLab
directional pack under `assets/sprites/characters/full_frame/sniper_pixellab/`.

SCRUM-431 adds the Priest v2 Design-source handoff under
`docs/design/references/characters_v2/priest/`: raw OpenAI source, alpha-clean
source, normalized `512x512` idle cell, `2560x1024` placeholder source-sheet
layout, accepted source sheet copy, handoff note and QA report. Asset-side
handoff copies live in
`assets/sprites/characters/v2/priest/priest_v2_idle_source.png`,
`assets/sprites/characters/v2/priest/priest_v2_sheet_source_handoff.png` and
`assets/sprites/characters/v2/priest/priest_v2_sheet.png`. These are source
handoff assets only; they do not replace current runtime Priest cutout/full-frame
assets until Animator/Back-end integration is accepted.

SCRUM-421 adds the Biologist v2 Design-source handoff under
`docs/design/references/characters_v2/biologist/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Asset-side handoff copies live in
`assets/sprites/characters/v2/biologist/biologist_v2_idle_source.png`,
`assets/sprites/characters/v2/biologist/biologist_v2_sheet_source_handoff.png`
and `assets/sprites/characters/v2/biologist/biologist_v2_sheet.png`. These
older v2 handoff assets remain source history. SCRUM-421 later finished the live
PixelLab runtime pack from character `cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`
under `assets/sprites/characters/pixellab/biologist/` and
`assets/sprites/characters/full_frame/biologist_pixellab/`, with a regenerated
front-facing south movement row and all 56 runtime frames normalized to `245 px`
visible alpha height.

SCRUM-432 adds the Robot v2 Design-source handoff under
`docs/design/references/characters_v2/robot/`: raw OpenAI source,
alpha-clean source, normalized `512x512` idle cell, `2560x1024` placeholder
source-sheet layout, accepted source sheet copy, handoff note and QA report.
Asset-side handoff copies live in
`assets/sprites/characters/v2/robot/robot_v2_idle_source.png` and
`assets/sprites/characters/v2/robot/robot_v2_sheet_source_handoff.png`. The
source is a bright/epic polished mechanical guardian with cyan/blue sensors and
empty hands, no baked weapon/tool/held object, visible height `376 px`, pivot
`[256,470]`, no edge-visible or floodable neutral/checker pixels after cleanup.
These are source handoff assets only; they do not replace current runtime Robot
assets until Animator/Back-end integration is accepted.

## Расширенный Ростер 0.1.4 (Фундамент, 2026-06-11)

Спрайты всех шести прошли Design art-review (2026-06-11) и приняты как polished dark fantasy full-art (512x512, RGBA). Cutout rig-части нарезаны `tools/slice_rig_cutouts.py` и лежат в `assets/sprites/characters/cutout/` (torso, arm_l, arm_r, leg_l, leg_r для каждого). Манифест обновлён в `scripts/sliced_rig_manifest.gd`. Weapon art v2 pass 2026-06-12 устранил fallback-текстуры в сценах оружия, перерисовал три оружия Рыцаря и заменил `knight.png` на unarmed base sprite без встроенного копья/щита, чтобы все три варианта реально крепились через socket.

| ID | Имя | Архетип | 3 стартовых оружия | «Свой» урон |
| --- | --- | --- | --- | --- |
| `assassin` | Ассасин | Быстрый крит-мили | `chakrams`, `shadow_daggers`, `venom_wire` | damage |
| `ranger` | Рейнджер | Дальний точный | `moon_crossbow`, `storm_longbow`, `hunter_trap` | damage |
| `doctor` | Доктор | Выживание через урон | `restore_potion`, `plague_syringe`, `bone_saw` | magic_damage |
| `chemist` | Химик | AoE + DoT зоны | `blast_powder`, `acid_flask`, `homunculus_vial` | magic_damage |
| `knight` | Рыцарь | Танк/копье | `long_spear`, `tower_shield`, `holy_flail` | damage |
| `druid` | Друид | Призыватель | `summon_amulet`, `briar_staff`, `raven_totem` | magic_damage |

Релевантность атрибутов расширена: strength -> berserk/assassin/ranger/knight; intelligence -> dark_mage/doctor/chemist; energy -> dark_mage/guitarist/doctor/chemist/druid. Вознесение: по 10 уровней на каждый новый класс (ID `<класс>_asc_1..10`, тематические имена в ASCENSION_LEVELS).

Канонические character PNG для новых классов: `assets/sprites/characters/assassin.png`, `ranger.png`, `doctor.png`, `chemist.png`, `knight.png`, `druid.png` (`512x512`, transparent). Канонические weapon PNG для новых 18 вариантов: `chakrams.png`, `shadow_daggers.png`, `venom_wire.png`, `moon_crossbow.png`, `storm_longbow.png`, `hunter_trap.png`, `restore_potion.png`, `plague_syringe.png`, `bone_saw.png`, `blast_powder.png`, `acid_flask.png`, `homunculus_vial.png`, `long_spear.png`, `tower_shield.png`, `holy_flail.png`, `summon_amulet.png`, `briar_staff.png`, `raven_totem.png` (`256x256`, transparent). Первые 9 weapon PNG для Berserk/Dark Mage/Guitarist остаются активными по существующим путям.
