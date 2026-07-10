# SCRUM-991 — resolved Artifact Reward text and badges

Статус: done
Контур: Codex
Owner: `/root/scrum990_artifact_reward`
Combined scope: `SCRUM-990` + `SCRUM-991`

## Contract

- Remove the vague `Interpretation` section from reward cards.
- Show concise concrete current-class effect text, including conditions,
  bonuses and penalties.
- Recommend only a unique safely comparable top damage/survivability offer;
  ties and unmodelled effects receive no badge.
- A unique hybrid may show both badges.
- Keep the full card copy inside card and gold-shell content zones at all three
  target viewports.

## Work evidence

- Deterministic scoring/text architecture and responsive content zones are
  documented in `docs/design/mockups/scrum990_991_artifact_reward/spec.md`.
- The focused acceptance oracle was authored independently from production
  implementation and passes for class-specific text, unique-winner badges,
  tied-offer suppression, hybrid badges, focus and one-shot choose semantics.
- All six runtime captures keep class label, resolved effects and optional
  badges inside the actual card StyleBox content margins.
- Verification PASS: focused Artifact Reward acceptance, UI no-overlap,
  progression/economy, route/chest/artifact, boss heal, gamepad full-flow and
  the full runtime smoke.

Disk cleanup: removed task `.godot` import cache (445 MB), Python caches and
unrelated import-generated UID sidecars; only the task capture tool UID is kept.

## QA-Вердикт — 2026-07-11

Статус: PASSED

- Independent SCRUM-992 QA ran from clean `origin/dev` at `ca61e83e8`
  (implementation `715fc0aba`) in an isolated disposable worktree.
- Current-class copy differs for Berserk and Dark Mage; mixed modeled and
  unmodelled mechanics/penalties retain canonical source semantics. Guardian
  keeps its full 18s condition/cooldown, Counterwave its full 3s copy, and
  Doctor-blocked generic sustain honestly reports a no-op without a badge.
- Damage, survivability and hybrid badges are deterministic; exact ties and
  unsafe/unmodelled axes remain unbadged. Exact selected artifact id, initial
  focus, no-Escape mandatory choice and one-shot apply/return behavior passed.
- All six committed 720p/1080p/1440 captures keep titles, tiers, badges,
  resolved effects and actions inside actual card and shell content zones.
- Gates passed: focused Artifact Reward, UI no-overlap, progression/economy,
  route/chest/artifact, boss heal, gamepad full-flow (3/3), full runtime,
  animation, meta progression and melee targeting.
- Bugs: none.
- Disk cleanup: disposable QA `.godot` cache, generated UID sidecars, worktree
  and local QA branch removed after Jira/Git synchronization.
