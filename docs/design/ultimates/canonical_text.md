# Canonical weapon-ultimate text (FAN-2515)

The selected weapon ultimate — never the legacy class ultimate — is what every
runtime surface names.

## Sources

| Layer | Owner | Content |
| --- | --- | --- |
| `data/ultimates/schema/v1/classes/*.json` | immutable catalog | `class_id`, `weapon_id`, `identity.profile_id/title_id/mechanic_id`, presentation IDs |
| `data/ultimates/text/ru.json` | canonical text | one `{title, description}` per `class_id/weapon_id`, exactly 51 records |
| `docs/design/references/weapon_ultimates/<class>/manifest.json` | accepted art | the same `title` per weapon, plus scene/timing |

`WeaponUltimateRegistry` reads the text table while it indexes the catalog and
attaches the record to the profile as `text`, so every consumer that already
resolves a profile reads the same title and mechanics. `WeaponUltimateText`
owns the file and its validation; `registry.text_validation_errors()` reports
a missing pair, an unknown pair, an empty field or a duplicated title. The
legacy class ultimate is never a text fallback.

## Consumers

- HUD — `UltimateHudRuntimeAdapter` caches `registry.ultimate_text(class, weapon)`
  into the widget's `ultimate` block (tooltip title and mechanics).
- Codex — `CodexData.characters()` carries the ultimate on each of the three
  weapons; `ui_screens` renders them under «Ультимейты» instead of one
  class-level entry with legacy radius/damage parameters.
- Pause dossier — the build summary and the «Арсенал» entry name the ultimate of
  the weapon the run actually selected (`WeaponUltimateText.text_for`).

`ProgressionData.ULTIMATE_CONFIGS` stays where it still belongs: the class-level
charge economy (`damage_charge_rate`, `taken_charge_rate`, `boss_cap`) that
`Player` reads. It is no longer a UI text source.

## Gate

`tests/ultimates/canonical_ultimate_text_test.gd` — 51 records resolve with a
unique non-empty title/mechanics, the art manifests and the canonical table
agree on all 51 titles, the validator rejects each defect class, and the live
HUD widget, Codex entry and pause dossier show the same text for the same pair.
