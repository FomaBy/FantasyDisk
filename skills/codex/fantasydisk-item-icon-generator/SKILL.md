---
name: fantasydisk-item-icon-generator
description: Use this skill when generating, revising, or specifying FantasyDisk artifact icons, stat or attribute icons, weapon icons, or item-icon source packs that need canonical IDs, transparent PNG output, D&D + Dark Fantasy Dragon style, small-size readability, and QA evidence.
---

# FantasyDisk Item Icon Generator

Use this skill for focused item-icon work after the repository instructions in `AGENTS.md` and the current Jira issue have been checked. This skill narrows `$fantasydisk-asset-generator` for three icon families: artifacts, stat/attribute icons, and weapon icons.

## Scope

- In scope: icon art direction, OpenAI Images prompt design, transparent source PNGs, exact naming, source/reference storage, contact sheets, alpha/readability QA, and handoff notes.
- Out of scope: gameplay, balance, runtime integration, UI layout code, animation rigs, and mass production packs unless the Jira issue explicitly asks for them.
- Do not use old manual or non-OpenAI generation flows. Reuse the current asset pipeline from `$fantasydisk-asset-generator`.

## Required Inputs

Before generating or specifying icons, record these inputs in the task notes:

- `asset_category`: one of `artifact`, `base_stat`, `derived_attribute`, or `weapon`. For attribute icons pick `base_stat` (→ `stats/stat_<id>.png`) for the eight core stats, `derived_attribute` (→ `derived/attr_<id>.png`) otherwise.
- `canonical_id`: snake_case runtime ID from `docs/design/content_registry.md` or the relevant `ProgressionData` table.
- `display_name`: player-facing name, only for prompt intent; do not bake text into the icon.
- `target_size`: final PNG size, normally `256x256` unless the issue names another size.
- `final_path`: exact runtime path from the asset matrix below.
- `source_dir`: exact source/reference folder under `docs/design/references/icons/`.
- `style_notes`: material, silhouette, class/stat association, palette constraints, and any must-avoid motifs.
- `qa_evidence`: preview/contact-sheet path and alpha/readability report path.

## Asset Matrix

Use these default paths unless the Jira issue names a newer canonical route:

| Category | Runtime PNG | Source/reference folder | Preview/evidence |
| --- | --- | --- | --- |
| Artifact | `assets/sprites/ui/icons/artifacts/artifact_<canonical_id>.png` | `docs/design/references/icons/artifacts/<canonical_id>/` | `docs/design/previews/artifact_icons_<batch>.png` |
| Base stat | `assets/sprites/ui/icons/stats/stat_<canonical_id>.png` (prefix `stat_`) | `docs/design/references/icons/attributes/<canonical_id>/` | `docs/design/previews/attribute_icons_<batch>.png` |
| Derived attribute | `assets/sprites/ui/icons/derived/attr_<canonical_id>.png` (prefix `attr_`) | `docs/design/references/icons/attributes/<canonical_id>/` | `docs/design/previews/attribute_icons_<batch>.png` |
| Weapon | `assets/sprites/weapons/<canonical_id>.png` | `docs/design/references/icons/weapons/<canonical_id>/` | `docs/design/previews/weapon_icons_<batch>.png` |

The eight base character attributes live in `stats/` with the `stat_` prefix (`strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership`). All derived/secondary attributes (damage, defense, move_speed, crit_chance, aoe_radius, pickup_radius, …) live in `derived/` with the `attr_` prefix. `scripts/ui_icon_registry.gd` (`ICON_PATHS`) loads base stats from `stats/stat_<id>.png` and derived attributes from `derived/attr_<id>.png` — match the folder/prefix to whether the canonical id is a base stat or a derived attribute, do not write a base stat into `derived/`.

For weapon attack signatures or VFX plates, use the dedicated VFX route only when the Jira issue explicitly asks for it: `assets/sprites/effects/vfx_weapon_<canonical_id>.png`.

## Generation Workflow

1. Confirm ownership in Jira and locked paths before creating files.
2. Validate canonical IDs against `docs/design/content_registry.md` and any live data table used by the issue.
3. Build one prompt per icon using the prompt template below, preserving the category and ID in local notes.
4. Generate through the OpenAI Images pipeline from `$fantasydisk-asset-generator`, saving source PNGs under the source/reference folder first.
5. Crop/resize only to the requested square size, keeping transparent padding and the full subject visible.
6. Export final PNGs to the runtime path with the exact matrix naming.
7. Produce a contact sheet at runtime scale and a QA report covering alpha, cropping, readability, and naming.
8. Update the Jira issue and local mirror with generated paths, evidence paths, and any handoff needed for integration.

The project-local `tools/artgen/generate_asset.py` is **optional** and is not present in the repository today — do not assume it exists. The canonical generator is the bundled one from `$fantasydisk-asset-generator` at `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py`; use it as the default. Only prefer a project-local `tools/artgen/generate_asset.py` if it has actually been added to the repo. Example bundled command (the canonical fallback), adjusted for the exact source path and size:

```bash
python3 ~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py \
  --prompt "<prompt from this skill>" \
  --output docs/design/references/icons/<category>/<canonical_id>/<canonical_id>_source.png \
  --size 1024x1024 \
  --quality high
```

Keep the same OpenAI Images API workflow and do not fall back to legacy generators. If the generator output is not alpha-ready, postprocess alpha before exporting the final runtime PNG.

## Prompt Template

Use one concise image prompt per icon:

```text
D&D + Dark Fantasy Dragon game icon, transparent background, isolated <asset_category> for FantasyDisk.
Canonical id: <canonical_id>. Player-facing concept: <display_name>.
Visual motif: <style_notes>. Centered full subject, readable silhouette at 32px and 64px, strong material contrast, subtle painterly highlights, no frame, no text, no letters, no numbers, no UI panel, no background, no cropping.
Final icon must work as a 256x256 RGBA PNG with clean alpha edges and 10-18% transparent padding.
```

For stat/attribute icons, favor symbolic silhouettes over literal labels: damage as a blade impact, defense as a shield plate, move speed as a boot trail, pickup radius as a magnet/rune ring, and so on.

## QA Checklist

The icon set is not ready until all checks pass:

- PNG is RGBA with transparent background and no opaque square matte.
- Subject is not cropped and keeps 10-18% transparent padding inside the square.
- Silhouette is readable at `32x32`, `40x40`, and `64x64`.
- No baked text, letters, numbers, watermark, frame, panel, or background scene unless the Jira issue explicitly requests it.
- Palette/materials match D&D + Dark Fantasy Dragon and are consistent across the batch.
- Runtime filename matches the canonical ID exactly, including the right prefix and folder: `artifact_` (`artifacts/`), `stat_` (`stats/`, base stats), `attr_` (`derived/`, derived attributes), weapon ids unprefixed (`weapons/`).
- Source PNG, final PNG, prompt notes, contact sheet, and QA report are all recorded in the local task mirror and Jira result comment.

When any check fails, regenerate or revise the icon before handoff. Do not patch failed images by drawing over them with unrelated UI panels or frames.
