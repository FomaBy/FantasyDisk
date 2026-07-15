---
name: fantasydisk-release-director
description: Cut, package, verify, and publish a FantasyDisk release. Use for requests to release, ship, publish, or build a version (for example “релизим 0.2.2”, “собрать релиз”, or “опубликовать версию”), including player-facing notes, a content-zone release image, the macOS DMG (strict signed/notarized channel, or the explicit owner-approved unsigned channel), Windows installer, Git tags, public GitHub Releases, the 0.2.2-only Telegram transition, and Discord delivery.
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

1. Set `project.godot::config/version` and every macOS/Windows version field in
   `export_presets.cfg` to `X.Y.Z`.
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
tools/build_release.sh X.Y.Z
```

Require `releases/vX.Y.Z/` to contain:

- `FantasyDisk-X.Y.Z-macos.dmg`;
- `FantasyDisk-X.Y.Z-windows-setup.exe` (the only Windows download);
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
  materialize --version X.Y.Z --repo-root "$PWD" \
  --release-dir "$PWD/releases/vX.Y.Z"
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
The release poster PNG is a GitHub/Discord asset and is additionally sent to
Telegram for v0.2.2 only. `update-manifest.json` must match both retained
installers byte-for-byte by name, size, URL, and SHA-256.

## 7. Integrity and publication

1. Verify `shasum -a 256 -c SHA256SUMS.txt`, the DMG mount/layout/signature, app
   bundle version, and NSIS CRC. Record the lack of native Windows runtime QA if
   no Windows machine is available.
2. Dry-run the canonical public GitHub Release, then publish it:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version X.Y.Z --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/github_release_publish.py \
  --version X.Y.Z
```

   Require a public, non-draft `vX.Y.Z` release containing DMG, Windows setup,
   SHA256SUMS, changelog, poster and update manifest. The publisher uploads the
   manifest last and marks the release latest only after all assets exist.
3. **Only for v0.2.2**, also dry-run and publish Telegram. Never run Telegram for
   later versions; `telegram_publish.py` must fail closed above 0.2.2.

```bash
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version 0.2.2 --dry-run
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version 0.2.2
```

4. Publish the player-facing news to Discord. Its download link must be the
   public GitHub Release, including for v0.2.2 (Telegram is an extra delivery
   channel, not the canonical URL):

```bash
python3 skills/codex/fantasydisk-release-director/scripts/release_publish.py \
  --version X.Y.Z
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
