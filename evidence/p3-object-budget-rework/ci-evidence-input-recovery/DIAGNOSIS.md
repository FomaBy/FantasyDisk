# FAN-3934 — protected-CI evidence-input failure group: diagnosis and repair

CI facts (retained): run 34786441886, job 103802677133, merge 7635ff23b
(tree equals reviewed candidate bc247030 tree 844bca28); static-quality
failed; visual regression and the repaired Thief suite passed.

## Failure group 1 — Engineer certification PNGs stayed LFS pointers

Source facts: the Engineer class manifest publishes its certification link as
`evidence.live_capture.certification_manifest` (linked manifest:
`docs/design/references/weapon_ultimates/engineer/certification_capture_manifest.json`),
while `tools/quality_gate.py:_certification_capture_declarations` read only
`live_capture.capture_manifest`; the linked manifest carries its 48 hydrated
PNG paths under `samples` (geometry-only `viewports` carry no paths), while
`_certification_artifact_paths` traversed captures/sheets/viewports. Both
gaps are CI-evidence-input discovery defects: the gate never learned those
48 paths existed, so the workflow never materialized them and the suite read
raw LFS pointer files.

Repair (granted helper path): the declaration lister accepts BOTH
`capture_manifest` and `certification_manifest` keys under `live_capture`;
artifact traversal unions every present record list (`captures`, `sheets`,
`viewports`, `samples`), skips path-less geometry records (including the
non-list geometry DICT shape the ranger/thief/soldier manifests publish —
found by the retained failing contract), rejects unsafe/empty paths, and
fails when no artifact path resolves at all. Existing ranger/thief/soldier
behavior is unchanged (their 84/84/132 `captures` paths were already read;
verified by the pre-existing contract tests passing unmodified).

## Failure group 2 — scrum895/scrum924 VFX reference directories

Source facts: both suites read `manifest.json` and `frame_qa_report.json`
from their `docs/design/references/scrum{895,924}_*` directories; all four
files have IDENTICAL blobs in base and candidate, but the workflow's sparse
cone omitted both directories, so the CI checkout never contained them.
Repair (granted workflow path): both directories added to the candidate-job
sparse cone with an explanatory comment; regression coverage asserts their
inclusion and the on-disk presence of both files.

## Failure group 3 — typography inventory stale diff

`tools/typography_inventory.py --check` at the candidate: STALE. The
canonical generator was run (retained): the regenerated file differs from the
committed one ONLY in two line-number fields (665→671, 693→694) — the
generator's fingerprints intentionally exclude line numbers, so this is
harmless source movement, exactly the "generator-produced correction"
condition of the grant. The regenerated inventory (285 entries, 0 unreviewed,
`--check` PASS) is committed; no generator or semantic change was made.

## What is demonstrated / uncertain

Demonstrated: all four CI failures are evidence-input discovery/checkout
defects reproducible from source facts (key mismatch, cone omission, stale
generated file); base and candidate blobs are identical for every involved
input, so none was caused by this candidate's content. Uncertain: no full
CI re-execution was run here (the terminal protected CI run remains the
acceptance gate); the typography diff is proven canonical only for the two
line-number fields visible in the retained diff.
