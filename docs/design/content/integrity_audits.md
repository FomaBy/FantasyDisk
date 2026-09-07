<!-- content-registry-section -->

# FantasyDisk Content Registry — Аудиты Целостности Ссылок

Раздел реестра контента. Индекс всех разделов и правила ведения:
`docs/design/content_registry.md`.

## SCRUM-723 Scene/Resource Reference Integrity Audit (0.2.0)

Reference-integrity sweep of scenes, `.tres` resources and project config — no asset
deletions, no canonical reference changes. Findings (all CLEAN as of the sweep):

- **0 broken `res://` references** across all tracked `.tscn`/`.tres`/`.godot`/`.cfg`
  (1510 literal refs checked offline; in-engine gate re-checks 1746 unique refs over
  184 files).
- **0 orphan sidecars** — no tracked `.import`/`.uid` whose base file is missing; all
  2561 media files under `assets/` have a tracked `.import`. The 427 images without
  `.import` are all `docs/design/**` backups/references + 2 `build/qa/**` artifacts —
  outside the `res://` import pipeline, correctly un-imported.
- **No duplicate `class_name`** declarations across `scripts/` + `tests/` (guards the
  ` 2`-suffix global-class collision class, SCRUM-440).
- **Version consistent** — `project.godot config/version` and every
  `export_presets.cfg` version field are `0.2.0`; no export-preset drift.
- **Gate strengthened:** `tests/asset_reference_integrity_test.gd` now also scans
  `.tres` under `assets/` (previously scripts/ + scenes/ only), so a broken
  SpriteFrames→texture `ext_resource path` fails the gate instead of rendering blank.
