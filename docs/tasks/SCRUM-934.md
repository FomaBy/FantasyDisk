# SCRUM-934 — Sniper projectile and telegraph VFX pack

Статус: done
Версия: 0.2.1
Jira: SCRUM-934
Owner: Design/Codex `/root`
Контур: Codex

## Решение

PixelLab MCP `create_map_object` produced four separate source components rather
than overwriting the three existing all-purpose Sniper attack plates:

- `sniper_shatter_rounds_projectile` — one right-facing needle projectile for
  repeated fan shots (`128x64`, intended combat display `48x24`);
- `sniper_deadeye_rifle_endpoint_impact` — compact precision hit flash
  (`192x192`, intended `96x96`);
- `sniper_spotter_scope_telegraph` — alpha-limited crimson target ring
  (`256x256`, intended `160x160` before world-radius scaling);
- `sniper_spotter_scope_impact` — distinct high-damage shell impact (`256x256`,
  intended `144x144`).

The immutable PixelLab downloads, accepted alpha-clean derivatives, exact
object IDs/prompts/hashes, runtime mappings and import contract are recorded in
`docs/design/references/sniper_projectile_vfx/manifest.json`. The deterministic
`build_pack.py` removes only flat preview backgrounds/edge marks, caps telegraph
alpha, preserves safe gutters, exports runtime PNGs and rebuilds QA evidence.
No OpenAI Images, `image_gen`, manual painting or legacy generator fallback was
used.

This is a Design package. Related Backend issues SCRUM-931/932/933 own scene and
gameplay integration; no Sniper script, scene, targeting, timing or balance data
is changed here.

## Verification

- PixelLab MCP config smoke: PASS (`get_balance`, no secret output).
- Four exact source IDs and SHA-256 hashes are present in the manifest.
- `build_pack.py`: PASS for dimensions, RGBA, transparent corners, non-empty
  alpha, >=4px gutters, telegraph max-alpha/coverage and impact edge-mark guard.
- Visual contact review at source and intended combat scale: projectile remains
  sharp, Deadeye reads as a precision endpoint, Spotter telegraph remains visibly
  translucent, and shell impact has a separate silhouette.
- `docs/design/previews/sniper_projectile_vfx_contact.png` is the committed
  review sheet; raw and accepted PNGs remain separated from runtime files.
- Godot 4.7 imported all four runtime PNGs as lossless `CompressedTexture2D`
  resources with mipmaps disabled; the generated `.import` sidecars are
  committed with the assets.
- `tests/asset_reference_integrity_test.gd`: PASS (200 files / 2549 unique
  `res://` references).
- `tests/runtime_smoke_test.gd`: PASS after rebase onto latest `origin/dev`
  including SCRUM-1016 failed-QA evidence `dc65b6d4` (the known dummy-renderer
  null-texture screenshot warning remains non-fatal).

This implementation report is ready for independent visual QA; it is not the
final QA verdict.
