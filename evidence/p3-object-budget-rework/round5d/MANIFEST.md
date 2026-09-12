# FAN-3934 round-5d immutable measurement manifest

- measured source: `f889eeeb9fa45577441676eebb352b0e67b222a8` tree `0b73b239f0e7c780141890deee9e67146d81081b` (production content identical to `1b548ee4c25458d804c1812697bbf0aa3433615f` / tree `fa05f171008f18d552d8e0ead97bfc1e16cadf42`; diff touches test/evidence only)
- probe: `perf_probe.gd` sha256 `57d817d2effc2627f5d5b115b8094ebdb6bda541e5a3640fab2a9f7f03eaa6f5`
- driver: `run_observed.py` (records argv, env, own pid, verbatim ps output before/during/after each run; foreign processes preserved)

## matrix p3-run1 (P3)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- staging raw names: `perf_p3.json` / `perf_p3.csv` (shared staging, disambiguated here)
- published: perf-p3-run1.json sha256 `e77a851c466633042661ad54edf2310d4275f03a7b976687d07c004ae3c3c4a8`, perf-p3-run1.csv sha256 `de7c2b400e8c3c567051c40f672bcb75fe4eb6c1a125115b24153ee3322fda5f`
- observation/command/exit record: log-matrix-p3-run1.txt sha256 `111b981558a5145f7b09d7d5c3f735528e63e2b108b78850b706fa169949b4b6`, env-matrix-p3-run1.txt sha256 `098a52b142f0ee9e8b18848d1fbc9a2f6d9a961159c9742966647abe222d7901` (before/during/after ps samples)
- recorded candidate_sha `f889eeeb9fa45577441676eebb352b0e67b222a8`, pass=True, peak=3593, exit_status=0

## matrix p3-run2 (P3)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- staging raw names: `perf_p3.json` / `perf_p3.csv` (shared staging, disambiguated here)
- published: perf-p3-run2.json sha256 `58c985ba098243560c754281a1a86401a3946b05d11f5e64363507158cd28b4a`, perf-p3-run2.csv sha256 `5d6d8b1d7c50b7d3852bb87fe4e8ba2e11fb2c3a39e800e9788ac305a67335e2`
- observation/command/exit record: log-matrix-p3-run2.txt sha256 `2c1a21ba28aff13968b0a93be65de9442a5bc0078d96cf4b6a949ea4bb839c3a`, env-matrix-p3-run2.txt sha256 `0468c12d0259b25faf9d1df2bf9bbaee99f2b8300ed74aa1e330ada717bc82bb` (before/during/after ps samples)
- recorded candidate_sha `f889eeeb9fa45577441676eebb352b0e67b222a8`, pass=True, peak=3815, exit_status=0

## matrix p1 (P1)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P1`
- staging raw names: `perf_p1.json` / `perf_p1.csv` (shared staging, disambiguated here)
- published: perf-p1.json sha256 `0aefb6db5f7a8d6ba76f0572902add513a92a848be85b4de0bf1db71c384f469`, perf-p1.csv sha256 `997da63bb622f267536a780dd6bfdb1825324f62e88171c8ff9e1fdef20bcbbc`
- observation/command/exit record: log-matrix-p1.txt sha256 `b6d8a8a9f3c2b4f3c70322694ed809647cd4170f7258a5c6eccec8803234526d`, env-matrix-p1.txt sha256 `7834bf2982a7de5c7d3d3fe8a0211acd461a1652b71b10ba4402c1d9a409507e` (before/during/after ps samples)
- recorded candidate_sha `f889eeeb9fa45577441676eebb352b0e67b222a8`, pass=True, peak=2271, exit_status=0

## matrix p2 (P2)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P2`
- staging raw names: `perf_p2.json` / `perf_p2.csv` (shared staging, disambiguated here)
- published: perf-p2.json sha256 `acb6b053c3aed6db7f2b90c272d22a1c382e138dd6e421dd01a77ebb02aa7e1b`, perf-p2.csv sha256 `9412280dc05891eeb5e11eea9ae67e2eb28c11a619559afb136d92d966a788e5`
- observation/command/exit record: log-matrix-p2.txt sha256 `b160d1888cdb9fc5f412a92f8ecbf577828bef57ebee36a30a52bee4af06997a`, env-matrix-p2.txt sha256 `08c655da05ad1c5b0c647317d7fd79811b404740f49d1cfbb590b1b55057d94f` (before/during/after ps samples)
- recorded candidate_sha `f889eeeb9fa45577441676eebb352b0e67b222a8`, pass=True, peak=4023, exit_status=0

## suite feedback
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/p3_feedback_allocation_test.gd`
- records: log-suite-feedback.txt sha256 `6ac5450e961daf2955bdee031a700d225e885499562507ede00589a13795aae8`, env-suite-feedback.txt sha256 `6c582afd971b7a30eca177401ba5a1eb0497fbb4dc27ab785ba69744fb8d0dd7`, exit_status=0

## suite residency
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/p3_executor_residency_test.gd`
- records: log-suite-residency.txt sha256 `30c5fd6df6dc330c2868468a8df3396062879090ba582da7f8339ad4b71e1663`, env-suite-residency.txt sha256 `80c6ea46c359bf0c0e7a82966c06f3a84b26b9f06e95f9b87f59a4ed78d8d219`, exit_status=0

## suite summon
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/boss_summon_cap_test.gd`
- records: log-suite-summon.txt sha256 `8fa30cf53eb8888363ece6a30e7111e0d5562dd75177d24548fd10a676b0f75e`, env-suite-summon.txt sha256 `fd338b5819c19760a15e93ee0e41fcbea2090b69f438e2226b7cdbfd5fafece5`, exit_status=0

## suite hazard
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/boss_hazard_cap_gate.gd`
- records: log-suite-hazard.txt sha256 `d5ea7822a1c0c0c709b9d15cbd5c1580f6fa1a2004c3a797de285bd43a6acccd`, env-suite-hazard.txt sha256 `b7aeeef4fc6b7bd57c74f665127d86fd221e78af8fec3e2b071148f368843c88`, exit_status=0

## suite hazardsmoke
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/hazard_vfx_smoke_test.gd`
- records: log-suite-hazardsmoke.txt sha256 `a444da5d09a17c41a0601d254b16296f373917b17eb7336d26c32ba520ec9e40`, env-suite-hazardsmoke.txt sha256 `4cb0d5db20f8ee6a6865f26712d43f9d8200771b0f890eeefcc92bb0c2871f03`, exit_status=0

## suite berserk
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/berserk_balance_test.gd`
- records: log-suite-berserk.txt sha256 `98c35bf5db2130765c34cc39bf520ba4ea96a53da043a8cb4b710e9cffffbe8c`, env-suite-berserk.txt sha256 `41b5c736ee516c98d2b6a814a502f48bfe024443b57302e65b002cf69e3d710a`, exit_status=0

Every before/during/after observation in env-* files records `(no foreign godot processes)` for the whole window.
