# FAN-3470 Repository Storage Design

## Goal

Make the frequent candidate checkout materially smaller without weakening exact-SHA, changed-range, provenance, release, or clean runtime build/test contracts. Contain future design-source growth without rewriting published history.

## Checkout contract

The `static-quality` job remains the required candidate gate. It uses sparse checkout so GitHub's checkout action automatically requests `blob:none`, but retains every runtime, test, tool, skill, and process input needed by the gate. Pull-request and merge-queue candidates use depth 2 because their comparison base is a direct merge parent. Pushes to `dev` retain full ancestry because `github.event.before` may span multiple commits.

The sparse list includes `assets`, `data`, `references`, `scenes`, `scripts`, `services`, `skills`, `source_docs`, `tests`, `tools`, process/task documentation, the single required QA fixture pack, constellation source data, release-note templates, the 0.2.4 release-note visual fixture, the typography inventory, and the weapon-ultimate reference pack used by core changed-profile tests. It excludes the remaining heavy design evidence and tracked historical QA output. `lfs: false` is explicit, so ordinary candidate jobs do not hydrate future design-source binaries.

Shallow candidate events fetch their exact event base at depth 2 into `refs/remotes/origin/dev`, then fetch the two legacy commits required by release-onboarding regression fixtures at depth 1. Static checks read omitted tracked source text from exact `HEAD:<path>`, preserving resource, architecture, and credential coverage without materializing historical binary evidence. Scheduled A5 provenance jobs keep their existing bounded lineage fetch. Release work is documented as requiring full history and tags; no release workflow exists in this repository to edit.

## Future reference storage contract

All new source/reference binaries, regardless of size, live under `docs/design/reference-assets-lfs/<issue-or-pack>/`. `.gitattributes` maps supported binary extensions there to Git LFS. Existing `docs/design/references`, `previews`, `mockups`, `backups`, and tracked `build/qa` content remains untouched and no historical object is rewritten.

A changed-range policy supplies a minimum fail-closed backstop: it rejects newly added or modified binary evidence in the legacy paths when any file is at least 1 MiB or their aggregate raw size exceeds 5 MiB. Those thresholds do not permit smaller new legacy binaries. Correct Git LFS pointers in the future-only path pass and declare their logical size. Runtime `assets/**` is deliberately outside the LFS mapping and remains present in sparse clean checkouts.

## Validation

Contract tests exercise workflow depth/sparse/history exceptions and the storage policy against temporary real Git repositories. A clean synthetic two-parent PR clone proves the exact base/parent contract, focused suite selection, and that the static gate reaches the same repository invariants as a full checkout. The benchmark records packed storage as a fetch proxy, total checkout disk, and wall time before and after using the same local upload-pack source; local upload-pack does not honor filters, so the measured after result is conservative relative to GitHub. Any pre-existing baseline failure is reported rather than waived or attributed to this change.

## Boundaries

- No history rewrite, migration, tag change, gameplay change, or current workdir-GC change.
- No global binary LFS pattern; runtime assets stay ordinary Git blobs.
- No automatic LFS hydration in candidate CI.
- Existing reference files are grandfathered unless modified.
