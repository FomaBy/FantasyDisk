# FAN-3934 round-6 immutable measurement manifest (QA-rework candidate)

- measured source = review candidate: `8d4d7d62b017856f43c735bfb06814fde54d939c` tree `eda3ca682a7a359b9a84b7098a4372cd6a4925c1` (final production source; probe sha256 `57d817d2effc2627f5d5b115b8094ebdb6bda541e5a3640fab2a9f7f03eaa6f5`)
- driver: `run_observed.py` (argv/env/own-pid, verbatim ps before/during/after, foreign processes preserved)

## matrix p3-run1 (P3)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- staging raw names: `perf_p3.json`/`perf_p3.csv` (shared staging, disambiguated here)
- published: perf-p3-run1.json `856548af082ea85bba17f4b73197d2e87691d5f172bd64145585f8d0c7a901b6`, perf-p3-run1.csv `cb44197d51772d8ce383b6cf960a4dff25fcf4e87a7407cd1c1f199052d63e25`
- records: log-matrix-p3-run1.txt `4da9fb79bf7f9a4ceae860692796c52c716b5cca08079dba1e9193dcf4c3f84e`, env-matrix-p3-run1.txt `98f00cb3e566fa8c6978b549c992d06ded99c38ebe02df8fcd874929dcead97e`
- recorded candidate_sha `8d4d7d62b017856f43c735bfb06814fde54d939c`, pass=True, peak=3856, exit_status=0

## matrix p3-run2 (P3)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P3`
- staging raw names: `perf_p3.json`/`perf_p3.csv` (shared staging, disambiguated here)
- published: perf-p3-run2.json `f6a8f78bb440fa6622791ca48c18d7816313e0ecbc8f4e901ad5ae7cdb3dcab0`, perf-p3-run2.csv `8f6da9c028f30d81ed35bdd02c50b0da3eb05c365e29c3143742679898ebaae1`
- records: log-matrix-p3-run2.txt `c908696074263952d09981e1aa70847f4c9a5d671579b0af030c07d2ec2d5e47`, env-matrix-p3-run2.txt `7d89bf66b80c9f6f21e29f9ec035fdba0cb4608de7807ec708b9b1057930ad04`
- recorded candidate_sha `8d4d7d62b017856f43c735bfb06814fde54d939c`, pass=True, peak=3840, exit_status=0

## matrix p1 (P1)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P1`
- staging raw names: `perf_p1.json`/`perf_p1.csv` (shared staging, disambiguated here)
- published: perf-p1.json `0d92130c81d74546d5300314a42540eadc924430e262c0099acea212fee5b2a3`, perf-p1.csv `b2efb648eee7590b15988dcb5ade83d28e3ae609739b47af03e6809d1936ee6a`
- records: log-matrix-p1.txt `bb7d46595e0d90d13134606b71cf28eec687bbe1b1eb8be85daa18b209c8f5d2`, env-matrix-p1.txt `ae0b628d635b925b21b28948c9644e5e7e246d54966cb532c256ce39ae574a65`
- recorded candidate_sha `8d4d7d62b017856f43c735bfb06814fde54d939c`, pass=True, peak=2244, exit_status=0

## matrix p2 (P2)
- command: `FSD_GODOT_EXCLUSIVE=1 GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --path . --script res://evidence/p3-object-budget-rework/raw-baseline/extracted/perf_probe.gd -- P2`
- staging raw names: `perf_p2.json`/`perf_p2.csv` (shared staging, disambiguated here)
- published: perf-p2.json `50917d86927eee90badef32dca9889511b4bb57e94576dbae4854298d6ce946d`, perf-p2.csv `a8ea866d84354b211738b48fea976eaef61e87b81f472bbc14619330d24b42da`
- records: log-matrix-p2.txt `39594b4369897a03f52044cc56488dea70efa855f232a7f36db08e40c4b5d842`, env-matrix-p2.txt `ef916bc7108ef03d2af518cef9694ad7d76e99ed5f3a6ce9f1ad57eee3891f02`
- recorded candidate_sha `8d4d7d62b017856f43c735bfb06814fde54d939c`, pass=True, peak=4004, exit_status=0

## suite feedback
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/p3_feedback_allocation_test.gd`
- records: log-suite-feedback.txt `b2d1938e95b2eca178dc3434a3bc9b7ab6c487ee51dfa98df7dcc9b6296b7f22`, env-suite-feedback.txt `14632f8b5eb3b874f71756c415b02514163d16a4547b6c36806b5ff202cb2643`, exit_status=0

## suite residency
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/p3_executor_residency_test.gd`
- records: log-suite-residency.txt `4d9e2af0f313d5ba19fa509b83c2959229172022112285296a268f929a05e9fa`, env-suite-residency.txt `e9a2229e962ddb299dab52eaae953eda0e2cd7ecf71e899fbbc5456944577556`, exit_status=0

## suite summon
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/boss_summon_cap_test.gd`
- records: log-suite-summon.txt `afe49e93a5a6ef003d29967a256897516d6aaa421891335796ba9356a3615610`, env-suite-summon.txt `ec0e233d45916607aa2d35f3dc1efe9a89ef0c0c52be928a695b3638153b6c5f`, exit_status=0

## suite hazard
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/boss_hazard_cap_gate.gd`
- records: log-suite-hazard.txt `9e92edf49b36b4017cb0892504a32a2545438dec0a495a60a851e32e9bef4f15`, env-suite-hazard.txt `cd0d9e788e22a0a35be4a7c3d8a1204b1364eb9adfde89869b7ecac94239776c`, exit_status=0

## suite hazardsmoke
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/hazard_vfx_smoke_test.gd`
- records: log-suite-hazardsmoke.txt `7bff8dd7fcab2fe4db0bf97a2549721a4d9c4d070edf34327649857acb688bc2`, env-suite-hazardsmoke.txt `fc5d21bf25b547a76eb0292d357e79961f7c5ee2812e9454edd6b29baa75a7cf`, exit_status=0

## suite berserk
- command: `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/berserk_balance_test.gd`
- records: log-suite-berserk.txt `102fd8ed43519b2400889ce48dfe0151a66a25ba666bb20fdfd6cf9b8ae630bd`, env-suite-berserk.txt `789142f43346a03e467adf2c4f0ea432bf0a5730eb5997c192e2a211f77f618d`, exit_status=0

No foreign Godot process was live during any matrix run window (strict overlap check; raw observations retained verbatim).
