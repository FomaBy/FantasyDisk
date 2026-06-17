# SCRUM-451 Minimal Metal Frames Rollout Spec

Status: ready_for_backend_integration
Role owner: Design
Task: `docs/tasks/design_ui_minimal_frames_rollout_task.md`
Jira: SCRUM-451
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Generated with: OpenAI Images API source packages from SCRUM-452/SCRUM-450 via `fantasydisk-asset-generator`; rollout preview composed from accepted transparent PNGs.

## Source Request

Roll out the accepted minimal-metal UI direction to every non-button frame family
and screen: menu, settings, hero select, codex, shop, rewards, level-up, events,
pause, results, combat HUD, tooltips and dialogs. Use one strict minimal-metal
frame family with thin dark-steel rails, aged-brass hairlines, rare ruby pins and
quiet obsidian centers. Runtime content must stay inside safe content zones.

## Source Packages

- Frame anchor: `docs/design/mockups/scrum452_ui_minimal_metal/spec.md`
- Frame metadata: `docs/design/references/ui_minimal_metal/scrum452_minimal_metal_frame_metadata.json`
- Frame assets: `assets/sprites/ui/frames/minimal_metal/`
- Button companion kit: `docs/design/mockups/scrum450_ui_minimal_metal_buttons/spec.md`
- Button metadata: `docs/design/references/ui_minimal_metal_buttons/scrum450_minimal_metal_button_metadata.json`
- Rollout matrix JSON: `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_matrix.json`
- Alpha audit: `docs/design/references/ui_minimal_metal_rollout/scrum451_minimal_metal_rollout_alpha_audit.json`
- Rollout preview: `docs/design/previews/scrum451_minimal_metal_rollout_contact.png`

## Frame Families And Safe Zones

| Family | Asset ID | Path | Size | Texture margins | Content margins | Content rect | Runtime use |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| `modal` | `ui_frame_minimal_metal_modal` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_modal.png` | `986x900` | `[46,62,46,58]` | `[72,92,72,84]` | `[72,92,842,724]` | Large shells/windows/dialogs |
| `panel` | `ui_frame_minimal_metal_panel` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_panel.png` | `782x716` | `[38,52,38,48]` | `[58,72,58,66]` | `[58,72,666,578]` | Inner panes, sidebars, hero preview/dossier areas |
| `card` | `ui_frame_minimal_metal_card` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_card.png` | `426x486` | `[32,42,32,40]` | `[46,58,46,54]` | `[46,58,334,374]` | Choice cards, reward cards, codex/shop cards, carousel cells |
| `tooltip` | `ui_frame_minimal_metal_tooltip` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png` | `760x242` | `[46,30,46,28]` | `[66,44,66,40]` | `[66,44,628,158]` | Tooltips, glossary hints, small helper panels |
| `hud_strip` | `ui_frame_minimal_metal_hud_strip` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_hud_strip.png` | `1122x288` | `[76,42,76,40]` | `[104,62,104,56]` | `[104,62,914,170]` | Combat HUD strips, carousel rails, status ribbons |
| `field` | `ui_frame_minimal_metal_field` | `assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_field.png` | `616x286` | `[42,38,42,36]` | `[58,52,58,48]` | `[58,52,500,186]` | Inputs, selectors, tabs, chips, small counters |

All six production PNGs are transparent RGBA and re-audit in SCRUM-451 at:

- `white_opaque_pixels=0`
- `pale_visible_pixels=0`
- `edge_visible_pixels_2px<=8` on the largest strip/modal/panel edge
  antialiasing, with `0` white/pale edge pixels

The cyan boxes in the rollout preview are the only legal content zones. Runtime
labels, icons, portraits, hover highlights, carousel thumbnails, click/focus
affordances and meter wrappers must stay inside the chosen family content rect
after scaling. Texture margins, rails, bevels, dark corner plates and ruby pins
are forbidden content zones.

## Screen Rollout Matrix

Use the JSON rollout matrix as source of truth when this summary drifts.

| Screen | Surfaces | Frame families |
| --- | --- | --- |
| Main menu | button-column backing, confirm dialogs, helper tooltips | `panel`, `modal`, `tooltip` |
| Settings | root shell, 3-slot tab switcher, tab sections, control rows, helper tooltips | `modal`, `field`, `panel`, `tooltip` |
| Hero Select | preview, dossier, radar shell, carousel rail, thumbnail cells, tooltips | `panel`, `field`, `hud_strip`, `card`, `tooltip` |
| Codex | root shell, nav panel, detail panel, entry cards, tabs, glossary tooltips | `modal`, `panel`, `card`, `field`, `tooltip` |
| Shop | shell, inventory/merchant panes, item cards, price badges, item tooltips | `modal`, `panel`, `card`, `field`, `tooltip` |
| Rewards | reward shell, reward cards, tier/status chips, artifact hints | `modal`, `card`, `field`, `tooltip` |
| Level-up | level-up shell, upgrade choice cards, stat chips, upgrade tooltips | `modal`, `card`, `field`, `tooltip` |
| Events/rest | event shell, story panel, choice cards, risk/cost fields, tooltips | `modal`, `panel`, `card`, `field`, `tooltip` |
| Pause | pause shell, stats/list panels, stat chips, hints | `modal`, `panel`, `field`, `tooltip` |
| Results | victory/defeat shell, summary panels, reward cards, stat fields | `modal`, `panel`, `card`, `field` |
| Combat HUD | resource strip, timer field, artifact/card wrappers, combat hints | `hud_strip`, `field`, `card`, `tooltip` |
| Global tooltips | generic tooltip panels, compact inline hints | `tooltip`, `field` |
| Dialogs | confirm/warning modal, body panel, status field, helper tooltip | `modal`, `panel`, `field`, `tooltip` |

## Responsive Rules

1280x720:

- Preserve compact live layouts and scroll inner content before shrinking frame
  margins.
- Keep content inset at least scaled `content_rect_xywh` plus an additional
  `8px` runtime reserve.
- Reduce card columns or use scroll/stacking before squeezing text onto rails.

1920x1080:

- Base layout target. Use source metadata ratios and 9-slice center stretch for
  generic surfaces.
- Large shells should usually occupy 70-82% viewport width depending on screen
  density.
- Card and field families should use native proportions unless a screen already
  owns a wider layout contract.

2560x1440:

- Increase layout spacing and columns before increasing text size.
- Keep metal rails and ruby pins visually thin; do not stretch caps into long
  ornaments.
- Cap large central shells around `1800-1960px` unless an accepted screen mockup
  owns a wider canvas.

## Implementation Notes For Back-end

- Add/promote one minimal-metal frame path set for the six families above.
- Add/promote SCRUM-450 minimal-metal button paths separately; do not mix
  button and non-button frame metadata.
- Back up or leave selectable the old ornate/minimal/red-gold kits until
  no-live-ref audit and QA pass. Design does not delete old assets in SCRUM-451.
- Keep Hero Select `HeroSelectRadarPanel` / `HeroStatRadar` behavior and current
  selection semantics; if the generic field/panel frame cannot preserve the
  square radar safe zone, request a small Design slice rather than stretching a
  round/compass element.
- Do not replace combat bar fills, progression node rings or gameplay icons with
  generic frame art. This rollout covers wrapper frames and UI surfaces only.
- Run runtime UI smoke, UI no-overlap matrix and full runtime smoke after wiring.

## Acceptance Checks

- [x] Design rollout matrix covers menu, settings, hero select, codex, shop,
      rewards, level-up, events, pause, results, combat HUD, tooltips and dialogs.
- [x] Every rollout family points to a transparent SCRUM-452 PNG with exact
      texture/content margins.
- [x] Companion button kit points to SCRUM-450 and remains separate.
- [x] No old ornate assets are deleted in Design scope; deletion/backup requires
      Back-end no-live-ref audit.
- [x] Runtime integration, screenshots and no-overlap tests are handed off to
      Back-end.

## Deviations

No new OpenAI image generation was needed in SCRUM-451 because SCRUM-452 and
SCRUM-450 already produced accepted OpenAI source sheets and transparent
production candidates. This task composes the rollout contract and preview from
those accepted assets to avoid style drift.
