# UI Mockup Spec — SCRUM-1064 Hero Select structured dossier

Status: ready_for_integration

Role owner: Back-end/UI Codex

Task/Jira: `docs/tasks/SCRUM-1064.md` / SCRUM-1064

Base resolution: 1920×1080

Responsive targets: 1152×648, 1280×720, 1920×1080, 2560×1440 and live resize

Accepted PixelLab screen/mockup family:
`docs/design/previews/scrum1063_hero_carousel_wide_buttons/hero_select_wide_buttons_mockup_1920x1080.png`

Accepted compact mockup:
`docs/design/previews/scrum1063_hero_carousel_wide_buttons/hero_select_wide_buttons_mockup_1152x648.png`

Accepted PixelLab dossier/stat art layer:
`docs/design/previews/scrum951_hero_stat_colors/pixellab_stat_color_art_layer_448x600.png`
(source ID `395cbafb-358b-4f46-9b95-019b67bf5c48`)

## Reuse decision

SCRUM-1064 changes only live dossier content and its scroll canvas. It creates
no new frame, button, icon, portrait or background. The accepted PixelLab Hero
Select shell from SCRUM-1063 and accepted stat-row art direction from SCRUM-951
already provide the required empty dossier interior, separate fixed stat lane
and frame-safe scrollbar lane. Reuse is therefore preferable to spending a new
PixelLab generation credit or introducing an unrelated fallback. No raster
asset is promoted or edited by this task.

## Content order

Inside `HS4DossierScroll`, top to bottom:

1. optional trait: `Особенность: <title> — <short_description>`;
2. hero name;
3. canonical three weapon names;
4. top three `BASE_STATS` with values;
5. complete primary relevance list;
6. complete secondary relevance list;
7. complete weak relevance list (`optional` data key, player-facing rename).

The right `HS4StatsColumn` keeps all eight bars and numeric values. No visible
description, prose strengths or prose weaknesses remains.

## Frames and safe zones

| Surface | 1920×1080 rect | Content margin/reserve | Forbidden zone |
| --- | --- | --- | --- |
| global Hero Select shell | `160,120,1600,830` | authored unified safe rails | all gold outer rails/corner rosettes |
| dossier frame | `706,280,1012,286` | ≥ 36 px horizontal, 29 px vertical | dossier border/highlight |
| dossier scroll viewport | `742,309,590,231` | 16 px dedicated scrollbar lane | stat lane and dossier border |
| fixed stat lane | `1362,309,320,231` | existing row padding | dossier text/scroll lane |
| compact dossier frame | `376,178,655,140` | ≥ 24 px horizontal, 16 px vertical | outer shell and panel border |
| compact scroll viewport | `400,194,270,106` | 14 px dedicated scrollbar lane | compact 2×4 stat grid |

## Fit and scroll decision

- The worst-case Russian content canvas is budgeted at 640 px at 1080p and
  930 px at 1152×648. It intentionally exceeds the visible viewport, so
  vertical scroll is required rather than truncation or tiny text.
- No category has an item cap, `+N` abbreviation or ellipsis. All applicable
  attributes remain reachable.
- Mouse wheel, keyboard/D-pad/left-stick vertical actions and PageUp/PageDown
  scroll locally; only a true top/bottom boundary transfers focus.
- Hero switch resets the dossier to the trait/name start.

## Responsive rules

- 1152×648 and 1280×720: compact 2×4 stat bars remain fixed; text lane uses the
  narrow scroll viewport and 14 px scrollbar reserve.
- 1920×1080 and 2560×1440: fixed one-column 8-stat lane; dossier content may
  still scroll because every relevance category is complete and untrimmed.
- Live resize rebuilds the screen from data; no cached line limits or manual
  offsets depend on one hero.
- Outer frame, portrait, Ascension, carousel, CTA and stat bars do not move in
  this content-only pass.

## Interaction states

- Dossier scroll: pointer wheel, keyboard, D-pad/left stick, PageUp/PageDown.
- Focus stays inside the dossier while more content exists; Back/Choose are
  boundary neighbors.
- Trait block is completely omitted when no canonical trait exists; there is
  no blank spacer.

## Acceptance checks

- [x] Accepted PixelLab source family and provenance identified before runtime work.
- [x] Exact 1080p and compact content zones declared before runtime work.
- [x] Longest Russian content uses a required scrollbar with a reserved lane.
- [x] No text, icon, portrait or control touches frame ornament.
- [x] No new or fallback art is introduced.
- [x] Runtime screenshots match the plan at all four targets.
- [x] Focus/scroll/no-overlap/schema tests pass for all 17 heroes.

## Deviations

The content-height budget is intentionally larger than the visible frame even
at 1080p/2K. This preserves complete, inspectable attribute categories instead
of repeating the old truncation/`+N` behavior. The frame and all art remain
unchanged; only the already-supported scroll canvas grows.
