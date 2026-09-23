# FAN-3965 — early publication capability preflight (2026-09-23)

Read-only preflight for the 0.3.1 public binary release. Owner: Claude Dev Fable
(`1cba3f6b-908a-4ba0-9baa-a849880b5682`). Nothing was tagged, drafted, uploaded,
sent or changed on GitHub, Telegram, Discord, the keychain or any config. No
token, API hash, session, webhook, proof or private inventory value was read
into a log or printed. Companion files: `github-readback-2026-09-23.json`
(sanitized API snapshot) and `dry-run-probe-v0.3.0-2026-09-23.log`.

This stage does **not** replace the final gates: exact FAN-3962 source tag,
FAN-3963 retained package, FAN-3964 native Windows PASS, `local_release.py
verify` on v0.3.1, byte checks and the two owner-attested writer proofs remain
mandatory at publication time.

## 1. GitHub distribution state — refreshed 2026-09-23T14:56:53Z

Astra's 10:19 UTC readback is confirmed unchanged; nothing older was resurrected.

| Check | Result |
| --- | --- |
| Publisher login | `FomaBy`, type User, admin on `FomaBy/FantasyDisk-Releases` |
| Repository owner | `FomaBy` (User), public, default branch `main` |
| Collaborators (`affiliation=all`, one page) | only `FomaBy` (admin) |
| Pending invitations / deploy keys | 0 / 0 |
| Immutable releases | `enabled=true` (`enforced_by_owner=false`) |
| Tag ruleset 20810935 | active, target tag, include `refs/tags/v*`, exclude none, bypass actors none, rules `update` + `deletion` |
| Default-branch tree (recursive, not truncated) | `README.md` only |
| Public releases | only `v0.2.4` (2026-07-16, `immutable=false`); **no public v0.3.0 exists** |
| `v0.3.1` tag | absent in source and distribution (HTTP 404) |

Consequence: v0.3.1 will be the first release after v0.2.4 and the first
GitHub-immutable one. `latest/download` currently still points at v0.2.4.

## 2. Complete GitHub App writer inventory — NOT available through supported operator access

- The active `gh` login is a classic OAuth token (scopes `gist, read:org, repo,
  workflow`). `GET /user/installations` returns HTTP 403 for it; that endpoint
  accepts only GitHub App user-to-server tokens and, even then, lists only the
  installations visible to that one App. `GET /repos/…/installation` needs an
  App JWT (HTTP 401). There is no REST/GraphQL call that enumerates every App
  installed on a personal account from operator credentials.
- The maintained publisher (`github_release_publish.py`) therefore refuses to
  publish without two `--writer-inventory-proof` JSON files exported by the
  owner from **GitHub → Settings → Applications → Installed GitHub Apps** (schema
  in `skills/codex/fantasydisk-release-director/SKILL.md`, "Owner-attested App
  writer proof"). Each proof expires after two minutes; the second must be
  observed after the publisher reports "Draft assets verified" and pauses on
  `input()`. This makes the GitHub publication step an **owner-attended,
  interactive terminal operation**; an unattended agent run cannot satisfy it
  and a pre-created or replayed second proof is rejected by design.
- ChatGPT Codex Connector: the 8 September claim that it holds write access was
  not re-verified here and cannot be verified from the API. It only matters if
  the App covers `FomaBy/FantasyDisk-Releases` (`repository_selection=all`, or
  `selected` including it) **and** holds `contents` or `administration` write.
  In that case the publisher fails closed and the owner must first narrow the
  App's repository selection or permissions in Settings → Applications; the
  publisher never changes App settings itself.

## 3. Telegram and Discord delivery capability (no secrets read)

Durable config `~/.config/fantasydisk/release.json` exists with `local_root`,
`macos_app`, `godot_projects_file`; `local_root` is the operator's checkout on
`dev` (HEAD `e59886c58a85cfdb129fcd84f6887997007afc62`, dirty operator WIP —
untouched). All publishers read their gitignored config from
`FANTASYDISK_REPO` (or cwd), so the real run must set
`FANTASYDISK_REPO=<local_root>`; an ephemeral worktree has no config.

| Capability | State | Evidence |
| --- | --- | --- |
| Telethon | installed 1.43.2 on `/usr/bin/python3` 3.9.6 | import OK |
| `release_webhook.cfg` `[telegram]` | present in `<local_root>`, keys `api_id`, `api_hash`, `session` all non-empty | key names only |
| Telegram session `fantasydisk_release.session` | present, contains one authorization row, last modified 2026-08-16T09:41Z | read-only SQLite row count |
| Telegram channel `release_tg.cfg` | present with `chat` and `download_url`; dry-run resolved the player link | dry-run |
| Session liveness with Telegram servers | **unproven** (provable only by connecting/sending; out of this stage). If revoked in Settings → Devices, re-login needs the owner's phone code | — |
| Discord `release_webhook.cfg` `[release] discord_webhook_url` | **MISSING** — the file has only the `[telegram]` section | configparser sections |
| Discord dry-run | passes, because dry-run never reads the webhook; the real `release_publish.py --version 0.3.1` would exit with a missing-section error **after** GitHub and Telegram were already published | script read |
| `github_release_verify.py` | unauthenticated (plain `urllib` to api.github.com / release downloads) | script read |

Tooling-chain probe (read-only, retained signed v0.3.0): `local_release.py
verify` → verified (candidate commit `fd9fd1a4…`, tree `0c887fb3…`, channel
`signed`, installed app verified) in ~38 s; GitHub, Telegram and Discord
`--dry-run` all exit 0 with the expected six/four/three asset lists. See the
probe log. This proves the chain, not the v0.3.1 package.

macOS trust channel (FAN-3963's gate, noted for ordering): one `Developer ID
Application` identity is installed; no notarytool credential item was found in
the default keychain search list (`security find-generic-password -s
com.apple.gke.notary.tool` → exit 44). The retained signed v0.3.0 package proves
notarization worked around 2026-09-07; 0.3.1 capability is still unproven and an
unsigned downgrade needs its own explicit owner decision.

## 4. Exact remaining operator-only operations

1. **Owner-attested writer proofs (GitHub, at publication time).** Export the
   complete Settings → Applications inventory twice into the proof schema: the
   first ≤2 min before starting `github_release_publish.py --version 0.3.1`, the
   second when the publisher pauses after draft-asset verification, then press
   Enter. Keep them in a `chmod 700` temp dir and `rm -rf` afterwards; never in
   git/Multica/logs. If any App (including the ChatGPT Codex Connector) shows
   `contents` or `administration` write reaching `FomaBy/FantasyDisk-Releases`,
   narrow it in Settings → Applications first.
2. **Discord webhook.** Add `[release]` / `discord_webhook_url` to the
   gitignored `<local_root>/release_webhook.cfg` before publication day.
3. **Telegram session liveness.** Confirm the userbot session is still listed
   in Telegram → Settings → Devices; otherwise re-login (phone code) before the
   send. No `--test` send was made in this stage.
4. (FAN-3963, not this card) Provide `MACOS_SIGN_IDENTITY` and a working
   `MACOS_NOTARY_PROFILE` for the signed 0.3.1 build, or record an explicit
   unsigned decision.

No other operator action is required for the GitHub trust gates: immutable
releases, the `v*` ruleset, sole collaborator, zero invitations and zero deploy
keys are already in the required state.

## 5. Safe final publication order (final stage of this card)

Preconditions (all must be terminal before step 1): FAN-3962 `v0.3.1` tag on the
exact approved commit; FAN-3963 `<local_root>/releases/v0.3.1` materialized on
the signed channel with candidate provenance equal to the tag; FAN-3964 native
Windows PASS on the exact SHA-256 of the retained `FantasyDisk-0.3.1-windows-setup.exe`;
recorded owner scope (Sergey Fomin, 2026-09-23T10:04Z) and the default signed
macOS decision; FAN-3866 / FAN-3905 AC7 release applicability recorded at
source promotion.

1. `FANTASYDISK_REPO=<local_root> python3 skills/…/local_release.py verify --version 0.3.1 --repo-root <local_root>`
   (signed). Then from the returned path: `shasum -a 256 -c SHA256SUMS.txt`,
   `update-manifest.json` name/size/SHA/URL vs both installers, DMG mount and
   `codesign`/`stapler`/`spctl`, NSIS CRC, poster `fantasydisk_031_announcement.png`,
   `CHANGELOG-0.3.1.md`. Any mismatch stops here.
2. Re-run the section 1 readbacks (immutable releases, ruleset, collaborators,
   invitations, keys, README-only tree, no `v0.3.1` tag/release). Any drift stops.
3. Operator-only items 2 and 3 above confirmed (section names only; no values).
4. Dry-runs with the exact package, in this order:
   `github_release_publish.py --version 0.3.1 --dry-run`,
   `telegram_publish.py --version 0.3.1 --dry-run`,
   `release_publish.py --version 0.3.1 --dry-run`.
5. GitHub publication, owner-attended: first proof → run publisher with
   `FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1` and both `--writer-inventory-proof`
   paths. The publisher itself performs: safe-tree check → immutable-release and
   ruleset asserts → sole-writer asserts + first proof → atomic tag claim at the
   distribution default-branch commit → `gh release create --draft --verify-tag`
   → byte-exact draft asset verification → pause → second proof (fresh, newer
   than the draft check) → sole-writer re-assert → tag re-verify → asset
   re-verify → `--draft=false --latest=false` → public verify + GitHub
   immutability → `--latest`. On any failure follow the skill's burned-version
   states; never delete, force or reuse a tag/release.
6. `github_release_verify.py --version 0.3.1 --local-release <local_root>/releases/v0.3.1`
   without credentials (public identity, immutable tag, bytes, update URLs).
7. `telegram_publish.py --version 0.3.1` (poster, DMG, Windows Setup,
   SHA256SUMS); record message links and verify presence in the channel.
8. `release_publish.py --version 0.3.1` (Discord announcement with the Telegram
   link and the public GitHub release URL); record the response.
9. Record external URLs, hashes, timestamps and any partial failure under
   `evidence/FAN-3965/**`; `rm -rf "$PROOF_DIR"`; hand the card to independent
   QA of the published state (no PASS from a draft or a missing channel).

## 6. Non-actions

No `v0.3.1` tag, draft, release, upload, Telegram/Discord message, `--test`
message, credential lookup, keychain read, settings change, bypass, QA PASS or
financial action. No file outside `evidence/FAN-3965/preflight/**` was written.
