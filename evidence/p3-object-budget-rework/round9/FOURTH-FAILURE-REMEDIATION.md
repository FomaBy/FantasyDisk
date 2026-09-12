# FAN-3934 — check-by-check remediation of the fourth-failure items (QA report 01a09657)

Eight preserved findings mapped to their fixes, with executed verifications.
Before = failed candidate `b7e3c4415b6a19934c3368c7021388fc2c10b9ff` unless noted; After = current successor.

1. **Missing .uid sidecar** (`round9/vsync_measure.gd`): fixed in `8ce23e22`
   — engine-generated sidecar committed; scan of every evidence `.gd` finds no
   other missing sidecar. Evidence: `git ls-files | grep uid` in the successor tree.
2. **Ownership guard (cross-domain)**: fixed in `8ce23e22` — commit message carries
   `cross-domain: FAN-3934 CI recovery legitimately spans core evidence and engineer
   presentation domains to keep the protected quality gate green` (schema-valid per
   `quality_static_guard.py:107`). `git log --format=%B origin/dev..HEAD | grep -c`
   → 1. Re-declared in the successor commit.
3. **Range whitespace — round8/MANIFEST.md:43**: trailing blank line removed in
   `8ce23e22`. Before hash (as committed in `b7e3c4415b6a19934c3368c7021388fc2c10b9ff`):
   `a699286ca79330e7d365ca67179ffa1b6ef7d40858346fcc1aef7ebd4b4c0f1c`;
   After: `6bf1101ae069e178b9dcb7456a8fab60bed6df2d9ccec7ac1bf4faad4e62c699`.
4. **Range whitespace — candidate-identity.txt.orig:13 (immutable original)**: the
   text copy was replaced by a gzip container in `8ce23e22` — binary content is
   outside `git diff --check`'s text scope while the bytes stay provable:
   gzip-decode executed now → decompressed SHA-256 `0e7be085cdeba0c85f7ab128b5df1719dc86499c07ea0d305c0cacb4a6a84963`, equal to the
   recorded pre-normalization original `0e7be085cdeba0c85f7ab128b5df1719dc86499c07ea0d305c0cacb4a6a84963`
   → original/decompressed identity binding holds. Live normalized file:
   `2eb379ef325d7cbe98f04bf9799ad64603130420cf741a62f893c48738968af7`.
5. **Curated Markdown before/after**: WHITESPACE-NOTE.md after
   `9aa4cf38d1c1e492b3a5c37ad64dbdbfb35030e5fda229f63d3db6b6a441fe64`;
   ROUND8-PACKAGE.md after `1f36983896d94044c1379b51c1619eb04a758dfdb18024e692fd61bfc88b601f`;
   ROUND9-EVIDENCE.md after `89ca44ccd29d250c423d60ae8ed5f1e66fe57001b32309818eb426de9ce41791`.
6. **Ignore-rule evidence**: the ineffective nested patterns were replaced by
   depth-independent `*.import` / `*.translation` rules in
   `evidence/p3-object-budget-rework/.gitignore`
   (`2e3474251d0b9a92faa257d36348b95090d1f8a9a7fa0d4c089dabfc527ef47d`); `git check-ignore`
   matches at any depth and `git status --short | grep -cE '\.(import|translation)$'`
   → 0 after a full engine import pass.
7. **Final static/range results on the successor**:
   `python3 tools/quality_gate.py --static-only --changed-ref origin/dev`
   → QUALITY PASSED: 16 static, 0 Godot; `git diff --check origin/dev...HEAD`
   → clean; `python3 -m unittest tests.test_quality_workflow
   tests.test_quality_static_guard` → OK.
8. **Source-applicability**: the successor's only changes vs the QA-verified
   `b7e3c4415b6a19934c3368c7021388fc2c10b9ff` are evidence storage, manifest, budget wording and its contract
   assertion — production, gameplay, workflow-executable and CI-guard bytes are
   identical, so the reviewer's own matrix (P3 3,806/3,830 of 4,000; P1 2,246;
   P2 4,035/5,000), windowed Engineer PASS, alpha-capture verification and
   leak-diagnosis controls remain applicable to the exact content.

## Observed vs extrapolated CI budget (17:14 decision)

OBSERVED (job 102722773634, run 34429832208, cancelled at the 60-minute limit;
GitHub job record + retained job log `round9/…` / QA log SHA
f6db49daca2d0c1c3a4d914ff78cc5c96c633857e8fe754830f52892bf0f30af):
job 02:32:15–03:32:31; import-warmup step 02:33:59–02:48:51 (14m52s); combined
gate 02:48:51–03:32:28 cancelled; inside the gate, suites 02:57:17–03:32:02
completing 210 of 537. EXTRAPOLATED at the observed ~9.9 s/suite: 537 suites
~89 min; full run estimated ~110 min (never observed). 180 minutes bounds the
estimate with slack. The earlier 14m52s-import mislabel of the whole
02:33:59–02:57:17 span (which includes gate time) is corrected in
`.github/workflows/quality.yml` and `tests/test_quality_workflow.py`, whose
assertions now require the OBSERVED/EXTRAPOLATED distinction, the job id, the
`estimated ~110 min` figure, and forbid any `measured total` claim.
