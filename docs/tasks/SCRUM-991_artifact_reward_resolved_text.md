# SCRUM-991 — resolved Artifact Reward text and badges

Статус: in_progress
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

Disk cleanup: pending task completion.
