# FAN-3470 Repository Storage Design

## Goal

Make the frequent candidate checkout materially smaller without weakening exact-SHA, changed-range, provenance, release, or clean runtime build/test contracts. Contain future design-source growth without rewriting published history.

## Checkout contract

The `static-quality` job remains the required candidate gate. It uses sparse checkout so GitHub's checkout action automatically requests `blob:none`, but retains every runtime, test, tool, skill, and process input needed by the gate. Pull-request and merge-queue candidates use depth 2 because their comparison base is a direct merge parent. Pushes to `dev` retain full ancestry because `github.event.before` may span multiple commits.

The sparse list includes `assets`, `data`, `references`, `scenes`, `scripts`, `services`, `skills`, `source_docs`, `tests`, `tools`, process/task documentation, the single required QA fixture pack, constellation source data, release-note templates, the 0.2.4 release-note visual fixture, the typography inventory, and the weapon-ultimate reference pack used by core changed-profile tests. It excludes the remaining heavy design evidence and tracked historical QA output. `lfs: false` is explicit, so ordinary candidate jobs do not hydrate future design-source binaries.

Shallow candidate events fetch their exact event base at depth 2 into `refs/remotes/origin/dev`, then fetch the two legacy commits required by release-onboarding regression fixtures at depth 1. Static checks read omitted tracked source text from exact `HEAD:<path>`, preserving resource, architecture, and credential coverage without materializing historical binary evidence. Scheduled A5 provenance jobs keep their existing bounded lineage fetch. Release work is documented as requiring full history and tags; no release workflow exists in this repository to edit.

## Future reference storage contract

All new source/reference binaries, regardless of size or format, live under
`docs/design/reference-assets-lfs/<issue-or-pack>/<file>`. `.gitattributes`
maps repository binary formats, including PNG/JPEG/audio/font/archive plus PDF,
GZip, DOCX, and XLSX, there to Git LFS. Active item-icon, UI-mockup, and asset
generator producers use that nested route; accepted runtime files still go to
`assets/**`. Existing design evidence and tracked `build/qa` content remains
untouched and no historical object is rewritten.

The changed-range policy preserves Git status and both paths for copies and
renames. Every added, modified, copied, or renamed binary destination under
`docs/design/**` or `build/qa/**` is rejected unless it uses the nested future
route; this is unconditional and has no size threshold. Unchanged legacy files
remain grandfathered and deletions are allowed. A conservative text-extension
allowlist keeps manifests, docs, scenes, resources, and scripts textual; any
other extension is treated as binary, while extensionless files use an 8 KiB
size/content probe. This catches unknown formats without materializing large
blobs.

The policy asks Git for each candidate blob size before content. Legacy binary
rejections never read the blob. Future blobs larger than the 256-byte pointer
bound fail without a content read; only bounded candidates are checked against
the exact three-line canonical LFS v1 form in fixed order, with one lowercase
64-hex SHA-256 OID, one canonical decimal size, a final newline, and no other
content. Runtime `assets/**` is deliberately outside the LFS mapping and remains
present in sparse clean checkouts.

## Validation

Contract tests exercise workflow depth/sparse/history exceptions, strict pointer
parsing, size-first rejection, producer output routing, and real-Git add/modify/
copy/rename/delete cases. A clean synthetic two-parent PR clone proves the exact
base/parent contract, focused suite selection, and that the static gate reaches
the same repository invariants as a full checkout. The benchmark records packed
storage as a fetch proxy, total checkout disk, and wall time before and after
using the same local upload-pack source; local upload-pack does not honor
filters, so the measured after result is conservative relative to GitHub. Any
pre-existing baseline failure is reported rather than waived or attributed to
this change.

## Boundaries

- No history rewrite, migration, tag change, gameplay change, or current workdir-GC change.
- No global binary LFS pattern; runtime assets stay ordinary Git blobs.
- No automatic LFS hydration in candidate CI.
- Existing reference files are grandfathered unless modified.
