# FAN-3934 — sixth-failure verification-coverage evidence (2026-09-13)

Raw runs of the FINAL checker (`tests/full_frame_atlas_parity_test.gd` at the
successor source, per-log command/argv/environment/exit recorded in each file):

- `checker-headless.log` — headless invocation, **exit 0**, PASS with the
  render-capture stage explicitly marked UNAVAILABLE (not substituted).
- `checker-windowed-render.log` — windowed `-- render` invocation on the real
  macOS/OpenGL renderer, **exit 0**, PASS: all 24 animation rows x 3 explicit
  cases (unflipped / flipped / scaled) spatially byte-equal to their reference
  Sprite2D renders; simultaneous-consumer hide/show determinism green.

Deliberate negative results executed and retained (inside the same checker):

- corrupted duration list (one value +0.5) is REJECTED by the tres-parsed
  equality rule;
- region-shifted AtlasTexture is REJECTED by pixel-SHA comparison;
- hide/show determinism failure path arms if the second consumer contributes
  no pixels.

Historical honesty note: the windowed/headless console logs previously named
"new-checker-*-console.log" and "old-checker-*.log" in this directory were
misnamed duplicates of the runs above (the "old checker" control was
inadvertently executed against the already-committed new test because the
working tree was clean); they were removed rather than relabeled. The two
canonical logs above are the actual executed runs whose contents were never
edited. No earlier product/performance sample is relabeled as a successor run:
the product content of `f400eabd` is byte-identical to QA-reviewed `68afccda`
(test-only diff), which is the exact unchanged-input proof for evidence reuse.
