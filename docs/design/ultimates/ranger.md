# Ranger weapon ultimates

Status: the three exact Ranger packages are ready. Each JSON binding is paired
with one class-local executor and its accepted Ranger presentation scene. The
shared registry, controller, executors, Player, ClassWeapon, progression data
and animation assets remain untouched.

## Trio roles

| Weapon | Ultimate | Mechanical role |
| --- | --- | --- |
| `moon_crossbow` | Лунная Охота | The heaviest silhouette in the aim sample takes the moon mark and the full bolt. Each of five waves also gives every other live enemy a fixed split floor; a killed mark transfers to the closest survivor. |
| `storm_longbow` | Око Бури | Six lightning beats keep their aimed moving front as the full-hit priority, while every live enemy receives the `beat_floor`; every struck body is pushed off the axis and slowed. |
| `hunter_trap` | Великий Капкан | Three spectral rings and the closing chain net catch every live enemy. Each snap keeps the nearest body as the full jaw bite and gives all other bodies the declared `net_ratio`; normals stay locked, resistant tiers keep shortened pull and slow. |

The runtime scenes embed the accepted `RangerMoonCrossbowMoonHunt`,
`RangerStormLongbowStormEye`, and `RangerHunterTrapGrandTrap` presentations from
FAN-1474. Each executor keeps its own `lifetime` (4.80 s / 4.45 s / 5.35 s);
since FAN-3736 the presentation runs on the shorter Ultimate Direction v2
envelope below. The two clocks are independent by contract — the gameplay
window may outlast the show and neither may be asserted against the other. The
immutable Cast phase IDs remain the seam with FAN-1494; shared live
presentation forwarding remains owned by FAN-1541.

## Safety and lifecycle

- Every profile uses the frozen Ranger `total_boss_cap = 0.09`. All delayed hits
  route through the same activation ledger, so actual removed HP — not attempted
  damage — is attributed and the cap applies to the whole cast.
- The moon mark is activation ledger state, not a target flag: it is recorded on
  the prey, transferred on a kill, and dropped with the activation. Nothing is
  written onto an enemy that outlives the cast.
- Storm and trap use the shared control policy. The storm never pins anything:
  normals take the full push and slow, epic targets 45% and bosses 20% of both.
  The trap locks normals only; epic targets keep 45% and bosses 20% of the pull
  and slow, both without a movement lock.
- Effect nodes, VFX children, tweens and status leases are activation-owned.
  Cancellation, death, node end and a new run remove them, and cleanup erases
  only the leases the cast itself took — a foreign status on the same target is
  left untouched.
- The frozen `ultimate_charge_ledger` contract remains the authority for one
  charge spend, no active-window income, one activation per encounter, and
  battle/act/Continue snapshots. Runtime adoption is shared infrastructure,
  outside this class-local package.

## Caps and balance

| Weapon | Lifetime | Map coverage | Per-target shaping |
| --- | ---: | ---: | --- |
| Лунная Охота | 4.80 s | every live enemy on every wave | 5 waves, 10% split floor; mark takes full bolt |
| Око Бури | 4.45 s | every live enemy on every beat | 6 beats, 0.46 focus falloff, 12% floor |
| Великий Капкан | 5.35 s | every live enemy on every ring/closure | 3 rings, 1 closure, 11% chain floor |

Ranger prices its ultimates as a burst archetype: the class ultimate declares no
duration, so the trio's defensive contribution is measured against its own
2.0 s class reference instead of the shared control-save bar.

The focused balance proof derives base Ranger damage and the selected weapon's
`ultimate_multiplier`, keeps solo output inside each frozen budget row, checks
the all-map per-enemy floor and control role, and contains a runaway-damage
negative control. Charge cadence and the 9% whole-activation boss cap remain
unchanged.

| Weapon | Solo / budget midpoint | Guaranteed floor | Defense role |
| --- | ---: | ---: | --- |
| Лунная Охота | 1.052 | 10% bolt split | none — pure mark pressure |
| Око Бури | 0.874 | 12% beat floor | 2.6 s push and slow |
| Великий Капкан | 0.806 | 11% chain floor | 3.4 s jaw lock |

The class-trio composite remains inside the `0.90…1.10` solo/control corridor;
map coverage is now a binary runtime assertion rather than a target-count score.

## Presentation: Ultimate Direction v2 (FAN-3736)

All three visuals show arena-wide reach without hiding the Ranger identity: Moon
Hunt keeps the archer/mark silhouette central while distant targets receive
moon-split impacts; Storm Eye keeps the advancing arrow corridor central while
the full arena flashes once at its floor; Grand Trap keeps the aimed jaw as the
focal impact while spectral chains visibly span the arena. The mechanic phases,
Cast IDs, charge economy and the frozen 9% boss cap are untouched by this work.

| Weapon | Total | Cast ceremony | Active window | Backdrop | Hitstop | Palette role |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| `moon_crossbow` | 3.10 s | 0.70 s | 1.90 s | `darken` | 95 ms | moonlight |
| `storm_longbow` | 3.45 s | 0.60 s | 2.25 s | `flash` | 120 ms | storm |
| `hunter_trap` | 3.80 s | 0.95 s | 1.75 s | `darken` | 145 ms | thicket |

Every timeline sits inside the `2.5–4.0 s` v2 envelope with a `0.6–1.0 s` cast
ceremony, at least `1.2 s` of active presentation and a visible recovery. The
trio stays pairwise distinct on both enforced axes (`cancel` 3.10 / 3.45 / 3.80;
`recovery − active` 1.55 / 1.90 / 1.30).

Each scene authors two presence nodes on top of its formation — a
viewport-fitted `BackdropVeil` (`Sprite2D` + `GradientTexture2D`, tagged
`fullscreen_layer`) and a `HeroPose` reusing the accepted
`ranger_idle_south` frame — and `ranger_ultimate_timeline_scene.gd` drives the
node-free weight devices: camera shake behind the player's `screen_shake`
setting, the first-impact hitstop (which freezes the drawn pose, never the
envelope clock) and SFX ducking across the release window. Identity is declared
once per pair: `cast_pose.ranger.hunter_draw` for the whole trio, each weapon's
own accepted runtime frame as its silhouette, and `palette.ranger.moonlit_hunt`
as the color source. No raster asset was regenerated.

`docs/design/references/weapon_ultimates/ranger/manifest.json` is the source the
shared bridge reads; `ranger_ultimate_presentation_pack.gd` is the second
authoritative timing source the parity gate cross-checks field by field. The
trio left `PRESENTATION_V2_MIGRATION_ALLOWLIST` in the same change, because a
v2-complete pair that stays on the ratchet fails as a stale entry.

Still pending for this class, tracked by the shared adoption ratchet: the
`capture` gate (one 4680x594 strip instead of four live-capture viewports) and
the `quality` gate (readability/accessibility declaration). Both remain listed
in `UltimateVisualDirectionContract.ADOPTION_GAPS`.

## Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/presentation/ranger_ultimate_presentation_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_package_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_live_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/mechanics/ranger_balance_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/ultimates/balance_harness_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
