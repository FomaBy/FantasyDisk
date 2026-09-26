# FAN-3964 v0.3.2 stage — preservation plan (written before any install), 2026-09-26 21:01Z

Same protected state, isolation and rollback as the 0.3.1 stage (`../preservation_plan.md`), re-applied with a fresh preimage in `preimage/`:

- Existing user install 0.3.0 at `C:\Program Files\FantasyDisk` (hashes in `preimage/preimage_capture.txt`): never written; re-hashed after every installer run.
- HKLM `WOW6432Node\...\Uninstall\FantasyDisk` (0.3.0): exported to `preimage/hklm_wow6432_uninstall_FantasyDisk_before.reg`; restored by elevated `reg import`; proof = byte-identical re-export.
- Per-user Start Menu `FantasyDisk.lnk` + `Uninstall.lnk` and Desktop `FantasyDisk.lnk`: byte copies in `preimage/lnk/` (this time including `Uninstall.lnk`); restored by copy; proof = SHA-256 equality.
- Godot user data `%APPDATA%\Godot\app_userdata\FantasyDisk`: full copy in `preimage/userdata_copy/`; the test build runs with `override.cfg` (`use_custom_user_dir` → `%APPDATA%\FantasyDisk-FAN3964-test`); proof = byte comparison after every launch.
- Isolated install target `<workdir>\install_target\FantasyDisk` via `/S /D=`; silent uninstall `/S _?=<target>`; test directories and user dirs removed at the end.

Host difference vs the 0.3.1 stage: a person is actively using FomaPC at the start of this stage (input 0 s ago, Chrome foreground, Telegram/Discord open, console session since 23:55 local). Game launches proceed as in the earlier stages; OS-level keystrokes are sent only if the last-input idle time is at least 120 s immediately before the smoke, otherwise the gameplay/hero-select smoke is recorded as not executed.

Stop conditions unchanged: any hash mismatch, a blocking UAC prompt, a locked file, or protected state that cannot be rolled back.
