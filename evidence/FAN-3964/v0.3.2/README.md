# FAN-3964 — native Windows Setup verification of FantasyDisk **0.3.2** (developer evidence stage)

Host FomaPC, 2026-09-26 20:59–21:24 UTC. Author: Windows Claude Fable 5.1 (`78cc066a`).
Developer-run evidence for the independent Windows `qa_high` review. **Not a Windows PASS.**
The 0.3.1 stage (FAILED by the independent review) is kept unchanged in the parent directory as history.

## Exact inputs (AC1/AC2)

| Item | Value |
|---|---|
| Tag `v0.3.2` | object `90279733311632aec88a70317e18afc67518e6d2` → commit `36340c473772781edafffb61ff1d8cc7caa42024`, tree `1a361d628d8a4160a6f44993f2ed954c50593341` (`git rev-parse` after `git fetch --tags`; `dev` = the same commit) |
| Installer | `FantasyDisk-0.3.2-windows-setup.exe`, 439,647,264 bytes, SHA-256 `8b7b3e7d1ce3ce6d935e50ff7b16962606772d416e5957e4847eceb305c8131f` |
| Transfer | 9 parts + `PARTS.sha256` (`48a5997b…`), `SHA256SUMS.txt` (`00d198dc…`), `update-manifest.json` (`1bbb0c9b…`) from comment `01a0df78-34ac-767c-83c5-666430b7e315` via `multica attachment download`; every part matched, binary concatenation aa→ai matched the whole-file pin (`host-gate/package_verify.txt`). The setup hash was re-checked immediately before every installer run. The 0.3.1 attachments were not used. |

## Host gate (`host-gate/host_gate.txt`, 20:59:58Z; presence in `host-gate/presence_at_start.txt`)

- Daemon `019fe1f0-73fb-79ac-b8f2-7acf92c4c42c` running (PID 19868 after a restart, uptime 4 min at start, 1 running task); task context binds agent `78cc066a…` to issue `01a0cda1…`.
- Same hardware/OS as the 0.3.1 stage (Windows 11 Pro 10.0.22000, i5-14600KF, RTX 4070 Ti SUPER, 32 GB, two 2560×1440 displays); Godot 4.7.stable found; the installed game reports engine `4.7.stable.official.5b4e0cb0f`.
- Free bytes at start: C: 47,822,069,760, D: 259,919,212,544; placement: the task workdir on C: (peak use ≈ 1.9 GB). User is Administrator, token not elevated, UAC elevates without prompting; installers ran unattended via `-Verb RunAs`.
- No game/installer/lock processes; exclusive-open probe on the existing install files succeeded; Defender real-time protection off.
- **A person was actively using FomaPC for the whole stage** (last input 0 s ago at every check; Chrome, Telegram, Discord, later a full-screen game in the foreground). Game launches were performed as in the earlier stages; **no OS-level keystrokes were sent** (`launch/keyboard_smoke_not_executed.txt`).

## Protected state, isolation and rollback (`preservation_plan.md`, `preimage/`, `uninstall/`, `rollback/`)

Fresh preimage 21:03Z: 0.3.0 install hashes (`c9937dbb…`, `b00f7398…`), HKLM key export (byte-identical to the 0.3.1-stage export), byte copies of Start Menu `FantasyDisk.lnk` (`477de086…`), `Uninstall.lnk` (`db365c58…`, 1,038 bytes as left by the 0.3.1 review) and Desktop `FantasyDisk.lnk` (`2303910…`), full copy of the 530-file Godot user-data tree. Isolation as before: `/S /D=<workdir>\install_target\FantasyDisk` and an `override.cfg` redirecting `user://` to `%APPDATA%\FantasyDisk-FAN3964-test`.

Rollback after each uninstall: elevated `reg import`, copies of all three shortcuts. Final proofs (`rollback/03_registry_reexport_diff.txt`, `rollback/userdata_integrity_final*.txt`): re-exported key byte-identical to the preimage after both cycles; all three shortcut hashes equal the preimage; `C:\Program Files\FantasyDisk` hashes unchanged; real user data 530/530 identical after every launch and at the end. The line `registry matches preimage: False` in the rollback logs is a string-compare artifact of the script; the byte-identical `.reg` diff is authoritative.

## Install / upgrade / reinstall / uninstall (AC3)

| Step | Result |
|---|---|
| Install #1 (`/S /D=`, elevated), `install/01_install1.txt` | exit 0, 5.8 s. `FantasyDisk.exe` 540,725,856 B, SHA-256 `7faca322bfee2628af1ab15eaa4c14e1c4e548c7836416d32b99e3aed3d931c7`, FileVersion 0.3.2.0 / ProductVersion 0.3.2; `Uninstall.exe` 39,938 B `86b4ea59…`; HKLM key DisplayVersion 0.3.2 → target; Start Menu + Desktop shortcuts → target. |
| Upgrade path, `install/03_*`, `install/04_*`, `uninstall/00_*` | A second isolated folder seeded with byte copies of the user's 0.3.0 `FantasyDisk.exe` + `Uninstall.exe`; installing 0.3.2 with `/D=` there: exit 0, 4.8 s, both files replaced by the 0.3.2 bytes (same hashes as above), registry/shortcuts → that folder. Silent uninstall from it: exit 0, files, key and shortcuts removed. The real `C:\Program Files\FantasyDisk` was never touched. |
| Reinstall over an existing 0.3.2 install, `install/02a_*`, `install/02b_*` | fresh install exit 0 (6.0 s), reinstall over it exit 0 (6.0 s), identical exe hash, `override.cfg` untouched. (A first reinstall attempt at 21:21Z left an empty log and was redone; `install/02_reinstall_attempt1_note.txt`.) |
| Silent uninstall (`/S _?=<target>`), ×2, `uninstall/01_*`, `uninstall/02_*` | exit 0, ≈1.1 s each; removes the exe, the three shortcuts, the Start Menu folder and the HKLM key; leaves `Uninstall.exe` (run in place with `_?=`) and the test-only `override.cfg`, as NSIS does. |

## Version, content, manifest, saves (AC3)

- Version identity: exe VersionInfo 0.3.2.0 / 0.3.2; engine stdout header identical in every launch; `stderr` empty in every launch.
- Content identity and PCK cleanliness (`launch/content_identity_pck.txt`, `launch/pck_paths_full.txt`): embedded PCK format 4, engine 4.7.0, **45,648 packed files** (0.3.1: 47,137); top-level prefixes are only `.godot`, `assets`, `scripts`, `scenes`, `data`, `project.binary`, `icon.svg(.import)`; **0 entries under `evidence/`, `skills/`, `docs/`, `tools/`, `tests/`, `releases/`**, no `before_/after_berserk*`; `data/ultimates/classes/` = **17 classes × 3 = 51 profiles** (tag: 51), 102 files under `scenes/vfx/ultimates/`, 138 under `scripts/ultimates/classes/`.
- Update manifest (`launch/update_manifest_check.txt`): 15/15 static checks PASS against the client's `validate_manifest` rules (schema 1, version 0.3.2, min 0.2.2, release URL, trusted download URLs, Windows name/size/SHA-256 equal to the reassembled installer, SHA256SUMS agreement for both assets). The live startup check targets `releases/latest/download/…`, which cannot serve v0.3.2 before publication; no error output was produced.
- Save compatibility (`launch/launchF_savecompat*.txt`): the real 0.3.0 user data seeded into the isolated profile; 0.3.2 started normally (responsive at 1 s), `fantasydisk_autosave.cfg` and `fantasydisk_meta.cfg` byte-identical afterwards, `settings.cfg` gained only `ultimate_reduced_motion=false` and `ultimate_photosensitivity_safe=false`; `godot.log` holds only the engine header lines.

## Startup and performance (perf-checklist P1; `launch/coldstart_*.txt`, `launch/launchA_first.txt`, `launch/verbose_trace_analysis.txt`)

All launches used the exact installed exe; the 0.3.0 comparison used a byte copy of the user's installed exe in a task folder with its own isolated profile (never launched in place).

| Metric | 0.3.2 | 0.3.0 (same host, same harness, same minutes) | Checklist |
|---|---|---|---|
| M4 cold start — first `Project FPS` stdout line (the 0.3.1 review's method), 100 ms polling, 5 runs / 3 runs | 5.9, 5.9, 5.9, 5.8, 5.9 → **median 5.9 s** (minus-1-s convention: 4.9 s) | 5.8, 5.9, 5.8 → **median 5.8 s** (4.8 s) | parity with 0.3.0; ≤5 s green by the minus-1-s convention, 5–8 s amber by the raw value — the reviewer measures independently |
| M4 — first moment the main window answers messages (`Process.Responding`) | 2.9, 3.1, 3.2, 3.0, 3.1 → median 3.1 s; 1-s-polled harness launches: 1 s in all four | 2.9, 2.9, 3.0 → median 2.9 s | parity |
| Load trace (`--verbose`) before the first FPS line | **264 `.ctex` loads, 2 SpriteFrames**; by folder: characters 192, enemies 116, elites 42, allies 43, bosses 22; `main.gd` is the 58th log line | 0.3.1 review: 9,089 `.ctex` + 41 SpriteFrames before first frame | the FAN-3973 fix is effective in the shipped bytes |
| M1 FPS, main menu idle 60 s (`launchA_first`, before the person's game started) | avg 4243, min 3281 (59 samples) | 0.3.1-stage baseline: avg 4288, min 3593 | green |
| Memory (process counters; engine monitors not accessible in the exported build) | peak working set ≈ 359–365 MiB during load, private ≈ 435–457 MiB at the menu | peak WS ≈ 309–320 MiB, private ≈ 408–414 MiB | M2/M3 not measured |
| M5 Windows setup size | 439,647,264 B = **419.3 MiB** (0.3.1: 511.1 MiB) | 0.3.0: ≈ 389 MiB | green |
| P2/P3, gameplay smoke of 17 classes / 51 ultimates, texture-memory residency | **not executed**: sending input was unsafe (person active) | — | for the reviewer; INCONCLUSIVE if still unsafe |

Later launches (`launchF`, `launchG`, `launchV`) ran while the person's full-screen game shared the GPU; their menu FPS (≈ 320–360) is not an M1 measurement. The ≈150 s first-frame delay seen twice on 0.3.1 did not occur in any of the 13 launches of 0.3.2 (all first-responsive within 1–3 s, including the very first launch after install).

## Limitations

- No publishable screenshot: every capture of the game window region had third-party windows on top (`launch/screenshots/README.txt`).
- No gameplay/hero-select smoke, no P2/P3, no M2/M3 engine monitors (see above).
- A first cold-start series attempt (21:07–21:17Z) used a stdout reader that could not open the redirected file and timed out per run; it was aborted and rerun with the fixed reader (`launch/coldstart_aborted_first_attempt_note.txt`, `launch/coldstart_v032_aborted_attempt1.txt`).

## Files

- `host-gate/`, `preimage/`, `install/`, `launch/`, `uninstall/`, `rollback/`, `scripts/` as in the 0.3.1 stage; `scripts/coldstart.ps1` and `scripts/presence.ps1` are new.

Disk cleanup: both install targets, the 0.3.0 copy, both test user-data dirs, the installer parts and the reassembled setup were removed from the host at the end of the run.
