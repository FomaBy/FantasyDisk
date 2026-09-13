# FAN-3934 — lossless Small Biter frame-representation experiment: pre-registered plan

Published BEFORE execution (07:16 decision, item 1). Sole write grant:
`evidence/p3-object-budget-rework/frame-representation-proof/**`. Production,
assets, import settings and probes unchanged.

## Hypothesis (pre-registered)

H: replacing the 184 per-frame Texture2D PNG references in
`small_biter_spriteframes.tres` with AtlasTexture entries over ONE packed atlas
(lossless: identical pixels, transparent padding, logical frame dimensions,
animation names/order/FPS/loops/durations) preserves the registry interface
(AnimatedSprite2D assignment unchanged) and reduces the loaded-set OBJECT count
by roughly the number of eliminated standalone textures' object overhead, with
equal-or-lower texture memory, no first-use stall, and exact pixel/metadata parity.
Measured quantities: before-load/loaded/first-render/repeated-use/release-one/
release-last object/node counts, texture memory, load and first-use timings;
per-phase deltas; parity metrics (pixel/crop equality, metadata diff); observer
overhead bound (before/after observation in the same process).

## Bounded experiment plan (predetermined)

1. Build the atlas prototype deterministically from the 184 committed PNGs at the
   evidence tip: fixed shelf packing by (height desc, width desc, path asc) into
   the smallest power-of-two atlas within 16384x16384 limits, transparent
   padding; write `prototype/` PNG + `.tres` SpriteFrames using AtlasTexture
   regions. Every input bound by SHA-256; output manifest records source hash,
   layout, and prototype hashes. Import via Godot CLI (same filter defaults as
   production per-frame textures — recorded).
2. Cold-process comparison, separate Godot processes, 2 original + 2 prototype
   repetitions, every result retained: phase protocol baseline → load → first
   render (one consumer) → second same-kind consumer → two simultaneous
   different animation states → release one → release last; object/node counts,
   `RenderingServer.get_video_memory_usage()`, load/first-use µs, resource
   identities (paths + instance IDs), canonical entity IDs; monitors read BEFORE
   any tree walk each phase; observer-overhead bracketed by an empty-observation
   pass. Prototype samples never load the original frame resource (separate
   process; verified by `ResourceLoader.has_cached`).
3. Parity: per-frame pixel equality (PNG decode byte comparison on the atlas
   region vs source file), logical frame dimensions, animation names/order/speed/
   loop per the original tres (parsed and diffed), rendered-image comparison of a
   live AnimatedSprite2D (original vs prototype process) with scale/flip
   exercise, then cleanup and repeated reload.
4. Analysis: cost table; if savings+parity hold, name the exact production
   resource and new artifacts for the NEXT grant (no production change here); if
   not, bounded negative result. Plus the required corrections section for the
   prior causal report.
