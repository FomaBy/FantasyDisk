# Knight — Long Spear Ultimate

`knight/long_spear` is a ready, class-local weapon-ultimate package. It is
discovered from the matching JSON and GDScript paths; Tower Shield and Holy
Flail remain declared and continue to use their legacy fallback.

## Phalanx Corridor

Activation snapshots the host aim and the ordered targets in a 780px, 72px
half-width corridor. Three rows advance at 0.32-second intervals. A target is
assigned to exactly one row by that snapshot order, so overlapping rows and
replayed callbacks cannot apply a second hit.

Each hit is player-owned `pierce` damage with a nine-percent whole-activation
boss cap. The target ledger claims the target before damage or control.

## Control And Cleanup

Only normal enemies receive the 180px stagger and a 1.2-second pin. Epic and
boss targets can receive their single capped pierce hit but receive neither
knockback nor a status. The effect scene owns pin leases and removes only its
own leases when the generic activation completes or cancels. The shared
activation/controller owns all scene nodes, tweens, target ledgers and active
state for cancellation, death, encounter end and Continue.

## Verification

`tests/ultimates/mechanics/knight_long_spear_test.gd` covers auto-discovery,
the three-row ordering, corridor exclusion, single-hit ledger, pierce feedback,
normal-only controls, boss/epic control refusal, callback replay, cancellation
cleanup, and the shared charge-ledger contract.
