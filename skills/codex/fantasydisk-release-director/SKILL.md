---
name: fantasydisk-release-director
description: Cut, package, verify, and publish a FantasyDisk release. Use for requests to release, ship, publish, or build a version, including player-facing notes, a content-zone release image, the macOS DMG, Windows installer, source tags, public binary-only GitHub distribution, mandatory Telegram files, and Discord delivery.
---

# FantasyDisk Release Director

Track work and evidence in the assigned Multica `FAN-*` issue. Treat Jira as
read-only history. Run from the repository root; do not hardcode a checkout path.

## 1. Preflight

1. Fetch `origin`, inspect the live Multica board, and verify that every
   actionable release issue is `done` with independent QA. Do not treat an
   explicitly parked backlog item as done; record why it is outside the release.
2. Work from current `origin/dev` with a clean task-owned tree. Freeze release
   inputs while finalizing.
3. Run the six core smoke suites and the certifying quality gate through
   `tools/godot_gate.py` / `tools/quality_gate.py`. Do not release a red SHA.
4. Compare `git log v<previous>..origin/dev` with the notes so every visible
   player change is represented and internal-only work is omitted.
5. For a signed macOS release, read the Apple Developer Program and Developer ID
   certificate actual expiry date from Apple/Keychain, keep a renewal reminder
   well ahead of it, and repeat the identity/notary authentication check. Never
   guess or hardcode an expiry date, identity, profile, or secret. An expired or
   unverifiable state blocks the release; renewal/purchase is a separate financial
   action requiring the owner's explicit approval.

## 2. Version and player notes

1. Choose a supported `<version>` before touching release inputs: a product
   release is `X.Y.Z`; a byte-changing technical-only hotfix may be `X.Y.Z.R`.
   Re-delivery of byte-identical existing artifacts keeps the old immutable
   version and does not run this release flow. Set `project.godot::config/version`
   to the logical `<version>`. For macOS, normalize `X.Y.Z` as `X.Y.Z.0`, keep
   `application/short_version` at `X.Y.Z`, and set `application/version` to
   `(X+1).Y.(10*Z+R)`. Bounds are `MAJOR=0…9998`, `MINOR=0…99`,
   `PATCH=0…9`, `HOTFIX=0…9`, which keeps a positive first Apple build component
   and at most two digits in its third component while preserving hotfix order.
   Windows `product_version` remains `<version>`; `file_version` is
   `<version>.0` for three components and `<version>` for four. Validate every
   field with `tools/release_version_mapping.py --version <version>`.
2. Finalize `CHANGELOG.md` as `## [<version>] — YYYY-MM-DD`, then leave a new empty
   `Unreleased` section above it.
3. Add the newest entry first in `scripts/patch_notes_data.gd`.
4. When character balance or mechanics changed, include a concise player-facing
   line for **every one of the 17 heroes**. Describe what the player feels;
   exclude issue IDs, paths, test names, formulas, raw harness values, and agent
   process details.
5. Mark three to five release highlights as `Главное`; keep secondary notes
   short and readable.

## 3. Release-notes image

Use `content-zone-image-compositor` before any image generation:

1. Inventory the exact release text and create `ui_plan.json` plus `layout.json`.
2. Continue only when `validate_ui_layout_plan.py` returns
   `decision: ready_for_image` with no blocking errors.
3. Generate the empty frame/layout layer through PixelLab MCP. Forbid baked
   text, pseudo-text, logos, and ornaments inside the declared zones.
4. Composite only the declared text/logo inside those zones, then keep the base,
   final PNG, debug overlay, fit report, plan, layout, prompt/source ID, and spec.
5. Require the final render report to contain `ok: true`; save the publishable
   PNG under `assets/marketing/`. Use the legacy
   `fantasydisk_022_announcement_telegram_discord.png` name only for v0.2.2;
   every later release uses neutral `fantasydisk_<version>_announcement.png`.

## 4. Git release state

1. Commit the green release preparation and push an immutable candidate to its
   remote source ref. Before creating `main`, `v<version>`, a GitHub Release or
   public assets, build the exact candidate and obtain independent exact-SHA QA.
2. Candidate build requires repository, remote `refs/heads/...` source ref and
   full 40-hex commit SHA. The build resolves that ref exactly, records its tree
   before import/export, and uses a clean detached worktree only from that commit;
   a candidate never falls back to a tag.
3. Only after QA `PASSED`, integrate the unchanged candidate commit into `main`,
   tag that exact release commit as `v<version>`, and verify the durable candidate
   against the tag. Reuse the verified package bytes без перепаковки; any tag/candidate
   provenance mismatch blocks publication.
4. Return the task worktree to its agent branch/dev flow. Never switch another
   worker’s checkout.

## 5. Build macOS and Windows

For a published immutable tag, run:

```bash
FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh <version>
```

For a pre-tag candidate, run only:

```bash
FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh <version> \
  --candidate-repository <repository> \
  --candidate-ref refs/heads/<candidate-ref> \
  --candidate-sha <40-hex-commit>
```

Candidate mode requires all three inputs, resolves the remote ref exactly to the
pinned SHA, records the commit tree before any build step, verifies the version
inside that snapshot via canonical mapping, and never creates or requires a tag,
`main`, public release, or public asset.

Independent exact-SHA QA may add `--candidate-presign-verify` (FAN-2426) to the
same pinned invocation:

```bash
tools/build_release.sh <version> \
  --candidate-repository <repository> \
  --candidate-ref refs/heads/<candidate-ref> \
  --candidate-sha <40-hex-commit> \
  --candidate-presign-verify
```

This QA-only mode verifies the version mapping and the truthful client channel
label, runs the headless import and the macOS export/materialization, prints
`PRE-SIGN CHECKPOINT` and stops there. It needs no credentials because packaging,
signing, notarization, `main`, tagging, GitHub Release and publication never run;
it produces no publishable artifact and removes its disposable output. It is
rejected on the tag/final-release path, and it weakens nothing: a normal `signed`
build still requires an installed Developer ID and notary profile, and `unsigned`
remains the separately selected channel with a truthful client label. Reaching the
checkpoint is import/export evidence only, never release readiness.

Require `releases/v<version>/` to contain:

- `FantasyDisk-<version>-macos.dmg`;
- `FantasyDisk-<version>-windows-setup.exe` (the only Windows download);
- `SHA256SUMS.txt`;
- `CHANGELOG-<version>.md`;
- the mandatory release poster PNG;
- `update-manifest.json` (schema 1, generated from the final installer bytes).

Do not create or publish a raw Windows exe or Windows zip.

### macOS trust channels

`FANTASYDISK_MACOS_CHANNEL` selects the channel explicitly; both directions are
fail-closed and there is never a silent downgrade:

The current production channel is `signed`. FAN-1121 remains the explicit
historical unsigned fallback, not the current product selection.

- `signed` (default) — the strict production channel below. Missing Developer ID
  or notary credentials aborts the build (exit 2); ad-hoc signing is forbidden.
- `unsigned` — the owner-approved historical credential-free fallback (FAN-1121, after
  FAN-1094 was cancelled). It must be requested explicitly and refuses to run
  while `MACOS_SIGN_IDENTITY`/`MACOS_NOTARY_PROFILE` are set. After every bundle
  mutation, apply an ad-hoc seal and run
  `codesign --verify --deep --strict` to verify bundle integrity and replace any
  export template signature; this seal does not identify the publisher or make
  the artifact trusted by Gatekeeper. Developer ID signing, notarization,
  stapling, and `spctl` are skipped; exact-tag inputs, DMG layout, NSIS CRC,
  secret scan, SHA-256 sums, and the update manifest remain mandatory, and asset
  names do not change. The build cross-checks `MACOS_UPDATE_CHANNEL` in the
  tag's `scripts/update_manager.gd` so the client truthfully labels the artifact
  unsigned and shows the manual Gatekeeper «Всё равно открыть» (Open Anyway)
  instruction. Never claim Developer ID, notarization, stapling, or a positive
  `spctl` result for an unsigned build. Known macOS 26 (Tahoe) limitation
  (FAN-2199/FAN-2297): a quarantined unsigned install may launch translocated
  and be asynchronously removed from `/Applications` after quit; never claim a
  durable unsigned install on Tahoe without fresh native evidence.

### macOS signing order (signed channel)

1. Export the macOS `.app` into a zip/staging directory.
2. Finish every bundle modification, then clear stale extended attributes.
3. Sign the final `.app` **last**. Use `MACOS_SIGN_IDENTITY` for Developer ID
   Application signing with hardened runtime and timestamp. Missing Developer ID
   or notary credentials blocks a publishable signed release; ad-hoc release
   builds are forbidden.
4. Run `codesign --verify --deep --strict --verbose=4` on the staged app.
5. Build a DMG containing the app, an `Applications` symlink, and the arrow
   background supplied by `tools/create_macos_dmg.sh`.
6. Mount the final DMG and repeat strict signature verification on the contained
   app; verify the Applications link and `hdiutil verify`.
7. Require `MACOS_NOTARY_PROFILE`, run `notarytool submit --wait`, then
   `stapler staple`, `stapler validate`, and `spctl` for both app and DMG.

The first signed stable release additionally requires independent exact-tag
native evidence in FAN-2207: DMG SHA/provenance; `Accepted` notarization for the
app and DMG; `codesign`, `stapler`, and `spctl` results; Safari download
source/event lineage; Finder copy into `/Applications`; launch outside App
Translocation; first launch → quit → relaunch ×2; and app survival after every
quit and remediation observation window. Until that review is terminal
`PASSED`, signed durability is not proven and FAN-1231 remains open.

### Windows verification

Build the temporary embedded-PCK exe, wrap it with NSIS, verify the exact NSIS
CRC algorithm, secret-scan staged payloads, and publish only setup.exe.

The final Windows verification card (`qa_windows`) must include a filled
performance section per `docs/qa/perf-checklist.md`: metrics M1–M5 measured on
real Windows hardware with the exact commands from that checklist. A QA verdict
without the filled performance section is incomplete and must not be accepted.

## 6. Durable local release — blocking

An ephemeral Multica worktree is never the retained release location. Configure
the operator machine once in `~/.config/fantasydisk/release.json`:

```json
{
  "local_root": "/absolute/path/to/FantasyDisk",
  "macos_app": "/Applications/FantasyDisk.app"
}
```

`FANTASYDISK_LOCAL_ROOT`, `FANTASYDISK_LOCAL_APP`, and explicit CLI arguments
override that file. There is no repo-root fallback: an ephemeral worktree is
never inferred as durable merely because it contains ignored config. The build
must use export presets, icons, installer sources, and DMG layout inputs from the
exact tag or pinned candidate; overlaying current worktree files onto either
snapshot is forbidden.

`tools/build_release.sh` must finish by running:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/local_release.py \
  materialize --version <version> --repo-root "$PWD" \
  --release-dir "$PWD/releases/v<version>"
```

Require all of the following before any external upload:

- the build writes into an isolated staging directory; only `local_release.py`
  may atomically create `<local_root>/releases/v<version>/`;
- the complete package, including the mandatory versioned poster PNG, is
  retained under `<local_root>/releases/v<version>/`;
- `project/` is immutable evidence from an exact `git archive` of `v<version>` or
  the pinned candidate commit. A candidate manifest records repository/ref/commit/tree,
  content source digest, and an inventory with size/SHA-256 for every package file;
  it never invents `tag_commit` before promotion. Its pre-build provenance must match
  the materialization arguments;
- after exact-SHA QA, `local_release.py verify` requires the created tag commit/tree
  to match the retained candidate provenance, so the already verified package bytes
  are reused без перепаковки;
- existing releases are byte-compared and never overwritten on mismatch, and a
  materialized release is never relabeled into another channel;
- `godot-project/` is a separate editable copy; `<local_root>/releases/current-project`
  points to it and is explicitly `favorite=true` in Godot's `projects.cfg`;
- on macOS, the app is installed atomically from the retained DMG at the
  configured local path. The retained DMG, contained app, and installed app pass
  layout, version, `hdiutil verify`, headless launch smoke, and `codesign`
  integrity verification in both channels (unsigned uses its local ad-hoc seal).
  The signed channel additionally requires `stapler` and `spctl` after
  Developer ID signing and notarization; the unsigned channel skips only those
  Apple trust requirements and nothing else.

There is no macOS skip flag. Windows/Linux may use the explicit platform
exception for app installation, but package, tag snapshot, manifest, current
pointer, and Godot registration remain mandatory. Every publication script runs
`local_release.py verify` before resolving credentials or sending anything, then
upload only files from the verified `local_release` path returned by that check.
`verify` compares the requested channel (`--macos-channel` /
`FANTASYDISK_MACOS_CHANNEL`, default strict `signed`) against the recorded
`macos_channel` and fails on mismatch, so an unsigned release can only be
published with the operator's explicit unsigned acknowledgement.
The release poster PNG is a GitHub/Discord asset and is also sent to Telegram
for every stable release together with DMG, Windows Setup and SHA256SUMS.
`update-manifest.json` must match both retained installers byte-for-byte by
name, size, URL, and SHA-256.

## 7. Integrity and publication

1. Verify `shasum -a 256 -c SHA256SUMS.txt`, the DMG mount/layout/signature, app
   bundle version, and NSIS CRC. Record the lack of native Windows runtime QA if
   no Windows machine is available.
2. Publish only to `FomaBy/FantasyDisk-Releases`, a public binary-only
repository. Before upload, prove its Git tree has no source/secrets; then
dry-run, publish the allowlisted assets, and verify the page, latest manifest
and installers without GitHub credentials:

```bash
FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1 \
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version <version> --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version <version> \
  --writer-inventory-proof "$PROOF_DIR/writer-proof-first.json" \
  --writer-inventory-proof "$PROOF_DIR/writer-proof-second.json"
python3 skills/codex/fantasydisk-release-director/scripts/github_release_verify.py \
  --version <version> --local-release /absolute/durable/releases/v<version>
```

   Require a public, non-draft `v<version>` release containing DMG, Windows setup,
   SHA256SUMS, changelog, poster and update manifest. The manifest upload starts
   last, but `gh` uploads assets concurrently, so completion order is not the
   safety mechanism. The verifiable invariant is: the release stays a draft
   until every asset, including the manifest, is verified uploaded byte-exact
   (name, size, SHA-256), and only a fully verified draft is made public and
   then latest — `latest/download` can never expose an incomplete installer set.

### Owner-attested App writer proof

Use two independently observed Settings → Applications inventories for the same
personal account and distribution repository. Create the first proof before the
command. The command creates and verifies the draft, then pauses at the terminal:
only then export the second proof and press Enter. The second observation must be
newer than the completed draft-asset check; a pre-created, replayed, malformed,
hidden, partial, empty-name, or duplicate selected-repository inventory is rejected
before `--draft=false`. Unknown repository selection is unsafe even for a read-only
App.

Keep proofs only in a private temporary directory, never in the checkout, shell
history, Multica, or logs. Replace the placeholders from the actual Settings UI;
the `installations` array must contain every visible installed App and each
`selected` App must include its complete selected-repository inventory.

```bash
PROOF_DIR="$(mktemp -d)"
chmod 700 "$PROOF_DIR"
write_proof() {
  python3 - "$1" <<'PY'
import json, sys
from datetime import datetime, timezone
json.dump({
  # JSON field: "complete": true
  "schema_version": 1,
  "source": "github-account-applications-settings",
  "account": "FomaBy",
  "repository": "FomaBy/FantasyDisk-Releases",
  "observed_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
  "complete": True,
  "installations": [{
    "id": 123456,
    "app_slug": "example-read-only-app",
    "permissions": {"contents": "read", "administration": "read"},
    "repository_selection": "selected",
    "repositories": {"total_count": 1, "repositories": [
      {"full_name": "FomaBy/FantasyDisk-Releases"}
    ]}
  }]
}, open(sys.argv[1], "w", encoding="utf-8"), indent=2)
PY
}
write_proof "$PROOF_DIR/writer-proof-first.json"
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version <version> \
  --writer-inventory-proof "$PROOF_DIR/writer-proof-first.json" \
  --writer-inventory-proof "$PROOF_DIR/writer-proof-second.json"
rm -rf "$PROOF_DIR"
```

When the publisher reports that the draft assets are verified, switch to the
Settings → Applications export, replace the example installation list with the
complete current list, run `write_proof "$PROOF_DIR/writer-proof-second.json"`,
and only then press Enter in the publisher terminal. The example is a complete
installation-bearing schema, not permission to omit Apps or repositories.

If validation or publication fails, inspect the reported non-secret error, retain
the proofs only long enough for the authorized incident review, then delete the
same temporary directory with `rm -rf "$PROOF_DIR"`. Never paste a proof into a
ticket: it is account-security evidence, not release metadata.

   FAN-1276 sole-writer boundary: draft release assets stay writable to any
   account with contents write access until the release goes public, and
   GitHub offers no publish-with-expected-bytes precondition, so
   verify-then-publish is race-free only while the publisher is provably the
   only write-capable account. Before the first external side effect — and
   again immediately before the public edit — the publisher proves that the
   distribution repository is owned by the authenticated publisher account
   (user-owned), lists no other collaborator and no pending collaboration
   invitation, holds no deploy key that can push, and is covered by no GitHub
   App installation with contents or administration write. Do not treat
   `GET /user/installations` from a `ghu_` token as account-wide evidence: it
   covers only that App's visible installations. For a personal account the
   supported proof is two owner-attested, complete Settings → Applications JSON
   inventories passed with `--writer-inventory-proof` (pre-draft then
   pre-public). Each binds account, repository, UTC observation time and full
   selected-repository details; both expire after two minutes and the second
   must be newer. Hidden, malformed, partial, stale, replayed, or writer-bearing
   evidence blocks publication. Keep attestations, cookies and tokens out of git,
   Multica and logs. Every draft asset is
   then re-verified byte-exact (name, size, SHA-256) as the last read before
   `gh release edit --draft=false`, so a concurrent asset swap after the last
   clean verification aborts the attempt while the release is still an
   unpublished draft — swapped bytes never become public or immutable. The
   boundary is intentionally strict and read-only: a foreign collaborator,
   invitation, writable deploy key, or write-capable App installation on the
   distribution repository fails publication closed until it is removed
   manually; the publisher never changes those settings itself.

   FAN-1249/FAN-1265/FAN-1272 fail-closed contract: the distribution repository must
   have GitHub-enforced immutable releases enabled (`Settings → General →
   Releases`) **and** an active tag ruleset with no bypass actors that blocks
   update and deletion of the release tags (pattern covering `v*`), or the
   publisher refuses to run before any external side effect. GitHub offers no
   atomic publish-with-expected-SHA, so that server-side ruleset is what keeps
   the atomically claimed tag frozen between the last pre-public identity check
   and publication. The release tag is claimed atomically at the exact
   default-branch commit; a tag or release that appears between preflight and
   create blocks publication instead of being reused. Draft creation passes
   `--verify-tag`: if the claimed tag disappears after the claim, creation
   aborts instead of implicitly recreating the tag. Tag identity is re-verified
   after create, again immediately before the public edit, and after publish,
   and the published release must report GitHub immutability before it is
   marked latest. The post-public checks the publisher actually repeats are
   the release's public state, byte-exact asset verification, tag identity,
   and GitHub-reported release immutability; the ruleset endpoint itself is
   proven before the claim and is not re-read after publication. After any
   create error or ambiguity the publisher performs a best-effort re-read of
   the release state (draft/public, latest marker) and the claimed tag, and
   reports what it observed — it never promises a draft-only state without
   that proof, because a concurrent publisher may already own a public, even
   latest, release on the claimed tag. There is no delete/clobber/force path:
   the publisher never removes a claimed tag, a draft, or a public release,
   and a published release has no rollback. Truthful failure states, each
   with its only safe action:

   - **Failed draft create.** `gh release create` failed after the claim and
     the best-effort re-read proves no public release exists: this process
     left at most the claimed bare tag and an unpublished draft (possibly
     with partial assets). Leave them in place and burn the version number.
   - **Ambiguous create.** The create error or the state re-read is
     inconclusive: the release may be a draft or already public (even
     latest). Manually inspect the release and tag on GitHub, then burn the
     version number.
   - **Foreign/racing public release.** A concurrent publisher created a
     public — possibly latest — release on the claimed tag before our draft
     create. Never delete, edit, demote, or reuse the foreign release or
     tag; burn the version number for this attempt.
   - **Successful public non-latest.** Our public edit was confirmed applied
     (`gh release edit --draft=false --latest=false` returned success) but a
     post-public check fails (foreign tag, missing immutability, or an asset
     mismatch): the public non-latest release we created remains. Leave it
     exactly as observed — never mark it latest, edit, demote, delete, or
     reuse it — and burn the version number.
   - **Latest-only failure.** The release is already public, byte-exact
     verified, and GitHub-immutable; only the final `--latest` marking
     failed. This is the one state that does not burn the version: after
     confirming the release page, rerun
     `gh release edit v<version> --repo FomaBy/FantasyDisk-Releases --latest`
     manually instead of recreating anything.

   A lost public-edit response (applied-but-response-lost) does not by itself
   prove a successful public non-latest release. Until a re-read resolves the
   ambiguity, four outcomes are documented separately: the release may still
   be an unpublished draft (the edit did not apply → Failed draft create), a
   public non-latest release (the edit applied → Successful public
   non-latest), an unexpected public latest release (handle it like a
   foreign/racing public latest and never demote it), or an unreadable state
   (Ambiguous create). Never treat a lost response as proof of a public
   non-latest state.

   Every other failed attempt burns that version number, and the next
   attempt must use the next `<version>` (hotfix component).
3. Dry-run and publish Telegram for **every stable release**. Telegram delivery
   is mandatory and contains the poster, DMG, Windows Setup and SHA256SUMS.

```bash
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version <version> --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version <version>
```

4. After verified Telegram file delivery, publish the player-facing news to
   Discord. It must include the Telegram download link and the public GitHub
   release used by the updater:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/release_publish.py \
  --version <version>
```

Keep GitHub tokens, webhook URLs, legacy Telegram credentials/session files,
signing identities, and notary profiles in ignored local config/keychain state.
Never print or commit secrets.

## 8. Finish

Update `docs/design/current_game_state.md` and release/versioning docs. Record
the exact SHA/tag, push state, gates, artifacts, hashes, macOS trust channel
(signed identity type and notarization result, or the explicit unsigned-channel
decision), publication result, residual risks, and `Disk cleanup:` in
Multica. Include the durable local release path, `current-project` target,
installed app path, and local verification result. Move implementation to
`in_review`; set `done` only after independent QA says `QA verdict: PASSED`.
