# FAN-3934 — validation-package reconciliation (01:16 decision)

## 1. Engineer PASS claim vs the failed attempt (item 1)

The published `suite-engineer_certification_capture_test.log` (retained
unchanged) genuinely FAILED: 48 unsmudged-LFS-pointer errors, and my prior
handoff's "exit=0" was the shell's status of a trailing `date` append, not
the Godot process — exactly as the PM diagnosed. Root cause of the local
failure: this branch worktree holds the engineer certification PNGs as LFS
pointers (never smudged locally), while CI materializes them via
`git lfs smudge` in the workflow's LFS-evidence step — the step my gate fix
now feeds the 48 engineer paths. No later successful attempt existed.

Corrected verification (this round): the 48 declared sample paths were
hydrated exactly as CI's materialization step does (`git lfs pull --include
docs/design/reference-assets-lfs/ultimate-certification/engineer/*`,
lfs-hydration.log, exit 0), then the suite was re-executed at the frozen
successor source with the complete argv and the Godot process exit captured
in-file: `suite-engineer_certification_capture_test-hydrated.log` — zero
unsmudged errors, `FAN-3939 Engineer certification capture package: PASS`,
exit_status=0. Applicability: identical input blobs (smudged from the same
tracked pointers) at the exact successor tree; nothing text-tracked changed
since. The failed attempt stays as the record of the discrepancy.

## 2. Source/exit binding of every claimed check (item 3)

- static-gate.log — re-executed at the exact successor: source/tree in its
  header, exit_status=0, PARTIAL_PASS classification preserved with the note
  above.
- feature-list-check.log — re-executed at the exact successor (the earlier
  `aedc3d38` source binding is superseded by this same-source run):
  51/51 PASS, exit_status=0.
- The four affected suites and Thief: logs retained with sources; the
  engineer log above is the same-source passing record.
- Reuse vs the final immutable successor: only evidence-directory text files
  changed since every executed source; the reused checks' inputs (gate,
  workflow, inventory, tests) are unchanged, which is the applicability proof.

## 3. Causal-bounds statement (item 2)

Demonstrated: each CI failure reproduces from source facts at the failing
merge (declaration-key mismatch, sparse-cone omission, stale generated
inventory); base and candidate blobs are identical for every involved input,
and the repairs address each mechanism directly. Bounded: identical selected
blobs do not prove independence from ALL candidate inputs, and no full CI
re-execution was performed locally — the terminal protected CI run on this
successor remains the decisive acceptance for the checkout/materialization
behavior end-to-end. The typography comparison is canonical for the two
line-number fields visible in the retained diff. All generation, assertions,
thresholds and original acceptance conditions are unchanged.
