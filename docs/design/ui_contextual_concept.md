# FantasyDisk Contextual UI Concept

Updated: 2026-06-12

## Goal

Replace the current one-size-fits-all fantasy frame language with contextual D&D/tabletop UI kits. The frame motif should tell the player what kind of screen they are in before they read the title: living wilderness for the start/hero flow, bone and ash for death, laurels and spoils for victory/rewards, tavern merchant craft for shop, field gear for route map, book/parchment for codex, and restrained leather/metal for combat HUD.

This pass is not about adding more decoration. It is about removing decoration that has no narrative job.

## Research Notes

Sources used as mood/reference logic only; do not copy layouts, logos, ornaments, icons or screenshots.

| Source | Useful Takeaway For FantasyDisk |
| --- | --- |
| D&D Beyond character sheet / builder: https://www.dndbeyond.com/characters | D&D UI works best when rule-heavy information is organized as a sheet: clear sections, tabs, class/stat identity, and automated numbers. Good reference for Codex, stats and character/weapon choice hierarchy. |
| D&D Beyond Maps / VTT coverage: https://www.polygon.com/tabletop-games/477300/dnd-beyond-maps-feature-open-beta-release-date-price-project-sigil-closed-beta | Digital tabletop map UI uses tokens, dice/log affordances and initiative tools around the play surface. Useful for route map: frame should feel like field navigation gear, not a generic modal. |
| Baldur's Gate 3 official site: https://baldursgate3.game/ | Strong class/race/background identity, character panels and fantasy presentation. Useful principle: important UI areas can carry small emblematic motifs tied to role, but gameplay readability stays dominant. |
| Larian UI commentary via GamesRadar: https://www.gamesradar.com/games/rpg/divinity-lead-says-were-taking-notes-on-all-of-the-ui-mods-for-baldurs-gate-3-we-had-more-improvements-in-mind-that-we-just-couldnt-cram-into-our-releases/ | Complex D&D/CRPG systems need UI that hides complexity in better surfaces. For FantasyDisk: contextual frames must not add visual noise to already dense stats/level-up/shop choices. |
| Darkest Dungeon official page: https://www.darkestdungeon.com/darkest-dungeon/ | Gothic UI mood is inseparable from subject matter: stress, disease, darkness and estate decay. Good reference for death/defeat: bone, ash, cracks and cold values should explain failure, not just look spooky. |
| Current FantasyDisk UI kit contact sheet: `docs/design/previews/current_ui_frames_audit_contact.png` | Current kit is clean and technically reusable, but the brass-corner/tavern motif is applied globally. It works for shop/settings, but loses meaning on death, codex, route map and victory. |

## Current Decoration Audit

Current runtime frame assets:

- `assets/sprites/ui/frames/global/ui_panel_frame.png`
- `assets/sprites/ui/frames/global/ui_button_frame.png`
- `assets/sprites/ui/frames/global/ui_card_frame.png`
- `assets/sprites/ui/frames/global/ui_level_panel_frame.png`
- `assets/sprites/ui/frames/global/ui_hud_panel_frame.png`
- `assets/sprites/ui/frames/global/ui_hud_card_frame.png`
- `assets/sprites/ui/frames/global/ui_tooltip_frame.png`
- `assets/sprites/ui/frames/escape/*.png`
- `assets/sprites/ui/shop/*.png`

Audit verdict:

| Current Detail | Problem | Keep / Remove / Reframe |
| --- | --- | --- |
| Brass studs/corner dots on nearly every frame | Good tavern/gear language, but meaningless when repeated on death, victory, route map and codex. | Keep only in merchant, settings, generic utility and compact HUD kits. |
| Same dark wood/leather fill everywhere | Reads coherent, but too uniform: death and codex should not feel like the same object as shop. | Reframe into a neutral fallback kit, not the default for every emotional screen. |
| Large curved gold strokes in corners | Decorative but not semantic. On small cards they can compete with icons/text. | Remove from most context kits; replace with motif-specific structure: vines, bone seams, page corners, rope knots. |
| Purple stat/group frame in Escape kit | Functional grouping, but weakly connected to formulas/attributes. | Keep for now; future stat kit should use ink, dividers and glyph chips instead of vague glow. |
| Shop slot heavy gold square | Has a stronger purpose than global frames: valuables/merchant display. | Keep as merchant kit basis; refine with wood, brass, price wax/seal language. |
| Generic tooltip frame | Works technically, but has no context and can appear disconnected from screen mood. | Keep as fallback; add context tooltip variants only for death/reward/codex if readability remains safe. |

## Context Map

| Screen / Area | Mood | Frame Motif | Functional Rule |
| --- | --- | --- | --- |
| Main menu / start | Living adventure, invitation, wilderness magic | Tree branches and thin vines wrapping buttons, small leaves on corners, warm moonlit green/brown | Buttons must remain high-contrast; vines should hug edges, never cross text. |
| Hero select / weapon select | Character showcase, camp before the run | Carved wood, leather straps, class sigil plates | Cards should emphasize portrait silhouettes; frame ornament must be quieter than character art. |
| Settings | Utility, workshop/tavern tools | Current tavern brass/wood kit | Preserve clarity; no bespoke drama needed. |
| Route map | Expedition planning | Parchment map edge, rope lashings, small pins, stamped node tabs | Must support scroll/pan and node readability; lines/nodes stay visually above background. |
| Event screen | Strange encounter, story prompt | Torn parchment, wax seal, small occult/object token slot | Frame should feel like a discovered note; avoid huge modal blocking background art. |
| Shop | Merchant stall, valuables, barter | Dark wood, brass trim, cloth tags, price wax seals | Current kit close; refine slots/tooltips around the shop background wall. |
| Campfire/rest | Warm safety, recovery | Soft leather, ember glow, blanket stitching, small ash flecks | Cozy but low noise; buttons can feel like cloth/leather tabs. |
| Combat HUD | Urgent readable instrument | Minimal leather/iron straps, small rivets only where they imply fastening | No ornate flourishes; HP/XP/money/ULT are instruments, not decorations. |
| Level-up / reward cards | Discovery, choice, buildcraft | Laurel leaves, gold leaf, arcane parchment, small reward sigil | Make reward cards feel valuable; keep formulas/tooltips readable. |
| Victory | Warm triumph | Laurel, gold, ribbon, sunlit metal | Strong celebratory outer panel, but buttons remain simple. |
| Death / defeat | Cold failure, decay | Bone frame, cracked stone, ash, grave-marker buttons, faded red/bone highlights | No warm tavern brass; buttons can look like grave slabs but still read as buttons. |
| Codex | Reference book, lore archive | Book cover, page edges, bookmark tabs, ink dividers | Tabs should feel like bookmarks; content panels like pages, not tavern boards. |
| Escape stats | Tactical sheet | Existing compact frame kit + future ink/stat glyph pass | Keep dense layout; do not add large motif assets that reduce stat rows. |
| Tooltips | Contextual explanation | Fallback: dark parchment. Context variants: codex page, death ash, reward gold | Tooltip padding/margins must remain stable across variants. |

## Proposed Context Kits

Keep the count small: 4 context kits plus current fallback.

### 1. Wild Start Kit

Purpose: main menu, hero select, weapon select.

Motif: dark living wood, thin vines, leaves, small natural knots. This is the "adventure starts outside the dungeon" kit.

Assets:

- `ui_wild_panel_frame.png`
- `ui_wild_button_frame.png`
- `ui_wild_card_frame.png`
- `ui_wild_tooltip_frame.png`

Avoid:

- vines crossing text;
- huge flowers;
- bright saturated green;
- random leaf clusters with no edge role.

### 2. Grave Defeat Kit

Purpose: death/defeat screen, danger confirmations, severe warning modals.

Motif: cracked bone, ash, cold stone, worn grave slab buttons. This kit should make failure feel final.

Assets:

- `ui_grave_panel_frame.png`
- `ui_grave_button_frame.png`
- `ui_grave_card_frame.png`
- `ui_grave_tooltip_frame.png`

Avoid:

- gore;
- skull stickers everywhere;
- unreadably dark text wells;
- bright red horror neon.

### 3. Laurel Reward Kit

Purpose: victory, level-up, reward selection, artifact reward cards.

Motif: laurel branches, warm gold leaf, parchment panels, subtle arcane seals where rewards appear.

Assets:

- `ui_laurel_panel_frame.png`
- `ui_laurel_button_frame.png`
- `ui_laurel_card_frame.png`
- `ui_laurel_tooltip_frame.png`

Avoid:

- casino gold;
- medal frames around every small icon;
- huge top crowns that waste vertical space.

### 4. Codex / Map Parchment Kit

Purpose: codex, route map headers/panels, event text cards.

Motif: parchment, book edge, bookmark tabs, rope/pin accents for route map. This can split by tint: book-brown for Codex, field-map tan for route map.

Assets:

- `ui_parchment_panel_frame.png`
- `ui_parchment_button_frame.png`
- `ui_parchment_card_frame.png`
- `ui_parchment_tooltip_frame.png`
- `ui_parchment_tab_frame.png`

Avoid:

- page stains under dense text;
- illegible handwritten texture behind formulas;
- random metal studs.

### Existing Tavern / Utility Kit

Purpose: shop, settings, generic fallback, some compact cards.

Current assets can remain the fallback:

- `ui_panel_frame.png`
- `ui_button_frame.png`
- `ui_card_frame.png`
- `ui_tooltip_frame.png`
- `ui_shop_*`

Refinement rule: do not extend tavern brass to screens where the screen fantasy is not merchant/workbench/utility.

## Asset Technical Spec

Target folder:

```text
assets/sprites/ui/frames/contextual/
```

Required source output:

| Asset Type | Suggested Size | Runtime Use |
| --- | --- | --- |
| panel frame | 256x256 RGBA | `StyleBoxTexture` for large windows |
| button frame | 220x96 RGBA | `StyleBoxTexture` normal/hover/pressed tint base |
| card frame | 220x180 RGBA | hero/reward/codex/route cards |
| tooltip frame | 240x140 RGBA | stable tooltip frame |
| tab frame | 180x72 RGBA | codex/map bookmarks/tabs |

Patch margins:

- panel: left/right/top/bottom 34-42 px;
- button: left/right 34 px, top 24 px, bottom 28 px;
- card: 30-36 px;
- tooltip: 28-34 px;
- tab: 24-30 px.

All assets must:

- be transparent PNG;
- have no text, watermark, logos or copied ornaments;
- have a clean central content well;
- keep ornament mostly on edges/corners;
- remain readable at 1280x720 and 2560x1440;
- avoid one-note purple/cyan glow;
- preserve a stable rectangular interaction affordance.

## Screen Assignment Draft

| Screen | Kit | Asset Notes |
| --- | --- | --- |
| Main menu | Wild Start | Buttons with vine edges; no dark overlay on the left if background already supports readability. |
| Character select | Wild Start + fallback cards | Wild panel shell, quieter cards to keep portraits dominant. |
| Weapon select | Wild Start + class sigil plates | Same as character select; weapon cards can keep current card proportions. |
| Route map | Parchment / Map | Header and node detail panels only; node icons remain their own art. |
| Event | Parchment / Map | Story choices as parchment buttons. |
| Shop | Tavern / Utility | Keep shop kit; refine later only if it fights merchant background. |
| Campfire | Tavern warm variant | Could use utility kit with ember tint until a dedicated rest kit is justified. |
| Combat HUD | Tavern minimal / leather metal | Existing HUD frames OK; remove decorative arcs if they distract at small size. |
| Level-up | Laurel Reward | Reward cards and main panel. |
| Victory | Laurel Reward | Panel/buttons. |
| Death | Grave Defeat | Full screen panel/buttons. |
| Codex | Parchment / Book | Main panel, tabs, tooltips. |
| Escape stats | Existing Escape kit | Keep compact; future stat sheet pass may merge into parchment. |

## Codex Design Generation Task

See `docs/tasks/codex_design_contextual_ui_frame_kits_generation_task.md`.

## Back-end Integration Handoff

See `docs/tasks/backend_contextual_ui_frame_theme_integration_task.md`. This is intentionally blocked until the new context kit PNGs exist and pass Design review.
