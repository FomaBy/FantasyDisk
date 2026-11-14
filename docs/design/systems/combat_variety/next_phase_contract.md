# Next-phase contract

The special route battle runs the existing five phases: marked target,
captain, next-phase contract, reward carrier, and early clear. The contract
offers the existing XP/gold reward for clearing a small group of risk enemies.
Stable feature IDs, act-state fields, reward amounts/caps and claim-before-pay
checkpoint ordering are unchanged.

## Risk lifecycle

Only pending enemy instance IDs decide whether the risk remains active. A
confirmed `died` signal removes that enemy from both pending IDs and live risk
references and disconnects its death callback. Its later animation/free cannot
interrupt the remaining enemies. The last confirmed death checkpoints success
and pays the one-time reward. Repeated signals and retries cannot pay it again.
A pending enemy freed, queued for deletion, or detached without `died` still
fails with `risk_interrupted` and pays nothing.

Each risk enemy enters the game tree, then uses the existing live
`context.combat._scale_enemy_for_current_wave` routine, exactly as an ordinary
enemy of the same scene. The extra `risk_multiplier` applies afterward to max
health and contact damage; current health is reset to max and the bar refreshed.
This includes route stage, wave, pressure, run modifiers and ascension scaling.
XP and gold drops are explicitly zeroed after the scaler assigns normal drops.
A missing scaler fails explicitly as `risk_scaler_missing`; there is no
unscaled fallback and no additional public accessor.

## HUD and pause lifetime

The offer and marked-target/captain labels belong to group `encounter_hud`.
When a level-up pick or defer rebuilds the combat HUD, `_create_hud` detaches
these controls before clearing the old layer and attaches them after building
the new HUD. Their instances, elapsed/remaining times, styles, screen anchors,
content and geometry remain intact. Feature resolution still owns cleanup;
normal combat teardown does not retain these controls. The offer restores its
safe Decline focus on tree reentry.

The offer retains `PROCESS_MODE_ALWAYS` so its buttons remain usable, but its
countdown and unhandled keyboard shortcuts ignore frames while the tree is
paused. The existing level-up pause reason therefore freezes the offer without
changing the pause stack. Unexpected removal of an offer checkpoints an explicit
decline with reason `offer_lost` on the next active feature tick, allowing the
carrier and early-clear phases to proceed. Failed persistence remains an
explicit failure through the existing checkpoint contract.

## Regression evidence

- `tests/encounters/contract_feature_lifecycle_test.gd`: real enemy deaths 150
  frames apart, zero drops, scaler ordering, once-only rewards/retries, and
  pending enemies freed or detached without death.
- `tests/encounters/contract_offer_lifetime_test.gd`: real Main route activation
  and feature sequence, marked/captain labels across actual level-up pick/defer,
  offer identity/geometry/focus/time across both exits, 840 paused frames,
  paused button decision, subsequent carrier/early-clear activation, freed and
  detached offers, and 60 ordinary-versus-risk comparisons (stages 0/1/4/8/16,
  ascensions 0–5, waves 0/8).
- Existing `tests/encounters/contract_offer_ui_test.gd` covers unchanged layout
  zones at 1280×720, 1920×1080 and 2560×1440 and active-time timeout decline.

Run automated engine commands through `tools/godot_gate.py`. The lifetime suite
accepts either an explicit `PROBE_SCRATCH` or the canonical quality runner's
matching `HOME`, `XDG_DATA_HOME`, `APPDATA` and `LOCALAPPDATA` scratch roots.
It refuses to instantiate Main unless the actual `OS.get_user_data_dir()` lies
inside that absolute root. Set the child profile roots to scratch before
imports as well as tests; an ignored `--user-data-dir` argument does not
isolate the profile. Use
`--fixed-fps 60`. For windowed inspection, set `FSD_CONTRACT_CAPTURE=1` and
`FSD_CONTRACT_ARTIFACT_DIR` to a writable evidence directory. This captures the
existing marked label, captain label and offer after the level-up operations.
Headless results cover state/geometry; a windowed run covers actual placement.
