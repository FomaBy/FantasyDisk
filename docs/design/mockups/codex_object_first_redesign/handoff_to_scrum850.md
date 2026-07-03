# SCRUM-849 Handoff To SCRUM-850

Status: ready_for_integration
Source task: SCRUM-849
Target task: SCRUM-850

## Package

- Mockup/spec: `docs/design/mockups/codex_object_first_redesign/spec.md`
- Machine-readable zones: `docs/design/mockups/codex_object_first_redesign/layout_zones.json`
- PixelLab prompt/provenance: `docs/design/mockups/codex_object_first_redesign/pixellab_prompt.md`
- PixelLab mockup PNG: `docs/design/mockups/codex_object_first_redesign/pixellab_mockup_v1.png`
- 1920 preview: `docs/design/previews/codex_object_first_redesign_mockup_v1_1920.png`
- Safe-zone overlay: `docs/design/previews/codex_object_first_redesign_safe_zones_v1.png`
- Contact sheet: `docs/design/previews/codex_object_first_redesign_contact_v1.png`

## Required Runtime Direction

- Keep all six sections: Characters, Monsters, Artifacts, Stats, Glossary,
  Ascensions.
- Left rail: category navigation only.
- Center panel: selected/list overview only; image + title + one short summary
  or compact selector. Do not duplicate full body text here.
- Right panel: full detail. `right_object_stage` is the largest image placement
  on screen and must remain the visual anchor.
- Use contained object-fit with nearest filtering and alpha-bbox centering for
  hero/monster/boss/object sprites. Do not cover-crop object art.
- Body text and scrollbars stay inside `right_text_scroll`; chips stay inside
  `right_chip_row`.
- No runtime content may overlap shell/panel/button ornaments, rivets, gems,
  dragon claws, brass rails, or scroll gutters.

## Canonical Image Sources

- Heroes: `ProgressionData.character_config().sprite_path`, usually
  `assets/sprites/characters/full_frame/<class>_pixellab/<class>_idle_south.png`
  for PixelLab-backed classes.
- Artifacts: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png`.
- Shop-only items in the artifact section:
  `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`.
- Monsters/bosses: `CodexData.MONSTERS[*].sprite`. Document weak or small art
  as separate Design follow-ups instead of hiding it with extra frames.
- Stats: `scripts/ui_icon_registry.gd`.

## Suggested Verification For SCRUM-850

- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/codex_data_smoke_test.gd`
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- Capture Codex screenshots at 1280x720, 1920x1080, and 2560x1440, including at
  least one non-character category.
