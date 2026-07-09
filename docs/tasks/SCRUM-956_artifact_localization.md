# SCRUM-956 — Russian-only artifact names

Статус: review  
Версия: 0.2.1  
Контур: Codex  
Owner: Backend/Content Codex `/root`  
Jira: SCRUM-956  

## Scope and canonical decisions

Player-facing artifact titles in `ProgressionData.ARTIFACTS`, Codex projections,
reward/shop projections and current authority docs must be Russian-only. Stable
internal ids remain unchanged.

Requested mappings:

| Canonical id | Player-facing title |
| --- | --- |
| `red_whetstone` | Точильный камень |
| `field_kit` | Полевой бинт |
| `magnetic_buckle` | Магнитный талисман |
| `fast_boots` | Легкие сапоги |
| `hawk_lens` | Линза охоты |

`quickstring` remains the distinct artifact «Быстрая струна».
«Масло темпа» is the shop-only `shop_weapon_cooldown`; «Пыльный артефакт» is
the shop-only `shop_artifact`. No `dusty_artifact` id is created.

## Verification plan

- extend `codex_data_smoke_test.gd` so every projected title rejects Latin text
  and the exact requested mappings cannot regress;
- verify the full Codex projection and reward/shop data;
- run artifact, Codex, content-registry and runtime smoke gates;
- hand off to independent QA without self-acceptance.

## Implementation result

All 154 canonical artifact records and seven shop projections are Russian-only.
The five requested artifact ids use the exact approved labels above; internal
ids, stats, modifiers, rarity and icon paths are unchanged. Codex already
renders `title` rather than raw ids for artifact rows/detail data, so no layout
or UI-frame change was needed.

`codex_data_smoke_test.gd` now fails on Latin text in any of the 161 projected
artifact/shop titles, on drift in any requested label, or on an invented
`dusty_artifact`. Current authority tables were updated in the content registry,
artifact system matrix and visual kit.

Verification through `tools/godot_gate.py` (all PASS):

- `tests/codex_data_smoke_test.gd` — 161 artifact/shop projections;
- `tests/artifact_family_roll_test.gd` — 32 families / 300 rolls;
- `tests/artifacts_606_609_test.gd` — 10 dedicated data/icon entries;
- `tests/class_artifacts_test.gd` — 85 entries / 17 classes;
- `tests/artifact_ascension_gate_test.gd` — 154 artifacts / 17 classes;
- `tests/runtime_smoke_triggered_artifacts_test.gd`;
- `tests/content_registry_consistency_test.gd` — zero allowlisted drift;
- `tests/runtime_smoke_test.gd`.

The runtime smoke emitted only the known dummy-renderer null-texture screenshot
diagnostic and completed PASS. Ready for independent QA; not self-accepted.
