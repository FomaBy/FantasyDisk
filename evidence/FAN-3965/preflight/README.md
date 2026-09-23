# FAN-3965 — early publication capability preflight (2026-09-23, reworked 2026-09-24)

Read-only preflight for the 0.3.1 public binary release. Owner: Claude Dev Fable
(`1cba3f6b-908a-4ba0-9baa-a849880b5682`). Nothing was tagged, drafted, uploaded,
sent or changed on GitHub, Telegram, Discord, the keychain or any config. No
token, API hash, session key, webhook, proof or private inventory **value** was
read into a log, printed or used. Companion files:
`github-readback-2026-09-23.json` (sanitized API snapshot),
`dry-run-probe-v0.3.0-2026-09-23.log` (tooling-chain probe) and
`qa-finding-repro-2026-09-24.log` (offline reproduction of the first-proof
timing defect found by independent QA).

Revision history: candidate `75e6785e…` (2026-09-23) was FAILED by independent
qa_high (run `01a0d041-b827-7f0e-aaaf-9bfb034f4b9d`, comment
`01a0d04a-7c87-743d-aafd-1c18e868754b`) because the safe order missed the
first-proof 120-second window that spans the tag claim and uploads, the real
TTY / `FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1` requirement, and used imprecise
"no keychain read" wording. This revision corrects sections 3–6 only; the
readback facts in sections 1–2 are unchanged and were independently re-confirmed
by QA at 2026-09-23T21:56:54Z.

This stage does **not** replace the final gates: exact FAN-3962 source tag,
FAN-3963 retained package, FAN-3964 native Windows PASS, `local_release.py
verify` on v0.3.1, byte checks, the two owner-attested writer proofs and the
publisher-code correction in section 4 remain mandatory at publication time.

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
  writer proof"). Each proof is accepted only while ≤120 s old; the second must
  be observed after the publisher's draft-asset check. This makes the GitHub
  publication step an **owner-attended, interactive terminal operation**; an
  unattended agent run cannot satisfy it and a pre-created or replayed second
  proof is rejected by design. The timing of the **first** proof is a separate
  unresolved gate, see section 4.
- ChatGPT Codex Connector: the 8 September claim that it holds write access was
  not re-verified here and cannot be verified from the API. It only matters if
  the App covers `FomaBy/FantasyDisk-Releases` (`repository_selection=all`, or
  `selected` including it) **and** holds `contents` or `administration` write.
  In that case the publisher fails closed and the owner must first narrow the
  App's repository selection or permissions in Settings → Applications; the
  publisher never changes App settings itself.
- Residual (noted by QA, not closable by an App inventory): OAuth apps and
  personal access tokens with `repo` scope act **as** FomaBy and never appear in
  the App inventory. The tag ruleset and the byte-exact draft re-verification
  narrow that vector but do not close it; it is an owner account-hygiene item.

## 3. Telegram and Discord delivery capability (no secret values read)

Durable config `~/.config/fantasydisk/release.json` exists with `local_root`,
`macos_app`, `godot_projects_file`; `local_root` is the operator's checkout on
`dev` (HEAD `e59886c58a85cfdb129fcd84f6887997007afc62`, dirty operator WIP —
untouched). All publishers read their gitignored config from
`FANTASYDISK_REPO` (or cwd), so the real run must set
`FANTASYDISK_REPO=<local_root>`; an ephemeral worktree has no config.

What was actually read, precisely: config **section and key names** and
non-emptiness (never values); the Telegram session SQLite file opened
read-only to **count** rows with a non-empty authorization key (no key bytes
were read into output); Keychain **metadata** via `security find-identity -v -p
codesigning` (identity count only) and `security find-generic-password -s
com.apple.gke.notary.tool` (exit code only, no `-w`, no attributes printed).
No credential value was read, printed or used, and no Apple, Telegram or
Discord service was contacted.

| Capability | State | Evidence |
| --- | --- | --- |
| Telethon | installed 1.43.2 on `/usr/bin/python3` 3.9.6 | import OK |
| `release_webhook.cfg` `[telegram]` | present in `<local_root>`, keys `api_id`, `api_hash`, `session` all non-empty | key names only |
| Telegram session `fantasydisk_release.session` | present, one authorization row, last modified 2026-08-16T09:41Z | read-only SQLite row count |
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
the default keychain search list (exit 44). The retained signed v0.3.0 package
proves notarization worked around 2026-09-07; 0.3.1 capability is still
unproven and an unsigned downgrade needs its own explicit owner decision.

## 4. Exact remaining gates and operator-only operations

### 4.0 UNRESOLVED PRE-CLAIM GATE — first-proof 120-second window (QA finding, reproduced)

`github_release_publish.py` (blob `9261e3e4…`, identical on `origin/dev`
`e33bded4…` and in the operator checkout) validates the **first** owner
App-inventory proof twice: once before any side effect (`publish()` →
`_assert_owner_attested_writer_proof`, and `assert_sole_publisher_write_access`)
and **again after the owner presses Enter**, through
`assert_owner_attested_writer_inventory(first, second)` (`:458`, `:474`), which
re-applies the `WRITER_PROOF_MAX_AGE = 2 min` check (`:422`) to the first proof
**from its already loaded in-memory bytes**. Editing the first proof file during
the pause has no effect.

So the 120-second window from the first proof's `observed_at` must span, in
sequence: publisher start and pre-claim asserts → **atomic `v0.3.1` tag claim**
→ `gh release create --draft` with **both installer uploads (~840 MB: v0.3.0
DMG 432 476 946 B + Setup 408 114 374 B; 0.3.1 will be similar)** → byte-exact
draft verification → the owner's Settings → Applications export of the second
proof → Enter → first-proof recheck. If it is exceeded, the publisher raises
`owner attestation is stale …` **after** the tag is claimed and the draft with
assets exists (no public edit). Per `SKILL.md` §7 that is a burned version: the
`v*` ruleset forbids deleting the tag, so 0.3.1 would have to be rebuilt,
re-verified and re-published as 0.3.1.1. Offline reproduction with the
repository's stateful mock harness (`qa-finding-repro-2026-09-24.log`):
90 s total → published; 130 s → stale after claim; 285 s → stale after claim.

Status: **unresolved gate before the first publication side effect.** It is not
closable inside this preflight write set (publisher code is out of scope here).
PM disposition (2026-09-23T22:47Z): a **separately reviewed publisher-code
correction** is required so that the first proof's freshness is checked only
**before the tag claim** and the **second** proof alone closes the pre-public
boundary (fresh, newer than the draft check, sole-writer re-assert, byte-exact
re-verify). A timed upload rehearsal (~840 MB in ≤90 s needs a sustained
≈75 Mbit/s or better upstream, plus the owner's export time) is **not** an
acceptable substitute: network and owner-export timing are variable and a
failure burns the immutable version. The correction must be merged to `dev`,
independently reviewed, and present in the checkout used for publication
before any `v0.3.1` claim.

### 4.1 Real TTY and `FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1` on the real command

The pause that lets the owner export the second proof happens only when **all**
of these hold (`:892–:898`): the second proof was given as a file path,
`FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1` is set on the **real publish
command**, and `sys.stdin.isatty()` is true. Otherwise the publisher does not
pause, loads the second proof file immediately, and rejects it (it is older than
the draft check, or a replay) — again **after** the tag claim, burning the
version. Consequences:

- Run the real publication in a real interactive terminal, by or beside the
  owner. A Multica agent run has no TTY and cannot perform it.
- `SKILL.md` §7 puts `FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1` only on the
  `--dry-run` example line. Follow this README, not that snippet: the variable
  is required on the non-dry-run command.

### 4.2 Operator-only operations

1. **Owner-attested writer proofs (GitHub, at publication time).** Export the
   complete Settings → Applications inventory twice into the proof schema:
   the first immediately before starting the publisher (after the section 4.0
   correction, its freshness is consumed before the claim), the second when the
   publisher pauses after draft-asset verification, then press Enter. Keep them
   in a `chmod 700` temp dir and `rm -rf` afterwards; never in git/Multica/logs.
   If any App (including the ChatGPT Codex Connector) shows `contents` or
   `administration` write reaching `FomaBy/FantasyDisk-Releases`, narrow it in
   Settings → Applications first.
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
**the section 4.0 publisher-code correction independently reviewed, on `dev`
and in the publishing checkout**; recorded owner scope (Sergey Fomin,
2026-09-23T10:04Z) and the default signed macOS decision; FAN-3866 / FAN-3905
AC7 release applicability recorded at source promotion.

1. `FANTASYDISK_REPO=<local_root> python3 skills/…/local_release.py verify --version 0.3.1 --repo-root <local_root>`
   (signed). Then from the returned path: `shasum -a 256 -c SHA256SUMS.txt`,
   `update-manifest.json` name/size/SHA/URL vs both installers, DMG mount and
   `codesign`/`stapler`/`spctl`, NSIS CRC, poster `fantasydisk_031_announcement.png`,
   `CHANGELOG-0.3.1.md`. Any mismatch stops here.
2. Re-run the section 1 readbacks (immutable releases, ruleset, collaborators,
   invitations, keys, README-only tree, no `v0.3.1` tag/release). Any drift stops.
3. Operator-only items 4.2/2 and 4.2/3 confirmed (section names only; no values).
4. Dry-runs with the exact package, in this order, from a real terminal:
   `github_release_publish.py --version 0.3.1 --dry-run`,
   `telegram_publish.py --version 0.3.1 --dry-run`,
   `release_publish.py --version 0.3.1 --dry-run`.
   Confirm the publishing checkout contains the corrected publisher (section 4.0).
5. GitHub publication, owner-attended, in a real interactive TTY:
   `PROOF_DIR=$(mktemp -d); chmod 700 "$PROOF_DIR"`; owner exports the first
   proof; then **within its window** run
   `FANTASYDISK_INTERACTIVE_PROOF_REFRESH=1 FANTASYDISK_REPO=<local_root> python3 skills/…/github_release_publish.py --version 0.3.1 --writer-inventory-proof "$PROOF_DIR/writer-proof-first.json" --writer-inventory-proof "$PROOF_DIR/writer-proof-second.json"`.
   The corrected publisher performs: safe-tree check → immutable-release and
   ruleset asserts → sole-writer asserts + first proof (freshness consumed
   here, before any side effect) → atomic tag claim at the distribution
   default-branch commit → `gh release create --draft --verify-tag` with all
   six assets → byte-exact draft asset verification → **pause** → owner exports
   the second proof and presses Enter → second proof validated (≤120 s old,
   newer than the draft check, not a replay) → sole-writer re-assert → tag
   re-verify → asset re-verify → `--draft=false --latest=false` → public verify
   + GitHub immutability → `--latest`. On any failure follow the skill's
   burned-version states; never delete, force or reuse a tag/release.
   **Do not run this step with the uncorrected publisher**: with it, the first
   proof must also survive the claim, both uploads, verification and the second
   export (section 4.0), and a failure burns 0.3.1.
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
message, connection to Apple/Telegram/Discord, credential value read or use,
settings change, bypass, QA PASS or financial action. Reads were limited to
GitHub API readbacks with the existing `gh` login, config section/key names,
a read-only session row count, and Keychain metadata (identity count and one
presence exit code), as itemized in section 3. No publisher code was changed.
No file outside `evidence/FAN-3965/preflight/**` was written.
