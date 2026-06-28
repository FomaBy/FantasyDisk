# UI Mockup Spec - Elite Artifact Reward 2K

Status: blocked_openai_api_key_missing
Role owner: Design
Task: docs/tasks/SCRUM-572_elite_artifact_reward_2k_design.md
Jira: SCRUM-572
Base resolution: 2560x1440
Responsive targets: 1920x1080, 2560x1440, 3840x2160
Mockup PNG: blocked - OpenAI Images API generation did not run
Preview PNG: blocked - no generated PNG exists
Generated with: intended OpenAI Images API via fantasydisk-ui-director + fantasydisk-asset-generator

## Source Request

Design-only stage for the elite artifact reward screen. Create an OpenAI-API-generated 2K mockup/spec/source package for the screen that appears after an elite victory and asks the player to choose 1 artifact from 3. Do not edit `scripts/ui_screens.gd` or runtime integration files.

## Generation Blocker

The required generator command failed before contacting OpenAI because `OPENAI_API_KEY` is not present in the shell environment, `C:\Users\FomaE\.codex\.env`, or the worktree `.env`.

Command attempted:

```powershell
python C:\Users\FomaE\.codex\skills\fantasydisk-asset-generator\scripts\generate_asset.py --prompt "<prompt below>" --output scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup_source.png --size 2560x1440 --quality high --no-task
```

Generator result:

```text
error: OPENAI_API_KEY is not set (looked in env and C:\Users\FomaE\.codex\.env, C:\Users\FomaE\OneDrive\Documents\Fantasy Disk SCRUM-572\.env)
```

No manual, local, or non-API mockup substitute was created because the UI skill requires blocking when OpenAI API generation is unavailable.

## Prompt To Re-run

```text
FantasyDisk elite artifact reward screen, full 2K 2560x1440 game UI mockup, Dungeons and Dragons dark fantasy dragon style, reward hall backdrop, centered heroic modal frame for elite victory reward, three tall artifact choice cards in one horizontal row, each card has an ornate metal frame with ruby accents and a large empty dark inner content zone for runtime icon/title/description/button, visible safe padding between content zone and border, top title banner area and subtitle band inside modal, bottom continue/choose affordance zones, no readable text, no letters, no numbers, no watermark, no logo, no character portraits, no content overlapping frame ornaments, clean orthographic UI layout, crisp 2D game interface, restrained graphite obsidian aged brass muted gold ruby accents, dragon claw corners and subtle scale motifs, clear separation of decorative border versus empty content zones, production-quality UI concept art
```

## Screen Elements

| ID | Type | Runtime content | Rect @ 2560x1440 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| reward_backdrop | TextureRect | `ui_backdrop_reward_hall` cover image + shade | 0,0,2560,1440 | full rect | 1280x720 | 0 | static | n/a |
| modal_frame | Frame/Panel | central reward shell | 320,126,1920,1188 | center | 1440x860 | 10 | static | modal_safe |
| modal_safe | Content zone | all modal runtime content | 466,248,1628,924 | center within modal | 1180x660 | 11 | static | modal_frame |
| title_band | Content zone | title `Награда элитки` | 660,250,1240,112 | top-center | 900x76 | 20 | static | modal_frame |
| subtitle_band | Content zone | instruction `Выбери 1 артефакт из 3` | 720,370,1120,58 | top-center | 820x44 | 20 | static | modal_frame |
| cards_row | HBox area | 3 artifact choices | 496,466,1568,650 | center | 1160x480 | 20 | modal/card states | modal_safe |
| artifact_card_0 | Button/Card frame | artifact choice | 496,466,464,650 | row left | 340x470 | 30 | default/hover/focus/pressed/disabled | card_0_safe |
| artifact_card_1 | Button/Card frame | artifact choice | 1048,466,464,650 | row center | 340x470 | 30 | default/hover/focus/pressed/disabled | card_1_safe |
| artifact_card_2 | Button/Card frame | artifact choice | 1600,466,464,650 | row right | 340x470 | 30 | default/hover/focus/pressed/disabled | card_2_safe |
| card_0_safe | Content zone | icon/title/description/tier/button | 562,544,332,488 | inside card 0 | 244x342 | 31 | static | artifact_card_0 |
| card_1_safe | Content zone | icon/title/description/tier/button | 1114,544,332,488 | inside card 1 | 244x342 | 31 | static | artifact_card_1 |
| card_2_safe | Content zone | icon/title/description/tier/button | 1666,544,332,488 | inside card 2 | 244x342 | 31 | static | artifact_card_2 |
| footer_hint | Content zone | keyboard/controller hint or return note | 840,1160,880,62 | bottom-center | 620x44 | 20 | static | modal_safe |

## Card Internal Layout

Each card safe zone is split after frame margins are applied:

| Part | Rect within card safe zone @ 2560x1440 | Notes |
| --- | --- | --- |
| icon_slot | x+96,y+0,140,140 | artifact icon centered; never touches top crest |
| title | x+14,y+166,304,48 | one or two short lines max |
| tier_badge | x+74,y+226,184,38 | compact rarity text/chip |
| description | x+10,y+286,312,126 | multiline body; use shrink/ellipsis if needed |
| action_label | x+44,y+434,244,54 | `Получить`; focus/click visual remains within safe |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| modal_frame | optional `assets/sprites/ui/frames/overhaul_2k/elite_reward_modal.png` | target 1920x1188 | 128,122,128,118 | 146,122,146,142 | outer metal rail, dragon claws, ruby sockets, title crest, bottom seal | yes only if center is flat; otherwise proportional TextureRect |
| artifact_card | optional `assets/sprites/ui/frames/overhaul_2k/elite_reward_artifact_card.png` | target 464x650 | 58,70,58,74 | 66,78,66,84 | top crest, side metal rails, corner claws, red gems, bottom ornament | yes only with exact source aspect/margins |
| footer_hint | reuse minimal-metal field/panel | 880x62 display | 28,20,28,20 | 38,18,38,18 | bevel/caps/ruby pins | yes |

Hard rule: runtime labels, icons, card text, focus rings, click hit art, and button affordances must stay in the listed content zones. Border ornament, metal rails, gems, claws, seals, crests, and bevels are never content area.

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| elite_artifact_reward_2k_mockup_source | `docs/design/references/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup_source.png` | OpenAI mockup source | 2560x1440 | opaque reference acceptable | n/a | see tables | blocked, not generated |
| elite_artifact_reward_2k_mockup | `docs/design/mockups/scrum572_elite_artifact_reward_2k/elite_artifact_reward_2k_mockup.png` | accepted mockup copy | 2560x1440 | opaque reference acceptable | n/a | see tables | blocked, not generated |
| elite_artifact_reward_2k_safe_zones | `docs/design/previews/scrum572_elite_artifact_reward_2k_safe_zones.png` | annotated safe-zone preview | 2560x1440 | n/a | n/a | n/a | blocked, requires generated mockup |

## Responsive Rules

- 1920x1080: scale the 2560x1440 contract by `0.75`. Modal target `1440x891` at `240,95`; card target `348x488`; card content margins scale to about `50/59/50/63`. Minimum gap between cards: `66`.
- 2560x1440: base contract. Modal `1920x1188`; cards `464x650`; card gap `88`; row centered.
- 3840x2160: scale by `1.5`. Modal target `2880x1782` at `480,189`; card target `696x975`; card content margins scale to `99/117/99/126`. Do not add new decorative side panels unless the mockup/spec is updated.
- Aspect ratio: this source package targets 16:9. For narrower future viewports, keep three cards in row down to 1280x720 only if card content remains above min size; otherwise Back-end must request a separate stacked/scroll design pass.

## Interaction States

- Card hover: brighten inner metal edge and increase artifact glow only inside the frame; no yellow wash over the border.
- Card focus: clear neutral outline inside the content-safe rail, not on the outer ornament.
- Card pressed: subtle darkening of the inner fill; no layout shift.
- Disabled/unavailable: desaturate content and lower opacity inside safe zone; frame border stays readable.
- Loading/empty: show a dark placeholder glyph or spinner inside `icon_slot`, never on the crest.

## Implementation Notes

- Godot scene/script: Back-end integration later, likely `_show_elite_artifact_reward` in `scripts/ui_screens.gd`; not edited in this Design-only task.
- Existing runtime background: `assets/backgrounds/ui/ui_backdrop_reward_hall.png`.
- Existing reward card precedent: SCRUM-338/SCRUM-404 uses `assets/sprites/ui/frames/rewards/ui_frame_reward_elite_artifact_card.png` with metadata in `docs/design/references/rewards/reward_frames_scrum338_metadata.json`.
- If final generated art creates new 2K frame assets, place accepted runtime candidates under `assets/sprites/ui/frames/overhaul_2k/elite_reward*` or `artifact_reward*` only in a follow-up or accepted design integration pass.
- Runtime artifact icons remain separate assets from `assets/sprites/ui/icons/artifacts/`; do not bake artifact objects into the mockup frame layer unless it is purely a non-runtime preview.

## Acceptance Checks

- [ ] Mockup generated through OpenAI Images API.
- [ ] Preview shown in chat when generated.
- [x] All visible elements are listed in the elements table.
- [x] Every proposed frame has texture margins and content margins.
- [x] Spec forbids UI content over frame border, ornament, gem, metal, or decorative corner.
- [x] Responsive FullHD/2K/4K rules are documented.
- [ ] Generated mockup visually confirms clear empty content zones.
- [ ] Annotated safe-zone preview created from generated mockup.
- [ ] Jira moved to QA after successful generation, or blocked with precise reason.

## Deviations

OpenAI-API-generated PNG deliverables are missing because the required API key is unavailable in this environment. The task should remain blocked or be released until `OPENAI_API_KEY` is restored for the asset generator.
