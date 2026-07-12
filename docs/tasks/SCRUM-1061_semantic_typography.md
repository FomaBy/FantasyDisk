# SCRUM-1061 — Semantic typography

Статус: done
Контур: Codex
Owner: /root/scrum1061_semantic_typography
Thread: /root/scrum1061_semantic_typography
Jira: SCRUM-1061
Branch: `codex/scrum1061-semantic-typography`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1061-semantic-typography`

## Locked paths

- `scripts/ui/semantic_typography.gd`;
- typography-only hunks in `scripts/ui_screens.gd`, route-map, pause dossier,
  global tooltip, toast, threat indicator, player/enemy feedback and HUD;
- SCRUM-1061 spec/inventory/tests/docs.

Excluded: SCRUM-1062 Continue Run geometry; Atlas topology owned by SCRUM-1068;
Atlas reset-footer owned by SCRUM-1070; the 139-site legacy cross-band geometry
follow-up SCRUM-1073; new art/assets.

## UI Director package

- Contact sheet:
  `docs/design/mockups/scrum1061_semantic_typography/accepted_frames_contact_sheet.png`.
- Geometry/spec: `docs/design/mockups/scrum1061_semantic_typography/spec.md`.
- Token/overflow contract:
  `docs/design/mockups/scrum1061_semantic_typography/token_contract.md`.
- Inventory:
  `docs/design/mockups/scrum1061_semantic_typography/typography_inventory.json`.
- Accepted PixelLab source screens are reused; no new art generation and no
  frame/content-zone changes.

## Result

- canonical 12-role semantic typography API implemented;
- route-map duplicate formula removed;
- readable/Settings/Codex/pause compatibility helpers delegate centrally;
- tooltips, toast, threat/world feedback and raw HUD routed centrally;
- stable fingerprint inventory and Russian/token matrix test added.
- all runtime compatibility helper calls carry an explicit semantic role;
  schema-2 inventory records exact reviewed bounds for 245 sites (104 in-band,
  141 accepted cross-band allowlist contracts) without weakening native tokens.
- allowlist routing is truthful: two Atlas-canvas fingerprints route to
  SCRUM-1068 and the exact remaining 139-site manifest routes to the dedicated,
  unassigned current-sprint follow-up SCRUM-1073; SCRUM-1070 owns no inventory
  fingerprint.

Landed in `origin/dev` through implementation commit `72b7493f0` and integration
commit `d05877228`. Two independent reviewers returned FINAL PASS with no
remaining P1/P2. Jira SCRUM-1061 is in `Контроль качества`; it must not move to
`Готово` before independent QA.

Post-integration PASS: inventory freshness, semantic typography, Settings
SCRUM-1060, Continue Run SCRUM-1062, Pause SCRUM-983, Codex SCRUM-954, Priest
Prayer SCRUM-926, runtime UI, six-size no-overlap, gamepad focus/full-flow and
full runtime smoke. macOS/Metal runs also passed Settings, Codex and Continue
Run. The known dummy-renderer texture warning remains non-fatal and pre-existing.

Disk cleanup: removed the task `.godot` cache (~445 MB), task Python cache and
all `/tmp/fsd-scrum1061-*` user-data roots. The clean registered worktree and
its tracked checkout are removed immediately after this mirror commit is pushed.

## QA claim (2026-07-11)

QA: complete — `/root/audit_new_sprint_tail`, disposable fresh-origin
worktree `codex/qa-scrum1061`. Implementation paths remain unlocked/read-only;
QA writes only verdict evidence and scoped Jira sync after the independent gate.

## QA-Вердикт (2026-07-11)

Статус: PASSED

- Reviewed implementation `72b7493f0` and the landed state through
  `4e36e7825`: semantic intent, the 12-role API, transform-aware Codex refresh,
  centralized compatibility helpers and documentation are coherent; no
  unrelated SCRUM-1061 functional changes were found.
- Inventory freshness passed at schema 2: 245 sites = 104 mapped + 141
  allowlisted + 0 unreviewed, with 16 indirect semantic bindings. Routing is
  exact: 2 Atlas fingerprints to SCRUM-1068, 139 non-Atlas fingerprints to the
  unassigned current-sprint SCRUM-1073, and 0 fingerprints to SCRUM-1070.
- Six independent guard mutations were rejected: new unreviewed site, runtime
  role drift, missing allowlist owner, wrong Atlas route, cross-band site marked
  mapped and a missing helper binding.
- Semaphore/isolated-user-data PASS: semantic/Russian 648/720/900/1080/2K/4K,
  Settings SCRUM-1060, Continue SCRUM-1062, Pause SCRUM-983, Codex SCRUM-954,
  Prayer SCRUM-926, gamepad menu/in-run/core/full-flow, runtime UI, six-size
  no-overlap matrix and full runtime smoke.
- Representative macOS/Metal PASS on Apple M4 Pro: Settings, Codex and
  Continue. The pre-existing dummy-renderer `texture_2d_get` screenshot warning
  remained non-fatal; both runtime suites exited 0.

Баги: нет.

Disk cleanup: removed generated UID sidecars, the disposable `.godot` cache
(~446 MB), isolated `/tmp/fsd-qa1061-*` user-data roots and Python caches;
tracked baseline QA evidence was preserved. The clean worktree is removed after
the verdict commit reaches `origin/dev`.
