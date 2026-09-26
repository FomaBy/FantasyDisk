# FAN-3964 preservation plan (written before any install), 2026-09-26

Host: FomaPC, Windows 11 Pro 10.0.22000, daemon `019fe1f0-73fb-79ac-b8f2-7acf92c4c42c` (PID 20596, CLI 0.5.3, running, 1 running task),
task context binds agent `78cc066a-6418-4dbf-8149-d4e3e3ee82a3` to issue `01a0cda1-f921-717a-a914-f1343b49c84f`.
Session: interactive desktop session 1, user is a local Administrator, current token not elevated, UAC on with
`ConsentPromptBehaviorAdmin=0` (elevate without prompting), so `Start-Process -Verb RunAs` elevates unattended.

## Protected state (preimage in `preimage/`, kept out of the public repo except listings/hashes)

| Item | Location | Preimage | Rollback |
|---|---|---|---|
| Existing user install 0.3.0 | `C:\Program Files\FantasyDisk\{FantasyDisk.exe,Uninstall.exe}` (484,761,120 / 39,938 bytes, SHA-256 in `preimage_capture.txt`) | hashes only; never written by this test (isolated `/D=` target) | none needed; re-hash after test must match |
| HKLM uninstall key (NSIS writes it machine-wide for any `/D`) | `HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\FantasyDisk` (DisplayVersion 0.3.0, InstallLocation `C:\Program Files\FantasyDisk`) | `hklm_wow6432_uninstall_FantasyDisk_before.reg` | elevated `reg import` of that file, then `reg query` compare |
| Start Menu shortcuts (per-user) | `%APPDATA%\Microsoft\Windows\Start Menu\Programs\FantasyDisk\{FantasyDisk.lnk,Uninstall.lnk}` | `lnk/startmenu_FantasyDisk.lnk` (SHA-256 recorded); `Uninstall.lnk` is 629 bytes and points at the 0.3.0 uninstaller | copy back from preimage; re-hash |
| Desktop shortcut (OneDrive-redirected Desktop) | `<Desktop>\FantasyDisk.lnk` | `lnk/desktop_FantasyDisk.lnk` (SHA-256 recorded) | copy back; re-hash |
| Godot user data (saves, settings, meta, feedback) | `%APPDATA%\Godot\app_userdata\FantasyDisk` (530 files, per-file SHA-256 in `userdata_listing_before.txt`) | full copy `userdata_copy/` | not expected to be touched: the test install runs with an `override.cfg` that sets `application/config/use_custom_user_dir=true` + `custom_user_dir_name="FantasyDisk-FAN3964-test"` so `user://` maps to `%APPDATA%\FantasyDisk-FAN3964-test`. Re-hash after every launch; if any file changed, copy back from `userdata_copy/`. |

## Isolated test target

Install with `FantasyDisk-0.3.1-windows-setup.exe /S /D=<workdir>\install_target\FantasyDisk` (task-owned, on C:, no spaces).
Only the HKLM key and the three shortcuts are global side effects; they are restored by the rollback above after the final uninstall.
The test user-data directory `%APPDATA%\FantasyDisk-FAN3964-test` is created by the test and removed at cleanup.

## Sequence

1. Fresh host gate (done: `host-gate/`), package verification (done: `host-gate/package_verify.txt`).
2. Install #1 silent to the isolated target; record exit code, files, registry, shortcuts.
3. First launch with isolated user data (fresh), stdout/stderr + `user://logs`, screenshots; version/content identity; update-manifest check.
4. Save-compatibility launch: copy of the 0.3.0 user data placed in the isolated user dir, launch again.
5. Reinstall (install #2 over the isolated target), verify identical result.
6. Silent uninstall from the isolated target; verify files, shortcuts and key are removed.
7. Rollback: import the `.reg` preimage (elevated), copy shortcuts back, verify all hashes and the untouched Program Files install and user data.
8. Remove the test user-data directory and the install target; record disk cleanup.

Stop conditions: any hash mismatch, a UAC prompt that blocks, a locked file, or any change to protected state that cannot be rolled back.
