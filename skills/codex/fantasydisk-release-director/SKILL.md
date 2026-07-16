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

## 2. Version and player notes

1. Choose a supported `<version>` before touching release inputs: a product
   release is `X.Y.Z`; a byte-changing technical-only hotfix may be `X.Y.Z.R`.
   Re-delivery of byte-identical existing artifacts keeps the old immutable
   version and does not run this release flow. Set `project.godot::config/version`
   and macOS fields to `<version>`; Windows `file_version` is `<version>.0` for
   three components and `<version>` for four.
2. Finalize `CHANGELOG.md` as `## [X.Y.Z] — YYYY-MM-DD`, then leave a new empty
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
   every later release uses neutral `fantasydisk_XYZ_announcement.png`.

## 4. Git release state

1. Commit the green release preparation and push it to `origin/dev`.
2. Integrate current `dev` into `main` with a release merge commit, tag the
   exact release commit as `vX.Y.Z`, and push `main` plus the tag.
3. Return the task worktree to its agent branch/dev flow. Never switch another
   worker’s checkout.

## 5. Build macOS and Windows

Run:

```bash
tools/build_release.sh <version>
```

Require `releases/v<version>/` to contain:

- `FantasyDisk-<version>-macos.dmg`;
- `FantasyDisk-<version>-windows-setup.exe` (the only Windows download);
- `SHA256SUMS.txt`;
- `CHANGELOG-X.Y.Z.md`;
- the mandatory release poster PNG;
- `update-manifest.json` (schema 1, generated from the final installer bytes).

Do not create or publish a raw Windows exe or Windows zip.

### macOS trust channels

`FANTASYDISK_MACOS_CHANNEL` selects the channel explicitly; both directions are
fail-closed and there is never a silent downgrade:

- `signed` (default) — the strict production channel below. Missing Developer ID
  or notary credentials aborts the build (exit 2); ad-hoc signing is forbidden.
- `unsigned` — the owner-approved credential-free channel (FAN-1121, after
  FAN-1094 was cancelled). It must be requested explicitly and refuses to run
  while `MACOS_SIGN_IDENTITY`/`MACOS_NOTARY_PROFILE` are set. Only
  codesign/notarization/stapling/`spctl` are skipped; exact-tag inputs, DMG
  layout, NSIS CRC, secret scan, SHA-256 sums, and the update manifest remain
  mandatory, and asset names do not change. The build cross-checks
  `MACOS_UPDATE_CHANNEL` in the tag's `scripts/update_manager.gd` so the client
  truthfully labels the artifact unsigned and shows the manual Gatekeeper
  «Всё равно открыть» (Open Anyway) instruction. Never claim Developer ID,
  notarization, stapling, or a positive `spctl` result for an unsigned build.

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

### Windows verification

Build the temporary embedded-PCK exe, wrap it with NSIS, verify the exact NSIS
CRC algorithm, secret-scan staged payloads, and publish only setup.exe.

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
exact tag; overlaying current worktree files onto the tag is forbidden.

`tools/build_release.sh` must finish by running:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/local_release.py \
  materialize --version <version> --repo-root "$PWD" \
  --release-dir "$PWD/releases/v<version>"
```

Require all of the following before any external upload:

- the build writes into an isolated staging directory; only `local_release.py`
  may atomically create `<local_root>/releases/vX.Y.Z/`;
- the complete package, including the mandatory versioned poster PNG, is
  retained under `<local_root>/releases/vX.Y.Z/`;
- `project/` is immutable evidence from an exact `git archive` of `vX.Y.Z`, with
  tag SHA, every package hash, and the macOS trust channel (`macos_channel`)
  recorded in `LOCAL_RELEASE.json`;
- existing releases are byte-compared and never overwritten on mismatch, and a
  materialized release is never relabeled into another channel;
- `godot-project/` is a separate editable copy; `<local_root>/releases/current-project`
  points to it and is explicitly `favorite=true` in Godot's `projects.cfg`;
- on macOS, the app is installed atomically from the retained DMG at the
  configured local path. The retained DMG, contained app, and installed app pass
  layout, version, `hdiutil verify`, and headless launch smoke checks; in the
  signed channel `codesign`, `stapler`, and `spctl` are additionally mandatory,
  while the unsigned channel skips exactly those three and nothing else.

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
dry-run, publish the allowlisted assets with manifest last, and verify the page,
latest manifest and installers without GitHub credentials:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version <version> --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version <version>
python3 skills/codex/fantasydisk-release-director/scripts/github_release_verify.py \
  --version <version> --local-release /absolute/durable/releases/v<version>
```

   Require a public, non-draft `v<version>` release containing DMG, Windows setup,
   SHA256SUMS, changelog, poster and update manifest. The publisher uploads the
   manifest last and marks the release latest only after all assets exist.
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
