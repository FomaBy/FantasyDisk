# SCRUM-999 — independent QA of elite combat and event flow

Статус: done  
Дата: 2026-07-10  
QA owner: Codex `/root`  
Implementation chain: SCRUM-994, SCRUM-995, SCRUM-996, SCRUM-997,
SCRUM-998, SCRUM-1000  

## QA-Вердикт

Статус: PASSED

The integrated route/event slice satisfies the acceptance contract. Elite route
nodes always enter the elite-combat flow and only award/complete after victory;
the protected altar/event path remains an event. The redesigned pool contains
exactly 12 unique events with exactly three choices each, no legacy pool entries,
non-repeating seeded selection, hidden-choice disclosure, deterministic checks,
combat/reward/rest coverage, and safe cleanup/transition into combat, shop and
route continuation.

Deterministic evidence:

- route generation seeds: `11`, `2026`, `70907`, `424242`, `999331`, `5150`,
  `86420`, `13571113`;
- elite activation seeds: `70907`, `424242`, `999331`;
- reachability matrix: 24 generated routes, eight rows plus boss per route;
- event contract: 12 events / 36 choices, 11 combat outcomes, eight reward
  outcomes, three rest outcomes, 13 checks, two class-reactive events and three
  events with hidden choices;
- runtime outcomes: pick context, check success/failure, hidden reveal,
  damage-floor safety, money/stats/artifact rewards, combat, `shop_after` after
  event and after victory, and transient-state cleanup.

## UI acceptance

The isolated Godot capture scene was rendered at 1280×720, 1920×1080 and
2560×1440 in normal, hidden-choice and revealed-outcome states (nine captures).
All nine were inspected. Story, title, three choice cards, hints, Back and
Continue remain inside their empty frame/content zones; the decorative borders
remain visible and unobstructed. There is no clipping, overlap or leaked hidden
outcome. The rect evidence in
`docs/design/previews/scrum997_event_dialog_rects.md` and the automated no-overlap
matrix agree with the visual verdict.

Commands (all through `tools/godot_gate.py`, all exit 0):

- `tests/route_elite_invariant_test.gd`
- `tests/event_data_contract_check.gd`
- `tests/event_data_smoke_test.gd`
- `tests/event_outcomes_runtime_test.gd`
- `tests/event_risk_reward_ev_test.gd`
- `tests/route_generation_reachability_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `tests/runtime_smoke_test.gd`
- `tools/capture_scrum997_event_dialog.gd` (nine windowed captures)

Runtime emitted only the known dummy-renderer null-texture screenshot diagnostic
and completed PASS. No follow-up defect was found.
