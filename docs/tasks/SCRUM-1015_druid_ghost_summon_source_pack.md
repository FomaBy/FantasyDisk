# SCRUM-1015 — Druid Ghost Summon PixelLab Source Pack

Статус: done (independent QA PASSED)
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

Git/Jira:

- Source package commit `9450c531` pushed directly to `origin/dev`.
- Live Jira SCRUM-1015 transitioned to `Контроль качества`; ready-for-QA
  evidence posted. This is not a self-QA verdict.
- SCRUM-1016 received the exact PixelLab-ID/source-path handoff and remains
  blocked until independent Design acceptance. SCRUM-901 remains decomposed and
  blocked by its children.

Disk cleanup: removed task `.godot` import cache (`445 MB`) and Python caches;
the clean disposable worktree is removed after the final sync commit is pushed.

## QA-Вердикт — 2026-07-10, `/root/audit_ready`

Статус: PASSED (`/root/audit_ready`, Codex QA lane).

- Reviewed the source package independently from fresh `origin/dev`, without
  modifying source PNGs, manifest, previews, runtime assets, scripts or tests.
- Provenance/contract PASS: the manifest contains exactly the five canonical
  IDs and five unique valid PixelLab UUIDs; each captured `create_character`
  request is a standard four-direction quadruped request, while repository
  exports are intentionally restricted to `west`/`east`.
- File/alpha PASS: exactly ten source PNGs, all transparent RGBA `180x180`, no
  `.import` sidecars, transparent corners, alpha extrema `0..255`, manifest
  bounding boxes reproduced, minimum exterior gutter `11 px`.
- Pair consistency PASS: west/east bottom-baseline deltas are wolf `1 px`, bear
  `1 px`, panther `1 px`, stag `4 px`, lion `3 px` (maximum `4 px`).
- Visual PASS: contact sheet and alpha/bbox overlay were reviewed at source
  resolution. Wolf, bear, panther, stag and lion remain distinct, readable and
  directionally coherent; the spectral cyan/blue treatment, safe gutters and
  transparent backgrounds are consistent. No text, logo or baked background is
  present in the source PNGs.
- Scope PASS: source commit `9450c531` and handoff sync `231e52c5` add Design
  source/evidence only; no SpriteFrames, animation rows, runtime integration,
  gameplay or balance implementation is included.
- Handoff PASS: SCRUM-1016 contains the exact five UUIDs and canonical source
  path contract, remains unassigned, and is released only after this verdict.

Independent verification:

- PASS `python3 docs/design/references/druid_summons_ghost_pack/build_contact_sheet.py`
  (`ok: true`; regenerated evidence leaves the worktree clean).
- PASS independent Pillow assertions for file set, RGBA/size, alpha bbox,
  transparent corners, gutters and west/east baseline deltas.
- PASS JSON parse and manifest/request-contract assertions.
- PASS `git diff --check 9450c531^..231e52c5`.
- PASS `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  (`Runtime smoke test passed`, exit `0`; the known headless `texture_2d_get`
  screenshot-helper warning remains non-fatal).

No QA bugs were found. Jira SCRUM-1015 may move to `Готово`; SCRUM-1016 may be
unblocked for the Animator lane; the raw Jira link payload confirms the existing
`SCRUM-1016 is blocked by SCRUM-1015` dependency direction is already correct.
