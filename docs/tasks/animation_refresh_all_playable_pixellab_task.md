# Refresh All Playable Character Animations From PixelLab

Jira: SCRUM-869
Статус: new
Контур: Codex
Исполнитель: Codex
Owner: unassigned
Thread: n/a
Locked paths: assets/sprites/characters/pixellab/; assets/sprites/characters/full_frame/*_pixellab/; assets/sprites/characters/*_spriteframes.tres; scripts/progression_data_characters.gd; scripts/player.gd; scripts/ui_screens.gd; tests/*animation*.gd; tests/*hero_select*pixellab*.gd; docs/design/systems/animation.md; docs/design/current_game_state.md; docs/design/content_registry.md; CHANGELOG.md

## Source Request

Пользователь: "И ещё нужно пересмотреть всех персонажей и обновить анимацию с Pixel Lab. Там уже на всех персонажах есть анимация, вот её нужно взять и обновить."

## Scope

- Review every playable character in `ProgressionData.character_ids()`.
- Use PixelLab MCP as the source of truth for existing playable character animation packs.
- Re-download/update the current PixelLab source rotations and movement animations for all playable characters where PixelLab has completed animation data.
- Rebuild normalized `512x512` runtime frames and Godot `SpriteFrames` resources.
- Preserve the current 8-direction idle + 6-frame directional move/walk contract.
- Do not use legacy/manual/non-PixelLab art fallback for refreshed source frames.
- Update manifests, PixelLab metadata, alpha-bbox reports, docs, and QA evidence.

## Acceptance Criteria

- [ ] `tools/update_pixellab_character_animations.py` refreshes all available playable PixelLab packs or records precise blockers for any missing/incomplete pack.
- [ ] Every refreshed character has 8 idle directions and directional move/walk rows that satisfy the current Godot tests.
- [ ] `scripts/progression_data_characters.gd` sprite paths still point to valid south idle runtime frames.
- [ ] Hero Select previews keep directional rotation for refreshed characters.
- [ ] Focused animation/Hero Select tests pass; broader runtime smoke is attempted and result recorded.
- [ ] Jira/local mirror include PixelLab source IDs, changed files, tests, commit/push evidence, and disk cleanup.
