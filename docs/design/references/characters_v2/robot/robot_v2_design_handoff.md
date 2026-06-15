# Robot v2 Design Source Handoff — SCRUM-432

Status: ready_for_review
Class ID: `robot`
Base style contract: SCRUM-422 bright+epic character v2 anchor

## Accepted Source Package

| Artifact | Path |
| --- | --- |
| Raw OpenAI source | `docs/design/references/characters_v2/robot/robot_v2_source_raw.png` |
| Alpha-clean source | `docs/design/references/characters_v2/robot/robot_v2_source_clean.png` |
| Normalized 512 cell | `docs/design/references/characters_v2/robot/robot_v2_idle_cell_512.png` |
| Source-sheet handoff | `docs/design/references/characters_v2/robot/robot_v2_sheet_source_handoff.png` |
| Asset-side idle source | `assets/sprites/characters/v2/robot/robot_v2_idle_source.png` |
| Asset-side source-sheet handoff | `assets/sprites/characters/v2/robot/robot_v2_sheet_source_handoff.png` |
| Contact preview | `docs/design/previews/scrum432_robot_v2_contact.png` |
| QA report | `build/qa/scrum432_robot_v2/scrum432_robot_v2_alpha_size_report.json` |

## Visual Direction

Robot v2 is a bright, epic, class-readable mechanical guardian: polished fantasy
metal plates, clean heroic silhouette, cyan/blue neon sensors, core glow and
rune seams. The hands are empty and readable: no weapon, gun, sword, shield,
tool, wrench, cannon, orb or other held object is baked into the character.

## Source Format

- Transparent RGBA source after checker/white matte cleanup.
- Normalized cell: `512x512`.
- Target visible body height: `376 px`.
- Pivot: `[256, 470]`, bottom-center foot alignment.
- Normalized visible bbox: `[121, 94, 391, 470]`.
- Source-sheet handoff: `2560x1024`, 5 idle placeholder cells + 5 move
  placeholder cells, provided only for source sizing/pivot continuity.

## QA

- Clean alpha min/max: `[0, 255]`.
- Edge-visible pixels after cleanup: `0`.
- Edge floodable neutral/checker pixels after cleanup: `0`.
- Removed disconnected checker/fringe component pixels: `43`.
- Dark-background contact preview confirms no baked white/checker backdrop.

## Animator Boundary

This package is Design-source only. Animator owns the real idle and move/walk
motion rows, SpriteFrames/AnimationPlayer/AnimationTree/runtime wiring and
smoke tests after this source handoff is accepted. Attack remains explicitly out
of scope for SCRUM-432.
