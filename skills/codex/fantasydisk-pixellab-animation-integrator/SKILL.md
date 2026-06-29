---
name: fantasydisk-pixellab-animation-integrator
description: "Use when integrating PixelLab-created FantasyDisk character animation packs into Godot: fetching a character by PixelLab tag/name, importing 8-direction idle and movement frames, normalizing PNGs into full-frame runtime assets, rebuilding SpriteFrames, wiring directional player movement, and making the Hero Select character preview rotate clockwise through the same directional frames."
---

# FantasyDisk PixelLab Animation Integrator

## Purpose

Apply PixelLab animation packs to existing FantasyDisk characters. This skill replaces the old rig/sprite-sheet animation director for character runtime integration; prefer PixelLab-authored idle and movement frames over generating or slicing new motion.

## Workflow

1. Sync the repo before work: check branch/dirty tree, fetch/pull `dev`, and keep unrelated WIP out of the commit.
2. Read the FantasyDisk onboarding/process docs required by `AGENTS.md` for animation, visual, UI, and gameplay-adjacent changes.
3. Locate the PixelLab character through the PixelLab MCP server. Prefer `list_characters` filtered by tag/name, then `get_character` for the selected ID.
4. Confirm the pack has 8 directional idle poses and 8 directional movement animations:
   `south`, `south-east`, `east`, `north-east`, `north`, `north-west`, `west`, `south-west`.
5. Download source PNGs into `assets/sprites/characters/pixellab/<character_id>/`.
   Store `manifest.json` with PixelLab IDs, directions, frame counts, and source file names. Do not store API tokens or Authorization headers.
6. Normalize source frames into full-frame runtime PNGs under `assets/sprites/characters/full_frame/<character_id>_pixellab/`.
   Use transparent 512x512 canvases, nearest-neighbor scaling, centered x, bottom-aligned y, and no crop.
7. Build or update `assets/sprites/characters/<character_id>_spriteframes.tres` with:
   `idle`, `move`, `walk`, plus `idle_<dir>`, `move_<dir>`, and `walk_<dir>` for all 8 directions. Use underscores in animation names, hyphens in PNG file names if that is how the source files are named.
8. Update `scripts/progression_data_characters.gd` so the character `sprite_path` points to the south idle runtime PNG.
9. Update or preserve `scripts/player.gd` directional logic:
   movement should play `walk_<dir>`/`move_<dir>` based on the current movement vector, idle should play `idle_<dir>` based on last facing direction, and directional animations must not be horizontally flipped.
10. Update Hero Select in `scripts/ui_screens.gd`:
   if the selected character has directional SpriteFrames, its preview should cycle clockwise through `south -> south_west -> west -> north_west -> north -> north_east -> east -> south_east` and advance the movement frame index.
11. Add or update focused smoke coverage:
   animation smoke must assert all 8 directional rows and frame counts; Hero Select smoke must assert the portrait texture advances for the integrated character.
12. Update live docs: `CHANGELOG.md`, `docs/design/current_game_state.md`, `docs/design/content_registry.md`, and relevant `docs/design/systems/*.md`.
13. Run focused Godot smokes through `tools/godot_gate.py`. Run broader smoke when the worktree is clean enough; if unrelated WIP blocks it, record the exact blocker.
14. Commit and push only task-owned files.

## PixelLab Access

Use PixelLab MCP tools when available in the chat. If the MCP tools are not exposed but the local Codex config already defines the PixelLab MCP server, it is acceptable to call `npx mcp-remote` locally for JSON-RPC calls. Never print or commit the bearer token. If direct image URLs return 403, retry downloads with a browser-like `User-Agent`.

Keep PixelLab source and runtime assets separate:

```text
assets/sprites/characters/pixellab/<character_id>/
assets/sprites/characters/full_frame/<character_id>_pixellab/
```

Use deterministic names:

```text
<character_id>_idle_south.png
<character_id>_move_south_00.png
<character_id>_move_south_01.png
```

## Helper Script

After downloading source PNGs, run the bundled helper from the repo root:

```bash
python3 ~/.codex/skills/fantasydisk-pixellab-animation-integrator/scripts/build_directional_spriteframes.py \
  --character-id berserk \
  --source-dir assets/sprites/characters/pixellab/berserk \
  --runtime-dir assets/sprites/characters/full_frame/berserk_pixellab \
  --spriteframes assets/sprites/characters/berserk_spriteframes.tres
```

The script validates all 8 idle poses and 6 movement frames per direction by default, writes normalized runtime frames, and writes a Godot 4 `SpriteFrames` resource. Adjust `--move-frame-count`, `--cell-size`, `--scale`, or `--bottom-padding` only when the PixelLab pack genuinely differs.

## Acceptance

The work is complete only when:

- The character moves in-game with the correct directional animation for cardinal and diagonal movement.
- Idle preserves the last facing direction.
- Hero Select preview rotates clockwise with live frames, not a static PNG.
- Source PixelLab files, runtime files, SpriteFrames, config, docs, and tests are committed.
- Focused animation and Hero Select smoke tests pass.
