# SCRUM-1075 — PixelLab mockup/spec for Atlas schema-6 3×6 constellation

Статус: blocked
Версия: 0.2.1
Jira: SCRUM-1075
Контур: Codex
Owner: Design / Codex
Thread/Worker: `/root/audit_new_sprint_tail`
Branch: `codex/scrum1075-constellation-mockup`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum1075-constellation-mockup`
Parent implementation: SCRUM-1068

## Locked source-only scope

- `docs/design/mockups/scrum1068_constellation_3x6/**`;
- this task mirror and scoped Jira sync metadata at final routing.

Runtime scripts, production assets and SCRUM-1068/SCRUM-1073 implementation
files are excluded.

## Workflow

UI Director inventory → content-zone plan and `ready_for_image` gate →
PixelLab MCP source mockup → composited preview/debug overlay → seven-size fit
evidence. The accepted Meta40 art family and SCRUM-1070 reset-footer contract
remain the production implementation source; this package defines the new
schema-6 topology without promoting new runtime art.

## Result: blocked before image generation

- content inventory and exact 1920×1080 geometry are recorded in
  `docs/design/mockups/scrum1068_constellation_3x6/ui_plan.json`;
- compositor planning gate: `ready_for_image`, `47` elements, `0` errors,
  `0` warnings;
- `layout.json`, guide overlay and exact PixelLab request were created before
  generation as required;
- PixelLab MCP config smoke passed through `get_balance`; no secret was printed;
- live balance: `$0.00` credits, `3/5000` subscription generations remaining;
- `create_ui_asset` documents a `20–40` generation UI-panel job and rejected
  the request with `no generations or credits remaining for creating a UI panel`.

No alternative image generator, manual fallback, runtime script or production
asset was used. The ticket returns to Jira `К выполнению` until PixelLab has
enough credits/generations; resume from `pixellab_request.json` without changing
the approved zones.

Disk cleanup: no Godot/cache or PixelLab export scratch was created; disposable
worktree is removed after the blocker evidence is pushed.

