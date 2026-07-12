# SCRUM-1084 — Atlas mockup exact 21-socket topology fix

Статус: done
Версия: 0.2.1
Jira: SCRUM-1084
Контур: Codex
Owner: Design / Codex
Thread/Worker: `/root/scrum1068_runtime_review`
Branch: `codex/scrum1084-atlas-topology-fix`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1084-atlas-topology-fix`
Parent QA task: SCRUM-1075

## Locked source-only scope

- `docs/design/mockups/scrum1068_constellation_3x6/**`;
- `docs/design/references/scrum1068_constellation_3x6/**`;
- `docs/design/previews/scrum1068_constellation_3x6/**`;
- this task mirror and SCRUM-1075 evidence;
- scoped Jira sync metadata only at final routing.

Runtime scripts/assets, `scripts/ui_screens.gd` and SCRUM-1073 are excluded.

## Acceptance contract

- regenerate through PixelLab MCP only; no manual pixel deletion/redraw or fallback;
- native raw graph visibly contains exactly 21 sockets: one core, three rays of
  six including finals, and exactly two single side-spur endpoints total;
- no extra junction/socket/keystone is present;
- preserve the accepted 47-element plan, 15 content zones, seven responsive
  targets, Meta40 underlay assembly and hard no-content-on-frame rule;
- update source provenance and deterministic QA evidence, then push directly to
  `origin/dev` and return this bug plus SCRUM-1075 to independent Design QA.

## Result: ready for independent Design QA

- PixelLab-only regeneration completed after two rejected iterations; accepted
  source ID `9bc178ba-1b69-43ce-82af-519e7abea66a`, name
  `scrum1084_constellation_3x6_exact21_v3`, seed `1086`;
- accepted raw source SHA-256:
  `88917fe4d9ebbdd16fbe4e7faf0582d1579439d661a7874e5ca8f05a307112ea`;
- native topology guard detects exactly `21/21` sockets and rejects the former
  source as a negative control; visual review confirms one core, three rays of
  six including finals, and exactly two single side-spur endpoints;
- planning contract remains unchanged: `47` elements, `0` errors, `0` warnings,
  decision `ready_for_image`;
- compositor result is `ok: true`, with all `15/15` content zones fitting and
  no content over frame ornament;
- responsive matrix passes `7/7` from 1152×648 through 3840×2160;
- deterministic regeneration produced byte-identical transparent source, base,
  preview, debug overlay, reports and responsive contact sheet;
- repository-wide `tests/runtime_smoke_test.gd` passed through
  `tools/godot_gate.py` on Godot 4.7; the known headless screenshot
  `texture_2d_get` warning remained non-fatal;
- runtime scripts/assets and SCRUM-1073 files were not modified.

Evidence:

- `docs/design/previews/scrum1068_constellation_3x6/atlas_schema6_topology_report.json`;
- `docs/design/previews/scrum1068_constellation_3x6/atlas_schema6_preview_report.json`;
- `docs/design/previews/scrum1068_constellation_3x6/responsive_fit_report.json`;
- `docs/design/mockups/scrum1068_constellation_3x6/provenance.json`.

Disk cleanup: task-generated `.godot`, import sidecars, UID sidecars, temporary
QA outputs and isolated worktree removed after direct push to `origin/dev`.
