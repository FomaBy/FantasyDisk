# SCRUM-934 — Sniper projectile and telegraph VFX pack

Статус: done (QA PASSED)
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

## QA-вердикт (2026-07-10)

**PASSED** — independent Design QA by Codex `/root/audit_ready` on a fresh
`origin/dev` worktree. Production code and assets were treated as read-only.

- Live PixelLab `get_map_object` returned `completed` for all four manifest IDs;
  prompts matched exactly. Fresh authenticated downloads were byte-identical to
  the immutable committed sources for Shatter projectile, Deadeye endpoint,
  Spotter telegraph and Spotter impact.
- Raw and accepted layers are correctly separated. The accepted Spotter files
  remove the service preview matte and the raw impact watermark; no watermark,
  text, frame or background remains in runtime output. No generic OpenAI Images,
  `image_gen`, manual-paint or legacy fallback was used.
- Independent visual review at source and intended combat scale passed: Shatter
  reads as a narrow repeatable projectile; Deadeye as a compact precision flash;
  Spotter telegraph as a translucent red danger ring with a transparent center;
  Spotter impact as a larger, distinct high-damage artillery burst.
- Independent PNG audit passed for exact RGBA canvases, non-empty alpha,
  transparent corners, safe gutters, accepted/runtime byte equality, telegraph
  alpha cap and center hole, and cleaned lower-right impact region.
- Deterministic builder replay in an isolated temporary tree passed twice with
  byte-identical output for all 11 generated files. The four existing generic
  Sniper plates were unchanged, and the implementation diff contains no scene,
  gameplay, balance or script changes.
- Clean Godot 4.7 import passed; all four lossless `CompressedTexture2D` imports
  produced non-empty `.ctex` resources with mipmaps disabled.
- `tests/asset_reference_integrity_test.gd`: PASS (200 files, 2549 unique
  `res://` references).
- `tests/runtime_smoke_test.gd`: PASS. The known non-fatal dummy-renderer
  null-texture screenshot warning was emitted; exit code remained 0 with the
  explicit `Runtime smoke test passed` result.

Critical/major/minor defects: none. Remediation ticket: not required.
