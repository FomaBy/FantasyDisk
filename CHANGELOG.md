# Changelog — FantasyDisk

Формат: [Keep a Changelog](https://keepachangelog.com/), версии: [SemVer](https://semver.org/) (0.MINOR.PATCH до релиза 1.0).

## [Unreleased] — ветка dev

### Added
- SCRUM-705: PixelLab Doctor full redraw at the new 240-250 px runtime scale.
  Generated a fresh PixelLab plague-doctor source character
  (`3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`), replaced the live source pack under
  `assets/sprites/characters/pixellab/doctor/`, normalized all idle and
  6-frame move/walk directions into transparent `512x512` runtime frames under
  `assets/sprites/characters/full_frame/doctor_pixellab/`, and kept empty hands
  so potion/syringe/saw remain weapon-owned visuals. The committed alpha-bbox
  QA report confirms all 56 runtime frames at 244 px visible height.
- SCRUM-779: PixelLab-first boss roster redraw source package and two new boss
  concepts. OpenAI image generation produced reference-only concept art for
  `skeletal_dragon` and `bloodthorn_lion`; PixelLab MCP produced transparent
  sprite candidates for current bosses, the secret ascension boss and the two
  new IDs under `assets/sprites/bosses/pixellab_candidates/`, with manifest and
  QA notes in
  `docs/design/references/bosses/pixellab_roster_redraw_2026_06/`. No live boss
  scenes, balance or route rotation changed in this design-source pass.
- SCRUM-694: Settings v3 full redraw — Designer pipeline package (inventory →
  geometry → OpenAI mockups → PixelLab final 9-slice family). Live Settings
  inventory + responsive `layout.json` (fit gate `ready_for_image`, geometry
  validated against the 2K runtime constants at 1280×720/1920×1080/2560×1440/
  3840×2160). Three textless OpenAI reference mockups
  (`docs/design/mockups/settings_v3_full_redraw/`, reference only). Five PixelLab
  final 9-slice production frames under `assets/sprites/ui/frames/settings_v3/`
  (main modal frame with dragon crest + red-gem corners, tab switcher, content
  panel, inset field/dropdown, action button) — native-size sources, transparent,
  textless, alpha-clean. Manifest + Back-end integration handoff with exact paths,
  rects, texture margins, node IDs and tests
  (`docs/design/references/settings_v3_full_redraw/`). Runtime wiring of the new
  frames is a tracked Back-end follow-up per the handoff; this drop is the design
  asset/spec package, no `ui_screens.gd` behaviour change.
- SCRUM-431: PixelLab Priest 8-direction character with directional movement.
  Generated v3 PixelLab holy Priest character
  (`ed7db59e-0845-4218-b178-a56f948254b5`), stored source rotations + walk frames
  under `assets/sprites/characters/pixellab/priest/`, normalized transparent
  `512x512` runtime frames under
  `assets/sprites/characters/full_frame/priest_pixellab/`, and rebuilt
  `priest_spriteframes.tres` with `idle_<direction>` plus 6-frame looping
  `move_<direction>` / `walk_<direction>` for all 8 directions. Priest now moves
  with directional walk in-game and rotates clockwise in Hero Select.
- SCRUM-703: PixelLab Berserk full redraw at the readable 240-250 px runtime
  scale. Generated new unarmed v3 PixelLab character
  (`8486ce45-f749-4c63-9a6d-f0477d619c2d`), stored `252x252` source rotations
  and 8-direction movement under `assets/sprites/characters/pixellab/berserk/`,
  normalized transparent `512x512` runtime frames under
  `assets/sprites/characters/full_frame/berserk_pixellab/` with every idle/move
  alpha bbox at `245 px` high, and rebuilt `berserk_spriteframes.tres` with
  `idle_<direction>` plus 6-frame looping `move_<direction>` / `walk_<direction>`
  for all 8 directions. The old live pack is backed up under
  `docs/design/backups/scrum703_berserk_pixellab_pre_redraw_2026-06-30/`.
- SCRUM-425: PixelLab Doctor 8-direction character with directional movement.
  Generated v3 PixelLab plague-doctor character
  (`c3d5ea3d-3b70-4154-b3c4-420d386f550a`), stored source rotations + walk frames
  under `assets/sprites/characters/pixellab/doctor/`, normalized transparent
  `512x512` runtime frames under
  `assets/sprites/characters/full_frame/doctor_pixellab/`, and rebuilt
  `doctor_spriteframes.tres` with `idle_<direction>` plus 6-frame looping
  `move_<direction>` / `walk_<direction>` for all 8 directions. Doctor now moves
  with directional walk in-game and rotates clockwise in Hero Select.
- PixelLab Guitarist static 8-direction character rotations: pulled existing
  PixelLab character `d327e6c2-a3fb-44b3-b02a-965a0ce52e7b`, stored source
  rotations under `assets/sprites/characters/pixellab/guitarist/`, normalized
  runtime frames under `assets/sprites/characters/full_frame/guitarist_pixellab/`,
  and rebuilt `guitarist_spriteframes.tres` with one-frame directional
  idle/move/walk rows so Hero Select rotates the Guitarist portrait clockwise
  at Berserk-scale height.
- SCRUM-704: PixelLab Dark Mage full redraw at readable 240-250px scale.
  Generated new v3 PixelLab character
  (`9bb0eca8-5afe-49d4-8e56-7115a45efdcc`), stored 8-direction idle source and
  `walking-6-frames` source under `assets/sprites/characters/pixellab/dark_mage/`,
  normalized transparent `512x512` runtime frames under
  `assets/sprites/characters/full_frame/dark_mage_pixellab/`, and rebuilt
  `dark_mage_spriteframes.tres` with `idle_<direction>` plus 6-frame looping
  `move_<direction>` / `walk_<direction>` for all 8 directions. Dark Mage hands
  stay empty; book/skull/wand/orb remain separate weapon assets.

### Changed
- SCRUM-695: rebuilt level-up attribute relevance as a direct attribute×class
  matrix instead of routing 24 combat attributes through 8 base stats. Added a
  canonical attribute registry (single source of truth: id/name/icon/value-type)
  in `progression_data_characters.gd`, and an `ATTRIBUTE_RELEVANCE` matrix with a
  hard per-attribute invariant of exactly 2 primary / 8 secondary / 7 optional
  classes (validated by `tests/attribute_relevance_test.gd`). Level-up reward
  weighting now reads relevance directly (primary > secondary >> optional). The
  3-option level-up offer enforces a relevance rule: at most 1 attribute that is
  `optional` for the current class, and always at least 1 primary/secondary (no
  all-optional offers); the rare main-stat slot and the «Озарение» capstone are
  unchanged. Reworded the previously abstract reward descriptions/titles
  («+0.18 силы поддержки», «+4 flat absorption», English titles) into clear
  Russian numeric units, consistent with the glossary; on-card before→after
  numbers continue to show the concrete effect for the current build.

### Fixed
- SCRUM-693: in active combat, Escape now opens the character board / pause
  dossier immediately with the left run controls, pauses gameplay, and resumes
  via Resume or repeated Escape without showing the old standalone pause menu.

## [0.1.7] — 2026-06-29

### Release Highlights
- FantasyDisk 0.1.7: крупный визуальный шаг вперёд — новый pixel-art Codex,
  более читаемый Level Up с предпросмотром эффектов, эпичный логотип в главном
  меню, аккуратный боевой HUD, обновлённые 2K-экраны и первые 8-направленные
  PixelLab-анимации Берсерка.
- Главное: Level Up теперь объясняет, что именно изменится у выбранного
  улучшения, Codex стал похож на тёмно-фэнтезийный справочник, а экран выбора
  героя оживляет Берсерка направленной анимацией.
- Сборка дополнительно очищена от документации, референсов, тестов, build- и
  release-папок через export filters; релизные файлы остаются только с нужными
  runtime-ресурсами.

### Added
- PixelLab Berserk runtime integration: `berserk_spriteframes.tres` now uses
  8-direction pixel-art movement from the PixelLab `Berserk` character (6-frame
  looping walk/move rows per direction), player movement selects the matching
  row by velocity, and Hero Select v4 animates the Berserk portrait clockwise
  through those directional rows.
- Berserk v2 dark-fantasy dragon Design source pack (SCRUM-531): generated a new
  brutal painterly D&D dragonslayer berserker source via `gpt-image-2`,
  alpha-cleaned it to true RGBA, normalized a `512x512` cell (pivot `256,470`,
  visible height `408 px`), assembled the idle/walk×5 source-sheet handoff
  (`2848x1168`, 48px gutters, attack row excluded), dark-bg + game-scale contact
  previews and an alpha/size/pivot QA report. Source under
  `docs/design/references/berserk_v2/`, candidate exports under
  `assets/sprites/characters/berserk_v2/`, with `berserk_v2_design_handoff.md`
  for the Animator (SCRUM-532). Visually distinct from the current
  cartoon-anchor; empty fists, no weapon baked in. No runtime, balance or
  animation logic changed.
- Combat feedback layer (SCRUM-497): enemy hits now show short-lived floating
  damage numbers, red hit outline/flash, distinct critical `!` markers and
  green player healing numbers, with a persisted Settings toggle and active
  label/effect caps for dense AoE.
- UI render verifier gate (SCRUM-483): expanded `tests/ui_no_overlap_matrix_test.gd`
  to cover 1920x1080, 2560x1440 and 3840x2160 headless screen passes, text
  allocation overflow, parent content containment, peer-control overlap and
  exact UI frame TextureRect no-stretch checks. The test writes dedicated QA
  evidence to `build/qa/scrum483_ui_render_verifier/ui_render_verifier_matrix.md`
  and remains part of the standalone focused smoke set. The new gate also
  tightened Level Up reward-card spacing/font sizing so wrapped reward
  descriptions fit the existing layout.
- Bright minimalist full-game UI Design anchor (SCRUM-478): generated the
  OpenAI source package under
  `docs/design/references/minimalist_full_ui_redesign/`, alpha-cleaned the
  button/frame source sheets into transparent PNGs, added a full-screen mockup
  board, exact 1280x720 / 1600x900 / 1920x1080 size matrix, self-QA evidence
  and the UI-director spec at
  `docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md`. Runtime
  integration and render/no-overlap verification are handed off to Back-end.
- Skeleton-source Design handoff for Dark Mage/Knight (SCRUM-475): added
  transparent separated source packages under
  `docs/design/references/chars_cartoon/skeleton_parts/{dark_mage,knight}/`
  with accepted source copies, 19 PNG parts per character, local pivots,
  manifests, alpha reports, contact sheets and dark-bg previews. Both
  `skeleton_source_manifest.json` files pass the animation-director validator;
  this is a Design-source handoff only. SCRUM-474 remains on USER HOLD for
  runtime rig/timeline work until an explicit newer go-ahead says
  `делай анимацию`.
- Cartoon2 Dark Mage/Knight animations (SCRUM-473): live
  `dark_mage_spriteframes.tres` and `knight_spriteframes.tres` now use real
  full-frame `idle` / `walk` / `move` loops from the accepted cartoon2 sprites,
  with no body attack rows because weapon visuals own attacks. Runtime frames
  live under `assets/sprites/characters/full_frame/{dark_mage,knight}/`,
  safe-gutter sheets under `assets/sprites/characters/cartoon2/`, and QA
  contact/GIF/manifest artifacts under
  `build/qa/scrum473_cartoon2_dark_mage_knight_anim/`. The temporary
  `CARTOON_TRIAL_CLASSES` legacy rig path is now empty; animation smoke passes.
- Final UI design review evidence (SCRUM-458): added the
  `tests/design_review_screenshot_capture_test.gd` harness and captured 23 UI
  states at 1280x720, 1920x1080 and 2560x1440 under
  `build/qa/design_review/`. The review filed follow-up defects SCRUM-464 for
  the opaque economy-screen matte, SCRUM-465 for Level Up viewport overflow and
  SCRUM-466 for minimal-metal frame seams crossing content; no runtime UI fixes
  were made in the review pass.
- Class damage table audit (SCRUM-453): added deterministic
  `tools/class_damage_table_3variants.gd` plus
  `tests/class_damage_table_3variants_test.gd` to generate the 17-class /
  51-weapon DPS table for 1, 5 and 20 targets across base lvl1, lvl20 optimum
  and lvl20 random-average builds. Evidence is written to
  `docs/design/reports/class_damage_table_3variants.md` and
  `build/qa/scrum453/class_damage_table_3variants.csv`; no live balance values
  were changed.
- Cartoon/anime character restyle anchor (SCRUM-456): generated the
  `fantasydisk-asset-generator` Berserk exemplar source, corrected the baked
  checkerboard output into transparent RGBA, created the
  `docs/design/references/chars_cartoon/` style-sheet/handoff package with
  strong per-class silhouette/palette directions, normalized a `512x512`
  Berserk source cell and safe-gutter `idle`/`walk` source-sheet handoff, and
  recorded contact/dark-bg/GIF/alpha QA under
  `build/qa/scrum456_chars_cartoon/`. Animator handoff is created but gated
  until source acceptance; attack remains out of scope.
- Minimal-metal button Design-source kit (SCRUM-450): generated an OpenAI
  source sheet under `docs/design/references/ui_minimal_metal_buttons/`, built
  15 button types x 5 states as transparent RGBA candidates under
  `assets/sprites/ui/frames/minimal_metal_buttons/`, added exact
  texture/content margins in
  `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`,
  plus style/spec docs and contact/safe-zone previews. All 75 production PNGs
  audit at `white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`;
  runtime rollout is handed off to Back-end.
- Minimal-metal UI anchor Design-source package (SCRUM-452): generated OpenAI
  minimal-metal style/source boards under
  `docs/design/references/ui_minimal_metal/`, produced a six-piece transparent
  RGBA frame candidate kit under `assets/sprites/ui/frames/minimal_metal/`,
  documented exact texture/content margins in
  `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`,
  added UI-director spec/style docs and contact/safe-zone previews. All six
  production PNGs audit at `white_opaque_pixels=0`,
  `pale_visible_pixels_after_cleanup=0`; runtime integration is handed off to
  Back-end.
- Minimal-metal frame rollout Design-source package (SCRUM-451): mapped menu,
  settings, hero select, codex, shop, rewards, level-up, events, pause, results,
  combat HUD, tooltips and dialogs to the six SCRUM-452 frame families, recorded
  exact screen-family metadata in
  `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`,
  added the UI-director rollout spec and contact preview, and created the
  Back-end integration handoff. Runtime wiring, old-kit backup/no-live-ref audit,
  screenshots and Godot UI smokes remain Back-end scope.
- Minimalist UI restyle Design-source package (SCRUM-448): generated an OpenAI
  project-wide UI style-board plus a six-piece transparent minimal frame kit
  under `assets/sprites/ui/frames/minimal/`, with exact texture/content margins
  in `docs/design/references/ui_minimal/scrum448_minimal_ui_frame_metadata.json`
  and `docs/design/mockups/scrum448_ui_minimalist/spec.md`. The package keeps
  SCRUM-273 Red & Gold buttons unchanged and audits all minimal frame PNGs at
  `white_opaque_pixels=0`, `pale_visible_pixels_after_cleanup=0`.
- Hero Select v3 Design-source package (SCRUM-446): generated a from-scratch
  OpenAI mockup for the hero select screen, extracted raw Vision zones and
  corrected them into non-overlapping source-of-truth `zones.json` /
  `zones_normalized.json`, generated transparent production frame assets under
  `assets/sprites/ui/frames/hero_select_v3/`, added `frames_spec.json` with
  texture/content margins and a UI-director spec package under
  `docs/design/references/hero_select_v3/` plus `docs/design/mockups/hero_select_v3/`.
  All transparent v3 frame assets audit at `white_opaque_pixels=0`; runtime
  rebuild is handed off to Back-end.
- Hero Select v3 runtime integration (SCRUM-447): `_show_character_select()`
  now uses the accepted SCRUM-446 1536x864 zones, v3 background and
  `assets/sprites/ui/frames/hero_select_v3/` production frames. The live screen
  preserves hero selection, ascension controls, Select/Back/Escape/focus
  behavior and the existing `HeroStatRadar`, keeps radar square, and writes QA
  screenshot/rect evidence under `build/qa/scrum446_hero_select_v3/`; runtime UI
  smoke, UI no-overlap matrix and full runtime smoke pass.

### Changed
- Berserk hammer live DPS cap (SCRUM-503): reduced only the hammer upgrade
  runaway by changing `upgrade_aoe_exponent` from `1.8` to `1.25` and
  `upgrade_damage_exponent` from `1.45` to `1.15`. Base lvl1 hammer stays
  unchanged, while regenerated `build/character_balance_dps.csv` now reports
  `berserk/hammer` lvl20 optimum at 2925.81 DPS on 1 target and 61199.86 DPS
  on 20 targets, down from ~7636 / ~184k. The current class-best 20-target
  median gate is 74785.73, with max 68574.57.
- Random event EV rebalance (SCRUM-494 / carry-over SCRUM-476): свёл каждую
  опцию каждого из 12 событий `scripts/event_data.gd` к явной таблице
  risk/cost → reward с EV (см. «Random Events EV» в
  `docs/design/systems/progression_balance.md`). Рискованные/платные опции
  теперь дают заметно более ценный апсайд (статы, артефакты, run-long моды),
  безопасные — скромную гарантию. Ключевые правки: `full_rest` больше не даёт
  бесплатно полный хил + Выносливость (убрана Выносливость, штраф следующему
  бою 1.20→1.25); `defile`/`duel` (elite) получили честные `post_combat`-награды
  и работающие денежные множители; `goblin_lottery`/`well`-исходы выровнены
  (дешевле вход, «хлам» 3→8 зол, провалы дают консолацию); проверочные опции
  получили мелкие добивки. Денежные множители event-боёв теперь применяются и
  к elite-ветке (`combat_director._grant_combat_completion_rewards`) — раньше
  они молча игнорировались, делая тултипы defile/duel неправдой. Экономика
  сверена против `stage_scaled_cost`/`COST_BY_TIER`/`DROP_CLASS_MULTIPLIERS`;
  `event_data_smoke_test.gd`, runtime/economy и балансные смоуки зелёные.
  Восстановлен фактический штраф `full_rest` (1.10→1.25) в `event_data.gd` после
  regression и согласован EV-инвариант SCRUM-508: чисто-штрафная ветка без боевой
  добычи (`hot_spring/full_rest`) больше не классифицируется как «рисковая» в
  `tools/route_economy_xp_model.gd` — это безопасный хил с побочкой, а не выбор
  «риск ради апсайда», поэтому safe-only событие `hot_spring` исключено из
  инварианта risk>=safe (16 событий-пар, все зелёные).
- Settings and Attribute Shop short-viewport fit (SCRUM-471): fixed the
  1152x648 no-overlap matrix failures by allowing the Settings v2 content panel
  to compress only on short modals and using compact Attribute Shop offer/action
  metrics below 660px viewport height. UI no-overlap matrix, runtime UI smoke
  and full runtime smoke pass; evidence lives under `build/qa/scrum471/`.
- Class lvl20 optimum balance normalization (SCRUM-469): added class/stat
  growth scalars that apply only to above-base stat points before derived
  parameter formulas. The SCRUM-453 report and CSV were regenerated; all
  17 classes now keep `Lvl20 optimum` `relative_score` inside `0.938..1.097`
  while `Base lvl1` stays inside `0.982..1.010`, preserving each class'
  three-weapon kit identities.
- Level Up viewport fit (SCRUM-465): the reward-choice overlay now uses
  responsive panel/card/header metrics and a compact `Позже` action height on
  short 720p layouts, so all three choices and the defer control remain inside
  the viewport at 1280x720, 1920x1080 and 2560x1440. The UI no-overlap matrix
  now includes Level Up nodes and QA evidence lives under `build/qa/scrum465/`.
- Minimal-metal frame rollout runtime integration (SCRUM-463): promoted the
  SCRUM-452 `assets/sprites/ui/frames/minimal_metal/` six-frame kit as the
  active generic runtime surface set for menus, Settings, Codex, economy choice
  cards/price badges/tooltips, rewards, pause/results and compact combat HUD
  wrappers, while preserving Hero Select v3 authored frames, progression nodes
  and combat bar fills/icons. QA/no-live-ref evidence lives under
  `build/qa/scrum451_minimal_metal_rollout/`; dark theme, runtime UI,
  no-overlap and full runtime smokes pass.
- Minimal-metal button runtime integration (SCRUM-462): promoted the SCRUM-450
  `assets/sprites/ui/frames/minimal_metal_buttons/` kit for live action-button
  families across menu/UI helpers, including main menu, back, pause, Codex tab,
  reset, rebind, utility/FAB and attribute selector states. Red & Gold PNGs are
  backed up under `build/qa/scrum450_minimal_metal_buttons/red_gold_button_backup/`;
  metadata/theme guards and QA dumps live under
  `build/qa/scrum450_minimal_metal_buttons/`. Card/hit-area exceptions and the
  SCRUM-390 combat plus button remain unchanged; dark theme, runtime UI,
  no-overlap and full runtime smokes pass.
- Minimal-metal frame runtime anchor (SCRUM-459): added the SCRUM-452
  `assets/sprites/ui/frames/minimal_metal/` six-frame kit as first-class
  runtime paths/constants plus a reusable tiled `StyleBoxTexture` helper backed
  by metadata texture/content margins. The kit remains a selectable candidate
  for the later rollout; SCRUM-273 Red & Gold buttons and current SCRUM-448 live
  generic frames are unchanged. Added metadata guard coverage and QA evidence
  under `build/qa/scrum452_minimal_metal/`.
- Attack VFX calmness pass (SCRUM-457): shared `AttackVfx` helpers now
  desaturate/dim additive colors, cap flash alpha, narrow beam visuals, reduce
  trail frequency and cut dust/note clutter so weapon attacks read without
  flooding the screen. Damage radii, hit queries, cooldowns and targeting are
  unchanged. `tests/attack_vfx_smoke_test.gd` now asserts the calmer alpha/beam/
  note contract and writes `build/qa/scrum457/attack_vfx_calmness_dump.md`.
- Weapon orbit visibility (SCRUM-455): player `WeaponSocket` now sits on a
  104px orbit around the hero and rotates toward the active aim/attack
  direction instead of staying on the body/hand center. Equipped weapon roots
  and `WeaponVisual` layers are normalized behind the hero body so held weapons
  do not cover playable character sprites; damage, timing and targeting
  mechanics are unchanged. Added focused gate `tests/weapon_orbit_smoke_test.gd`
  and QA dump `build/qa/scrum455/weapon_orbit_runtime_dump.md`.
- SCRUM-449 wires the SCRUM-448 minimalist frame kit into live non-button UI
  surfaces: generic panels/cards, Settings shell/switcher/content panel, Codex
  shell/list/detail/tooltip, economy choice cards/price badges, reward cards,
  pause/result shells and compact combat HUD wrappers now use
  `assets/sprites/ui/frames/minimal/` where safe. SCRUM-273 Red & Gold buttons,
  Hero Select v3 authored frames, progression circular nodes, combat bar fills
  and other screen-specific authored controls remain unchanged. QA evidence lives
  in `build/qa/scrum448_ui_minimalist/`; runtime UI smoke, UI no-overlap matrix
  and full runtime smoke pass.
- Berserk v3 single-sprite candidate (SCRUM-442): generated a slightly
  cartoonish unarmed 3/4-right Berserk source, cleaned the checker/white matte
  to strict transparent RGBA with no white/neutral/pale pockets, normalized a
  `512x512` game candidate at `assets/sprites/characters/berserk_v3_sprite.png`,
  corrected the generator-source filename so `berserk_v3_source_raw.png` is
  also transparent RGBA instead of opaque RGB, backed up the old
  `berserk_unarmed.png`, and added contact/dark-bg previews plus alpha/pose QA
  under `build/qa/scrum442_berserk_v3/`; animations and runtime wiring remain
  follow-up scope.
- Robot v2 Design-source handoff (SCRUM-432): generated the bright+epic
  unarmed Robot source, removed the baked checker/white matte with strict
  edge-connected cleanup plus connected-component fringe removal, normalized a
  `512x512` source cell with pivot `[256,470]`, and added source-sheet handoff,
  accepted source sheet copy, contact preview and QA report under
  `docs/design/references/characters_v2/robot/` and
  `build/qa/scrum432_robot_v2/`; Animator/runtime wiring remains follow-up.
- Biologist v2 Design-source handoff (SCRUM-421): generated the bright+epic
  unarmed Biologist source, removed the baked checker/white matte with strict
  edge-connected cleanup plus bioluminescent neutral clamp, normalized a
  `512x512` source cell with pivot `[256,470]`, and added source-sheet handoff,
  accepted source sheet copy, contact preview and QA report under
  `docs/design/references/characters_v2/biologist/` and
  `build/qa/scrum421_biologist_v2/`; Animator/runtime wiring remains follow-up.
- Priest v2 Design-source handoff (SCRUM-431): generated the bright+epic
  unarmed Priest source, removed the baked checker/white matte with strict
  edge-connected cleanup plus warm white clamp, normalized a `512x512` source
  cell with pivot `[256,470]`, and added source-sheet handoff, accepted source
  sheet copy, contact preview and QA report under
  `docs/design/references/characters_v2/priest/` and
  `build/qa/scrum431_priest_v2/`; Animator/runtime wiring remains follow-up.
- Sniper v2 Design-source handoff (SCRUM-433): generated the bright+epic
  unarmed Sniper source, alpha-cleaned the checker matte with global white/
  neutral cleanup plus edge-alpha fix, normalized a `512x512` source cell with
  pivot `[256,470]`, and added source-sheet handoff, accepted source sheet copy,
  contact preview and QA report under `docs/design/references/characters_v2/sniper/`
  and `build/qa/scrum433_sniper_v2/`; Animator/runtime wiring remains follow-up.
- Elementalist v2 Design-source + Animator integration (SCRUM-427): generated
  the bright+epic unarmed Elementalist source, alpha-cleaned the checker matte
  with global white/neutral cleanup, normalized a `512x512` source cell with
  pivot `[256,470]`, and promoted the accepted source into live v2 `idle` /
  `walk` / `move` SpriteFrames at
  `assets/sprites/characters/elementalist_spriteframes.tres`. The pass derives
  5-frame loops, writes runtime PNGs under
  `assets/sprites/characters/full_frame/elementalist/`, backs up previous live
  frames under `docs/design/backups/scrum427_elementalist_v2_pre_anim/`, and
  adds contact/GIF/manifest QA artifacts under
  `build/qa/scrum427_elementalist_v2_anim/`. Attack frames remain intentionally
  absent for this v2 row; animation and runtime smoke pass.
- Thief v2 Design-source + Animator integration (SCRUM-435): generated the
  bright+epic unarmed Thief source, alpha-cleaned the checker matte with global
  white/neutral cleanup, normalized a `512x512` source cell with pivot
  `[256,470]`, and promoted the accepted source into live v2 `idle` / `walk` /
  `move` SpriteFrames at `assets/sprites/characters/thief_spriteframes.tres`.
  The pass derives 5-frame loops, writes runtime PNGs under
  `assets/sprites/characters/full_frame/thief/`, backs up previous live frames
  under `docs/design/backups/scrum435_thief_v2_pre_anim/`, and adds contact/GIF/
  manifest QA artifacts under `build/qa/scrum435_thief_v2_anim/`. Attack frames
  remain intentionally absent for this v2 row; animation and runtime smoke pass.
- Assassin v2 Design-source + Animator integration (SCRUM-419): generated the
  bright+epic unarmed Assassin source, alpha-cleaned the checker matte,
  normalized a `512x512` source cell with pivot `[256,470]`, and promoted the
  accepted source into live v2 `idle` / `walk` / `move` SpriteFrames at
  `assets/sprites/characters/assassin_spriteframes.tres`. The pass derives
  5-frame loops, writes runtime PNGs under
  `assets/sprites/characters/full_frame/assassin/`, backs up previous live
  frames under `docs/design/backups/scrum419_assassin_v2_pre_anim/`, and adds
  contact/GIF/manifest QA artifacts under `build/qa/scrum419_assassin_v2_anim/`.
  Attack frames remain intentionally absent for this v2 row; animation and
  runtime smoke pass.
- Guitarist v2 Design-source + Animator integration (SCRUM-429): generated the
  bright+epic unarmed Guitarist source, alpha-cleaned the checker matte,
  normalized a `512x512` source cell with pivot `[256,470]`, and promoted the
  accepted source into live v2 `idle` / `walk` / `move` SpriteFrames at
  `assets/sprites/characters/guitarist_spriteframes.tres`. The pass derives
  5-frame loops, writes runtime PNGs under
  `assets/sprites/characters/full_frame/guitarist/`, backs up previous live
  frames under `docs/design/backups/scrum429_guitarist_v2_pre_anim/`, and adds
  contact/GIF/manifest QA artifacts under `build/qa/scrum429_guitarist_v2_anim/`.
  Attack frames remain intentionally absent for this v2 row; animation and
  runtime smoke pass.
- Dark Mage v2 Design-source handoff (SCRUM-424): generated the bright+epic
  unarmed Dark Mage source, alpha-cleaned the checker matte, normalized a
  `512x512` source cell with pivot `[256,470]`, and added source-sheet handoff,
  contact preview and QA report under `docs/design/references/characters_v2/dark_mage/`
  and `build/qa/scrum424_dark_mage_v2/`. Animator integration now routes live
  Dark Mage through v2 `idle` / `walk` / `move` SpriteFrames at
  `assets/sprites/characters/dark_mage_spriteframes.tres`, derived 5-frame loops
  from the accepted source, backed up the previous live frames under
  `docs/design/backups/scrum424_dark_mage_v2_pre_anim/`, and added contact/GIF/
  manifest QA artifacts under `build/qa/scrum424_dark_mage_v2_anim/`. Attack
  frames remain intentionally absent for this v2 row; animation smoke passes,
  while full runtime smoke is currently blocked by an unrelated
  `scripts/ui_screens.gd` parse failure in the active UI/settings lane.
- Berserk v2 Design-source handoff (SCRUM-420): generated the bright+epic
  unarmed Berserk source, alpha-cleaned the checker matte, normalized a
  `512x512` source cell with pivot `[256,470]`, and added source-sheet handoff,
  contact preview and QA report under `docs/design/references/characters_v2/berserk/`
  and `build/qa/scrum420_berserk_v2/`. Animator integration now routes live
  Berserk through v2 `idle` / `walk` / `move` SpriteFrames at
  `assets/sprites/characters/berserk_spriteframes.tres`, derived 5-frame loops
  from the accepted source, backed up the previous live frames under
  `docs/design/backups/scrum420_berserk_v2_pre_anim/`, and added contact/GIF/
  manifest QA artifacts under `build/qa/scrum420_berserk_v2_anim/`. Attack
  frames remain intentionally absent for this v2 row; animation and runtime
  smoke pass.
- Settings v2 rebuild mockup/spec (SCRUM-439): added the OpenAI-generated
  all-tabs Settings redesign package with transparent frame candidates, exact
  safe zones, responsive rules for 1280x720 / 1920x1080 / 2560x1440, and Back-
  end handoff notes under `docs/design/mockups/scrum439_settings_v2/`; runtime
  wiring remains follow-up.
- Hero Select v2 rebuild mockup/spec (SCRUM-436): added the OpenAI-generated
  Hero Select redesign package with preserved live compass/radar contract,
  exact safe zones, responsive rules for 1280x720 / 1920x1080 / 2560x1440, and
  Back-end handoff notes under `docs/design/mockups/scrum436_hero_select_v2/`;
  runtime wiring remains follow-up.
- Codex v2 rebuild mockup/spec (SCRUM-438): added the OpenAI-generated full
  Codex window redesign package with exact safe zones, responsive rules for
  1280x720 / 1920x1080 / 2560x1440, and Back-end handoff notes under
  `docs/design/mockups/scrum438_codex_v2/`; runtime wiring remains follow-up.
- Character redraw v2 anchor (SCRUM-422): established the 0.1.6 bright+epic
  playable-character source style/spec with transparent Berserk exemplar,
  `512x512` cells, bottom-center pivot, idle/move-only handoff and 2x-monster
  visual size target. Source, preview and QA artifacts live under
  `docs/design/references/characters_v2/bright_epic_anchor/` and
  `build/qa/scrum422_character_v2_anchor/`.

### Fixed
- Hero Select v4 runtime smoke blocker (SCRUM-479): runtime/UI smoke tests now
  target the native v4 node contract (`HS4BackButton`, `HS4Portrait`,
  `HS4Radar`, `HS4Carousel`, `HS4ChooseButton`) instead of stale v3/mockup-era
  names, with a legacy back-button fallback and responsive carousel assertions.
  Full runtime smoke, UI no-overlap matrix and animation smoke pass.
- Event screen grey/unclickable hardening (SCRUM-477): `_show_event_screen()`
  now keyboard-focuses the first selectable option and wires focus neighbours
  across the choice cards and Back button, so options are selectable with the
  keyboard/gamepad even if a mouse click fails to land (HiDPI/layer/platform).
  Empty/broken choice sets fall back to procedural choices, and when no option
  is affordable the Back button is force-enabled as an anti-stuck escape so a
  run can never freeze on an event with no resolvable choice. The full-screen
  `LevelUpDim` ColorRect no longer swallows clicks (`MOUSE_FILTER_IGNORE`).
  Runtime smoke now asserts event options exist, at least one is selectable,
  options are focusable, and the screen grabs keyboard focus on a choice.
- Paid random-event choices (SCRUM-454): `cost_money` options now display the
  stage-scaled gold cost, disable unaffordable choices with an explanatory
  tooltip, and the Back-end `_apply_event_choice()` path refuses direct
  unaffordable activation without mutating the run snapshot or advancing the
  route. Runtime smoke now covers the `goblin_lottery` insufficient-gold case.
- Runtime asset size cleanup (SCRUM-418): removed confirmed unused/superseded
  assets from shipping `assets/`, including the legacy main-menu background,
  duplicate UI screen backdrop copies, historical contextual/leather-gold frame
  kits and unreferenced dark modal/menu frames. Canonical UI backdrops now remain
  the only runtime screen background contract, backups/checksums live under
  `build/qa/scrum418/`, `assets/` dropped from 393M to 368M, and a local macOS
  export check now lands at 286M after source-only export excludes.
- Duplicate ` 2` artifact cleanup (SCRUM-440): removed verified macOS/Finder
  duplicate files, generated `.import` sidecars, empty duplicate directories,
  release-staging app/symlink copies and the stale cleanup backup carrier.
  Added a permanent duplicate-artifact guard and an early runtime smoke check;
  repository `find`/`git ls-files` counters are now zero, Godot import has no
  `hides a global` class collisions, and runtime smoke passes 3/3.
- Runtime smoke death-flow determinism (SCRUM-444): `_test_death_flow` now
  neutralizes meta `death_save` before the intentional lethal hit, preserving
  gameplay behavior while keeping the full runtime smoke deterministic.
- Hero Select v2 runtime rebuild (SCRUM-436): the reopened live screen now uses
  the accepted `1536x1024` `hero_select_layout_mockup.png` composition, corrected
  bad runtime frame slices from the mockup for portrait/dossier/ascension/select/
  carousel/back, and routes `_show_character_select()` through the
  `assets/sprites/ui/frames/hero_select_v2/` frame kit. The existing
  `HeroSelectRadarPanel` / `HeroStatRadar` compass contract is preserved in the
  mockup `stat_radar` slot, all live labels/portraits/buttons stay inside safe
  content zones, and QA dumps live under `build/qa/scrum436/`; runtime UI smoke,
  no-overlap matrix and full runtime smoke pass.
- Settings v2 runtime rebuild + Mac/HiDPI resolution fix (SCRUM-439/SCRUM-441):
  live Settings now uses the accepted v2 modal frame and three-slot switcher
  with preserved screen/audio/controls semantics, rebind flow, debug toggle and
  Escape/back behavior. Resolution choices now use physical-pixel/scale-aware
  fitting/clamp, append a macOS native logical option when applicable, enable
  HiDPI in project settings, and write QA evidence under `build/qa/scrum439/`
  and `build/qa/scrum441/`; display resolution, UI smoke, no-overlap matrix and
  full runtime smoke pass.
- Codex v2 runtime rebuild (SCRUM-438): the live Codex screen now follows the
  accepted v2 layout with left section navigation, center scrollable entry list,
  right detail panel, compact safe-zone back arrow, preserved data sections and
  SCRUM-416/SCRUM-417 portrait routing/scaling. Runtime UI smoke, no-overlap
  matrix and full runtime smoke pass; QA dumps live under `build/qa/scrum438/`.
- Economy choice-card width (SCRUM-437): rest, upgrade, event and Attribute
  Shop choices now use the wide `ui_frame_economy_choice_card_wide*.png`
  runtime frames with source-space safe rect metadata, responsive 360/420/480px
  card targets, compact 1152px fallback and QA dumps under `build/qa/scrum437/`.

## [0.1.6] — 2026-06-17

### Released
- FantasyDisk 0.1.6: экран выбора героя переделан заново (нативная вёрстка — крупный портрет, читаемое досье, роза характеристик и карусель героев с прокруткой), Тёмный маг и Рыцарь перерисованы в более мультяшном стиле с анимацией движения, починены внутриигровой фидбек и форма настроек, ребаланс классов, оружие вращается вокруг героя без перекрытия, приглушены VFX атак, чистка ассетов и десятки UI-фиксов.

### Changed
- Выбор героя: полностью новая нативная вёрстка без перегруза — крупный портрет слева, читаемое досье (характеристики, возвышение с описанием усложнений, «Выбрать») по центру, роза характеристик справа, карусель всех героев со стрелками-прокруткой снизу.
- Персонажи: Тёмный маг и Рыцарь перерисованы заметно мультяшнее (тот же мотив) и анимированы в движении; перерисовка остальных классов — в работе.
- Оружие вращается вокруг персонажа и не перекрывает его; интенсивность VFX атак снижена (не «вырвиглазно»).

### Fixed
- Внутриигровой фидбек (P): отправка больше не падает на крупных скриншотах (лимит Discord), форма помещается на любом разрешении с прокруткой.
- Настройки: заголовок «Настройки» больше не сталкивается с переключателем вкладок.
- Докача характеристик: кнопки «Обновить»/«Пропустить» больше не уезжают за нижний край на 720p.

### Balance
- Сводная таблица урона классов (1/5/20 целей × без прокачки / lvl20-оптимум / lvl20-случайно) и ребаланс на выравнивание классов по эффективности.

## [0.1.5] — 2026-06-15

### Released
- FantasyDisk 0.1.5: перерисовка всех 17 героев + анимации, единый D&D-фрейм UI, ребаланс призывателей/возвышений/соло-урона, классовая мета-прогрессия, внутриигровой фидбек (P), автосейв, новые фоны/иконки, множество UI-фиксов.

### Added
- Biologist animation source sheet (SCRUM-284): generated and alpha-cleaned the
  unarmed `assets/sprites/characters/biologist_sheet.png` Design source sheet
  with 5 idle / 5 walk / 5 attack_primary frames, plus 32px-gutter reference,
  contact preview, GIF previews and manifest/report under
  `build/qa/scrum284_biologist/`. Animator integration now routes Biologist
  through `assets/sprites/characters/biologist_spriteframes.tres`, extracted
  per-frame runtime PNGs under `assets/sprites/characters/full_frame/biologist/`,
  and passing manifest/Godot import/animation/runtime smokes.
- Elementalist animation source sheet (SCRUM-289): generated and alpha-cleaned
  the unarmed `assets/sprites/characters/elementalist_sheet.png` Design source
  sheet through `fantasydisk-asset-generator`, with 5 idle / 5 walk /
  5 attack_primary frames, close hand fire/ice/lightning energy only, no
  staff/wand/orb/focus/held object, plus source refs, contact preview, GIF
  previews and manifest/report under `build/qa/scrum289_elementalist/`.
  Animator integration now routes Elementalist through
  `assets/sprites/characters/elementalist_spriteframes.tres`, extracted
  per-frame runtime PNGs under
  `assets/sprites/characters/full_frame/elementalist/`, and passing
  manifest/Godot import/animation/runtime smokes.
- Thief animation sheet (SCRUM-297): refreshed the accepted unarmed
  `assets/sprites/characters/thief_sheet.png` source sheet through
  `fantasydisk-asset-generator`, with 5 idle / 5 walk / 5 attack_primary frames,
  alpha-clean + 32px-gutter references, contact preview, GIF previews and
  manifest/report under `build/qa/scrum297_thief/`; parallel Animator output
  routes the class through `assets/sprites/characters/thief_spriteframes.tres`
  and full-frame PNGs under `assets/sprites/characters/full_frame/thief/`.
- Guitarist animation sheet (SCRUM-291): generated and alpha-cleaned the
  unarmed `assets/sprites/characters/guitarist_sheet.png` runtime sheet with
  5 idle / 5 walk / 5 attack_primary frames, plus source refs, contact preview,
  GIF previews and animation manifest under `build/qa/scrum291_guitarist/`.
  Animator integration now routes Guitarist through
  `assets/sprites/characters/guitarist_spriteframes.tres`, extracted per-frame
  runtime PNGs under `assets/sprites/characters/full_frame/guitarist/`, and
  passing manifest/Godot import/animation/runtime smokes after SCRUM-409.
- Assassin and Ranger animation sheets (SCRUM-282/SCRUM-294): accepted unarmed
  source sheets now route through `assassin_spriteframes.tres` /
  `ranger_spriteframes.tres`, with extracted per-frame runtime PNGs under
  `assets/sprites/characters/full_frame/assassin/` and
  `assets/sprites/characters/full_frame/ranger/`; manifests, contact sheets and
  GIF previews live under `build/qa/scrum282/` and `build/qa/scrum294/`.
- Dark Mage animation sheet (SCRUM-286): generated and alpha-cleaned the
  unarmed `assets/sprites/characters/dark_mage_sheet.png` runtime sheet with
  5 idle / 5 walk / 5 attack_primary frames, plus source refs, contact preview,
  GIF previews and animation manifest under `build/qa/scrum286_dark_mage/`.
  Animator integration now routes Dark Mage through
  `assets/sprites/characters/dark_mage_spriteframes.tres`, extracted per-frame
  runtime PNGs under `assets/sprites/characters/full_frame/dark_mage/`, and
  passing animation/runtime smokes.
- UI Overhaul «Пауза и финальные экраны» (SCRUM-330, новым скиллом fantasydisk-
  asset-generator): геральдические кресты победы (драконий венок) и поражения
  (череп-драконы) над заголовком экранов победы/смерти; тонкая dark-fantasy-dragon
  рамка меню паузы (`ui_frame_dark_menu.png`). Общий `_create_menu_box`/`_panel_style`
  не тронут (scoped). Ассеты в `assets/sprites/ui/` + `docs/design/references/`.
- Progression UI runtime integration (SCRUM-408): live skill-tree screen now uses
  the SCRUM-331 progression main panel, class panel, points badge, branch panels
  and circular node state frames; long node titles/descriptions moved out of the
  ornate node rings into adjacent labels/tooltips, while Codex remains on the
  accepted SCRUM-345/SCRUM-403 frame kit.
- Призывные существа (SCRUM-336): анимация движения через конечности + белое
  контурное свечение всех спрайтов призыва.

### Fixed
- Character readability scale (SCRUM-417): playable combat visuals now use
  `BASE_SPRITE_SCALE = Vector2(0.36, 0.36)` for both full-frame
  `AnimatedSprite2D` and cutout-rig fallback paths, about +29% from the old
  `0.28` baseline, while the player collision radius stays unchanged. Hero
  Select large portraits and Codex character portraits use tighter covered
  scaling inside safe zones; QA dumps live under `build/qa/scrum417/`.
- New character art binding (SCRUM-416): all 17 playable static portrait
  `sprite_path` entries now point to accepted cleaned full-frame idle frames
  under `assets/sprites/characters/full_frame/<class>/`, so Hero Select large
  portrait, carousel thumbnails, Codex and level-up portrait surfaces no longer
  show legacy static PNGs. Registry/runtime smokes write QA path dumps under
  `build/qa/scrum416/`.
- Attribute/event economy UI stabilization (SCRUM-413/SCRUM-415): the
  post-battle Attribute Shop now uses a responsive panel, scrollable content,
  grid-based offers, compact reachable action buttons, disabled-grey
  unaffordable cards, and insufficient-gold tooltips. Random event choice cards
  now avoid duplicated `Риск:` prefixes and keep long option text inside the
  economy card safe zone.
- Elite/boss health bar visibility (SCRUM-414): large elite and boss overhead
  HP bars keep their normal world attachment but clamp into the visible
  viewport when the sprite reaches the top edge; ordinary enemy bars keep the
  previous behavior and boss phase markers remain intact.
- Character full-frame alpha cleanup (SCRUM-412): cleaned all 255 playable
  character runtime PNG frames under `assets/sprites/characters/full_frame/`
  so white/checkerboard mattes no longer appear behind animations on dark
  arenas; preserved existing paths and SpriteFrames contracts, reimported in
  Godot, and hardened `tools/build_character_sheet.py` with the same
  edge-connected alpha-clean/de-halo pass for future sheets. QA artifacts live
  under `build/qa/scrum412_character_alpha/`; Godot import, permanent
  representative alpha/matte animation smoke, and runtime smoke pass.
- Playable full-frame animation visibility (SCRUM-411): accepted character
  SpriteFrames now render through the visible `Player/VisualRoot/Body` layer
  while the legacy cutout `RigRoot` is hidden; fallback characters without
  full-frame frames still use the old cutout rig.
- Runtime smoke reliability (SCRUM-410): Assassin crit-shadow VFX assertion is
  now deterministic by isolating the manual hook from auto-weapon cooldown and
  checking immediate VFX spawn instead of a fragile lifetime timer; runtime smoke
  passed 10/10 consecutive runs.
- Assassin critical shadow VFX smoke blocker (SCRUM-409): the Assassin crit
  shadow hook now parents its ring/slash VFX to the combat-local player parent,
  and runtime smoke checks newly spawned VFX instance IDs instead of a fragile
  total-count delta that could be masked by older effects expiring mid-check.
- Pause/result UI runtime integration (SCRUM-407): pause menu,
  pause dossier/stats, victory and death screens now use the SCRUM-330
  pause/end modal frame with scaled safe-zone margins; result crests stay
  decorative, 720p result actions are adaptively sized, and QA layout dumps
  are written to `build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`.
- Shop/economy UI runtime integration (SCRUM-406): shop keeps compact square
  wall slots with SCRUM-332 economy price badges, while attribute shop,
  campfire/rest, upgrade and event choices now use the economy panel and
  choice-card frames inside authored safe zones; UI no-overlap writes
  `build/qa/scrum332/economy_ui_no_overlap_matrix.md`.
- Backup import UID cleanup (SCRUM-405): excluded `docs/design/backups/` from
  Godot import scope and removed tracked `.import` sidecars there so archive PNG
  copies no longer duplicate live resource UIDs during `--import`; documented
  backup hygiene to avoid copying sidecars into future asset archives.
- Reward screens runtime integration (SCRUM-404): battle rewards and elite
  artifact choices now use the SCRUM-338 per-reward frame textures with
  metadata-scaled safe-zone content containers, whole-card click/focus, runtime
  texture/safe-rect assertions and QA dumps under `build/qa/scrum338/`.
- Codex texture runtime integration (SCRUM-403): live Codex screens now use
  the SCRUM-345 texture kit for the root panel, section panel, tabs, entry
  cards, portrait/icon slots and glossary tooltip while keeping runtime content
  inside metadata safe zones; UI no-overlap, runtime UI smoke and full runtime
  smoke cover the texture paths and layout dump.
- Settings menu unified restyle integration (SCRUM-396): runtime Settings tabs
  now use the SCRUM-391 3-slot switcher asset and exactly three source safe
  rects for `Экран`, `Звук`, `Управление`, removing the obsolete fourth hit area
  while keeping tab labels/click/focus zones inside the authored content zones.
- Unified thin frame runtime margins (SCRUM-392): `UIThemePaths` now uses the
  SCRUM-384 metadata-aligned 72px 9-slice margins and 88px source safe rect for
  the unified master frame, with the theme smoke checking against metadata
  instead of stale 128px expectations.
- Hero Select ascension default (SCRUM-389): selecting/opening a hero now
  defaults the ascension selector to that class's current selectable maximum,
  while the minus/plus controls still let the player lower or restore the run
  level before weapon select.
- Feedback Discord webhook attachments (SCRUM-374): multipart `payload_json`
  now declares `attachments[0]` with the same filename as `files[0]`, so
  Discord API v10 keeps the `fantasydisk_feedback.png` screenshot instead of
  accepting text-only 204 responses; runtime smoke now asserts the filename
  mapping without network.

### Added
- Pause/result UI Design kit (SCRUM-330): generated a D&D/dark-fantasy mockup
  for pause, victory and defeat screens through `fantasydisk-asset-generator`,
  added transparent runtime modal frame candidate
  `assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png`, documented
  strict safe-zone/content margins, produced contact/safe-zone previews and
  handed runtime wiring to Back-end.
- Progression UI frame kit (SCRUM-331): generated a mockup-first Design package
  for the skill tree/progression side of the progression+Codex cluster, with
  spec under `docs/design/mockups/scrum331_progression_codex/`, nine
  alpha-cleaned progression frames under `assets/sprites/ui/frames/progression/`,
  reference copies and a Back-end integration handoff. Existing SCRUM-345 Codex
  frames remain the accepted Codex baseline.
- Economy UI frame kit (SCRUM-332): generated a mockup-first Design package for
  shop, attribute shop, rest, upgrade and event screens, with spec under
  `docs/design/mockups/scrum332_shop_economy/`, six alpha-cleaned runtime-ready
  frames under `assets/sprites/ui/frames/economy/`, reference copies and a
  Back-end integration handoff.
- Attack VFX regeneration (SCRUM-337): rebuilt the full active combat VFX art
  pack through `fantasydisk-asset-generator` source sheets, replacing 83
  `assets/sprites/effects/*.png` and 2 projectile PNGs with alpha-cleaned
  D&D/dark-fantasy raster effects while preserving paths, canvas sizes and
  gameplay/runtime behavior; previews and QA manifests added under
  `docs/design/previews/` and `build/qa/scrum337/`.
- Reward frame kit (SCRUM-338): generated Design-ready D&D/dark-fantasy reward
  card frames for battle rewards and elite artifact rewards, with transparent
  `768x1024` production PNGs, hover variants, source references, strict
  safe-zone metadata, contact preview and Back-end integration handoff.
- Artifact icon regeneration (SCRUM-340): recreated all 53
  `assets/sprites/ui/icons/artifacts/artifact_<id>.png` files through
  `fantasydisk-asset-generator` / OpenAI Images as transparent 256px
  D&D/dark-fantasy magic item PNGs, with old-icon backup, source references,
  coverage manifest, contact sheet and 40px readability preview.
- Codex texture kit (SCRUM-345): generated a new D&D/Dark Fantasy Dragon Codex
  UI reference through `fantasydisk-asset-generator`, cut/imported 10 RGBA
  production candidates under `assets/sprites/ui/frames/codex/`, and documented
  strict content-zone metadata plus 720p/1080p/1440p design mocks for Back-end
  no-overlap integration.
- Animation source sheet safe gutters (SCRUM-394): repacked 26 canonical
  enemy/elite/boss full-frame source sheets to `1704x1144` RGBA and rebuilt 19
  death-row reference sheets to `1704x304` RGBA with `256x256` cells, `24px`
  transparent gutters and `24px` outer padding, updating manifests and contact
  preview without changing runtime SpriteFrames or gameplay.
- Ethereal summon redesign (SCRUM-399): generated a new summon source sheet
  with `fantasydisk-asset-generator` and replaced the four mobile summon static
  sprites plus existing move/attack/death frame PNGs with blue/cyan translucent
  allied spirit visuals, preserving SpriteFrames paths, frame counts and timings;
  all 80 animated frame PNGs were repacked with 24px transparent safe gutters
  to satisfy no-crop validation. Contact/readability previews and manifest are under
  `docs/design/references/summons_ethereal/` and `docs/design/previews/`.
- Combat HUD redraw kit (SCRUM-390): generated a new D&D/dark-fantasy dragon
  HUD reference sheet with `fantasydisk-asset-generator`, alpha-cleaned it, and
  cut production candidates for the resource panel, HP/XP/money/ultimate cards,
  timer, ascension badge, opaque level-up plus button, bar fills and gold
  medallion under `assets/sprites/ui/frames/combat_hud/` and
  `assets/sprites/ui/hud/combat_hud/`; metadata, safe-zone preview, 720p/1080p/
  1440p mock screens and Back-end integration handoff are ready.
- Unified master UI frame kit (SCRUM-373): added design-ready D&D/dark fantasy
  9-slice assets under `assets/sprites/ui/frames/unified/`, metadata
  `docs/design/references/unified_master_frame/unified_master_frame_metadata.json`,
  contact/safe-zone previews and Back-end handoff for projectwide runtime
  centralization without one-axis frame stretching.
- Unified master frame thin revision (SCRUM-384): replaced the SCRUM-373
  preserved runtime frame paths with a thinner dark-metal frame, small red
  corner gems, separate optional dragon overlays, updated metadata margins
  (`72px` texture / `88px` content), previews and QA notes; Godot import,
  UI no-overlap matrix, runtime UI smoke and runtime smoke PASS.
- Arena background redraw (SCRUM-369): regenerated and integrated all 10
  `assets/backgrounds/field_*.png` combat backgrounds through
  `fantasydisk-asset-generator` as realistic 2560x1440 D&D/dark fantasy arena
  floors, including newly created `field_dry_road.png` and
  `field_stone_garden.png`; contact/readability previews, Godot import,
  background load smoke, combat smoke and runtime smoke PASS.
- Settings tab switcher design (SCRUM-391): generated and alpha-cleaned a
  Design-ready 3-slot red-gold/dark-steel Settings switcher candidate at
  `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`,
  documented exact safe rects and created Back-end handoff for runtime path/rect
  integration.
- Unified master UI runtime integration (SCRUM-382): generic panels, cards,
  tooltips, timers and HUD frames now route through a shared tiled 9-slice
  unified frame builder in `scripts/ui_screens.gd` / `UIThemePaths`; authored
  Hero Select frames, Settings tab strip and Red & Gold buttons remain
  proportional/specialized.
- Character animation art standard (SCRUM-298): added
  `docs/design/references/character_animation_style_sheet_0_1_5.md` with the
  D&D dark fantasy playable-character visual canon, `384x384` cell format,
  `idle`/`walk`/`attack_primary` row convention, bottom-center pivot guidance,
  unarmed base-sheet rule and Design/Animator/Back-end handoff boundaries.
  `Player` now probes `assets/sprites/characters/<class_id>_sheet.png`, builds
  `idle`/`walk`/`attack_primary` plus runtime `attack` SpriteFrames when present,
  and keeps safe static/cutout fallback for classes without final sheets.
- Berserk animation source sheet (SCRUM-283): generated the accepted unarmed
  `assets/sprites/characters/berserk_sheet.png` Design source sheet with
  `384x384` cells, 5 `walk` frames and 5 `attack_primary` frames on a
  transparent `1920x768` canvas; source, contact preview and validation manifest
  are accepted. Animator integration now routes Berserk through
  `assets/sprites/characters/berserk_spriteframes.tres`, extracted per-frame
  runtime PNGs under `assets/sprites/characters/full_frame/berserk/`, 5-frame
  walk and attack animations, QA manifest/contact/GIFs in `build/qa/scrum283/`,
  and passing animation/runtime smokes.
- Main menu background (SCRUM-316): added `assets/backgrounds/main_menu_epic_battle_v2.png`, a native 2560x1440 smooth D&D dark fantasy battle scene with three new bosses, two heroes, and UI-safe left/top composition zones.
- Full-frame animation registry (SCRUM-351): added
  `scripts/full_frame_animation_registry.gd` as a data-driven SpriteFrames
  state bridge for heroes/enemies/allies/elites/bosses. Allies can now opt into
  source-specific full-frame move/attack playback, and enemies/bosses keep
  cutout/static fallback when no SpriteFrames are registered.
- Enemy/elite/boss full-frame source sheets (SCRUM-352): generated 26 accepted
  transparent production sheets for standard enemies, route elites, mini-elites
  and bosses in `assets/sprites/{enemies,elites,bosses}/full_frame/`, with
  manifest `docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`
  and previews `scrum352_full_frame_sheets_preview.png` /
  `scrum352_full_frame_sheets_contact.png`.
- Rift Cutter full-frame pilot (SCRUM-363): integrated the accepted SCRUM-352
  enemy sheet as padded runtime SpriteFrames with `move` 6f loop and
  `attack_primary`/runtime `attack`, `hit`, `death` 6f one-shots through
  `FullFrameAnimationRegistry`, with no gameplay, targeting, spawn or balance
  changes.
- Standard enemy full-frame batch (SCRUM-364): integrated accepted SCRUM-352
  sheets for `ash_marksman`, `spark_runner`, `stone_bruiser`, `bone_caller`, and
  `void_mage` as padded SpriteFrames/registry entries with the same `move`,
  `attack_primary`/runtime `attack`, `hit`, and `death` contract.
- Standard enemy full-frame batch 2 (SCRUM-365): integrated accepted SCRUM-352
  sheets for `venom_spitter` and `rift_shieldbearer` through
  `FullFrameAnimationRegistry` with no gameplay, targeting, spawn, or balance
  changes.
- Standard enemy full-frame batch 3 (SCRUM-366): integrated the accepted
  SCRUM-352 `small_biter` sheet as padded SpriteFrames with the standard
  full-frame enemy state contract.
- Standard enemy full-frame batch 4 (SCRUM-367): integrated accepted SCRUM-352
  sheets for `bone_shaman` and `winged_spark`; `winged_spark` now exposes a
  looped `hover_flap` state plus the standard runtime hit alias.
- Route elite full-frame batch (SCRUM-368): integrated accepted SCRUM-352 sheets
  for `iron_bastion`, `night_stalker`, and `plague_prophet` as full-frame
  SpriteFrames/registry entries with `move`, `attack`/`attack_primary`, two
  `skill_*` rows and validator-facing `attack_*` aliases per elite.
- Shard Marshal full-frame animation (SCRUM-371): integrated the accepted
  SCRUM-352 `shard_marshal` sheet as a full-frame SpriteFrames/registry entry
  with `move`, `attack`/`attack_primary`, `skill_shard_fan`,
  `skill_command_pulse`, and matching `attack_*` aliases.
- Mini-elite full-frame visual hook (SCRUM-372): elite instances now prefer a
  registered `mini_elite_kind` SpriteFrames entry for visual identity, then
  fall back to their base `elite_behavior`; this is visual-only and does not
  alter mini-elite spawn, stats, AI, damage, or rewards.
- Mini-elite full-frame batch (SCRUM-376): integrated all six accepted SCRUM-352
  mini-elite sheets as SpriteFrames/registry entries for the SCRUM-372
  `mini_elite_kind` visual-id hook, with `move`, `attack`/`attack_primary`, two
  `skill_*` rows and matching `attack_*` aliases per mini-elite.
- Boss full-frame batch (SCRUM-377): integrated all five accepted SCRUM-352 boss
  sheets as boss SpriteFrames/registry entries with `move`,
  `attack`/`attack_primary`, two `skill_*` rows and matching `attack_*` aliases
  per boss; created Back-end follow-up for visual-only skill-state playback
  hooks.
- Boss full-frame skill hooks (SCRUM-378): boss mechanics now request matching
  full-frame `skill_*` states for gravity wells, rift zones, skull volleys,
  bone prison, brood spawn/web zones, molten slam and armor pulse while keeping
  gameplay damage, hazards, cooldowns, targeting and spawn timing unchanged.
- Full-frame death lifecycle (SCRUM-379): standard enemies with explicit
  `FullFrameBody.death` now leave combat groups, disable collision/HP bars and
  play their drawn death row before cleanup; entities without a full-frame death
  row keep the existing `DeathGhostRig` fallback.
- Full-frame death row source pack (SCRUM-380): generated 19 accepted
  transparent Design source rows and 114 `death_00..05` frames for allies, route
  elites, mini-elites and bosses, with manifest
  `docs/design/references/scrum380_death_rows/scrum380_death_rows_manifest.json`
  plus contact/readability previews for Animator integration.
- Full-frame death rows integration (SCRUM-370): added 6-frame non-loop `death`
  rows to existing SpriteFrames for 4 allies, 4 route elites, all 6 mini-elites
  and all 5 bosses; manifest, contact sheet and GIF previews live under
  `build/qa/animation_integrate_all_move_attack_death_states/`. Animator
  validation is green; final runtime umbrella verification is blocked by an
  unrelated victory-flow text regression handed to Back-end.
- Run autosave (SCRUM-349): активный забег теперь атомарно сохраняется в
  `user://fantasydisk_autosave.cfg` после безопасных route checkpoints
  (бой/элитка после reward flow, event/rest/upgrade, shop visit); главное меню
  при наличии валидного сейва предлагает «Продолжить» или «Новая игра», а
  смерть/победа очищают autosave. Добавлены persistence + runtime smoke checks.
- Cleanup audit (SCRUM-269): added `docs/design/reviews/cleanup_assets_audit_2026_06.md`
  with dynamic-path protection for weapon VFX, weapon sprites, boss/mini-elite
  source art and UI/icon/cutout families; spawned SCRUM-271 for isolated orphan
  ` 2.png.import` sidecar cleanup.
- Опорные balance-гейты патча 0.1.5 (SCRUM-249): `tests/global_damage_balance_smoke_test.gd` (комбинированное бюджет-отклонение по всем парам класс×оружие в коридоре ±25%) и `tests/global_survivability_balance_smoke_test.gd` (TTD/митигация в коридорах + проверяемое «бессмертие недостижимо»: митигированный входящий урон > реген). Отчёты в `build/global_*_balance_report.md`. Запуск: `tools/run_focused_tests.sh global_damage global_survivability` или по отдельности через Godot headless. Каждая балансовая задача 0.1.5 проверяется против этих гейтов.
- Class mechanics framework (SCRUM-256): добавлен `ProgressionData.CLASS_MECHANIC_IDENTITIES` и API `class_mechanic_identity` / `class_main_attribute` / `weapon_mechanic_identity`, фиксирующие главный атрибут, уникальную идентичность и 3 weapon identity для всех 17 классов без изменения текущего баланса.
- Attribute×weapon synergy matrix (SCRUM-243): добавлены `ProgressionData.ATTRIBUTE_WEAPON_SYNERGY_MAP`, `weapon_archetype()` и `attribute_weapon_synergy_description()`; smoke проверяет, что каждый из 8 базовых атрибутов меняет фактический параметр для melee/projectile/beam/aoe/summon/aura representative оружия.
- Melee identity hooks (SCRUM-251): `ClassWeapon` и `BerserkWeapon` получили data-driven melee effects — close-hit bonus, wounded execute, stagger knockback, cleave follow-up и small sustain; добавлен focused smoke `tests/melee_unique_mechanics_test.gd`.
- Summoner role hooks (SCRUM-254): `SummonerWeapon`, `AllyMinion` и deploy-оружия получили data-driven summon roles (`pack_damage`, `tank_control`, `support_totem`, `engineer_sentry`, `support_drone`), Leadership scaling для урона/живучести/темпа и focused smoke `tests/summoner_strengthening_test.gd`.
- Status effects system (SCRUM-245): добавлен reusable `scripts/status_effects.gd` для длительности, refresh/stack, DoT, slow, vulnerability и ally buffs; Player раздает тематические on-hit debuffs и leadership auras, Enemy/AllyMinion тикают фактические статусы.
- Elite/boss mechanics framework (SCRUM-259): добавлен `ProgressionData.ENEMY_MECHANIC_CATALOG`, `ELITE_ATTACK_CONFIGS` и `UNIQUE_ENCOUNTER_PATTERNS` для 4 элиток и 5 боссов; runtime записывает unique pattern/mechanics в meta, а smoke проверяет каталог, уникальность signatures, telegraph/state phases и фактический spawn уникальных boss mechanics.
- Aim modes (SCRUM-241): во вкладке «Управление» добавлен persisted переключатель `Автонаводка на ближайшего` / `По курсору`; оружие берет направление и point-AoE из единого `Player.attack_aim_direction()` / `attack_aim_position()`, а focused smoke проверяет персист и фактическую смену вектора атаки.
- UI buttons (SCRUM-263/SCRUM-264): стандартные action-кнопки используют единую высоту 104px; главное меню поднято до нового стандарта, широкие кнопки capped по визуальной ширине, а text-heavy choices в наградах/костре/событиях/upgrade показывают описание в отдельной рамке над короткой стандартной кнопкой.
- Red & Gold Dragon buttons (SCRUM-273): добавлен live-кит из 15 button types × 4 states в `assets/sprites/ui/frames/red_gold/`, pipeline `tools/build_red_gold_button_kit.py`, contact preview `docs/design/previews/red_gold_button_kit_contact.png` и backup прежнего parchment/wax button kit в `build/cleanup_backup_red_gold_buttons_2026_06_14/`.
- Ornate Dark frames (SCRUM-274): добавлен live-кит из 13 non-button frame assets в `assets/sprites/ui/frames/ornate/`, pipeline `tools/build_ornate_ui_frame_kit.py`, contact preview `docs/design/previews/ornate_dark_frame_kit_contact.png` и backup прежних leather/gold + dark_fantasy/escape panel textures в `build/cleanup_backup_ornate_frames_2026_06_14/`.
- Hero Select frames (SCRUM-281): экран выбора героя получил отдельный herouiframe kit из 8 live PNG в `assets/sprites/ui/frames/hero_select/`, pipeline `tools/build_hero_select_frame_kit.py`, preview `docs/design/previews/hero_select_frame_kit_contact.png` и QA screenshots `build/qa/scrum281/hero_select_1280x720.png`, `hero_select_1920x1080.png`, `hero_select_2560x1440.png`.
- Hero Select carousel frame (SCRUM-320): `ui_frame_hero_select_thumbnail_strip.png` пересобран из референса Carusel как 1536x255 RGBA frame с прозрачным фоном, pipeline `tools/build_hero_select_carousel_frame.py`, preview `docs/design/previews/hero_select_carousel_frame_contact.png`, backup прежнего SCRUM-281 strip в `build/cleanup_backup_hero_select_carousel_2026_06_14/`.
- Hero Select portrait frame (SCRUM-321): принят live `ui_frame_hero_select_portrait.png` as production heroframe-style asset, добавлен safe-area preview `docs/design/previews/hero_select_portrait_frame_content_zone.png`, backup исходника в `build/cleanup_backup_hero_select_portrait_2026_06_14/`.
- Hero Select windrose radar frame (SCRUM-322): `ui_frame_hero_select_radar.png` пересобран из windrose reference как 1024x1024 RGBA compass frame, pipeline `tools/build_hero_select_windrose_frame.py`, safe-area preview `docs/design/previews/hero_select_windrose_radar_content_zone.png`, backup прежнего SCRUM-281 radar в `build/cleanup_backup_hero_select_windrose_2026_06_14/`.
- Hero Select dossier frame (SCRUM-323): `ui_frame_hero_select_dossier.png` пересобран из DescriptionHS reference как 1120x1140 RGBA frame, pipeline `tools/build_hero_select_dossier_frame.py`; runtime больше не тянет dossier как StyleBox, а рисует цельный proportional `HeroSelectDossierFrame` (`387x394`, `581x591`, `774x788` at 720p/1080p/1440p) с content margins `Vector4(96, 66, 96, 54)`, preview `docs/design/previews/hero_select_dossier_frame_content_zone.png`, backup прежнего asset в `build/cleanup_backup_hero_select_dossier_2026_06_14/`.
- Settings tab switcher frame (SCRUM-325): добавлен design-ready D&D/dark fantasy PNG `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher.png` (`1280x256`, RGBA, без baked text), safe-area preview `docs/design/previews/settings_tab_switcher_frame_content_zone.png` и Back-end handoff SCRUM-334 на runtime integration.
- Druid wolf summon animation assets (SCRUM-280): нарезаны reference sheets `docs/design/references/wolfanimate/` в 14 normalized 256x224 PNG frames, собран `assets/sprites/allies/ally_druid_wolf_spriteframes.tres` с `move` 8f/12fps loop и `attack` 6f/14fps no-loop; QA preview/gifs в `build/qa/druid_wolf_summon_animation/`.
- Elite/boss VFX kit (SCRUM-261): добавлены 13 dedicated D&D/painterly PNG для `BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`, summon portal, shield block, reflect-thorns aura, command aura, shadow blink mark и shard fan warning; preview `docs/design/previews/scrum261_elite_boss_vfx_contact.png`.
- Unique weapon VFX kit (SCRUM-258): добавлен полный набор из 51 transparent PNG `assets/sprites/effects/vfx_weapon_<weapon_id>.png` для всех class weapon identities 0.1.5, contact/readability previews и focused smoke `tests/unique_weapon_vfx_assets_test.gd`.
- Final balance audit (SCRUM-262): global damage smoke теперь проверяет не только combined solo/5-target DPS, но и финальный solo corridor ±20% плюс crowd-clear time 5/10/20 в коридоре ±30%; `tools/balance_harness.gd` пишет `build/balance_final_audit_0_1_5.md` с class viability и CCT таблицами для всех 51 class+weapon пар.
- In-game feedback tool (SCRUM-362): added a global `P` feedback action, top-level `FeedbackOverlayLayer` with pre-overlay screenshot preview, Discord-compatible webhook delivery through `FeedbackReporter`, safe `user://feedback/` fallback reports and runtime smoke coverage.
- Per-class meta progression (SCRUM-360): boss victories now build `class_boss_wins` for the played class, unlock class-only damage/HP/attack-speed bonuses at 1/2/4/6/9 wins, apply them only to the selected hero at run start, and show a compact «Классы» section in the skill tree screen.
- Debug combat movement (SCRUM-375): settings now include a persisted
  OFF-by-default «Дебаг-режим» toggle; when enabled in combat, right-click or
  Shift+left-click sets a smooth arena move target and middle-click teleports to
  the clamped arena point. Normal combat input is unchanged while the toggle is
  off.

### Changed
- Combat HUD runtime integration (SCRUM-400): live combat HUD now uses the
  SCRUM-390 resource panel, HP/XP/money/ULT cards, bar fills, timer frame,
  ascension badge and opaque bottom-right level-up plus button while preserving
  HP/XP/money/ULT/timer semantics; no-overlap/runtime smoke dumps are written to
  `build/qa/scrum390/`.
- Summoner rebalance (SCRUM-357): `SummonerWeapon` now gives summons a
  noticeable Leadership-driven damage multiplier, stronger controlled HP/speed/
  lifetime/haste scaling, owner-leashed group target assignment with overkill
  avoidance, and data-driven small splash hits through `AllyMinion`.
- Hero Select unified frame (SCRUM-356): runtime now renders
  `ui_frame_hero_select_unified_panel.png` (`1536x1024` RGBA) as one
  proportional `HeroSelectUnifiedFrame` containing portrait, dossier and bottom
  controls inside SCRUM-356 source safe-zones; `-`/`+` use
  `ui_frame_hero_select_asc_button_small.png`, radar and carousel remain
  separate, and smoke QA dumps the scaled safe rects in
  `build/qa/hero_select_radar_rects.md`.
- Hero Select frames (SCRUM-355): rebuilt the dossier and thumbnail-strip frame
  PNGs with a thinner/lighter D&D dark-fantasy treatment, added deterministic
  `tools/build_hero_select_thin_frames.py`, strict ornament-safe content margins
  and QA preview/rect artifacts under `build/qa/scrum355/`.
- Hero Select layout (SCRUM-354): switched runtime dossier and thumbnail-strip
  layout to the strict SCRUM-355 safe margins, fixed the description/carousel
  visual overlap with a 16px+ frame gap, and added runtime smoke assertions for
  computed safe-zone containment plus QA rect dumps in `build/qa/hero_select_radar_rects.md`.
- Hero Select carousel (SCRUM-342): bottom hero thumbnails are taller and
  easier to read inside the existing Carusel frame safe-zone, with compact 2px
  separation and reduced runtime margins; QA rects show 49x66 at 1280x720,
  75x101 at 1920x1080 and 101x136 at 2560x1440 without touching frame
  ornaments.
- Level-up buttons (SCRUM-348): in-run `LevelUpPlusButton` now uses the
  Red&Gold main-menu button frame while keeping bottom-right anchoring, opacity
  and badge readability; `LevelUpLaterButton` uses a non-cropped 260x104
  medium back frame. Runtime smoke verifies both styles and the deferred-choice
  flow.
- Hero Select radar (SCRUM-347): removed the old `Характеристики` title inside
  the windrose, centered `HeroStatRadar` in the compass content area and raised
  the polygon radius factor from `0.30` to `0.36` (+20%) with tighter label
  offsets so labels stay inside the frame; runtime smoke covers 1280x720,
  1600x900 and 2560x1440.
- Quit confirmation (SCRUM-344): кнопки «Выйти»/«Отмена» в диалоге выхода
  теперь принудительно остаются 220x72 и используют 72px-safe Red&Gold
  `pause` frame вместо сплющенного `back_s`; runtime smoke проверяет размеры,
  texture type, модальность и фокус на «Отмена».
- Back buttons (SCRUM-343): `HeroSelectBackButton` теперь использует 240x104
  medium back-frame вместо узкого 170px варианта, чтобы текст и Red&Gold
  орнамент не обрезались; runtime smoke также проверяет SkillTree/PatchNotes/
  Codex back buttons и пишет QA dump в `build/qa/scrum343/back_button_frames.md`.
- Shop route flow (SCRUM-339): leaving a shop now returns to the route map
  without advancing the route stage or clearing node-bound stock; the visited
  shop stays revisitable with purchased slots preserved until the player chooses
  the next route node, which finalizes/clears the shop and starts the next step.
- Settings tabs (SCRUM-334): экран настроек теперь использует production `ui_frame_settings_tab_switcher.png` как proportional 5:1 strip; встроенные tab headers скрыты, а runtime labels/click/focus зоны вкладок `Экран`, `Звук`, `Управление` лежат строго внутри recorded safe rects. UI smoke проверяет aspect ratio, safe-rect геометрию и click switching.
- Hero Select portrait frame (SCRUM-321): `HeroSelectPortraitPanel` сохраняет левую треть master layout, но сам `HeroSelectPortraitFrame` рисуется отдельным цельным `TextureRect` и масштабируется пропорционально (`249x394`, `423x669`, `596x944` на 720p/1080p/1440p); портрет героя лежит в content-zone `Vector4(128, 230, 128, 330)` и не попадает на металл, гребни или нижний самоцвет.
- Hero Select windrose radar (SCRUM-322): floating `HeroSelectRadarPanel` больше не использует stretchable radar StyleBox; windrose art рисуется цельным квадратным `TextureRect` (`390x390`, `585x585`, `780x780` at 720p/1080p/1440p), а `HeroStatRadar` масштабируется внутри safe margins `Vector4(245, 245, 245, 235)`.
- Hero Select dossier (SCRUM-323): центральное досье больше не растягивает декоративный frame по одной оси; `HeroSelectDossierPanel` центрирует `HeroSelectDossierFrame`, где DescriptionHS-art рисуется цельным `TextureRect`, а текст/Возвышение/кнопка «Выбрать» живут в `HeroSelectDossierContent` с base safe margins `Vector4(96, 66, 96, 54)`.
- Hero Select layout (SCRUM-333): экран выбора героя переведен на master-компоновку 1/3·2/3: `HeroSelectPortraitPanel` занимает левую треть, `HeroSelectRightRegion` занимает правые две трети с досье и невидимым резервом под floating top-right radar. Bottom carousel, hover и tooltip поведение сохранены; runtime smoke теперь проверяет фактические пропорции и no-overlap на 1280x720, 1600x900 и 2560x1440.
- Attack VFX runtime coverage (SCRUM-335): `BerserkWeapon` now routes existing
  `vfx_weapon_<weapon_id>.png` signature plates for Berserk/Knight melee
  attacks, and enemy magic projectiles gained textured trail + impact feedback
  using existing VFX textures; damage/timing/collision/balance unchanged.
- Main menu UX (SCRUM-319): the «Выйти из игры» button and Escape on the
  main menu now open a game-styled confirmation overlay; the real quit request
  is sent only after explicit «Выйти», with «Отмена» focused by default.
- UI buttons (SCRUM-318): hover/focus no longer use baked Red&Gold `*_hover`
  glow textures or yellow hover text; button themes now reuse the normal
  texture with neutral bright tint and near-white hover/focus font while
  pressed/disabled semantics stay unchanged.
- Druid summon (SCRUM-279): `druid_beast` allies now use
  `ally_druid_wolf_spriteframes.tres` in `AllyMinion` for looping movement,
  one-shot attack playback and horizontal facing; static ally visuals remain as
  fallback/other summon variants.
- Summon animations (SCRUM-353): all four mobile ally visuals now validate under
  `fantasydisk-animation-director` as full-frame SpriteFrames with `move` 8f loop
  and `attack_primary`/runtime `attack` 6f one-shot; wolf frames were padded to
  safe 256x256 canvas with registry placement compensation.
- Combat HUD (SCRUM-278): in-run `LevelUpPlusButton` now uses bottom-right
  anchoring, a fully opaque static style, and identical normal/hover/focus
  styleboxes; runtime smoke verifies position, alpha, no hover restyle and
  writes `build/qa/combat_level_up_button.md`.
- Settings UI (SCRUM-275): вкладка «Управление» теперь прокручивается внутри
  `ControlsScroll` с `follow_focus`, поэтому переключатель прицеливания, все
  биндинги и кнопка сброса доступны на 1280x720, а кнопка «Назад» остается вне
  скролла и не перекрывается.
- Weapon integrity (SCRUM-277): 18 legacy proxy-texture links in Thief,
  Elementalist, Sniper, Priest, Biologist and Engineer weapon scenes now point
  to their canonical `assets/sprites/weapons/<weapon_id>.png`; `PriestChime`
  no longer renders as the Guitarist `sound_amp`. Added
  `tests/weapon_integrity_test.gd` covering all 17 classes and 51 weapons from
  data -> scene -> equipped player visual.
- Attribute formulas (SCRUM-243): `derived_parameters` получил мягкий universal cross-scaling для damage/magic/sound, attack speed, range/AoE, projectile speed, DoT, aura, summon и ultimate, чтобы непрофильные атрибуты тоже работали на любом weapon archetype; `budget_damage_multiplier` удерживает стартовый DPS в глобальном damage-smoke коридоре.
- Melee balance (SCRUM-251): Берсерк, Soldier Bayonet, Assassin Shadow Daggers, Doctor Bone Saw, Knight melee kit и Robot compression/anchor получили разные ближние identity-эффекты без авто-движения игрока; `ProgressionData.estimate_weapon_budget()` учитывает эти melee bonuses при tuning.
- Summoner balance (SCRUM-254): Друидская стая стала быстрым damage-pack, гомункул Химика — более живучим control-minion, вороний тотем — support/control deploy, а инженерные sentry/drone получили роли устройств; `ProgressionData.estimate_weapon_budget()` больше не считает чистые summon-оружия как невидимый прямой удар.
- Aura/buff/debuff gameplay (SCRUM-245): Dark Mage/Elementalist накладывают arcane vulnerability, Chemist/Doctor/Assassin/Biologist — toxic DoT, Soldier/Knight/Robot — stagger slow; Guitarist/Druid/Engineer/Priest поддерживают мягкую class aura без новых арт-зависимостей.
- Crit formulas (SCRUM-247): crit chance now has diminishing returns and a 55% cap, crit damage is capped at 2.75x, flat crit rewards are softened, and `ProgressionData.weapon()` tuning keeps average class+weapon DPS inside the global damage smoke corridor.
- Survivability formulas (SCRUM-255): regeneration and vampirism were strongly nerfed; defense/dodge/absorb now use diminishing returns with lower caps (defense 62%, dodge 55%, absorb min-through 35%). Synthetic tank contact swarm TTD in the survivability harness dropped from 321.0s to 38.5s while global damage/survivability gates stay green.
- Enemy sizes/balance (SCRUM-260): размеры врагов вынесены в `ProgressionData.ENEMY_SIZE_PROFILES`; mini-элитки Возвышения стали меньше полноценных route-элиток (`1.05 < 1.68 < 1.90`), карточные элитки стали крупнее/страшнее и получили небольшой HP/damage buff, а hitbox/contact/HP-bar остаются согласованными через один node scale.
- Elite/boss combat (SCRUM-259): боссы получили дополнительные честно телеграфированные mechanics — gravity well Стража, vampiric bite Пожирателя, bone prison Архонта, дополнительный web pressure Матери Роя и molten armor pulse Колосса; Железный Оплот отражает малый урон вблизи во время активного щита.
- Hazard VFX routing (SCRUM-261): `HazardVfx` теперь выбирает отдельные texture assets по runtime node name и добавляет визуальные shield/summon/aura helpers без изменения damage, cooldowns, timings или mechanics API.
- Player weapon VFX routing (SCRUM-258): `ClassWeapon` добавляет короткую `AttackVfx.weapon_signature()` пластину по текущему `weapon_id`, чтобы новые unique attacks/auras/status identities имели отличимый visual read без изменения damage, targeting, cooldowns, timings или balance.
- Combat control (SCRUM-253): критовые механики Ассасина больше не двигают тело игрока автоматически; бывший crit dash заменен на неподвижный shadow burst у цели, а `shadow_backstab` Вора стал фантомным ударом без телепорта игрока. Smoke-тест проверяет, что крит, уворот и backstab не меняют `global_position` героя без ввода.
- Balance gates (SCRUM-262): финальная 0.1.5 сверка прошла без числовых правок оружия — худшее crowd-clear отклонение +22.0% (`doctor/plague_syringe`, 20 целей), внутри ±30%, каждый класс имеет минимум одно crowd-viable оружие.
- UI theme (SCRUM-273): runtime button styleboxes теперь выбирают Red & Gold Dragon texture type по node name/role/size (`main_menu`, `hero_confirm`, `reset_audio`, `reset_bindings`, `codex_tab`, `attr_selector`, `back_s/m/l`, `fab`, `utility`, `pause`, `rebind`); non-button panels оставались отдельным scope и затем были заменены SCRUM-274.
- UI frames (SCRUM-274): global/level/card/hero/hover/tooltip/HUD/timer styleboxes теперь используют signed texture/content margins из Ornate Dark spec sheet; Escape stats menu переведен на ornate pause/stat frames и Red & Gold pause buttons.
- Hero Select layout (SCRUM-281): портрет, досье, radar reserve, radar panel, ascension controls и bottom thumbnail strip используют dedicated 9-slice frames; 720p safe-area исправлена так, чтобы back button и миниатюры не вылезали за экран, а `HeroSelectChooseButton` стал локальным compact hero-confirm 260x72.
- Hero Select carousel (SCRUM-320): bottom thumbnail strip теперь использует Carusel reference frame как цельный `TextureRect` без 9-slice/one-axis stretch; рамка масштабируется пропорционально (`1024x170` at 720p, `1536x255` at 1080p, `2048x340` at 1440p), а 17 hero thumbnails центрируются в отдельном content layer с base margins `112/46/112/46` и адаптируются до `42-124px`, не перекрывая орнамент.
- Hero Select portrait (SCRUM-321): левый portrait frame больше не тянется как StyleBox по одной оси; колонка остается 1/3 ширины, а внутренняя heroframe-рамка центрируется и масштабируется единым коэффициентом. Safe margins: `Vector4(128, 230, 128, 330)`.
- Hero Select windrose radar (SCRUM-322): правый radar frame заменен на windrose compass reference, не растягивается в прямоугольник и растет пропорционально с разрешением; graph/title остаются в safe inner field, а тест проверяет square aspect вместо старого fixed 500px cap.

## [0.1.4] — 2026-06-13

- Docs (SCRUM-195): synchronized the remaining 0.1.4 domain-doc drift after
  the data/UI splits and cleanup pass: fixed stale `0.2` wording, corrected
  system doc filenames, refreshed boss/mini-elite summaries and aligned current
  state with the active `dev` stabilization target.

- Cleanup (SCRUM-193): verified the legacy sprite cleanup backup at
  `build/cleanup_backup_2026_06_13/`, confirmed old character placeholders are
  absent from active runtime folders, and hardened the asset audit around split
  `progression_data_*` files so dynamic artifact/shop families stay protected.

- Refactor (SCRUM-199): `scripts/ui_screens.gd` оставлен compatibility facade,
  а hero radar control, dark-fantasy theme paths, shop UI constants и hero
  select constants вынесены в `scripts/ui/` modules без изменения node names,
  визуала или gameplay behavior.

- Bugfix (SCRUM-257): укреплен umbrella `runtime_smoke_test` — delayed orb/curse
  weapon callbacks больше не захватывают временные freed nodes напрямую, а
  плавающий hero-select radar получил стабильный вертикальный зазор от header
  на 1280×720; финальная isolated smoke-серия 12/12 без warning/error.

- Marketing art: добавлен Steam Library Logo для FantasyDisk (`assets/marketing/steam/fantasydisk_steam_library_logo.png`, 1280x720 RGBA transparent) и preview на темном фоне; generator `tools/generate_steam_logo.py`.

- Animation (SCRUM-239): unique class attack timing events now drive the cutout
  rig as `weapon_id:attack_mode:phase` variants, so windup/release/pulse/burst/
  deploy/channel beats reuse Animator-owned poses without changing weapon
  damage, targeting, VFX spawn, or balance; animation smoke covers all current
  playable class weapon variants.

- Refactor (SCRUM-198): `ProgressionData` стал compatibility facade, а данные
  вынесены в domain owners: characters, weapons, rewards/artifacts, shop,
  ascension, balance и enemies; public constants/API сохранены для старых smoke
  и runtime-ссылок без изменения баланса.

- Bugfix (SCRUM-230): в выборе героя текст Возвышения возле кнопки старта теперь показывает только изменение выбранного уровня (`Уровень N: ...`), а не весь кумулятивный список 1..N; полный список сохранен для tooltip/кодекса.

- Content (SCRUM-192): `sprite_path` новых классов выровнен с canonical registry — Вор, Элементалист, Снайпер, Священник, Биолог и Инженер теперь используют собственные full-art PNG вместо proxy-спрайтов старых классов; добавлен focused registry alignment test на все 17 персонажей.

- Tests (SCRUM-203): добавлен focused UI no-overlap matrix test для main/settings/codex/patch/hero/victory/death peer-controls на 1152x648, 1280x720, 1600x900 и 2560x1440; rect dump пишется в `build/qa/ui_no_overlap_matrix.md`.

- Tests (SCRUM-202): umbrella `tests/runtime_smoke_test.gd` сохранен как главный smoke path, а регрессии разложены на focused suites: `runtime_smoke_ui_test.gd`, `runtime_smoke_combat_test.gd`, `runtime_smoke_progression_economy_test.gd`, `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_boss_elite_test.gd`.

- Refactor (SCRUM-196): `ClassWeapon` переведен с длинного `attack_mode` dispatch-match на публичный registry executor-ов; focused weapon smoke и umbrella smoke проверяют, что каждый data-driven `attack_mode` из `ProgressionData.WEAPONS_BY_CLASS` имеет зарегистрированный executor.

- Performance (SCRUM-197): добавлен `CombatTargetQuery` с per-frame cache для enemy target lookups; hot-path запросы в ClassWeapon/BerserkWeapon/player ultimates/allies/summoner переведены на nearest/radius/corridor/segment helpers, добавлен focused cache test.

- Баланс-аудит (SCRUM-190): добавлен сценарный survivability harness для fragile/steady/sturdy/tank профилей и roster projection по реальным классам; отчеты `build/survivability_report.md` и `build/survivability_scenarios_report.md` фиксируют текущие TTD/mitigation слои без изменения балансовых констант.

- Локализация (SCRUM-210): добавлен data-driven русский глоссарий `scripts/glossary.gd`, вкладка «Глоссарий» в Кодексе, пунктирные интерактивные термины и tooltip hook (hover / Alt+hover для popup-контекста); русифицированы ключевые visible strings магазина, level-up наград, HUD и кодексных описаний.

- Bugfix (SCRUM-211): товары магазина перенесены из старой правой wall-зоны в центр нового shop backdrop; frameless стиль и node-bound stock сохранены, runtime smoke проверяет центр группы (`center_delta_x=0.0`) и no-overlap на 1280x720/2560x1440.

- UI Art (SCRUM-147): user correction applied — Parchment & Wax Seal remains only on buttons, button PNGs are taller so the wax seal fits, and all non-button panels/cards/HUD/tooltips/shop frames were restored to the old interface look; active preview `docs/design/previews/ui_button_only_legacy_panels_contact.png`, pipeline `tools/apply_button_only_ui_revert.py`.

- UI Theme (SCRUM-222): Back-end style layer remains path-compatible — buttons use real primary/secondary/danger 4-state Parchment & Wax Seal PNG (`idle/hover/pressed/disabled`), while `dark_fantasy` non-button frame paths now visually mirror the old interface after the SCRUM-147 correction.

- Bugfix (SCRUM-231): на экране выбора героя роза характеристик снова вынесена из рамки досье в плавающий правый верхний виджет; досье/описание остаются слева от радара и no-overlap проверяется на 1280x720, 1600x900 и 2560x1440.

- UI (SCRUM-224/SCRUM-225/SCRUM-226/SCRUM-227): экран выбора героя собран в единую правую информ-панель (досье слева от радара), выбор оружия показывает PNG-спрайт и русские статы в легких кликабельных карточках, level-up варианты стали text-field карточками без тяжелой reward-button рамки, а wax-seal кнопки подняты до читаемой высоты с компактным no-seal стилем для utility/dropdown controls. Runtime smoke пишет dumps `build/qa/hero_select_radar_rects.md`, `weapon_select_clean_layout.md` и `parchment_button_seal_sizes.md`.

- Tests (SCRUM-228): стабилизирован `tests/melee_weapon_targeting_test.gd` — hammer AoE блок теперь ждет один frame после добавления enemies, чтобы тест не читал устаревший per-frame target cache; production `combat_target_query.gd` не менялся.

- UI Art (SCRUM-223): игровой курсор заменен на выбранный пользователем dark steel dragon/clawed fire pointer — default/hover/attack PNG обновлены в `assets/sprites/ui/cursor/`, hotspot выверен на `(2, 2)`, preview `docs/design/previews/cursor_clawed_fire_before_after.png`.

- UI Art (SCRUM-229): панели/окна/плашки/чекбоксы переведены с временного legacy вида на leather+gold dark fantasy kit из пользовательских референсов `docs/design/references/interface/`; добавлен пайплайн `tools/build_leather_gold_ui_kit.py`, source kit `assets/sprites/ui/frames/leather_gold/`, live replacements для `dark_fantasy/global/escape/shop/system` PNG и QA preview `docs/design/previews/interface_leather_gold_panel_kit_contact.png`.

- Art (SCRUM-156): подготовлены 9 финальных painterly D&D source sprites для новых боссов и мини-элиток SCRUM-155 — `boss_bone_archon`, `boss_brood_mother`, `boss_ashen_colossus`, `mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`, `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`; все PNG `512x512` RGBA transparent, preview `docs/design/previews/new_bosses_mini_elites_contact.png` и scale-лист `new_bosses_mini_elites_scale_preview.png`.

- Баланс-аудит (SCRUM-188): добавлен route-level отчет `build/route_economy_xp_model.md` для balanced/combat-heavy/shop-heavy маршрутов; модель подтверждает 8-9 level-up и healthy/high покупательную способность, поэтому текущий XP uplift +7.1% оставлен без дополнительного повышения.

- Animation API (SCRUM-208): добавлен Back-end side-channel `weapon_animation_event` для delayed/pulse/deploy/channel оружия; phase metadata (`windup/release/pulse/burst/deploy/channel/recover`) идет из существующих gameplay таймингов и не меняет урон, targeting, VFX spawn или баланс.

- Visual integration (SCRUM-170): центральные экраны получили role-specific dark fantasy backdrops из `assets/backgrounds/ui/` с cover scaling: cathedral для системных экранов, merchant archive для магазина, arcane lab для event/level-up/meta, reward hall для наград/победы и crypt для поражения/danger screens.

- Visual integration (SCRUM-157): призывные союзники и deployables теперь различаются по источнику — Друидский амулет выбирает beast/pack-spirit, гомункул Химика использует отдельный homunculus sprite, звуковой усилитель и вороний тотем ставят собственные field sprites без изменения баланса и cleanup-групп.

- VFX (SCRUM-181): все 19 активных `assets/sprites/effects/*.png` перерисованы в более сдержанный painterly D&D/tabletop стиль без кислотного неона и голой геометрии; добавлены before/after и meadow/marsh readability previews, Godot import и `attack_vfx_smoke_test` проходят.

- UI Art (SCRUM-182): derived stat icons, shop-only icons and shop state sprites refreshed in-place as compact fantasy raster objects/frames with transparent alpha; added before/after and 40px readability previews for Escape stats, level-up, shop and tooltip usage.

- Design Audit (SCRUM-183): confirmed obsolete legacy placeholder/root prototype sprite candidates and updated Back-end cleanup handoff; no runtime assets were deleted in Design scope, with live exceptions documented for `berserk_walk_sheet_v2.png`, `enemy_projectile_magic_64.png`, and active `assets/sprites/enemies/*.png`.

- Bugfix (SCRUM-207): магазин больше не регенерирует сток при повторном открытии того же shop-узла — набор товаров привязан к конкретной точке маршрута, купленные позиции остаются снятыми со стены, повторная покупка невозможна; новый shop-узел получает свежий сток.

- UX (SCRUM-205): Escape в активном забеге теперь везде открывает единое меню паузы поверх текущего экрана; досье персонажа доступно кнопкой из этого меню, повторный Escape возвращает к подлежащему экрану без сброса состояния. Магазин получил единый «Назад», события показывают «Назад» с пояснением, если skip недоступен.

- Bugfix (SCRUM-206): на экране выбора героя радар характеристик увеличен до 370x230, опущен ниже шапки и получил резервное пространство в досье; runtime smoke проверяет rect/no-overlap на 1280x720, 1600x900 и 2560x1440, dump сохранен в `build/qa/hero_select_radar_rects.md`.

- Bugfix (SCRUM-172): исправлена потенциальная «немая» аудио-конфигурация — `master_volume=0` больше не hard-mute'ит Master bus, старые профили с нулем без явного intent-флага мигрируют к 100%, кроссфейд музыки сбрасывает застрявшие low-volume состояния, а вкладка «Звук» получила кнопку «Сбросить звук по умолчанию».

- UI (SCRUM-160): магазин больше не показывает товары в золотых карточках — предметы висят на стене фона как реальные товары лавки, с контактной тенью, компактным ценником с монетой, hover tooltip, затемнением недоступного товара и empty-hook состоянием после покупки; runtime smoke проверяет отсутствие frame-style слотов и no-overlap на 1280x720/2560x1440.

- Контент (SCRUM-164): добавлен финальный класс Class Sheet — Инженер (`engineer`) с 3 уникальными оружиями: ключ часового (`engineer_sentry_link`), ремонтный дрон (`engineer_repair_drone`) и минная сетка (`engineer_pressure_mines`); выбор героя/кодекс/тесты расширены под 17 классов и 51 weapon variant. Арт и rig/motion переданы Design/Animator handoff-задачами.
- Арт (SCRUM-164): подготовлен canonical Engineer visual kit — `assets/sprites/characters/engineer.png`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_repair_drone.png`, `assets/sprites/weapons/engineer_pressure_mines.png`; добавлен preview `docs/design/previews/engineer_art_contact.png`, Godot import и PNG/alpha validation пройдены.

- Контент (SCRUM-166): добавлен класс Робот (`robot`) с 3 уникальными оружиями — магнитный якорь (`robot_magnetic_anchor`), гидравлический пресс (`robot_compression_line`) и реакторное ядро (`robot_reactor_vent`); выбор героя/кодекс/тесты расширены под 16 классов и 48 weapon variants. Runtime smoke blocker по indentation в weapon-mechanics awaits исправлен. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.
- Арт (SCRUM-166): подготовлен canonical Robot visual kit — `assets/sprites/characters/robot.png`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `assets/sprites/weapons/robot_hydraulic_press.png`, `assets/sprites/weapons/robot_reactor_core.png`; добавлен preview `docs/design/previews/robot_art_contact.png`, Godot import и PNG/alpha validation пройдены.

- Контент (SCRUM-162): добавлен класс Биолог (`biologist`) с 3 уникальными оружиями — споровая линза (`bio_spore_bloom`), инъектор образцов (`bio_sample_dart`) и семя симбионта (`bio_symbiote_web`); выбор героя/кодекс/тесты расширены под 15 классов и 45 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.
- Арт (SCRUM-162): подготовлен canonical Biologist visual kit — `assets/sprites/characters/biologist.png`, `assets/sprites/weapons/biologist_spore_lens.png`, `assets/sprites/weapons/biologist_sample_injector.png`, `assets/sprites/weapons/biologist_symbiote_seed.png`; добавлен preview `docs/design/previews/biologist_art_contact.png`, Godot import и PNG/alpha validation пройдены.

- Контент (SCRUM-165): добавлен класс Священник (`priest`) с 3 уникальными оружиями — светлый реликварий (`priest_sanctify`), кадило обета (`priest_ward`) и колокол молитвы (`priest_prayer_chain`); выбор героя/кодекс/тесты расширены под 14 классов и 42 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Контент (SCRUM-167): добавлен класс Снайпер (`sniper`) с 3 уникальными оружиями — винтовка Мертвого Глаза (`sniper_lockshot`), прицел Наводчика (`sniper_kill_zone`) и осколочные патроны (`sniper_split_round`); выбор героя/кодекс/тесты расширены под 13 классов и 39 weapon variants. Runtime smoke blocker по GDScript type inference в sniper weapon methods исправлен явными типами/casts. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Музыка (SCRUM-154): меню и бой переведены на струнный тавернный эмбиент (RandomMind, CC0/OpenGameArt) — «The Old Tower Inn» в меню, «Minstrel Dance» в бою, тёмная вариация «Battle» в босс-бою; бесшовные лупы (шов меню сглажен микро-фейдом), громкость треков нормализована к одному уровню, добавлен кроссфейд меню↔бой 0.9с; источники и лицензии в docs/design/audio.md.

- Контент (SCRUM-163): добавлен класс Элементалист (`elementalist`) с 3 уникальными оружиями — кольцо стихий (`elemental_orbit`), призматический фокус (`prism_rift`) и ядро метеора (`meteor_shards`); выбор героя/кодекс/тесты расширены под 12 классов и 36 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Контент (SCRUM-169): добавлен класс Вор (`thief`) с 3 уникальными оружиями — кошель рикошета (`coin_ricochet` + steal money), плащ захода (`shadow_backstab`) и дымовая бомба (`smoke_bomb` + временный dodge); выбор героя/кодекс/тесты расширены под 11 классов и 33 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Контент (SCRUM-168): добавлен класс Солдат (`soldier`) с 3 уникальными оружиями — аркебуза строя (`suppression_burst`), граната с фитилем (`grenade_cook`) и штык-стойка (`bayonet_brace`); подключены canonical Soldier character/weapon PNG, выбор героя/кодекс/тесты стали data-driven под 10 классов и 30 weapon variants. Rig/motion передан Animator handoff-задачей.

- Контент (SCRUM-155, ч.2): 3 новых финальных босса — Костяной Архонт (волны скелетов, веер черепов, костяная стена с проходом), Матерь Роя (выводок паучат, паутинные зоны замедления, рывок в финальной фазе) и Пепельный Колосс (slam-волны с тлеющими зонами, энрейдж ниже четверти HP); ротация финального узла теперь из 5 боссов, у всех русские титулы в баннере появления, кодекс пополнен. Арт — placeholder с тинтом до готовности SCRUM-156.

- Visual: добавлены dark fantasy UI backdrops `2560x1440` для экранов с центральными окнами и заменен арт главного меню на новую battle-сцену с героями/боссами FantasyDisk; существующие shop/event/campfire background paths обновлены совместимо, расширенное screen-role подключение вынесено в Back-end handoff.

- Контент (SCRUM-155, ч.1): свита Возвышения L7 получила 6 data-driven видов мини-элиток (Жнец-Падальщик, Чумной Звонарь, Костяной Страж, Искровик, Гнилая Гончая, Теневой Пожиратель) — каждый со своим профилем HP/скорости/урона и тинт-идентичностью на placeholder-спрайтах; свита выбирает случайный вид. Все 6 добавлены в кодекс (раздел «Мини-элитки»). Боссы ростера — следующим инкрементом.

- UX/баланс: Escape в активном забеге теперь открывает досье персонажа поверх боя, карты, магазина, события, level-up, докачки и награды элитки; досье показывает портрет, оружие, уровень/XP, Возвышение и выделяет приоритетные атрибуты класса из единого `ATTRIBUTE_PRIORITIES`.

- Баланс: level-up переведен на 3 фиксированных варианта, редкие основные характеристики стали существенно реже (~5% на слот), обычные награды взвешены по профильным атрибутам класса; вампиризм получил cap лечения в секунду и малую долю урона, а регенерация/защита/уклонение усилены.

- UX: экран победы очищен от технических строк (`Meta points`, raw `asc_` IDs) и показывает только русский пользовательский итог: победа над боссом, очки наследия, прогресс Возвышения и смысл новой награды.

- Bugfix: cleanup эффектов оружия стал устойчивее при смене оружия Гитариста — отложенные callbacks старого усилителя больше не создают новые VFX после cleanup; summon-союзники Друида получили корректный импорт ассетов и устойчивый spawn parent.

- UX: вкладка «Звук» в настройках получила читаемые слайдеры громкости — видимый трек на всю ширину, отличающуюся заполненную часть, шаг 2%, keyboard focus и понятный mute-переключатель «Вкл./Выкл.»; QA-скриншот сохранен в `build/qa/settings_volume_slider_ux.png`.

- Баланс: дроп и экономика перебалансированы по классам целей — bruiser/shield, мини-элитки, элитки и боссы дают заметно больше XP/золота; магазин, докачка, reroll и платные event-исходы подорожали через общий multiplier x1.10; XP-кривая замедлена до `ceil(req*1.42+3)`. Balance harness показывает +10.6% эффективной покупательной способности и +7.1% XP в типовом маршруте.

- Bugfix: верхний боевой HUD больше не пересекается на 1152x648/1280x720/2560x1440 — ресурсная панель адаптивно сжимается, таймер/бейдж Возвышения уступают место, ряд артефактов переносится ниже при нехватке ширины; runtime smoke пишет `build/qa/hud_no_overlap_rects.md`.

- Visual: добавлен D&D/painterly набор призывных союзников и deployable-объектов (`assets/sprites/allies/`); `AllyMinion.tscn` получил raster fallback вместо Polygon2D-placeholder, а source-specific mapping вынесен в Back-end handoff.

- Visual: 4 элитки (`iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`) и 2 босса (`boss_rift_warden`, `boss_disk_devourer`) переведены на native 512x512 PNG и перенарезаны в cutout rig pipeline, чтобы убрать мыло на epic scale в QHD/Retina без изменения хитбоксов и gameplay scale.

## [0.1.3] — 2026-06-12

- Элитки и боссы — крупнее, сложнее, эпичнее: элитки ~1.73x, боссы ~2.35x моба с согласованными хитбоксами; в фазе 2 элитки бьют чаще (-20% кулдаун) и получают второе применение атаки, боссам добавлен паттерн «волна зон» с гарантированным безопасным коридором; подача — баннеры появления, умеренная тряска камеры (тумблер «Тряска камеры» в настройках) на спавне/ударах/смерти и hit-stop на смерти элитки/босса.

- UX: level-up теперь дает 5 фиксированных вариантов, ровно 1 выбор за уровень, редкие основные характеристики с visual rare-пометкой и отложенный выбор через Escape/«Позже» + нижнюю кнопку «Повышение уровня (N)».

- UX: убрано дублирование входа в level-up — при pending-уровнях видна только нижняя кнопка с бейджем, а `UpgradeFabButton` остается отдельным режимом докачки атрибутов за золото при pending=0.

- UX: экран выбора героя переведен на v3-компоновку — крупный портрет слева, досье/оружие/Возвышение/программный радар 8 BASE_STATS справа, лента 9 героев снизу и отдельная кнопка «Выбрать» для перехода к оружию.

- Bugfix: выбор героя v3 очищен от layout-дублей — нижняя карусель теперь только из картинок без подписей, радар характеристик вынесен в правый верхний угол, имя героя осталось только в досье.

- Bugfix: окно «Трофей элитки» больше не уезжает в правый нижний угол — панель центрируется через full-rect `CenterContainer`, а smoke-тест проверяет фактический `global_rect` центр на 1280x720, 1469x908 и 2560x1440.

- Bugfix: в босс-бою больше не создается замороженная панель таймера — boss combat flags выставляются до создания HUD, а smoke-тест проверяет фактическое отсутствие `CombatTimerPanel`/`timer_label`.

- Награда элитки: окно выбора 1 из 3 артефактов переоформлено крупными карточками (иконка 112px, название и тир в цвете тира, эффект, классовая интерпретация), центрировано на любом разрешении, выбор обязателен (Escape не закрывает), добавлена навигация клавиатурой/геймпадом (стрелки + Enter); награда гарантированно показывается до экрана докачки даже если элитка пала на последней секунде таймера.

- VFX: боссовский hazard смены фазы переведён с голого красного круга на оформленный HazardVfx (баг QA); 19 эффект-спрайтов перерисованы в приглушённый D&D-стиль (без неона).

- Bugfix: рестайл 6 новых классов (Ассасин/Рейнджер/Доктор/Химик/Рыцарь/Друид) реально подключён в выбор героя — игра загружала placeholder-спрайты вместо принятого арта.

- Чистка проекта: обновлен conservative audit `tools/audit_unused_assets.py`, из `assets/` вынесены obsolete preview/source PNG и временные `.DS_Store`/swap в `build/cleanup_backup_2026_06_12/`; активные фоновые ресурсы `field_dry_road`/`field_stone_garden` восстановлены после missing-resource проверки.

- VFX: DoT-тики на врагах получили искру-маркер; level-up эффект и баннер переведены с программных Polygon2D/ColorRect на текстурные спрайты (вспышка/кольцо/искры); перф на 120 врагах с зонами в норме.

- VFX: лечение игрока получило зелёный восстановительный отклик (пульс+искры) вместо безмолвного хила; подтверждено, что ульты 9 классов уже на оформленном VFX.

- Возвышения 2.0: режим усложнения из 10 кумулятивных уровней (враги/цены/орда/элитки/трофеи/лечение/мини-элитки/таймер/босс/макс-HP), прогресс и разблокировка по персонажу, селектор в выборе героя, HUD-индикатор, раздел кодекса; старые asc-баффы стали наградным треком меты.

- VFX: аура командира-элитки получила визуальный пульс (золотая расходящаяся волна) вместо невидимого бафа.

- Анимация оружия: held-оружие в сокете получило отдачу/выпад/подъём по типу атаки (anticipation→удар→follow-through), снаряды — трейлы; ранее статичные дальнобой/каст-оружия ожили.

- VFX: опасные зоны (боссовские rift/disk-slam и зона смены фазы, элитный яд и лужи) переведены с голых программных кругов на оформленный телеграф→детонацию (HazardVfx) с бурлящими лужами яда.

- Боевые фоны: переотрисованы как профессиональные D&D-батлмапы (2560x1440, top-down) и расширены до 10 активных арен; добавлены 6 новых фонов без крупных камней/кустов (`ruined_courtyard`, `misty_marsh`, `dusty_badlands`, `enchanted_meadow`, `ashen_rift`, `cursed_grove`), подключены в ротацию боев/боссов.

- Баланс классов: добавлен Godot budget harness `tools/balance_harness.gd`, отчет `build/balance_report.md`, профили solo/aoe/balanced+tank для 27 пар класс+оружие, auto budget tuning и smoke-проверка отклонения ≤ ±10% по solo и 5-target DPS.

- Сложность акта: добавлен единый `stage_scale` для силы монстров и цен, усилены обычные волны, элитки получили HP-бюджет под ~45-90с и награду 1 из 3 артефактов, боссы получили 3 HP-фазы с фазовыми hazard-зонами и гарантированный tier-3 артефакт за победу.

- Случайные события: добавлен data-driven пул из 12 сценариев с историями, 2-3 выборами, no-repeat за акт, attribute checks, отдыхом, наградами с ценой и боевыми исходами через временный event combat payload.

- Debug cleanup: убран Godot debug spam `Lambda capture ... was freed` в level-up intro и weapon VFX/deploy callbacks; editor/import, runtime smoke и animation smoke проходят без красных ошибок в свежем Godot log.

- VFX-полировка: persistent pools Химика/Друида больше не программные круги — добавлены растровые `poison_pool`, `spark_pool`, `briar_pool` с мягкой пульсацией/fade-out и QA preview.

- VFX-арт: все 19 PNG в `assets/sprites/effects/` перерисованы в сдержанный D&D/tabletop стиль без кислотного неона и пересветов; preview-лист использовался для QA и затем вынесен из runtime assets чисткой проекта, import + attack/runtime smoke green.

## [0.1.2] — 2026-06-12

- UI: тёплый рестайл интерфейса под D&D-таверну — рамки/панели/кнопки/окна из тёмного дерева и кожи с латунной окантовкой и заклёпками, системные иконки в тёплом золоте, без циановых самоцветов; светлый текст сохранён читаемым.

- Артефакты: старый pictogram/пентаграммный набор заменен на 53 realistic epic D&D/tabletop raster magic item PNG (`256x256`, RGBA, transparent), с предметами по смыслу каждого artifact ID и QA-превью `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`.

- Оружие v2: перерисованы `long_spear`, `tower_shield`, `holy_flail`, Рыцарь переведен на unarmed base sprite без встроенного копья/щита, все 27 weapon scenes теперь используют matching PNG и уменьшенный visual scale для лучшей читаемости персонажей.

- Design overhaul: добавлен reusable fantasy UI texture kit (`assets/sprites/ui/frames/global/`, system icons), основные панели/кнопки/HUD/level-up/route nodes переведены на texture frames; 4 боевых фона заменены на плоские top-down 2560x1440 ground textures; добавлены отдельные motion profiles для 6 новых классов.

- Новые классы (art pass): 6 полноценных dark fantasy full-art спрайтов персонажей (512x512 RGBA) и 6 weapon PNG (256x256 RGBA) для Ассасина/Рейнджера/Доктора/Химика/Рыцаря/Друида приняты Design-review. Cutout rig-части нарезаны `tools/slice_rig_cutouts.py` и добавлены в `assets/sprites/characters/cutout/`; манифест `scripts/sliced_rig_manifest.gd` обновлён.

- Шесть новых классов (фундамент): Ассасин, Рейнджер, Доктор, Химик, Рыцарь, Друид — статы, сигнатурное оружие с механиками архетипов, релевантность/аффинити/вознесение/кодекс; Design visual set готов: новые герои art-approved, полный набор 27 weapon PNG для 9 классов добавлен в `assets/sprites/weapons/`.

- Полный набор атрибутов: подключены поглощение, регенерация, вампиризм (новый артефакт «Клык Пиявки»), дальность отталкивания, множитель дальности; «Сила ульты» теперь усиливает ultimate ability.

- Настройки v2: выбор монитора при нескольких экранах, честные оконные разрешения (масштаб ОС, центрирование, без вылезания за экран), слайдеры громкости Общая/Музыка/Эффекты с mute-чекбоксами, сохранение в user://settings.cfg.

- UX: выбор героя переведен в fullscreen 3x3 grid без скролла — все 9 классов видны сразу, портреты крупнее, статы перенесены в tooltip/нижнюю панель.

- Классовая идентичность: 9 классов разведены по уникальным паттернам — crit dash Ассасина, stance charge Рейнджера, drain-link Доктора, combo clouds Химика, block/counter Рыцаря и command pets Друида; кодекс и smoke-проверки обновлены.

- Прогрессия: вторичные атрибуты стали универсально полезными для всех классов — старая фильтрация «нерелевантных» статов отключена, level-up/докачка/артефакты показывают иконки и интерпретации, чужие affinity-эффекты работают через class-specific hooks (magic enchant, DoT, echo weapon, battle shout, Energy cooldown/charge scaling).

- Берсерк: data-driven конфиг двуручного меча синхронизирован со сценой и актуальным геймплеем — вместо старой узкой `strip`-полосы теперь используется `frustum`-замах 90° радиусом 600; melee targeting regression test обновлен под новую геометрию.

- Настройки: экран разделен на вкладки «Экран» / «Звук» / «Управление», аудио-слайдеры стали full-width и снова видимы на 1280x720, добавлены persisted keybindings для движения/паузы/`ultimate` с конфликт-чеком и reset defaults.

- Ультимейты: добавлен data-driven framework заряда 0-100 от урона/полученного урона, HUD-шкала `ULT`, активация через ребиндящийся action `ultimate`, boss damage cap и 9 классовых ульт: Неистовство, Темная буря, Соло, Танец клинков, Лунный залп, Переливание, Цепная реакция, Бастион, Зов стаи.

## [0.1.1] — 2026-06-11

- Hotfix сборки: исправлен битый NSIS CRC Windows-инсталлера (makensis на macOS писал неверную контрольную сумму), добавлены SHA256SUMS.txt.

- Прогрессия: классовая релевантность атрибутов (чужие damage-статы не предлагаются и честно отражены в превью), фикс эксплойта бесплатного реролла — наборы level-up и пары докачки фиксируются до выбора.

- Иконки артефактов: финальный Design pass — все 52 активные `artifact_*.png` переведены в `256x256` epic dark fantasy item icons с прозрачным фоном, усиленной светотенью/магическими акцентами и 40px preview; инструмент `tools/final_redesign_artifact_icons.py`.
- Флоу забега: баннер «Победа» после боя, окно докачки атрибутов за золото (1 из 2, reroll x2), желтая FAB-кнопка прокачки на небоевых экранах с бейджем уровней.
- Экономика: цены магазина x3.5; артефакты получили тиры 1-3 (сила x2.5, редкость и цена по тиру), 6 новых легендарных билдообразующих артефактов; классовая совместимость class_affinity с честными пометками в магазине/наградах/HUD/паузе/кодексе.
- Классы/оружие: у всех 9 классов теперь по 3 выбираемых стартовых оружия (27 weapon IDs); добавлены backend-режимы `stab_flurry`, `dot_beam`, `trap`, summon/deploy fallback-сцены и smoke-проверка всех вариантов.

- UX: Escape возвращает назад на всех экранах (единый стек, в бою — пауза), карточки персонажей кликабельны целиком с hover, крупнее картинки в кодексе/HUD/паузе/магазине, pointer-курсор на кнопках, подключение фона карты route_map_backdrop.png с fallback.

- Анимации: вариантные замахи Берсерка под формы оружия (выпад/дуга/верхний слэм), фазовые анимации уникальных атак элиток, переработанный walk Темного Мага.

- Кодекс в главном меню: энциклопедия персонажей, монстров (с каноническими именами умений), артефактов и характеристик.

- Сборочная инфраструктура релизов: Windows-пресет (x86_64, embed_pck, icon.ico), `tools/build_release.sh` (worktree-сборка из тега, dmg + NSIS-инсталлер + zip), `tools/windows_installer.nsi`.

- Усиление элиток: размер x1.35, уникальные телеграфированные атаки.
- HP-бары над всеми монстрами, элитками и боссами: синхронизация с фактическим `health / max_health` после runtime-скейлинга и после урона; ревизия контактных хитбоксов, красная виньетка урона.
- Идентичность оружия Берсерка: меч — узкая полоса, топор — широкая дуга, молот — слабый старт/мощный рост.
- Фикс прицеливания: атака всегда по ближайшему врагу.
- Усиление Темного Мага (2 луча, 2 взрыва), переработка Гитариста (бас — скорость/контроль, амп — деплой с лимитом от Лидерства).
- Артефакты: иконки в HUD/паузе, размещение в магазине на «стене», dark-fantasy рестайл 46 иконок артефактов до 256x256.
- Артефакты: 46 иконок перегенерированы в dark-fantasy стиле элиток/боссов, 256x256 PNG с прозрачным фоном; финальное Design review принято, точечные доработки old_codex/ink_candle/summoners_bell.
- Артефакты: v3 pass — 52 иконки перегенерированы в glossy RPG item style с визуальными тирами 1-3, 256x256 PNG с прозрачным фоном; готово к Design review.
- Артефакты: финальный пользовательский rework — все 52 иконки заменены в яркий, жуткий epic dark fantasy artifact style (черненый металл, кость, руны, трещины, магические акценты), 256x256 PNG с прозрачным фоном.
- Стилизованный таймер боя с красной подсветкой на последних 5 секундах.
- Фоны арены в нативном 2560x1440.
- Жутковатый нейтральный фон маршрутной карты `route_map_backdrop.png` в 2560x1440.
- Полное код-ревью, чистка debug-ошибок и мертвого кода.

## [0.1.0] — 2026-06-11

Первая зафиксированная версия (срез разработки).

- Полный игровой цикл: меню → выбор персонажа и оружия → вертикальная маршрутная карта → бои/события/магазин/костер → финальный босс.
- 3 класса: Берсерк (меч/топор/молот), Темный Маг (книга/череп/палочка), Гитарист (электро/бас/усилитель).
- Монстры, элитки (4), боссы (2), волны по таймеру `30 + 5 * route_stage`.
- Мета-прогрессия: уровни вознесения (10 x 3 персонажа), артефакты (46), характеристики.
- Боевая арена 2560x1440 с камерой, зумом и физическими стенами; 4 биома фонов.
- HUD, экраны паузы/статов, настройки видео и управления.
- Smoke-тесты: runtime, animation, meta progression.
