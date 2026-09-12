# FAN-3934 round-7 immutable measurement manifest (composition-rework candidate)

- measured source = production content `2202408c5f021f6b734d8409b1354f3ae71943ee` tree `bd46662b7f39bb541f799cebc1239dfecb3924a1`; probe sha256 `57d817d2effc2627f5d5b115b8094ebdb6bda541e5a3640fab2a9f7f03eaa6f5`

## matrix p3-run1
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- published: perf-p3-run1.json `7f80e0f51494cdd8f81182da41880e06f477c734d3e5a380a06d6151c60123c9`, perf-p3-run1.csv `17b8da14585209aedcd479781ca9b0a28079b10f5a8b139db9a40eed7ab1643d`, log-matrix-p3-run1.txt `35d02f505ea8768b84aea7c57f275added5d4078f33c4effc7530ffef52cd482`, env-matrix-p3-run1.txt `1fd995a8c0ca170d920941a0af562abc92bd6ad3d2a7f309a2105f300586f0bb`
- recorded candidate_sha `2202408c5f021f6b734d8409b1354f3ae71943ee`, pass=True, peak=3832, exit_status=0

## matrix p3-run2
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- published: perf-p3-run2.json `699b6708b924fa62a006232ad2311aa45a2bb4c5944143e681e8912d8a0fd8df`, perf-p3-run2.csv `ef2ca19b3c66d4ab906e5a7581bafb04b1763b72df86cea82d8fcb96e61a5ba2`, log-matrix-p3-run2.txt `086c5e3e1aef0aae0ccd4c4b411b1eea71fe96c64ae031e0f77e5d42ea90d07f`, env-matrix-p3-run2.txt `07305e23a3c784630187434637324a1a1fe46d247769aae147a0364a03ad068d`
- recorded candidate_sha `2202408c5f021f6b734d8409b1354f3ae71943ee`, pass=True, peak=3828, exit_status=0

## matrix p1
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P1`
- published: perf-p1.json `5b4829676f35a5f5dde5b98ba741e82e9b3819adca76dcacca209fae98b5c89e`, perf-p1.csv `c135c17ee99cebbb2b5efa35679ed155c480ac1b939154ff4f7dc75a99a28cee`, log-matrix-p1.txt `c0215641cbdff6953f729c3eac4a435808385197a407b2bb4d0433019af6f2b3`, env-matrix-p1.txt `00d0b7dde16a71f140908133e968649087c52960d4fda56aed9287232546b805`
- recorded candidate_sha `2202408c5f021f6b734d8409b1354f3ae71943ee`, pass=True, peak=2244, exit_status=0

## matrix p2
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P2`
- published: perf-p2.json `b63af30d837298a20e4bd1238ad3c7ae3cf45e24b639dd9c76b3e3f4e491be72`, perf-p2.csv `57acd273f913abbbba48b53ec7c56950ab8d9777c2bb8b9a9914c173147621a0`, log-matrix-p2.txt `2314e429cde0492d5bdd053da91973fb5f43b35b6c8fd45a06c1f1a463160529`, env-matrix-p2.txt `357e3c61c46e6e3a336a3d663b330b7e6a37a702dfdcf973fc71c9022231a6ee`
- recorded candidate_sha `2202408c5f021f6b734d8409b1354f3ae71943ee`, pass=True, peak=4008, exit_status=0

## suite feedback
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/p3_feedback_allocation_test.gd`
- records: log-suite-feedback.txt `e6d946d36a2beba0c995e39a28d4a396947cc482a4edd0dfefc329d358471012`, env-suite-feedback.txt `879fb0113601e231b3563a55730b9f5216e37ab20692584a956d936148bb3cdb`, exit_status=0

## suite residency
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/p3_executor_residency_test.gd`
- records: log-suite-residency.txt `f336ab18a754b9d575bfc9163cb0b36c5cf63c2fa4aec5292dcfb8deea06e549`, env-suite-residency.txt `61f17736dd3e8310bfba20dae53e25014a4bd97d6ed519c4397b102ece70393e`, exit_status=0

## suite summon
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/boss_summon_cap_test.gd`
- records: log-suite-summon.txt `9d2ecc353c723b4969f4881e967c4a9a01321b5a1c2c4db8fabf5efd43b4147d`, env-suite-summon.txt `26c192b1f03f5df02567994fab6f8dc1f2f48eb89c9b074f5dd306a3cb7a70e9`, exit_status=0

## suite hazard
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/boss_hazard_cap_gate.gd`
- records: log-suite-hazard.txt `4f5d40a73478ca0736d2dcb40529493c1e7db1adea89ec482a4d91a48404a55c`, env-suite-hazard.txt `6b4e78182b4367e8bd70c54ca00d9f1691545f1a20bafab5319a206d35cddcf5`, exit_status=0

## suite hazardsmoke
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/hazard_vfx_smoke_test.gd`
- records: log-suite-hazardsmoke.txt `63c113bd8ea9fa48da62cd2c38c4f606061b8dc397afd9c0d4f838268ec19c91`, env-suite-hazardsmoke.txt `bded1c4b1a8127d4551167cf0f6ee0cbbd089814c130f345869965b49021f159`, exit_status=0

## suite berserk
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/berserk_balance_test.gd`
- records: log-suite-berserk.txt `171ad1339125edf7aac0fccbdc76915b2320d3c60f963674b6792025c8435b31`, env-suite-berserk.txt `141d370ba1615e270ae86584376e3a27efc596da215cdc7aff4c10bb4be6cd8b`, exit_status=0

No foreign Godot process was live during any matrix run window (strict overlap check; raw observations retained verbatim).
