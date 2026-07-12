# SCRUM-990/991 — Artifact Reward gold hall

## Design decision

Elite, chest and boss artifact choice reuse one responsive presentation contract.
The reward hall remains a full-screen background; `frame_border.png` is the only
ornamental screen shell and is rendered last with `draw_center=false`. There is
no opaque or decorated central modal. The three interactive cards are quiet
Atlas chips, not a second screen frame.

PixelLab MCP source `3929f7e7-8182-495e-a794-7565cb51afda` is a textless full-page
reference for the one-shell/three-well composition. Runtime deliberately reuses
the canonical existing sources required by SCRUM-990:

- background: `assets/backgrounds/ui/ui_backdrop_reward_hall.png`;
- hollow shell: `assets/sprites/ui/meta40/frame_border.png`;
- artifact icons: canonical `artifact_<id>.png` registry assets;
- card bodies: runtime Atlas chip styles with content margins larger than the
  2px border.

This is an explicit `existing source reuse` decision, not a PixelLab fallback:
the ticket asks for the shared gold shell and current reward-hall background.
No PixelLab bitmap is promoted to production.

## Responsive content zones

Validated source plans:

| Viewport | Gold inner rect | Card row | Card slot |
| --- | --- | --- | --- |
| 1280×720 | `157,137 966×446` | single row, `y=219..563` | `286×344` |
| 1920×1080 | `224,193 1472×694` | single row, `y=323..843` | `360×520` |
| 2560×1440 | `299,257 1962×926` | single row, `y=443..1103` | `430×660` |

The title, subtitle, all cards, card descendants and hitboxes stay inside the
real gold inner rect. Live resize recomputes every authored rect. The hollow
frame remains the final mouse-ignore child and cannot be covered by content.
Scrollbars are neither required nor allowed.

## Card contract

Each card contains, in order, one icon, a two-line title, tier, zero to two
comparison badges, a resolved current-class effect and the `Выбрать` affordance.
The former `EliteArtifactRewardInterpretation` section is removed.

Resolved effect text is built from the same dry-run semantics used when a reward
is applied: current stats/modifiers are copied, reward stats and modifiers are
applied, and `ProgressionData.derived_parameters()` is compared before/after for
the selected class/weapon. The concise text names the current class, preserves
the artifact's concrete conditional/mechanical description and adds the most
material visible deltas. Thus a class-dependent artifact can resolve differently
for different classes without inventing a generic interpretation.

Badge rules are deterministic:

- `Лучший урон` goes only to one unique positive top DPS gain;
- `Лучшая выживаемость` goes only to one unique positive top EHP/sustain gain;
- one card may receive both badges;
- a tie, zero/negative gain, or an effect that cannot be represented safely by
  derived parameters receives no badge for that axis.

These badges compare only the three offered cards. They do not claim an absolute
build recommendation.

## Interaction contract

- elite/chest and boss flows keep their existing reward pools and callbacks;
- selection applies exactly one reward, clears the modal and invokes `on_done`;
- the first card receives initial focus;
- Left/Right wrap across the three cards; Up/Down stay on the current card;
- Escape cannot bypass the mandatory choice.

## Acceptance evidence

The design gate is `ready_for_image`, with no errors or warnings at all three
target viewports. The final renderer matrix contains fresh elite and boss
captures at 1280×720, 1920×1080 and 2560×1440; all six pass manual frame-zone
and text-fit review. The focused SCRUM-990/991 test covers live resize, exact
selected artifact id, mandatory initial focus/no-Escape choice, mixed
modelled/unmodelled bonuses and penalties, Doctor-blocked sustain, complete
long-form cooldown conditions and compact 720p fit. Focused, UI no-overlap,
progression/economy, route/chest/artifact, boss heal, gamepad full-flow and full
runtime smoke gates all pass.
