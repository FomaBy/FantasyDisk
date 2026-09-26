# FAN-3934 — lossless Small Biter frame-representation experiment report

Pre-registered plan: `PLAN.md` (published before execution). Sole write grant honored:
everything lives under `frame-representation-proof/**`; no production, asset, import,
test or probe byte changed.

## Prototype

Deterministic shelf packing of the 184 committed 512x512 frames into one 8192x8192
RGBA atlas (14x14 grid; layout, source SHAs and output hashes in
`prototype/atlas_manifest.json`; source tres SHA recorded). The prototype SpriteFrames
`prototype/small_biter_spriteframes_packed.tres` keeps the original file structure and
replaces each standalone texture ext_resource with an AtlasTexture region sub_resource —
the registry interface (`AnimatedSprite2D.sprite_frames` assignment) is unchanged.
Import: default texture importer, `compress/mode=0` (lossless) — the same class of
import settings as the production per-frame textures; recorded in the sidecar.

## Parity (all proven, cold process, gate-admitted)

- **Pixels:** all 184 atlas regions byte-for-byte equal to their source PNGs
  (offline full-unfilter decode + region compare, `pixel-parity.json`;
  atlas PNG SHA-256 `db661651…`). In-engine, every frame's logical dimensions match.
- **Animation metadata:** names, order, per-animation speed and loop mode identical
  (`parity.json`: `animation_names_equal=true`, `animation_metadata_parity=true`).
- **Rendering:** simultaneous consumers in different animation states, flip and 0.3
  scale, cleanup, and repeated reload all pass in-engine (`simultaneous_consumers_rendered=true`,
  `reload_ok=true`).

## Cost table (predetermined phase protocol; separate cold processes; 2 original +
2 prototype repetitions, every result retained: `phase-{orig,proto}-{1,2}.json/.log`)

| metric (steady loaded) | original | packed prototype | delta |
|---|---:|---:|---:|
| OBJECT_COUNT delta at load | +369 | **+187** | **−182 objects** |
| live resources | 192 | 193 | +1 (the atlas) |
| static memory above baseline | 218,984 KB | 292,488 KB | **+73.5 MB** |
| load (cold) | 55–86 ms | 48–69 ms | comparable |
| first use (assign+play) | 3.3–3.8 ms | 5.6–5.9 ms | slower, no stall |
| release-one / release-last | −1 / full release | identical | same lifetime semantics |
| post-release cache | not cached | not cached | same |

Observer overhead bracket (two consecutive snaps without work): identical counts —
measured bound of 0 in this protocol. `pre_has_cached=false` in every run; prototype
runs never loaded the original resource (separate processes).

## Result

The hypothesis is **supported for the object budget and refuted for memory**: the
lossless packed representation saves **182 objects per distinct live enemy kind**
(184 standalone textures → 184 AtlasTextures + 1 atlas), with exact pixel/metadata/
render parity, no first-use stall, and unchanged lifetime semantics — at a cost of
**+73.5 MB static memory per kind** (the 8192x8192 atlas decodes larger than 184
separate 512x512 images because the atlas pads 184 frames into 196 slots). Projected
onto the P3 contour with 3–4 distinct live kinds: 546–728 objects saved — more than
the 4,018 breach — while combat memory would rise by roughly 220–290 MB, still far
below the 900 MiB combat cap but a real regression risk for the menu (P1 ≤400 MiB)
if atlases loaded there.

## Recommended next-grant paths (not changed here)

Production resource changes per converted kind: new atlas PNG +
`*.import` sidecar under `assets/sprites/enemies/full_frame/`, regenerated
`<kind>_spriteframes.tres` (same structure as the prototype), source PNGs retained
for provenance. Supporting test: a new dedicated regression comparing each shipped
SpriteFrames against a committed pixel/metadata manifest (this experiment's parity
method), e.g. `tests/full_frame_atlas_parity_test.gd`. No production code change is
required — `full_frame_animation_registry.gd` and `enemy.gd` are untouched interface
seams. Decision input for the board: object saving vs +73.5 MB/kind memory and the
P1 menu interaction.

## Corrections to the prior causal report (item 4; prior files preserved)

- The historical failed sample's kind census is **missing**; the two non-breaching
  census samples do not reconstruct it.
- The +78 post-release residual was **attributed** to config caches, not directly
  measured; it is an unexplained observation.
- The prior census omits setup/warmup/cleanup phases, uses display labels
  (`enemy_type_name`) rather than canonical actor IDs, and reads monitors AFTER its
  tree walk (this experiment's protocol reads monitors before any walk and brackets
  observer overhead).
- The prior census maxima are sampled observations; its near-zero observer-cost claim
  was not a measured bound.
- Earlier feedback-ablation savings predate the pooling repair and are not
  established remaining headroom.
- This experiment supplies phase/overhead evidence only for its own comparison, not
  retrospective evidence for old runs.

## Process disclosure

Two prototype-build defects were found and corrected before any reported measurement:
the first atlas PNG omitted per-row filter bytes (undecodable), and an initial
four-run batch silently measured the packed file for both arms (shell word-splitting
bug); that invalid batch was deleted and re-run with the correct argument splitting.
All retained files are from the corrected protocol.
