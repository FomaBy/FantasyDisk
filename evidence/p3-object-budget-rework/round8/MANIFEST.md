# FAN-3934 round-8 immutable measurement manifest (CI-recovery candidate)

- measured source = candidate `53afca416d83aaf2101a0435440a15c896ab0ca4` tree `d189660756b8c52cd99848b7abd4949b4df45163`; probe sha256 `57d817d2effc2627f5d5b115b8094ebdb6bda541e5a3640fab2a9f7f03eaa6f5`
- note (corrected per the 15:03 decision): the raw FPS difference vs earlier rounds is NOT attributable to renderer settings — project.godot is byte-identical and measured runtime vsync/max-fps/display are identical between bases (ROUND9-EVIDENCE.md); cause unknown, all thresholds pass with margin

## matrix p3-run1
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- published: perf-p3-run1.json `4e6b635f050e00bc62727ae0c42f25a738a669b8d0fe659471e04575ef7498ac`, perf-p3-run1.csv `5c4d995263599ceb024ac21b31373fc08e8a8aef9aa4ba0b6b446b8eeef3d56c`, log-matrix-p3-run1.txt `ef3e06e789ab587273b78063cb0fc3bb275efdb4e8a42e8e4ce6dd143dfd45f1`, env-matrix-p3-run1.txt `9e4773a7a5706268c6d44dee43a15d024b79fb6085f667a6b922b9da7eac31ef`
- recorded candidate_sha `53afca416d83aaf2101a0435440a15c896ab0ca4`, pass=True, peak=3820, exit=0

## matrix p3-run2
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- published: perf-p3-run2.json `bd317f213405b9ae0206f97bc2a95f63403332e26ddd410bf3c52bb4214c6ff6`, perf-p3-run2.csv `94f867a51d878a5b7418b9025b7d006800d8be5a066ad96f8aafc07de97d9a5b`, log-matrix-p3-run2.txt `9d9a49772ddf5afe8fb65a7754730aeb4870f1d293bf491e3b6e1fd588ad16b5`, env-matrix-p3-run2.txt `74a821ba53db111516a4b695e5d6b2e7e3023de48966570149f655f17a57bb0a`
- recorded candidate_sha `53afca416d83aaf2101a0435440a15c896ab0ca4`, pass=True, peak=3839, exit=0

## matrix p1
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P1`
- published: perf-p1.json `7339a70fb501cd67c23cc1ceff2c1c6eaf65584d9243a4e5c6009223b8b4dd57`, perf-p1.csv `89bbd690d3d6fb44df476729fcd332dba4ce6126cd8fe1fcac71dbb21f086693`, log-matrix-p1.txt `3c8e3520ec534094fe43bd95df942ee51fd9f378e05a8f25ad6f8cc8131e0784`, env-matrix-p1.txt `a195ec75ee5bc3fff197a38c9bc4a3bae109e047c9223ce705fab889034f5d8f`
- recorded candidate_sha `53afca416d83aaf2101a0435440a15c896ab0ca4`, pass=True, peak=2246, exit=0

## matrix p2
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P2`
- published: perf-p2.json `c9d9e06701d983c52cabb2b32b4e1b6818f11641a7834c0fe528ed538f7a3c90`, perf-p2.csv `e79dd0ffb0e63f1c840f71c8438dc46379c88f888e909fb334b8ef0dc3752541`, log-matrix-p2.txt `b52ec9c8c7d4147baf9e65fe580088a39d84f5cf2f0282ff348f48a55ad9f5af`, env-matrix-p2.txt `a83bef79bce274dea3cd331a26022a5e780ceb7f76144866e5476c3a26d8a692`
- recorded candidate_sha `53afca416d83aaf2101a0435440a15c896ab0ca4`, pass=True, peak=4001, exit=0

## suite feedback
- records: log-suite-feedback.txt `23f44e9bf161daf66db89c0606a0e7f13f337e6ff0335c49997c866c81106e2b`, env-suite-feedback.txt `10f517b6525e636562fc1aae0f0c0baf242565425480b551f4ccba4b4f88dfab`, exit=0

## suite residency
- records: log-suite-residency.txt `600ef2903624f2a86c989636c729445c333d71b520d215f16ad7232d2f19d296`, env-suite-residency.txt `22e395cab0a0f5f7b45a62e8c674d6a774141b50cd67131d210f83385d4f2d65`, exit=0

## suite summon
- records: log-suite-summon.txt `728307beeadc749141e0e7750d6843cae5fc56190b5a43d14ea631a0b07ca7e1`, env-suite-summon.txt `d447dd69655e36c47654b940de97835eabff1de8c0241e1c167f2e6741e1ab48`, exit=0

## suite hazard
- records: log-suite-hazard.txt `958e5e009f18beef6c3f290d402439d5618332fe63fba192bd74a7e04bdbae40`, env-suite-hazard.txt `e2ca66b6d9763eb22f48357caa50d546677154d48600631df9392f33dacccd64`, exit=0

## suite hazardsmoke
- records: log-suite-hazardsmoke.txt `167ae0f2400c07bfe0c56cf3ff9cd99adc81a7ae82a6f37258716bdf27ed1e70`, env-suite-hazardsmoke.txt `efd690277275b9d729acef36d555cd12fac6484140c177bfea8a5cc0a9fb115d`, exit=0

## suite berserk
- records: log-suite-berserk.txt `5c231cd1438a0f22668e55748e072426713ac3712fe35a35f095699f7c08551d`, env-suite-berserk.txt `a3c99ed0814e5af263535b3a50b7787e3f355aefe73ce6c26e0902d7979caa52`, exit=0

