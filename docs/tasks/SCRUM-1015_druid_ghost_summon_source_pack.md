# SCRUM-1015 — Druid Ghost Summon PixelLab Source Pack

Статус: done (ready for independent Design QA)
Контур: Codex
Owner: Design Main/Codex
Thread/Worker: `/root/audit_repo`
Jira: SCRUM-1015
Parent: SCRUM-901
Animator handoff: SCRUM-1016
Backend dependency: SCRUM-902
Locked writes: `docs/design/references/druid_summons_ghost_pack/**`, `docs/design/previews/druid_summons_ghost_pack_*.png`, this mirror, scoped SCRUM-1015 sync-map entry.
Read-only: `assets/**`, `scripts/**`, `scenes/**`, `tests/**`, runtime/product docs.

## Goal

Create a PixelLab-only five-creature source concept pack for the Druid Summon
Amulet: wolf, bear, panther, stag and lion. Deliver only west/east transparent
Design concepts and provenance. Do not perform animation or runtime work.

## Progress

- SCRUM-901 decomposed into this Design issue and Animator SCRUM-1016.
- PixelLab MCP config smoke PASS; existing matching character inventory empty.
- Five standard 4-direction quadruped requests prepared; repository exports are
  restricted to west/east.

## Result — 2026-07-09

- Created five PixelLab-only characters and exported ten transparent RGBA
  `180x180` source PNGs, west/east only:
  - wolf `8d473df8-9bc2-481c-ad58-b69cfecc5d33`;
  - bear `6805608a-b64a-471c-a1d9-9601a3062e2f`;
  - panther `b2d06d20-aabb-48e2-9d8a-5053daa03e8e`;
  - stag `f17948e2-8e1d-44f2-93f1-8f8593ae01fe`;
  - lion `48d76788-eeba-4a9f-a36f-bd40a8f42e07`.
- Visual review PASS: all five creatures have distinct friendly spectral
  silhouettes and readable role families; west/east facings are coherent.
- Alpha/crop QA PASS for all ten files: transparent corners, alpha range
  `0..255`, minimum exterior gutter `11 px`, maximum pair baseline delta `4 px`.
- Evidence:
  `docs/design/references/druid_summons_ghost_pack/qa_report.json`,
  `docs/design/previews/druid_summons_ghost_pack_contact.png`, and
  `docs/design/previews/druid_summons_ghost_pack_alpha_qa.png`.
- PixelLab MCP only; no OpenAI Images/manual/legacy fallback. No animation,
  SpriteFrames, runtime asset, scene, script, gameplay, balance or test file was
  created or changed.
- SCRUM-1016 remains blocked until independent QA accepts this Design pack.

Verification:

- PASS `python3 docs/design/references/druid_summons_ghost_pack/build_contact_sheet.py`.
- PASS JSON validation for manifest and QA report.
- PASS static source-pack validation: 10/10 files are RGBA `180x180` PNGs.
- PASS `git diff --check`.
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  (`texture_2d_get` from the headless Weapon Select screenshot helper is an
  existing non-fatal warning; exit 0 and `Runtime smoke test passed`).

Git/Jira and disk-cleanup evidence are appended after push and status sync.
