# ART/ANIM PixelLab: «Ассасин» (assassin) — final 8-direction runtime redraw

Статус: done
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.1.8
Создано: 2026-07-01
Jira: SCRUM-803
Контур: Codex
Owner: Design/Codex
Thread/Worker: codex-scrum-803-sidecar-cleanup-20260702
Locked paths: `assets/sprites/characters/pixellab/assassin/`, `assets/sprites/characters/full_frame/assassin_pixellab/`, `assets/sprites/characters/assassin_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.

Dispatch: Jira-pull claimed by Animator/Codex (`codex-animator-auto`) 2026-07-01.

## Context / Problem

`assassin` still uses legacy/v2 non-PixelLab runtime art in active `dev`.
SCRUM-419 was a v2 design-source handoff and is already done; this ticket is the
PixelLab-final live runtime pass.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. The base body must
stay empty-handed: no baked chakrams, daggers, venom wire, or UI frame.

References:
`docs/design/references/characters_v2/assassin/assassin_v2_source_clean.png`,
`docs/design/references/characters/assassin/assassin_sheet_source.png`,
`assets/sprites/characters/assassin.png`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/assassin/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/assassin_pixellab/`.
- `assets/sprites/characters/assassin_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `assassin.sprite_path` to `res://assets/sprites/characters/full_frame/assassin_pixellab/assassin_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.

## Result / 2026-07-01 Codex Animator

Status: implementation complete on branch; blocked from QA handoff by stale
external Godot/godot_gate processes occupying the required test gate.

- Accepted PixelLab source: `ec73da27-b704-4336-9275-74c8e3e578df`
  (`FantasyDisk Assassin SCRUM-803 empty open hands retry`).
- Rejected/deleted PixelLab source: `cdee7e9a-1d04-430e-8fc9-60fafc2cd4a8`;
  rejected before import because the preview baked a held blade, violating the
  empty-hands requirement.
- Source pack: `assets/sprites/characters/pixellab/assassin/` with
  `manifest.json`, 8 idle rotations and 48 movement frames.
- Runtime pack: `assets/sprites/characters/full_frame/assassin_pixellab/` with
  56 transparent `512x512` PNGs normalized to 245 px visible height.
- Runtime wiring: `assassin_spriteframes.tres` now exposes generic
  idle/move/walk fallbacks plus 8-direction `idle_`, `move_` and `walk_` rows;
  `scripts/progression_data_characters.gd` points Assassin portraits to
  `assassin_idle_south.png`.
- Evidence: `docs/design/previews/scrum803_assassin_pixellab_contact.png`,
  `docs/design/previews/scrum803_assassin_pixellab_bbox_report.json`, and
  `docs/design/previews/scrum803_assassin_pixellab_bbox_report.md`.

Local validation:

- PASS: Python/Pillow asset shape check confirmed 56 source PNGs, 56 runtime
  PNGs, and every runtime frame is transparent RGBA `512x512`.
- BLOCKED: `python3 tools/godot_gate.py --headless --path . --script
  res://tests/character_sprite_registry_alignment_test.gd` did not reach Godot
  because the gate was occupied by unrelated long-running Godot imports/tests
  (examples observed: `unique_weapon_vfx_assets_test.gd`,
  `attack_vfx_smoke_test.gd`, `animation_smoke_test.gd`, multiple
  `--import --quit` processes aged 5-22 minutes). This worker stopped only its
  own waiting gate process and did not kill other workers' processes.

Next worker/dispatcher action: free or wait out stale Godot gate processes, then
run the required focused smokes:

- `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`

## QA-Вердикт (2026-07-02)

Статус: FAILED

Проверено:
- origin/dev `90b77eb2`, worktree `/Users/sergeyfomin/.codex/worktrees/36b8/AI Agent`.
- Static PixelLab contract for `assassin`: PASS for 56 source PNGs, 56 runtime
  PNGs, source `manifest.json`, runtime `512x512` RGBA frames, resolved
  `assassin_spriteframes.tres` refs, generic and 8-direction idle/move/walk
  rows, and canonical `assassin_idle_south.png` `sprite_path`.
- FAIL: task-owned sidecars are committed under the PixelLab pack directories:
  56 `.import` files in `assets/sprites/characters/pixellab/assassin/` and 56
  `.import` files in `assets/sprites/characters/full_frame/assassin_pixellab/`.
  Acceptance for the combined QA batch requires no task-owned `.import`/`.uid`
  sidecars.
- BLOCKED environment evidence: first required Godot gate,
  `FSD_GODOT_MAXWAIT=86400 python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`,
  started the headless import, but after 5:48 `.godot/imported` still had 0
  files and `.godot/` contained only `.gdignore` plus
  `global_script_class_cache.cfg`; the worker interrupted its own gate with exit
  130 and confirmed no Godot/Godot gate process remained.

Баги: no separate bug issue created; SCRUM-803 itself is returned to
`К выполнению` for a focused fix: remove the 112 tracked Assassin PixelLab
`.import` sidecars, keep the PNG/source/runtime contract unchanged, then rerun
the required Godot gates from origin/dev.

Disk cleanup: removed this worker's `.godot/` cache after recording evidence.

## Result / 2026-07-02 Codex sidecar cleanup

Status: focused SCRUM-803 QA fix complete; ready for QA rerun.

- Removed only the 112 tracked Assassin PixelLab `.import` sidecars:
  56 under `assets/sprites/characters/pixellab/assassin/` and 56 under
  `assets/sprites/characters/full_frame/assassin_pixellab/`.
- Preserved all Assassin source/runtime PNGs, `manifest.json`,
  `assassin_spriteframes.tres`, and
  `scripts/progression_data_characters.gd`.
- Final static validation PASS:
  56 source PNGs, 56 runtime PNGs, 56 resolving SpriteFrames refs,
  generic and 8-direction idle/move/walk rows with 1/6/6 frames,
  canonical `assassin_idle_south.png` `sprite_path`, and 0 tracked/physical
  `.import` or `.uid` sidecars in the two Assassin PixelLab dirs.
- Godot gates PASS through `python3 tools/godot_gate.py`:
  `res://tests/character_sprite_registry_alignment_test.gd`,
  `res://tests/hero_select_pixellab_layout_test.gd`,
  `res://tests/animation_smoke_test.gd`, and
  `res://tests/runtime_smoke_test.gd`.
- No art was regenerated and no PNG/source/runtime/SpriteFrames contract was
  changed.

Disk cleanup: removed this worker's `.godot/` cache, removed generated untracked
`.import`/`.uid` sidecars from the Godot verification run, and no Python
`__pycache__` remained.
