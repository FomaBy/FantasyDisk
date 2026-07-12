# SCRUM-1090 — Atlas detailed upgrade descriptions UI mockup

Статус: done
Версия: 0.2.1
Jira: SCRUM-1090
Контур: Codex
Owner: Design / current Codex task
Thread/Worker: current user-facing Codex task
Branch: `dev`
Worktree: `/Users/sergeyfomin/Documents/AI Agent`

## Locked scope

- `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/`;
- `docs/design/references/scrum1090_atlas_upgrade_descriptions/`;
- `docs/design/previews/scrum1090_atlas_upgrade_descriptions/`;
- this task mirror and task-scoped Jira sync metadata.

Excluded: runtime UI, constellation manifest/data, balance values and tests owned
by SCRUM-1088/SCRUM-1089. Back-end implementation is a separate linked Jira
handoff.

## Source request

The Atlas must explain exactly what each invested point improves. The final
point of every weapon path must read as a unique, sufficiently strong reward
worth reaching.

## Design acceptance

- retain the accepted Atlas page hierarchy and existing production art;
- provide a PixelLab MCP source-only reference for the detailed dossier state;
- show exact-effect, scope, path progress and next-point result as separate
  semantic blocks;
- give a final node a clearly named `УНИКАЛЬНЫЙ ФИНАЛ` callout with trigger,
  numeric result and weapon-only scope;
- reserve a scrollable information viewport instead of shrinking long copy or
  covering ornament;
- keep every runtime label and action inside the calm dossier interior at
  1280×720, 1920×1080 and 2560×1440;
- create a linked Back-end handoff for runtime descriptions/final-node strength.

## Evidence

- PixelLab MCP config smoke: PASS (`get_balance`, no secrets printed).
- Planning contract: `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/ui_plan.json`.
- Render contract: `docs/design/mockups/scrum1090_atlas_upgrade_descriptions/layout.json`.
- PixelLab source ID: `b6693906-f259-4b43-a1b5-4283ff88bec3`.

## Result

- PixelLab source-only page reference generated as
  `b6693906-f259-4b43-a1b5-4283ff88bec3` (688×384, 40 generations); no fallback
  and no runtime promotion.
- Planning gate: `ready_for_image`, 0 errors/warnings.
- Compositor fit: 13/13 content zones PASS. The final-node preview explicitly
  shows a 3-hit trigger, 35% execute threshold, +24% boss cap and +20% strength
  floor over node 5.
- Responsive reference: 3/3 PASS at 1280×720, 1920×1080 and 2560×1440.
- Preview/debug/contact sheet:
  `docs/design/previews/scrum1090_atlas_upgrade_descriptions/`.
- Back-end/data/balance handoff created as linked SCRUM-1091 and left blocked
  until independent Design QA plus release of SCRUM-1088/SCRUM-1089 locks.
- Runtime/data files changed: none.

Disk cleanup: temporary responsive render directory auto-removed; no Godot
cache, disposable clone or worktree created.

Thread cleanup: not a disposable worker thread.
