# FAN-3934 ci-atlas-diagnosis SHA-256 manifest

## diagnosis evidence (originally published on diagnostic branch commit
`c28336c86a74ea7cdf3c7068186019655990406c`; identical files carried here for the repair handoff)

- DIAGNOSIS.md `0d0acea0e4a8c0bc44353920ad461d1dc4cffee11c19f4840cf5babea7591cd5`
- sparse-cone-suite-fail.log `f442bf4764253bf66321b1f2866a01cb8179439454759a6b2dc1d022df4cb82f`
- full-checkout-suite-pass.log `e8b80604be93df23e6a744921f5d65cc95253f4baedd39f5c39907d78a873f7e`

## repair validation (this candidate)

- corrected-cone-suite-pass.log `495c74da1ad96ade4f0752af1631b94aac4901781616e945a1cc9fd276417c5b` —
  isolated blob-filtered checkout at synthetic merge 6d454ed7ef6f…, the repaired
  workflow's exact sparse cone (fragments subtree) applied via
  .git/info/sparse-checkout (root project files added: actions/checkout includes
  root files, a manual cone must too), then:
  `FSD_GODOT_RUN_TIMEOUT=400 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/a5/scenarios/ultimate_atlas_attribution_test.gd`
  → exit 0, `ultimate_atlas_attribution_test: PASS`; both the ultimate_atlas and
  offensive fragment inputs PRESENT under the corrected sparse checkout.

## before/after fragment observations

- BEFORE (pre-repair cone at 6d454ed7): ultimate_atlas fragment ABSENT from the
  working tree (tracked blob a9a19376c5bc280fc822185235304a3133f4ec57); suite FAIL exit 1
  (sparse-cone-suite-fail.log).
- AFTER (corrected cone, same commit): fragment PRESENT (working-tree SHA-256
  prefix 26c0b1074dbbd7cd matches the full-checkout control); suite PASS exit 0.
- Historical note: no in-CI hash observation of the fragment exists — the failed
  job log records only the existence-assertion error; that observation is
  unavailable and is not asserted.
