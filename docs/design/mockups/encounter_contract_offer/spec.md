# UI Mockup Spec - Encounter Contract Offer

Status: ready_for_qa_design_package
Role owner: Design
Task: FAN-2235 / parent FAN-1452
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_mockup.png`
Preview PNG: `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_preview.png`
Generators: background=existing gameplay underlay; non-background UI=PixelLab MCP `create_ui_asset`
Source ID: PixelLab UI asset `3f29a8f8-1c59-4cfa-aa3a-02d40e5ebb2a`, canonical tag `encounter_contract_offer`, seed `20932235`
Runtime integration: none in this task

## Source Request

Design a modal opt-in offer before the next normal encounter phase. Show the
risk and capped reward before Accept. Decline and timeout are safe and carry no
penalty. The package is a generator-routed handoff only; it does not add or
change Godot scenes, scripts, gameplay, shared UI themes, or runtime assets.

## Screen Purpose And Underlay

The modal pauses attention over an existing combat underlay while preserving the
critical combat HUD. No new scenic or full-canvas background is generated. The
preview uses the existing `assets/backgrounds/field_ruined_courtyard.png`,
existing combat HUD frame assets, and existing artifact icons only as a visual
context layer; none are modified or promoted by this task.

The dim layer is below the existing top resource/timer/artifact HUD and the
bottom-right level-up FAB. The modal rect begins below the top HUD reserve and
ends above the FAB reserve at every target resolution.

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `combat_hud_reserved_top` | reserved underlay | resource/timer/artifact HUD | `0,0,1920,112` | full/top | `1280x75` | 20 | visible above dim | underlay |
| `modal_frame` | `NinePatchRect` / `StyleBoxTexture` | empty textless frame | `280,160,1360,760` | center | `1080x620` | 10 | static | screen |
| `title_zone` | `Label` | contract title | `700,180,520,52` | center/top | `440x36` | 30 | static | modal_frame |
| `subtitle_zone` | `Label` | opt-in explanation | `748,312,424,34` | center | `360x26` | 30 | static | central_empty_frame |
| `risk_panel` | logical content column | risk summary in the central empty frame | `740,350,210,210` | central-left | `180x180` | 20 | static | central_empty_frame |
| `risk_icon_zone` | `TextureRect` | risk icon, existing artifact source | `518,314,92,92` | side-well-left | `64x64` | 30 | normal/focus | modal_frame |
| `risk_label_zone` | `Label` | `Риск` | `742,350,204,28` | central-left | `170x24` | 30 | static | risk_panel |
| `risk_value_zone` | `Label` | dynamic risk value | `742,383,204,62` | central-left | `170x48` | 30 | static | risk_panel |
| `risk_body_zone` | `Label` | phase scope explanation | `742,449,204,96` | central-left | `170x70` | 30 | static | risk_panel |
| `reward_panel` | logical content column | capped reward summary in the central empty frame | `974,350,210,210` | central-right | `180x180` | 20 | static | central_empty_frame |
| `reward_icon_zone` | `TextureRect` | reward icon, existing artifact source | `1256,314,92,92` | side-well-right | `64x64` | 30 | normal/focus | modal_frame |
| `reward_label_zone` | `Label` | `Награда` | `978,350,202,28` | central-right | `170x24` | 30 | static | reward_panel |
| `reward_value_zone` | `Label` | dynamic reward value | `978,383,202,42` | central-right | `170x34` | 30 | static | reward_panel |
| `reward_cap_zone` | `Label` | capped-reward statement | `978,429,202,28` | central-right | `170x22` | 30 | static | reward_panel |
| `reward_body_zone` | `Label` | success/idempotency explanation | `978,462,202,82` | central-right | `170x62` | 30 | static | reward_panel |
| `accept_button` | `Button` | `Принять контракт` | `672,838,258,56` | modal-bottom-left | `220x48` | 40 | normal/hover/focus/pressed/disabled | modal_frame |
| `decline_button` | `Button` | `Отказаться` | `990,838,258,56` | modal-bottom-right | `220x48` | 40 | normal/hover/focus/pressed/disabled | modal_frame |
| `timeout_zone` | `Label` | timeout and safe default | `744,715,430,48` | central-bottom | `360x34` | 30 | static/countdown-ended | lower_center_panel |
| `input_hint_zone` | `Label` | keyboard/controller hint | `760,254,400,26` | center | `340x22` | 30 | keyboard/controller variants | modal_frame |
| `combat_hud_reserved_fab` | reserved underlay | level-up FAB | `1827,987,93,93` | bottom-right | `62x62` | 20 | visible above dim | underlay |

Runtime strings and numbers are not baked into generated art. The sample copy
above is composited only inside the declared zones for fit and visual review.

## Frames And Safe Zones

| Frame ID | Source / intended node | Source size | Texture margins (L/T/R/B) | Content margins (L/T/R/B) | Forbidden zones | 9-slice |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `modal_frame` | `docs/design/references/encounter_contract_offer/pixellab_encounter_contract_offer_688x384_alpha_clean.png`; `NinePatchRect` or `StyleBoxTexture` | `688x384`, target `1360x760` | source `62/0/64/0` visible bbox; texture contract `64/66/64/50` | irregular child zones; minimum outer reserve `82/66/82/50` source px | outer rails, dragon corners, ruby pins, top/bottom ornaments, all generated metal | yes only for an isolated flat center; never stretch ornate caps |
| `central_empty_frame` | same PixelLab source; logical split, no extra frame | exact source safe rect `232,83,224,157`, target scaled ≈ `739,324,443,311` | `44/40/44/40` source reserve | two columns: `742,350,204,210` and `974,350,210,210` target | dragon lattice, gems, inner border; two columns stay inside the calm center | no full-image stretch; 9-slice only if center is isolated |
| `side_icon_wells` | same PixelLab source; existing icons in `TextureRect` | exact source wells `118,82,54,54` and `496,82,54,54`; target icon zones `518,314,92,92` and `1256,314,92,92` | n/a | `12px` reserve inside each square icon zone | circular rim, side panel rails, studs | no; preserve aspect |
| `accept_button` / `decline_button` | same PixelLab source; `Button` | exact source inner wells `214,347,98,19` and `372,347,98,19`; target `672,838,258,56` and `990,838,258,56` | source button edge reserve `16/6/16/6` | source inner well plus `8px` reserve; target rects are label zones | bevel caps, rails, ruby pins, corner claws | no; keep native ratio |
| `risk_icon_zone` / `reward_icon_zone` | existing `artifact_battle_doctrine.png` / `artifact_battle_fan.png`; `TextureRect` | `256x256` | n/a | `12px` reserve inside `92x92` | circular rim and any panel ornament | no; preserve aspect |

The declared content margins are intentionally larger than texture margins by a
minimum 12px reserve. Text, icons, hit targets and focus visuals stay inside
the empty internal zones; they never use border, gem, metal, corners, or
ornament. The two round icon wells are aspect-preserved and are not 9-sliced.
If the future runtime needs a different aspect ratio, use the same source with
NinePatchRect/StyleBoxTexture center stretching; do not scale the entire ornate
image with `STRETCH_SCALE`.

## Generator Provenance

- Route: PixelLab MCP only for new non-background UI art; no built-in/OpenAI
  background generation was used.
- Tool: `create_ui_asset`, status must be `completed` before QA.
- PixelLab source/project/tag: source UI asset `3f29a8f8-1c59-4cfa-aa3a-02d40e5ebb2a`; `list_projects` returned `0 projects` (personal UI asset library, no project ID exposed); canonical tag `encounter_contract_offer`.
- Prompt/spec: `docs/design/references/encounter_contract_offer/pixellab_create_request.json`.
- Export: `688x384`, PNG, alpha-preserving (`no_background=true`); raw filename `pixellab_encounter_contract_offer_688x384_raw.png`, accepted source filename `pixellab_encounter_contract_offer_688x384_alpha_clean.png`.
- Postprocess: PixelLab's scaffold auto-added two button labels despite the
  no-text contract. `postprocess_pixellab_source.py` removed only those labels
  from the declared button interiors and preserved every frame/alpha pixel;
  the accepted source is text-free.
- Alpha audit: `docs/design/references/encounter_contract_offer/alpha_audit.json`;
  accepted source is RGBA `688x384`, transparent pixels `114716`, opaque pixels
  `149476`, visible bbox `[62,0,623,383]`, white opaque pixels `5` (isolated
  highlights, no letters/labels).
- Planned Godot nodes: modal `NinePatchRect`/`StyleBoxTexture`, panels
  `PanelContainer`, buttons `Button`, icon wells `TextureRect`.
- Existing gameplay underlay and existing artifact icons are verify-only
  references; no new runtime asset path is part of this task.

## Responsive Rules

All base rectangles scale uniformly by `s = viewport_width / 1920` for the
three 16:9 targets, with integer rounding. Anchors remain center for the modal,
panel row, and action row. Content margins scale with the frame and retain at
least a 12px reserve at the final target.

| Target | Modal rect | Top HUD reserve | FAB reserve | Notes |
| --- | --- | --- | --- | --- |
| `1280x720` | `187,107,907,507` | `0,0,1280,75` | `1218,658,62,62` | Uniform frame scale plus button clamp to `220x48`; action row remains bottom-anchored and readable. |
| `1920x1080` | `280,160,1360,760` | `0,0,1920,112` | `1827,987,93,93` | Base design; modal starts 48px below reserved top HUD and ends 67px above reserved FAB. Buttons are `258x56`. |
| `2560x1440` | `373,213,1813,1013` | `0,0,2560,149` | `2436,1316,124,124` | Modal ends at y=1226; 90px remains before the FAB. Buttons grow to `344x75`; top-right artifact HUD stays above modal. |

At 1280x720, if runtime typography floors require more width, preserve the
modal and button minimums and allow body copy to wrap to two lines inside the
same zones. No scrollbar is required: all content is compact and fixed.

## Interaction States

- Default: both actions have equal hit size; Accept uses restrained amber accent,
  Decline uses quiet brass/steel.
- Hover: outer rim brightens only; no layout movement and no content-zone change.
- Focus: 2px worn-gold inner line inside the button safe zone; keyboard and
  controller focus are visible without covering text.
- Pressed: center darkens and rim compresses visually; rect remains unchanged.
- Disabled: desaturated button plus readable label; used when offer is no
  longer eligible or the encounter is not a normal phase.
- Timeout / safe default: countdown reaches zero and Decline is applied; no
  reward, risk, or penalty is committed.
- Initial focus: Decline, to prevent accidental opt-in to risk. Left/Right
  toggles the two actions; Enter/A confirms; Escape/B maps to Decline.

## Implementation Notes

- Godot scene/script: future Back-end child only; no `scenes/`, `scripts/`,
  `assets/`, `tests/`, or shared theme paths changed here.
- Suggested tree: `EncounterContractOffer` (modal root) → `ModalFrame` →
  `Title`, `Subtitle`, `RiskPanel`, `RewardPanel`, `AcceptButton`,
  `DeclineButton`, `TimeoutHint`, `InputHint`.
- Use `NinePatchRect`/`StyleBoxTexture` with the declared margins for the
  outer frame and panel/button pieces. Keep source-relative corners fixed.
- Put text/numbers in Labels and icon textures in TextureRects. Do not bake
  runtime content into PNGs.
- The overlay should not consume or hide critical combat HUD input. The modal
  captures its own actions; HUD remains visible above the dim layer.

## Generated Artifacts

| Artifact | Path | Role |
| --- | --- | --- |
| Planning gate | `docs/design/mockups/encounter_contract_offer/ui_plan.json` / `ui_plan.report.json` | pre-generation geometry; `ready_for_image` |
| Planning guide | `docs/design/mockups/encounter_contract_offer/ui_plan_guide.png` | content-zone guide |
| PixelLab request | `docs/design/references/encounter_contract_offer/pixellab_create_request.json` | prompt, route, exact source spec |
| PixelLab source | `docs/design/references/encounter_contract_offer/pixellab_encounter_contract_offer_688x384_alpha_clean.png` | textless accepted UI art source; raw export is retained for provenance |
| Source manifest | `docs/design/references/encounter_contract_offer/manifest.json` | IDs, size, alpha, hashes, provenance |
| Base underlay composite | `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_base.png` | existing gameplay context + PixelLab layer |
| Final mockup | `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_mockup.png` | content-composited sample |
| Preview | `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_preview.png` | handoff preview |
| Annotated overlay | `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_safe_zones.png` | debug safe-zone evidence |
| Fit report | `docs/design/mockups/encounter_contract_offer/encounter_contract_offer_render.report.json` | compositor `ok=true` |

## Acceptance Checks

- [x] `fantasydisk-ui-director`, UI/style docs and FAN-1452 were read before generation.
- [x] Purpose, visible elements, risk/reward values, capped reward, Accept,
      Decline, timeout/safe default and input states are documented.
- [x] `ui_plan.json` passed `decision=ready_for_image` with `ok=true` before generation.
- [x] Base mockup is `1920x1080`; responsive rules cover all requested targets.
- [x] No new scenic/full-canvas background was generated.
- [x] New non-background UI art is routed through PixelLab MCP and is textless.
- [x] Runtime content is composited only in declared zones and existing HUD is
      outside the modal safe envelope.
- [x] Exact rectangles, anchors, minimums, z-order, forbidden zones, margins,
      and 9-slice/no-stretch rules are present.
- [x] Source download, alpha audit, visual inspect, and compositor report pass.
- [ ] Independent QA verifies the exact pushed SHA and generator/safe-zone contract.
- [ ] Runtime implementation/screenshot comparison are intentionally deferred.

## Verification Evidence

- `validate_ui_layout_plan.py`: PASS; report is `ok=true`, `decision=ready_for_image`, with no errors.
- `render_content_zones.py`: PASS; report is `ok=true` for every declared content zone.
- `audit_source.py`: PASS; accepted source is RGBA, alpha-preserving, text-free, and has the recorded visible bounding box.
- `build_responsive_previews.py`: PASS; 1280x720 and 2560x1440 previews were generated from the same layout contract.
- `tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`: PASS.
- `git diff --check`: PASS before publish.

## Deviations

This is a Design-only package. Existing gameplay and icon assets are shown as
verify-only underlay context; no runtime files or shared UI themes are changed.
