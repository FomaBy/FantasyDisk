# FAN-3934 — compact lossless Small Biter atlas: repair report

## Implementation (granted paths only)

- `tools/build_small_biter_atlas.py` — deterministic packer (shelf layout, fixed
  slot order from the committed frame list); `--check` re-verifies the committed
  pages, manifest and converted tres byte-for-byte (exit 0 on the candidate).
- `assets/sprites/enemies/full_frame/small_biter_atlas_{0,1,2}.png` (+ committed
  `.png.import` sidecars, lossless compress/mode=0, no mipmaps) — three 4096x4096
  pages = exactly 192 frame-equivalents, within the PM bound; 184 of 192 slots
  used (8 slot-equivalents theoretical padding).
- `small_biter_atlas_manifest.json` — layout, per-frame region map, source and
  page SHA-256 hashes, effective import settings.
- `small_biter_spriteframes.tres` — converted in place: identical structure,
  animation names/order/speed/loops/durations; every standalone texture becomes
  an AtlasTexture region. Original PNGs and their sidecars untouched
  (provenance intact).

## Verification

- **Dedicated regression** `tests/full_frame_atlas_parity_test.gd` (+uid), PASS
  headless AND windowed:
  - bijective pixel mapping — every (animation, frame) texture matches EXACTLY
    ONE manifest slot's original PNG byte-for-byte (SHA-256 over pixel data),
    every slot used exactly once, regions equal the manifest rectangles,
    durations positive;
  - negative fixture: a deliberately shifted region IS detected (detector not
    vacuous);
  - captured-render comparison (windowed, real renderer): SubViewport captures
    of the AnimatedSprite2D vs `draw_texture_rect_region` reference across every
    animation row, with flip, 0.3 scale and two simultaneous consumers — color
    histograms match; `is_playing()` is never used as render evidence, and the
    headless run explicitly records the render stage UNAVAILABLE rather than
    substituting;
  - lifecycle: full release, cold reload with byte-identical re-verification,
    orphan-free; import-sidecar settings checked (lossless, no mipmaps).
- **Unchanged suites green** on the converted resource: full_frame registry
  integrity/shard-validation/eight-direction/row-scale-invariant, combat contact
  feedback + runtime combat smokes, take_damage routing, p3_feedback_allocation,
  berserk balance.

## Predeclared 2-orig / 2-compact cold comparison (separate processes, gate,
exclusive; all 4 runs + logs retained; every result kept, no re-rolls)

| phase metric (steady) | orig (standalone) | compact (3 pages) | delta |
|---|---:|---:|---:|
| OBJECT_COUNT at load | +368 (1878−1510) | **+190 (1700−1510)** | **−178 objects** |
| resources | 191 | 195 | +4 |
| static memory (absolute KiB) | 218,813–218,890 | 226,822–226,900 | **+7.8–8.0 MiB** (within the 8 MiB theoretical padding bound) |
| load (cold) | 89.6–119.1 ms | 44.2–122.6 ms | overlapping; one compact outlier 122.6 ms |
| first use | 3.3–3.5 ms | 3.7 ms / 87.2 ms (one outlier) | see disclosure |
| release-one / release-last | −1 / full | identical | same semantics |
| cold reload | ok | ok | — |

Absolute-vs-delta distinction: static figures above are ABSOLUTE sampled KiB;
the deltas between arms are differences of absolutes. GPU/VRAM telemetry is
UNAVAILABLE in this environment and is marked so in the raw records (never
zero-substituted). Observer bracket: two consecutive idle snapshots identical
(measured zero in this protocol). The single 87.2 ms first-use outlier (compact
 rep 2) did not reproduce in rep 1 (3.7 ms) and is disclosed as-is.

## Census diagnostics (2 samples, unchanged scenario, separate from the decisive probe)

Both: Rift Warden + Rift Cutter + 6 Small Biters, 3 unique frame sets,
floors **3,513 / 3,553** (pre-conversion comparable floors were 3,421–3,520),
peaks 3,782 / 3,830. Small Biter's live-set cost dropped by its measured
~178-object margin, offset in these absolute floors by one-random-kind variance.

## Decisive original matrix on the committed compact source `5b3ff607…`

| Run | Peak / limit | FPS avg / 1% | Mem | Result |
|---|---:|---:|---:|---|
| P3 run 1 | 3,831 / 4,000 | 772.8 / 421.7 | 163.6 MiB | PASS |
| P3 run 2 | 3,843 / 4,000 | 717.7 / 514.2 | 162.1 MiB | PASS |
| P1 | 2,246 | 499.9 / 382.7 | 137.0 MiB ≤ 400 | PASS |
| P2 (exactly 48) | 4,040 / 5,000 | 80.9 / 49.7 | 126.9 MiB | PASS |

All 10 driver exits 0; strict foreign-overlap check NONE in every window; every
in-JSON check true (boss alive, 1/18 ultimates, orphans 0, non-monotonic).
P2's 1% low of 49.7 passes the ≥45 floor with reduced margin — disclosed.

## Corrections (prior files preserved, not rewritten)

- The previous experiment's "73.5 MiB / padding" explanation was wrong in
  mechanism: the 8192-atlas occupied 256 frame-equivalents; the compact 3-page
  layout occupies exactly 192 (measured +7.8–8.0 MiB, matching the bound).
- The prior experiment's manifest named an uncommitted prototype import
  sidecar; all three sidecars here are committed and hash-verified.
- The prior invalid 4-run batch (both arms measured the packed file) remains
  deleted history; its replacement and this stage's 4 retained runs supersede.
- Historical failed-sample kind census remains missing; census diagnostics here
  are separate from the decisive probe and reconstruct nothing.


## Publication correction (10:26 decision; prior raws preserved)

The original handoff claimed a complete manifest; that claim was wrong. The
previous MANIFEST.md listed 110 entries of which 52 named files absent from
the candidate commit — 48 generated `.translation` and 4 generated
`.csv.import` engine cache outputs, hashed from the local working tree during
generation before the commit (local ignored files must never be treated as
delivered evidence). The three committed atlas `.png.import` sidecars and
`tests/full_frame_atlas_parity_test.gd.uid` were omitted. The canonical
manifest above is rebuilt from Git blobs of the successor's inventory commit,
includes the sidecars and the UID, states its self-hash convention, and
classifies the generated outputs as reproducible-derived exclusions rather
than publishing them. `publication-correction/audit_manifest.py` audits any
manifest against any commit by reading blobs from Git and demonstrates the
expected HASH-MISMATCH/ABSENT failures in a self-test; its full run on the
final successor is recorded in `publication-correction/audit-result.txt`.
No measurement, raw file or production byte changed in this correction.
