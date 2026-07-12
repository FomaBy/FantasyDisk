# SCRUM-1065 — Player Projectile Art Pack

Jira: SCRUM-1065
Статус: done
Контур: Codex
Owner: Design/Codex
Thread/Worker: `/root/scrum1065_projectile_pack_resume`
Branch/worktree: `codex/scrum1065-projectile-pack` at
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1065-projectile-pack`
Locked paths: `docs/design/references/SCRUM-1065_player_projectiles/**`,
`docs/design/previews/SCRUM-1065_player_projectiles/**`,
`assets/sprites/projectiles/player/**`, this mirror, and projectile inventory
hunks in the four design docs updated by this task.

## Scope

Design-only source/production projectile pack and canonical 17-class/51-weapon
inventory. No scripts, scenes, gameplay timing, collision, damage, targeting or
runtime routing changes. Backend integration remains SCRUM-1066.

## Result

- PixelLab MCP config smoke PASS; no secrets printed and no fallback used.
- Five permanent `create_1_direction_object` review packs produced 19 accepted
  new objects; accepted SCRUM-934 Sniper shatter projectile was preserved as the
  twentieth profile.
- Inventory: 17/17 classes, 51/51 weapons, 20 flying/projectile-like profiles,
  31 intentional non-projectile entries with mechanical explanations.
- Source exports and provenance:
  `docs/design/references/SCRUM-1065_player_projectiles/manifest.json`.
- Production PNG:
  `assets/sprites/projectiles/player/<character_id>/`.
- QA: 40/40 source/runtime images RGBA, transparent corners, non-empty alpha
  bbox and minimum 6px crop padding; all PASS in `qa_report.json`.
- Previews: native source contact sheet plus real-game-scale dark/light contact
  sheet in `docs/design/previews/SCRUM-1065_player_projectiles/`.
- PixelLab task-reported cost: 100 generations (five calls ×20). Final shared
  account balance after parallel work: 2656 generations remaining.

## Handoff

SCRUM-1066 may claim the backend runtime integration only after this commit is
on `origin/dev` and the Jira QA-ready comment records the exact commit. Backend
must consume `manifest.json`, not infer profiles from filenames, and must not
edit or regenerate the accepted source pack.

## Verification

- `python3 -m json.tool .../manifest.json` — PASS.
- `python3 -m json.tool .../qa_report.json` — PASS.
- Inventory assertions: 17 classes, 51 weapons, 20 projectile profiles,
  31 intentional N/A — PASS.
- Asset QA assertions: 20 source/runtime pairs, 40/40 PASS, min padding 6px.
- Visual review: native and real-scale dark/light contact sheets — PASS.
- `HOME=/tmp/scrum1065-home XDG_CACHE_HOME=/tmp/scrum1065-cache
  GODOT_BIN=/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot
  python3 tools/godot_gate.py --headless --path . --script
  res://tests/runtime_smoke_test.gd` — PASS (the known dummy-renderer null
  texture message during headless screenshot capture is non-fatal; exit 0 and
  `Runtime smoke test passed.`).

Disk cleanup: removed task `.godot/` (446 MB), `/tmp/scrum1065-home` and
`/tmp/scrum1065-cache`; disposable worktree will be removed after push, Jira
handoff and final sync.
