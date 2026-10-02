# FAN-3965: GitHub publication of accepted 0.3.1.2 bytes

This evidence covers publication only. It introduces no game, package, publisher,
GitHub protection, Telegram, or Discord change. The accepted packages were not
rebuilt. Independent publication QA remains required on this same card.

## Inputs and authority

`provenance.json` records the source tag/object/commit/tree, reviewed publisher
blob, current run, owner delegation, package QA, native Windows QA, and write set.
`artifacts.json` records all six retained files' pinned SHA-256 and sizes.
The source tag points to `9a19870a15d71bc2b63e622c7895519bd84dafb4`; the
distribution tag points to the binary-only repository's existing README commit
`162ac9f886a7c4deaa05d6c70c23779f406c7080`. These are different repositories.

## Executed checks

- All six retained files rehashed against the issue pins; manifest URLs use
  `releases/download/v0.3.1.2/`.
- `local_release.py verify --version 0.3.1.2 --macos-channel signed`: exit 0.
  The local signed-channel verification output is in `local-verify.json`.
- Unchanged `github_release_publish.py --version 0.3.1.2 --dry-run`: exit 0;
  `dry-run.txt` contains the exact allowlist.
- Read-only binary-only tree, immutable-release setting, active tag update and
  deletion ruleset without bypass, unclaimed tag/release, no foreign
  collaborators, invitations, or writable deploy keys: `github-preflight.json`.
- Unchanged reviewed publisher, signed channel, `FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1`,
  two proof paths, run-owned PTY session 84763: exit 0. Its actual built-in pause
  and final release URL are preserved in `publisher-pty.txt`.
- `github_release_verify.py --version 0.3.1.2 --local-release <retained package>`:
  downloaded every public asset without credentials and compared names, sizes,
  SHA-256, installer checksums, canonical URLs, latest manifest, and local bytes.
  Result: `public-download-verification.json` (`ok: true`).
- Separate unauthenticated public API readback: stable, public, immutable release
  402050629, latest; distribution tag identity; prior v0.3.1 id/immutability and
  publication date retained. See `public-state.json`.

## Honest live-browser observation

The owner delegated the browser/Terminal step; these are agent observations,
not claims that the owner personally inspected the pages. Chrome's live DOM was
read through AppleScript for the full Installed GitHub Apps list and every listed
installation's configuration, permissions, checked repository-selection radio,
and complete selected-repository list. The first complete inventory finished at
18:14:35.192312Z; the second finished at 18:16:57.018923Z after the publisher's
verified-draft pause. The publisher then performed its own freshness, sole-writer,
tag, and asset checks unmodified.

`first-inventory-summary.json` and `second-inventory-summary.json` contain only
sanitized App names, permission levels, release-repository coverage, counts,
observation times, and capture hashes. The identical hashes reflect unchanged
pages independently fetched again; no file was restamped or reused as a new
observation. `browser-inventory-observer.py` records the observation procedure.
ChatGPT Codex Connector's write permissions exclude the release repository;
Multica AI includes it with read-only permissions.

An initial sudo/verification-code prompt stopped preflight without credentials
being entered or any tag claimed. The same task tab subsequently became readable
during the run. The agent does not claim to have performed that authentication.
Both publication inventories were taken after access was restored.

Raw captures and full writer proofs were confined to a task-private 0700
directory and deleted at cleanup. No credentials or private repository list are
part of this candidate. Only the task-created browser tab was closed at cleanup.

## Acceptance and handoff

The final Russian Multica comment from run
`01a0fdcc-bb51-7193-bc8d-639e1619234d` is the single owner notification. It includes
direct release/DMG/Setup links and summarizes the already accepted macOS and
Windows animation/crash checks. `owner-notification.md` contains its owner-facing
text; candidate/handoff details are appended in the actual comment.

Package gameplay acceptance remains FAN-3994 and FAN-3990: all 51 new ultimate
scenes across 17 classes were verified, and regression sessions did not reproduce
the 0.3.1.1 crash. Native Windows QA completed 12/12 sessions with ordinary exit;
the old build reproduced the crash as a control. No full gameplay rerun was
performed for this publication transfer.

Carried nonblocking package-QA risk: forced ultimate recharge and uncollected
loot can exceed 6,250 objects on macOS; normal-rule measured peaks remained below
that limit. The prior macOS QA also records a known unrelated callback error and
ad-hoc test copies with identical game payloads. This publication adds no broader
claim of error-free gameplay or owner acceptance.

No PR or repository integration is required for this evidence-only publication
stage (`post_qa_integration_required=false`). The exact pushed candidate awaits
independent same-card qa_high review; the implementer does not assign QA or mark
the deliverable done. The current PM lifecycle binding receives one handoff.
