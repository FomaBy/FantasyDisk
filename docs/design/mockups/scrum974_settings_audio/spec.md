# SCRUM-974 — compact real Audio Settings

## Product decision

Add exactly three settings with real runtime ownership:

- `ui_volume` (default `1.0`): a fourth volume row. `AudioManager` creates a
  `UI` child bus that sends into `SFX`; only `ui_click`, `ui_back` and
  `ui_error` use it. Existing `sfx_volume`/`sfx_enabled` therefore remain the
  global parent controls, while economy/reward/gameplay cues stay on `SFX`.
- `mute_when_unfocused` (default `false`): hard-mute Master only while the
  application is unfocused and the option is enabled, then restore immediately
  on focus. Focused `master_volume=0` retains its existing non-hard-mute contract.
- `low_hp_warning_enabled` (default `true`): gates the existing
  `low_hp_pulse`. Requested and effective loop state are separate so disabling
  stops the warning and re-enabling at still-low HP resumes it immediately.

Reject dynamic-combat music: runtime has shuffle/outro but no intensity/layer
state, so a toggle would be ambiguous. Reject ambient/tavern volume: ambience
is baked into current OGG tracks and has no separate stream or bus.

## Layout

The fullscreen Settings shell, seamless background, tabs, native rows and
footer remain unchanged. The Sound page uses four full-width volume rows, two
short stacked toggle rows, then Reset. At 1600×900 and above the stack fits
without a visible scrollbar. At compact sizes `AudioScroll` exposes every
control through wheel/keyboard/gamepad follow-focus instead of shrinking labels
or overlapping the footer.

Accepted PixelLab MCP source `11178250-472a-4f22-84bf-85f1e45d8ea7` is a
textless full-page direction with one continuous dark field, four slider rows
and two separated compact option rows. The first source baked English footer
text; the third inserted scenery into the content zone, so both are rejected.
A fourth transparent refinement could not start because PixelLab reported no
remaining UI generations; project policy forbids switching to a non-PixelLab
fallback. Runtime uses no generated asset and follows the validated native
content-zone plan.

All content stays inside `(48,34,592,316)` on the 688×384 design canvas. The
outer frame and tab ornaments remain uncovered. PixelLab must generate a
textless border/control layer around these exact zones; native text is applied
only by the compositor/runtime.

## Acceptance

- persisted values are clamped/normalized and Reset restores all eight audio
  keys;
- 1920×1080 shows no Audio scrollbar, clipped row or cramped option stack;
- 1280×720 remains fully reachable through AudioScroll/focus;
- UI bus routing, parent SFX mute/volume, focus mute/restore and low-HP
  disable/re-enable are deterministic and covered by focused tests;
- existing Master/Music/SFX behavior and all other Settings tabs are unchanged.
