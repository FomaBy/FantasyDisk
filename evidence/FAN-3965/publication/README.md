# FAN-3965 — 0.3.1 publication evidence (2026-09-28 / 2026-09-29)

Publisher agent: Claude Dev Fable (`1cba3f6b-908a-4ba0-9baa-a849880b5682`), macOS.
Source tag `v0.3.1` = `8c2cbdf89f07f8d63417303fb35387a29250b446` → commit
`f4d05fea91a5ce8b3fb858a5035df1fe54236369`, tree `e659e92afdd2dad1a3aec8ca7bce49cfac250ec6`.
Publisher blob at the tag: `2fa675358de24db8540e916d7011c85392652e11` (reviewed FAN-3969).
No secret value, proof, token, webhook or session content is in this directory.

## Exact bytes (retained `/Users/sergeyfomin/FantasyDisk/releases/v0.3.1`)

| File | SHA-256 | Size |
| --- | --- | --- |
| FantasyDisk-0.3.1-windows-setup.exe | `db99a9298a6acbdc545f8545e66b8455c8798351cfc4ba96147af490180c67de` | 438 427 863 |
| FantasyDisk-0.3.1-macos.dmg | `f391b86f3bd26494723264ad017f8991aa8fd3cb920d60d08b0506b6ac6760ca` | 462 967 900 |
| SHA256SUMS.txt | `ac2e0424ecf26e4de7ba40aef96481a2175387ad0096abb996d702fb7620cbe9` | 196 |
| update-manifest.json | `6fb982a86c1fdbcbbdb6065b5900404e64cdcf2063ec596658ff818a6ca009bf` | 793 |
| CHANGELOG-0.3.1.md | `9f3b1c6d0fcfe92c908ec12f74cf74308d8f3f52555fc0b743e7074918c89975` | 5 901 |
| fantasydisk_031_announcement.png | `6d0267c7f56adae7b2cf9c2b6a19b91c180d68d8cd4b21b293331f3e77c5e5a7` | 95 930 |

`shasum -a 256 -c SHA256SUMS.txt` OK on 2026-09-28 and 2026-09-29;
`local_release.py verify --macos-channel signed` → `verified`, `tag_commit f4d05fea…`
(`local-release-verify-2026-09-28.json`; repeated 2026-09-29 15:0xZ with the same result).

## Timeline (UTC)

### 2026-09-28 — run 1 (window expired, nothing claimed)

- 13:32 read-only readback (`github-readback-2026-09-28T13-32Z.json`): publisher `FomaBy` (User, admin);
  collaborators only `FomaBy`; invitations 0; deploy keys 0; immutable releases `enabled=true`;
  ruleset `20810935` active on `refs/tags/v*`, no bypass, rules update+deletion; releases only `v0.2.4`;
  distribution tag/release `v0.3.1` → 404; default tree `README.md` only.
- Task worktree of tag `v0.3.1` clean; temporary 0600 `release_webhook.cfg` (gitignored) built from
  `[telegram]` (owner secrets) + `[release]` (owner mirror); Discord webhook read-only `GET` → 200;
  Telegram session authorized, channel `FantasyAgents` resolved (no message sent);
  GitHub / Telegram / Discord `--dry-run` exit 0.
- 13:39 owner instruction comment `01a0e83d-b179-74d5-994a-56359131ad69` posted; bounded wait until 14:39:31
  with no tag, draft, release or reply. Temporary config deleted; `pipeline_status=waiting_on_owner_publication_window`.

### 2026-09-29 — owner-attended GitHub step and run 2

- 14:56:23 owner wrote the first proof and started the reviewed publisher from the task worktree
  (PM readback 14:57–14:59: tag `v0.3.1` claimed at `162ac9f886a7c4deaa05d6c70c23779f406c7080`,
  draft id `399255752`, six assets uploaded byte-exact by 14:59:30).
- The publisher run ended without the second proof (no process by 15:03; no `writer-proof-second.json`).
  Agent readback 15:03 (`github-readback-2026-09-29T15-03Z.json`): draft with all six assets, digests exact,
  not public; trust settings unchanged. Agent made no GitHub write in either run.
- 15:08 agent state report `01a0edb6-274b-7959-b36c-b1daad4a1b18` with options A (publish the verified draft
  manually, owner decision) / B (burn the version).
- 15:18:03 the owner published the draft manually (`gh release edit … --draft=false --prerelease=false --latest=false`,
  re-verified assets/immutability/tag, then `--latest`); recorded by the owner in `01a0edc1-8880-7417-bc88-af3aeebd1fd7`
  and confirmed by the PM in `01a0edc2-79fd-7761-a267-3861be7f0b70` (`owner_publication_decision`, limited
  exception to the burned-version rule). Owner-side Settings → Applications check before the public edit:
  two installations, neither with write reach to `FomaBy/FantasyDisk-Releases`.
- 15:19 agent readback (`github-public-release-2026-09-29T15-19Z.json`): release `399255752`, `draft=false`,
  `prerelease=false`, `immutable=true`, `published_at=2026-09-29T15:18:03Z`, author `FomaBy`, latest = `v0.3.1`,
  tag `162ac9f8…`, six assets with the exact digests above.
- 15:19–15:20 `github_release_verify.py --version 0.3.1 --local-release …/releases/v0.3.1` → exit 0, `ok: true`
  (`github-release-verify-2026-09-29.json`): both installers downloaded without credentials via
  `releases/latest/download/update-manifest.json`, SHA-256 and sizes equal to the retained bytes.
- 15:20:44–15:28:40 `telegram_publish.py --version 0.3.1` → exit 0. Channel `FantasyAgents` (`-1004452439686`),
  player link `https://t.me/+ByVTScmUaJMzZDJi`. Delivered (`telegram-readback-2026-09-29.txt`):
  album messages 146 (DMG 462 967 900 B, caption with the link), 147 (Windows Setup 438 427 863 B),
  148 (SHA256SUMS.txt 196 B) at 15:28:40. **Poster message 145** (caption «FantasyDisk v0.3.1 — проверенные сборки
  macOS + Windows.») was sent first and **deleted by FomaBy at 15:22:16** (channel admin log). The agent did not
  resend it: owner action, owner decision.
- 15:29:48 `release_publish.py --version 0.3.1` (Discord) stopped before sending:
  `local_release.py verify` failed with `macOS app is not installed: /Applications/FantasyDisk.app`
  (`discord-attempt-2026-09-29.log`). The owner had removed the installed app and mounted the release DMG
  (`/Volumes/FantasyDisk 0.3.1`). Retried every 45 s until 15:40:46; app still absent. **No Discord message was sent.**
- 15:26:59 comment `01a0edc6-bb97-767a-8ea5-0c9ddb59d726`: owner observed missing new ultimate animations in the
  published 0.3.1 DMG; read-only diagnosis names two export-path defects (`docs/*` manifests excluded from the PCK;
  `.gd` discovery vs `.gdc`/`.remap` in export). PM disposition on further distribution was requested; the PM run
  could not start (`/Applications/Multica 2.app` binary missing, see `01a0edc6-bf07-75be-8b26-9ae06b4d1a29`).
- Agent decision: **Discord announcement held** — its text advertises the new ultimate presentations that the owner
  reports missing, the verify guard blocks it anyway, and the PM's distribution disposition is pending.
  Temporary config deleted again; worktree clean; owner files and operator checkout untouched.

## Channel state at hand-off (2026-09-29 15:43Z)

| Channel | State |
| --- | --- |
| GitHub | public, immutable, latest: https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.3.1 — verified byte-exact |
| Telegram | DMG, Windows Setup, SHA256SUMS delivered (messages 146–148); poster deleted by the owner |
| Discord | **not sent** (held; see above) |

Acceptance 4 (Discord + independent verification) is therefore not complete; `candidate_ready_for_review` stays false
until the PM/owner disposition on the reported defect and the Discord announcement.

## Non-actions

No tag, draft, release, asset or GitHub setting was created, edited, published or deleted by the agent in either run.
No Discord message was sent. No file outside `evidence/FAN-3965/publication/**` was committed. No secret value was
printed, logged or committed; the temporary 0600 config existed only in the gitignored worktree root during each run.
