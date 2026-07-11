# SCRUM-952 — Hero Select trait-copy hierarchy

Jira: SCRUM-952
PixelLab source: `c72b6dba-895e-4f6a-93a1-1a5a36934a54` (`688×384`, generated 2026-07-11)

## Decision

The existing black-minimal Hero Select shell, frame assets, portrait, stats,
ascension strip and carousel stay unchanged. The dossier copy column is the only
visual scope. It exposes three immediately scannable sections in this order:

1. `Особенность — <trait title>: <short mechanics copy>` in antique amber;
2. `Плюсы: <strengths>` in muted green;
3. `Минусы: <weaknesses>` in muted red.

The PixelLab render is a textless composition reference. Russian labels are
composited only into the declared zones in `layout.json`; runtime text remains
native Godot labels for accessibility, localization and responsive wrapping.

## Content-zone contract

- All live copy stays inside `HS4DossierScroll` and its dark inner content
  area. No label may enter the outer gold frame or ornamental corner reserve.
- The trait precedes strengths and weaknesses. It may wrap to three lines and
  carries the full text in its tooltip; it must not be ellipsized.
- Strengths and weaknesses may wrap to two lines and keep their full text in
  tooltips. The dossier scroll is the compact-height fallback; frame geometry
  must not grow into portrait, ascension, carousel or CTA zones.
- At 1280×720, the copy column may scroll vertically. At 1920×1080 and
  2560×1440, all three sections must be visible without clipping.
- Colors reinforce hierarchy only. Literal headings `Особенность`, `Плюсы` and
  `Минусы` remain present for color-independent comprehension.

`ui_plan.json` is the pre-generation fit decision. The validated decision must
be `ready_for_image` before the generated source is accepted.

## Data contract

- `ProgressionData.CLASS_TRAITS[class_id]` is the shared mechanics and
  player-facing trait source. Every selectable class must provide non-empty
  `id`, `title` and `description`.
- `CHARACTER_CONFIGS[class_id].strengths` and `.weaknesses` remain the shared
  concise plus/minus source.
- Hero Select and Codex project those same dictionaries; neither screen owns a
  duplicate trait table.
