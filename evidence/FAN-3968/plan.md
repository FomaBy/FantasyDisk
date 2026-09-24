# FAN-3968 implementation and validation plan

Pinned base: `e33bded444e301919dc93c8c9b9f0257e640a1ea` (tree `9a8401ca1a6dda8a4b446fe45de3fa4f97074426`). The fresh isolated ratchet run exits 1 with 18 findings; five belong to this card. Its log is `baseline_ratchet.log`.

The two Assassin scene regressions are the later fullscreen `ColorRect` veils. Replace those with textured radial gradient veils while keeping their CanvasLayer, node names, tint, opacity, and fullscreen metadata. The ratchet's three older scene primitives per file remain unchanged. Replace the two Assassin and two Doctor cast pose polygons with a small radial texture behind the weapon silhouette and a deterministic frame of an already approved weapon-local flipbook. Replace Doctor's fullscreen `ColorRect` and Robot's fullscreen `Polygon2D` with textured radial gradient backdrops. Keep all gameplay IDs, timeline phase times, node names used by contracts, hit feedback, and cleanup.

Use existing PixelLab packs only; no new art generation or charge. Verify the same 13 unrelated diagnostics remain after the five owned diagnostics disappear. Run class presentation tests, ratchet, static guard, runtime checks, four windowed capture sizes, diff/storage/secret checks, then publish only the owned paths for independent QA.
