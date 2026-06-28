# Design — Berserk v2 visual redesign (board mirror)

Jira: SCRUM-531 · Role: Design · Lane: design-main · Priority: P1 · foma
Статус: Выполнено / Контроль качества — source pack delivered 2026-06-28 by r2i3.

Short board mirror. Full spec, steps, acceptance and grounding:
`docs/tasks/SCRUM-531_berserk_v2_visual_redesign_source_pack.md`.

## Delivered (Design/source only)

- New brutal dark-fantasy / D&D dragon berserker source (non-pixel, painterly),
  visually distinct from the current cartoon-anchor; empty fists, no weapon baked.
- Alpha-clean RGBA source + normalized `512x512` cell (pivot `256,470`, visible
  height `408 px`) + idle/walk×5 source-sheet handoff (`2848x1168`, 48px gutters,
  attack row excluded).
- Dark-bg + game-scale contact previews; alpha/size/pivot QA report.
- Animator handoff: `docs/design/references/berserk_v2/berserk_v2_design_handoff.md`.

## Key paths

- Source/refs: `docs/design/references/berserk_v2/`
- Candidate exports: `assets/sprites/characters/berserk_v2/`
- Previews: `docs/design/previews/scrum531_berserk_v2_{dark_bg,contact}.png`
- QA report: `build/qa/scrum531_berserk_v2/scrum531_berserk_v2_alpha_size_report.json`

## Boundary

No gameplay / balance / runtime / animation logic changed. Animation is the
follow-up Animator ticket SCRUM-532.
