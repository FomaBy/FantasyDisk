# Hero Select — PixelLab-first Rebuild (SCRUM-686)

Status: ready for QA / back-end handoff
Role owner: Design (claude lane)
Jira: SCRUM-686
Base resolution: 2560x1440 (16:9)
Responsive targets: 2560x1440 (primary), 1920x1080, 1536x864
Source pipeline: **PixelLab** for all UI frames + **live 512x512 PixelLab character frames** for the portrait preview. The older generic OpenAI redraw pipeline is **not** the source of final UI visuals.

Machine-readable layout: [`zones.json`](zones.json)
Mockup preview: `docs/design/previews/scrum_hero_select_pixellab_rebuild_mockup.png`
Debug overlay: `docs/design/previews/scrum_hero_select_pixellab_rebuild_debug.png`
Frame asset manifest: `docs/design/references/hero_select_pixellab_rebuild/asset_manifest.json`

## Why

The character-select screen needed a from-scratch redraw sized to the **actual** screen space and to the **new PixelLab character sprite dimensions**. Earlier Hero Select passes were tuned around OpenAI-baked frames and around small/legacy portrait sprites, so the new 512x512 PixelLab directional sprites (Berserk, Dark Mage, …) ended up tiny or clipped. This rebuild fixes the sizing contract first and lays the frames around it.

## Measured sprite references (read-only)

Measured directly from the live PixelLab idle frames (`assets/sprites/characters/full_frame/{berserk,dark_mage}_pixellab/`):

| Class | Dir | Canvas | Visible bbox | Visible size | Feet (bbox bottom-center) |
| --- | --- | --- | --- | --- | --- |
| Berserk | south | 512x512 | (184,152)-(332,368) | 148x216 | (258,368) |
| Berserk | east  | 512x512 | (212,156)-(296,364) | 84x208  | (254,364) |
| Dark Mage | south | 512x512 | (174,202)-(334,376) | 160x174 | (254,376) |
| Dark Mage | east  | 512x512 | (176,202)-(304,382) | 128x180 | (240,382) |

Berserk south is the **tallest** measured silhouette (216px) and Dark Mage south is the **widest** (160px); both are used as the sizing extremes for the portrait box.

## Layout (2560x1440)

Three-column composition under a title bar, with a full-width large carousel along the bottom — matching the user's requested "large carousel + big icons" direction.

| Region | Frame asset | Frame pos | Frame size | Content rect (screen) |
| --- | --- | --- | --- | --- |
| Title | `frame_title.png` | (360,28) | 1840x184 | 480,70,1600,96 |
| Back | `button_back.png` | (48,48) | 460x148 | 118,86,320,72 |
| Portrait (left col) | `frame_portrait.png` | (90,240) | 600x820 | **162,334,456,620** |
| Dossier (center col) | `frame_dossier.png` | (770,240) | 980x820 | 862,324,796,640 |
| Radar (right-upper) | `frame_radar.png` | (1762,240) | 780x520 | 1860,297,584,406 |
| Ascension (right-lower) | `frame_ascension.png` | (1762,790) | 780x270 | 1836,840,632,183 |
| Choose / Start | `button_choose.png` | (1004,838) | 512x118 | 1074,872,372,50 |
| Carousel (bottom) | `frame_carousel.png` | (64,1086) | 2432x330 | 174,1147,2212,220 |

Helper buttons: carousel arrows `button_carousel_left/right.png` (132x176) at (174,1169)/(2254,1169); ascension stepper `button_asc_minus/plus.png` (132x92) at (1836,920)/(2336,920). Hero slots use `frame_hero_slot.png` (196x220, interior 18,18,160,160) on the track rect 330,1147,1924,220 (9 visible slots, center slot enlarged for the selected hero).

**Gaps (all positive, no frame overlaps):** title→portrait 28px · portrait→dossier 80px · dossier→radar 12px · radar→ascension 30px (vertical) · main band→carousel 26px · carousel→screen bottom 24px. The Choose button is intentionally seated inside the dossier's lower interior (it is the CTA for the selected hero) and stays clear of the dossier ornament.

## Portrait sprite display box — the core contract

The portrait interior safe area is **(162,334)–(618,954)** = `456 x 620`.

Display rule for any 512x512 PixelLab character frame:

1. Crop the source frame to its non-transparent bounding box.
2. Scale uniformly by **2.45** (NEAREST — keep pixels crisp).
3. Place so the **feet pivot** (visible bbox **bottom-center**) lands on **(390, 916)** and is horizontally centered.

`feet_anchor_normalized = (0.50, 0.94)` of the display box → feet sit 6% above the interior floor, leaving a small "ground" gap.

Why scale 2.45: it maps the tallest silhouette (Berserk south, 216px) to **529px = 85%** of the 620px box, leaving ≥53px headroom; the widest (Dark Mage south, 160px → 392px) stays inside the 456px box with margin. No class clips at top, bottom, or sides.

Demonstrated placements (see debug overlay — Berserk solid green, Dark Mage magenta, both inside the yellow box, feet on the red cross):

| Class | Displayed rect | Fits box (162,334,456,620)? |
| --- | --- | --- |
| Berserk south | 208,388,363,529 | yes — head at y388 (+54 headroom), x 208–571 |
| Dark Mage south | 194,491,392,426 | yes — head at y491, x 194–586 |

East/3⁄4 directions are narrower/shorter than south, so they fit automatically under the same rule. Use the **south (front) idle** frame for the portrait preview by default.

## Frame rule compliance

No text, portrait, button, icon, carousel slot, radar chart, stepper glyph, or control is placed over decorative frame ornament — every content rect above is the **empty interior** of its frame (cyan boxes in the debug overlay all sit inside their metalwork). The portrait sprite is bounded by the yellow display box, which is inset from the portrait frame ornament.

## Raster text policy

All frame/button/background assets are **textless** (`background`, `frame_*`, `button_*`). Labels — title text, "Назад", hero name/role/description, weapon trio, stat-bar values, ascension title/description, "+"/"−", "Выбрать/Старт", carousel hero names — are drawn at **runtime** in Godot inside the listed content rects. No gameplay text is baked into raster layers.

## Responsive rules

- **2560x1440** — use the pixel rects above verbatim.
- **1920x1080** — multiply every x/y/w/h by **0.75**.
- **1536x864** — multiply every x/y/w/h by **0.60**.
- Keep carousel slot squares square; keep the three-column structure and the separate ascension panel at every target. Portrait sprite scale and feet anchor scale by the same factor (sprite scale 2.45 → 1.84 @1080p → 1.47 @864p).

## Handoff to Back-end (UI)

Implement against [`zones.json`](zones.json) (authoritative coordinates):

1. **Frames/background** — load the textless PixelLab assets from `assets/sprites/ui/frames/hero_select_pixellab/` at the documented `pos`/`size`; scale by the resolution factor. Treat each frame as a whole-image proportional sprite (do **not** 9-slice the ornate frames — they are art-authored at native size).
2. **Content nodes** — anchor every label/chart/control inside its `content_rect`; never spill onto ornament.
3. **Portrait preview** — implement the display-box rule exactly: crop-to-bbox → scale 2.45 (×res factor) → feet-anchor at the normalized (0.50, 0.94) point. This is the one new behavior versus prior Hero Select runtime; it replaces any fixed-scale portrait logic so 512x512 PixelLab sprites read large and uncropped.
4. **Carousel** — 9 visible `frame_hero_slot` thumbnails on the track rect between the arrow buttons, center slot enlarged for the selected hero; thumbnails are the same per-class portrait frames covered/centered into the 160x160 slot interior.
5. **Ascension stepper / Choose / Back** — wire to existing Hero Select signals; geometry only changes.

**Fallback / history:** the previous Hero Select v3/v4 frame assets and the OpenAI-sourced exploration packs (`docs/design/mockups/hero_select_large_carousel_user/`, `docs/design/mockups/hero_select_parts/`) may remain in the repo as fallback/reference; they are superseded as the **final** visual source by this PixelLab rebuild and should not be wired into the live screen.

## Acceptance checklist

- [x] PixelLab-sourced Hero Select mockup/spec package with exact 2K coordinates, normalized zones, and content margins.
- [x] Spec states target sprite display box, scale rule, pivot/feet alignment, and safe area for 512x512 PixelLab frames.
- [x] Berserk and Dark Mage preview placements demonstrated in the debug overlay; neither overlaps frame ornament, text, radar, or carousel.
- [x] Production-ready frame/background/button/carousel assets identified (textless), with no baked gameplay text in raster layers.
- [x] Back-end handoff section maps zones↔assets and names which old assets remain as fallback/history.
