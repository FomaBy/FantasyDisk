# Druid Ghost Summon Source Pack — Design Handoff

Jira: SCRUM-1015
Parent: SCRUM-901
Animator handoff: SCRUM-1016
Backend roster/gameplay: SCRUM-902
Role: Design Main/Codex
Status: source pack complete; ready for independent Design QA

## Scope

This package contains source concepts only. It deliberately does not include
animation frames, SpriteFrames, runtime ally assets, Godot scripts, gameplay
data or tests. Animator SCRUM-1016 owns the west/east motion integration after
this package is accepted.

## Canonical Roster

| ID | PixelLab template | Gameplay-reading target | Animator action target |
| --- | --- | --- | --- |
| `druid_ghost_wolf` | dog | lean pack hunter; physical melee AoE | claw/body sweep |
| `druid_ghost_bear` | bear | massive guardian; physical melee AoE | heavy ground slam |
| `druid_ghost_panther` | cat | low fast predator; physical melee AoE | pounce and circular rake |
| `druid_ghost_stag` | horse | antlered spirit focus; magical ranged | spirit-lance cast |
| `druid_ghost_lion` | lion | regal luminous mane; magical ranged | spectral roar projectile |

## PixelLab Contract

- Use `create_character` in standard quadruped mode with exactly four source
  directions. No 8-direction generation.
- Save only west/left and east/right PNG concepts in this repository. The
  remaining PixelLab rotations are source-service metadata, not repo/runtime
  dependencies.
- Transparent full-body silhouettes, no crop, stable feet/baseline and enough
  exterior gutter for Animator to normalize later to 256x256 cells.
- Friendly allied blue/cyan spectral palette; no red/orange enemy language,
  gore, decay, hostile skull motifs, text, logo, watermark or background.
- West/east views must preserve identity and readable role-specific silhouette.

## Handoff To SCRUM-1016

Animator consumes the recorded PixelLab character IDs and produces only
`move_left`, `move_right`, `attack_left`, and `attack_right` rows with 5+
frames each. Design does not generate or integrate those animations.

Animator must not claim SCRUM-1016 until this Design pack receives independent
QA acceptance. When accepted, consume these exact source identities:

| ID | PixelLab character ID | Source files |
| --- | --- | --- |
| `druid_ghost_wolf` | `8d473df8-9bc2-481c-ad58-b69cfecc5d33` | `druid_ghost_wolf_{west,east}.png` |
| `druid_ghost_bear` | `6805608a-b64a-471c-a1d9-9601a3062e2f` | `druid_ghost_bear_{west,east}.png` |
| `druid_ghost_panther` | `b2d06d20-aabb-48e2-9d8a-5053daa03e8e` | `druid_ghost_panther_{west,east}.png` |
| `druid_ghost_stag` | `f17948e2-8e1d-44f2-93f1-8f8593ae01fe` | `druid_ghost_stag_{west,east}.png` |
| `druid_ghost_lion` | `48d76788-eeba-4a9f-a36f-bd40a8f42e07` | `druid_ghost_lion_{west,east}.png` |

All source files are RGBA `180x180`. Preserve the original west/east facing
identity. Normalize later animation frames into a shared transparent canvas by
centering the alpha bbox on X and anchoring the visible bottom to a common
baseline; do not scale source pairs independently. Current static-pair bottom
deltas are 1–4 px and all exterior gutters are at least 11 px.

## Design QA Evidence

- `qa_report.json`: PASS for alpha, empty corners, crop gutters and west/east
  baseline stability.
- `../../previews/druid_summons_ghost_pack_contact.png`: reviewed contact sheet.
- `../../previews/druid_summons_ghost_pack_alpha_qa.png`: alpha-bbox overlay.
- PixelLab MCP was the only image-generation source. No OpenAI Images, manual
  drawing, legacy generator, animation or runtime integration was used.
