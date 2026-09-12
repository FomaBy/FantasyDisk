# FAN-3934 round 4 — composition/resource-ownership diagnosis of the P3 run variance

Source tip `e403c84693e97ff06aabff029dfed118579f32a2` (candidate `85405739a`). Read-only
diagnosis; no production file changed and no seed used in any acceptance-style run, per
the 07:35:07Z direction.

## Finding

The ±300-object bimodality between the round-3 decisive P3 runs is **enemy-composition
resource ownership**: each enemy kind's full-frame SpriteFrames set retains a large,
permanent block of resource objects the first time any instance of that kind appears.

Static per-kind resource census (every `[sub_resource]`/`[ext_resource]` entry of the
kind's `*_spriteframes.tres` becomes a live Object once loaded):

| enemy kind | retained resource objects |
|---|---:|
| rift_cutter | 224 |
| winged_spark | 224 |
| stone_bruiser | 216 |
| spark_runner | 208 |
| ash_marksman | 184 |
| bone_caller | 184 |
| bone_shaman | 184 |
| rift_shieldbearer | 184 |
| small_biter | 184 |
| venom_spitter | 184 |
| void_mage | 184 |
| **all kinds total** | **2,160** |

Correlation with the round-3 raws: both decisive runs held exactly 2 initial enemies,
but run 1 began sampling at 3,619 objects and run 2 at 3,321 — a 298-object difference
present before any sampled gameplay, i.e. determined by which random kinds the encounter
director spawned during setup (each distinct new kind adds ~184–224; shared atlas
textures and the always-present small_biter/riftling set overlap partially). The
variance band (~±300) is 1–2 distinct random kinds; the worst case (two never-loaded
expensive kinds) is ~+450 over the best case.

## Why this is now the deciding factor

After the lazy-executor-residency repair the P3 mean sits at ~3,500–3,900 and the peak
inside the ±300 composition band around the 4,000 cap: run 2 passed at 3,970 with the
lucky composition, run 1 failed at 4,332 with the unlucky one. Certification requires
both unchanged runs ≤4,000, so the contour outcome currently depends on spawn RNG.

## Ownership and repair surface (not in my authorized paths)

- The load happens in `full_frame_animation_registry.gd::configure_entity_visual` →
  `load(frames_path)` on first instance of each kind; resources then persist in the
  engine cache for the run. `enemy.gd` calls it from `_ready` via
  `_configure_full_frame_animation()`. Neither `full_frame_animation_registry.gd` nor
  the encounter/spawn selection is among my granted paths, and the 07:35:07Z direction
  grants no further shared production path — so no repair was attempted this round.
- Candidate levers, each needing an explicit scope decision:
  1. **Deferred per-kind residency** (allocation-only, mirrors the round-3 executor
     pattern): pre-scale/preview cheap placeholders until a kind's frames are actually
     needed — but any visible frame of the kind immediately needs its real set, so this
     only helps kinds that never render; for the 2 initial enemies it does not help.
  2. **Shared-atlas frame composition**: the per-kind 184–224 objects are mostly
     per-kind AtlasTexture/Animation resources over shared sheets; consolidating
     animation resources across kinds would be a content-pipeline change, not
     allocation-only.
  3. **Composition-stable P3 contour**: the QA probe could pin the two initial enemies
     to fixed kinds (probe-side change, owned by QA/FAN-3877 acceptance, not by me; the
     PM has already excluded favorable-seed certification, and a fixed-kind contour
     must be chosen for representativeness, not for passing).
  4. **Accept the band and cut the mean further** via the previously queued
     feedback-density levers (~300–600 measured headroom), making even the worst
     composition pass. This remains the only lever set that does not touch the
     variance source itself.

## Measurement environment note

During this round the shared gate was occupied by another agent's windowed Godot run
(PID 97499); the queued dynamic per-kind measurement was cancelled in favor of the
static `.tres` census above, which counts exactly the objects the engine instantiates
per resource entry. No timing or acceptance claims were made from this shared-host
window.
