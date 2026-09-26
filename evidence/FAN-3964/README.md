# FAN-3964 — native Windows Setup verification of FantasyDisk 0.3.1 (developer evidence stage)

Host FomaPC, 2026-09-26 03:10–03:52 UTC. Author: Windows Claude Fable 5.1 (`78cc066a`).
This is the developer-run evidence candidate requested by the card. **It is not a Windows PASS**; the
independent `qa_high` verdict (AC4) is a separate stage by a non-author Windows reviewer.

## Exact inputs (AC1/AC2)

| Item | Value |
|---|---|
| Tag `v0.3.1` | object `676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71` → commit `448a0cc12f02eb05bc16becc69fde365021a9a17` (checked with `git rev-parse`) |
| Installer | `FantasyDisk-0.3.1-windows-setup.exe`, 535,974,634 bytes, SHA-256 `375c5290040ac349a1e75cd2e09e3ddd520216b3ddeadfab758d413fb12dafed` |
| Transfer | 11 parts + `PARTS.sha256`, `SHA256SUMS.txt`, `update-manifest.json` downloaded with `multica attachment download` from comment `01a0dba7-b3bf-7818-83fc-d42cb6f4167e`; every part hash matched, binary concatenation aa→ak matched the whole-file hash; `SHA256SUMS.txt` `a1cc64e8…`, `update-manifest.json` `a81d1149…` matched their pins (`host-gate/package_verify.txt`). The setup hash was re-checked immediately before each installer run. |

## Host gate (fresh, `host-gate/host_gate.txt`, 03:10:35Z)

- Daemon `019fe1f0-73fb-79ac-b8f2-7acf92c4c42c` (PID 20596, CLI 0.5.3, running); task context binds agent `78cc066a…` to issue `01a0cda1…`.
- Windows 11 Pro 10.0.22000, i5-14600KF (14C/20T), RTX 4070 Ti SUPER (driver 32.0.15.9649 / OpenGL "NVIDIA 596.49"), 32 GB RAM, two 2560×1440 displays, interactive session 1.
- User is a local Administrator; the task token is not elevated; UAC `ConsentPromptBehaviorAdmin=0` (elevate without prompt) — the NSIS `RequestExecutionLevel admin` installer ran unattended via `Start-Process -Verb RunAs`.
- Free bytes: C: 87,610,155,008 (pre-install snapshot 81,178,296,320), D: 309,044,523,008. Placement: the task workdir on C: (task-owned, no charge). No task-owned D: route was verified; not needed (peak use ≈ 2.2 GB).
- Godot editor on host: `Godot_v4.7-stable_win64.exe` 178,485,256 bytes, product 4.7.stable.official (not executed). The installed game reports engine `4.7.stable.official.5b4e0cb0f`.
- Processes: no `godot`, `FantasyDisk`, `msiexec`, `makensis`, `nsis` or uninstaller process; Steam and the Multica/Claude/Codex tooling were running. `handle.exe` is unavailable; lock exclusion for the two existing install files was proved by exclusive-open (`FileShare.None`) success. Microsoft Defender real-time protection is **off** on this host (`Get-MpComputerStatus`).

## Protected state, isolation and rollback (`preservation_plan.md`, `preimage/`, `rollback/`)

Existing user install 0.3.0 at `C:\Program Files\FantasyDisk` (exe 484,761,120 B `c9937dbb…`, Uninstall.exe `b00f7398…`), HKLM `WOW6432Node…\Uninstall\FantasyDisk` (0.3.0), per-user Start Menu + Desktop shortcuts, and Godot user data `%APPDATA%\Godot\app_userdata\FantasyDisk` (530 files) were hashed/exported/copied before any install.

- Install target: `<workdir>\install_target\FantasyDisk` via `/S /D=…`. As predicted from the NSIS script, the HKLM key and the three shortcuts are rewritten machine/user-wide even with `/D`; they were the only global side effects.
- User data isolation: an `override.cfg` next to the installed exe (`application/config/use_custom_user_dir=true`, `custom_user_dir_name="FantasyDisk-FAN3964-test"`, file logging on) redirected `user://` to `%APPDATA%\FantasyDisk-FAN3964-test`. Proven: the real user-data tree was byte-compared against the preimage copy after every launch and at the end — 530/530 identical, nothing new or missing.
- Rollback after each uninstall: elevated `reg import` of the exported key, shortcut copies restored. Final proof: re-exported `.reg` is byte-identical to the preimage (`rollback/03_registry_reexport_diff.txt`), both shortcut hashes match, Program Files hashes unchanged. The Start Menu `Uninstall.lnk` had no byte copy in the preimage (only its target was recorded); it was recreated with the same target. The line `registry matches preimage: False` in the rollback logs is a string-compare artifact of the script; the byte-identical `.reg` diff is the authoritative check.
- The first rollback attempt (`uninstall/01_uninstall_and_rollback.txt`) failed on a PowerShell variable-name collision (`$P` vs `$p`, case-insensitive) and was rerun with `scripts/rollback_only.ps1` (`rollback/02_rollback_rerun.txt`); the fixed script was used for the third cycle (`uninstall/02_uninstall3_and_rollback.txt`).

## Install / reinstall / uninstall (AC3)

| Step | Result |
|---|---|
| Install #1 (`/S /D=`, elevated) | exit 0, 9.5 s. `FantasyDisk.exe` 850,651,688 B SHA-256 `ce3bc7ff2ed4bd1cf5eaf599d5155a8b3c91e369cd8690a834793151e062fda0`, FileVersion 0.3.1.0 / ProductVersion 0.3.1; `Uninstall.exe` 39,936 B `99e2ccd0…`; HKLM key DisplayVersion 0.3.1 + InstallLocation/UninstallString → target; Start Menu `FantasyDisk.lnk`/`Uninstall.lnk` and Desktop `FantasyDisk.lnk` → target. Only the WOW6432Node view is written (as for 0.3.0). |
| Reinstall #2 over the same target | exit 0, 8.3 s, identical exe hash, extra `override.cfg` left untouched. |
| Install #3 (for the keyboard smoke) | exit 0, 7.3 s, identical hashes. |
| Silent uninstall (`/S _?=<target>`, elevated), ×2 | exit 0, ≈1.1 s. Removes `FantasyDisk.exe`, all three shortcuts, the Start Menu folder and the HKLM key. Leaves the target directory because `Uninstall.exe` (run in place with `_?=`) and the test-only `override.cfg` remain — expected NSIS behaviour, not a defect. |
| Upgrade in place over 0.3.0 | **not exercised**: it would rewrite the user's `C:\Program Files\FantasyDisk` install. |

## Launch, identity and smoke (AC3)

- Version identity: exe VersionInfo 0.3.1.0/0.3.1; the main menu shows `v0.3.1` (`launch/screenshots/launchB_long_178s.png`).
- Content identity (`launch/content_identity_pck.txt`, `launch/pck_paths_full.txt`): embedded PCK format 4, engine 4.7.0, 47,137 packed files (0.3.0: 10,155); `data/ultimates/classes/` has exactly **17 class directories × 3 profile JSON = 51** (matches the tag: 51), plus 102 files under `scenes/vfx/ultimates/` and 138 under `scripts/ultimates/classes/`.
- Runtime smoke: main menu renders; Enter opens hero select showing the roster pager "1–3 из 17" with Берсерк/Солдат/Вор and a "14›" page button (`launch/screenshots/launchH_keyboard_smoke_key1_ENTER.png`); Escape returns to the menu. No run was started, so **the 51 ultimates were verified by content identity only, not in gameplay** — a limitation for the reviewer.
- Save compatibility (`launch/launchF_savecompat*.txt`): a copy of the real 0.3.0 user data (autosave, meta, settings, feedback) seeded into the isolated user dir; 0.3.1 started normally, left `fantasydisk_autosave.cfg` and `fantasydisk_meta.cfg` byte-identical, and rewrote `settings.cfg` adding only `ultimate_reduced_motion=false` and `ultimate_photosensitivity_safe=false`.
- Update manifest (`launch/update_manifest_check.txt`): all 15 static checks PASS against the client's `validate_manifest` rules (schema 1, version 0.3.1, min 0.2.2, release URL, trusted download URLs, name/size/SHA-256 equal to the reassembled installer bytes, SHA256SUMS agreement). The live startup check hits `releases/latest/download/update-manifest.json`, which cannot yet serve v0.3.1 (unpublished); it produced no error output in any run. `stderr` was empty in every launch.
- 0.3.0 baseline: the user's installed exe was **copied** into a task folder (never launched in place) and run with the same harness (`launch/baseline030_run1.txt`).

### Timing of every launch (first responsive main window, seconds after process start)

| Run | Build | First responsive | Notes |
|---|---|---|---|
| A `launchA_first` | 0.3.1 | **not by 60 s**; WM_CLOSE unanswered for 20 s; stopped at 84 s | black window, main thread busy (≈1 CPU-s/s), no errors |
| B `launchB_long` | 0.3.1 | **≈155 s** (responding at the 160 s sample, `settings.cfg` written at +162 s) | menu OK afterwards, clean exit on WM_CLOSE |
| C `launchC_031_mislabeled_as_baseline030` | 0.3.1 | ≤10 s | harness parameter bug: file name says baseline, exe hash proves 0.3.1 |
| D1 `launchD1_fps` | 0.3.1 | 9 s | 60 s menu idle with `--print-fps` |
| E1 `launchE1_freshcopy` | 0.3.1 (fresh file copy, first execution) | 9 s | tests "first execution of a new file" — did not reproduce A/B |
| E2 `launchE2_samecopy` | 0.3.1 | 8 s | |
| F `launchF_savecompat` | 0.3.1 + 0.3.0 saves | 8 s | |
| G `launchG_after_reinstall` | 0.3.1 | 9 s | |
| H `launchH_keyboard_smoke` | 0.3.1 | 10 s | hero select smoke |
| `baseline030_run1` | 0.3.0 | **1 s** | |

Two of nine 0.3.1 launches (the first two after install #1) took ≈150 s to the first frame; the other seven took 8–10 s. The slow starts did not reproduce with a freshly copied file, Defender is off, no crash/WER/Application-Hang event was logged, and the cause is not identified. The consistent 8–10 s cold start of 0.3.1 vs 1 s for 0.3.0 correlates with the larger package (850 MB exe, 47k packed files vs 10k).

### Performance section per `docs/qa/perf-checklist.md` (measured on the real host; P1 only)

| Metric | 0.3.1 | 0.3.0 (same host, same harness) | Checklist |
|---|---|---|---|
| M1 FPS, P1 main menu idle 60 s (`--print-fps`) | avg 4273, min 3973 (59 samples, D1); other runs avg 4000–4600 | avg 4288, min 3593 | green (≥60 / 1% low ≥45). Note: V-Sync is requested by the engine but frames are not capped on this host. |
| M2 static memory (engine monitor) | **not measured** — the exported build exposes no `Performance` monitor path; process private bytes at menu idle ≈ 465–533 MiB, peak working set during load ≈ 593–634 MiB | private ≈ 403–445 MiB, peak WS 308 MiB | not assessable against the MiB targets from process counters |
| M3 object count | **not measured** (same reason) | — | — |
| M4 cold start to first frame, P1 | median **9 s** over 8 timed runs (values >84*, ≈155, ≤10, 9, 9, 8, 8, 9, 10) | 1 s | **red** by the checklist (>8 s), plus two ≈150 s outliers |
| M5 Windows setup size | 535,974,634 B = **511.1 MiB** | 0.3.0 setup 408,114,374 B ≈ 389 MiB (FAN-3963 preflight record) | green (≤800) |
| P2 (48 enemies) / P3 (boss) | **not exercised** — no gameplay automation path in the exported build | — | needs a human/QA gameplay run |

## Verdict boundary

Everything above is developer evidence for the independent reviewer. Observed exact failure boundaries: none for install/uninstall/rollback/identity/manifest/save compatibility; the cold-start metric (M4) is outside the checklist target and two unexplained ≈150 s first-frame delays were observed. No Windows PASS is claimed here.

## Files

- `host-gate/` fresh host measurements and package verification.
- `preimage/` registry export, hashes and a sanitized user-data listing (byte copies of shortcuts and user data stay on the host only).
- `install/`, `uninstall/`, `rollback/` installer/uninstaller runs, rollback proofs, cleanup.
- `launch/` per-launch harness logs (`*.txt`), engine stdout/stderr/`godot.log`, content identity, manifest check, `screenshots/` (cropped, half size).
- `scripts/` the exact PowerShell/Python used (paths sanitized).

Disk cleanup: install target, test user dirs (`FantasyDisk-FAN3964-test`, `-test030`), the 0.3.0 exe copy and the fresh-copy test folder were removed on the host; the reassembled installer and its parts were deleted from the task workdir after this evidence was pushed.
