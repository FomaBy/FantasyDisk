---
name: fantasydisk-release-director
description: Cut, package, verify, and publish a FantasyDisk release. Use for requests to release, ship, publish, or build a version (for example “релизим 0.2.2”, “собрать релиз”, or “опубликовать версию”), including player-facing notes for every playable character, a content-zone release image, a final-signed/notarized macOS DMG, the Windows installer, Git tags, and Discord/Telegram delivery.
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
   PNG under `assets/marketing/`.

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
- the release poster when present.

Do not create or publish a raw Windows exe or Windows zip.

### macOS signing order

1. Export the macOS `.app` into a zip/staging directory.
2. Finish every bundle modification, then clear stale extended attributes.
3. Sign the final `.app` **last**. Use `MACOS_SIGN_IDENTITY` for Developer ID
   Application signing with hardened runtime and timestamp. If no identity is
   available, use a final ad-hoc signature and state the Gatekeeper limitation.
4. Run `codesign --verify --deep --strict --verbose=4` on the staged app.
5. Build a DMG containing the app, an `Applications` symlink, and the arrow
   background supplied by `tools/create_macos_dmg.sh`.
6. Mount the final DMG and repeat strict signature verification on the contained
   app; verify the Applications link and `hdiutil verify`.
7. When `MACOS_NOTARY_PROFILE` and a Developer ID identity are available, run
   `notarytool submit --wait`, then `stapler staple` and `stapler validate`.
   Never claim notarization when credentials or Developer ID are absent.

### Windows verification

Build the temporary embedded-PCK exe, wrap it with NSIS, verify the exact NSIS
CRC algorithm, secret-scan staged payloads, and publish only setup.exe.

## 6. Integrity and publication

1. Verify `shasum -a 256 -c SHA256SUMS.txt`, the DMG mount/layout/signature, app
   bundle version, and NSIS CRC. Record the lack of native Windows runtime QA if
   no Windows machine is available.
2. Dry-run Telegram publication first:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/telegram_publish.py \
  --version X.Y.Z --dry-run
```

3. Upload the DMG, Windows setup.exe, and SHA file to Telegram only when the
   channel/session config resolves. Then publish the player-facing news and
   Telegram download link to Discord:

```bash
python3 skills/codex/fantasydisk-release-director/scripts/release_publish.py \
  --version X.Y.Z
```

Keep webhook URLs, Telegram credentials, session files, signing identities, and
notary profiles in ignored local config/keychain state. Never print or commit
secrets.

## 7. Finish

Update `docs/design/current_game_state.md` and release/versioning docs. Record
the exact SHA/tag, push state, gates, artifacts, hashes, signing identity type,
notarization result, publication result, residual risks, and `Disk cleanup:` in
Multica. Move implementation to `in_review`; set `done` only after independent
QA says `QA verdict: PASSED`.
