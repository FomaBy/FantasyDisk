# SCRUM-606 / SCRUM-609 Artifact Icon QA

Batch: artifact-icon-unblock-worker
Style: D&D + Dark Fantasy Dragon, no text, transparent RGBA PNG, 256x256 runtime assets.
Contact sheet: `docs/design/previews/artifact_icons_606_609_contact.png`

| ID | Runtime path | Source path | Final alpha bbox | Corner alpha max | 32/40/64 readable |
| --- | --- | --- | --- | --- | --- |
| `field_kit` | `assets/sprites/ui/icons/artifacts/artifact_field_kit.png` | `docs/design/references/icons/artifacts/field_kit/field_kit_source.png` | `(37, 34, 219, 222)` | 0 | PASS |
| `vital_siphon` | `assets/sprites/ui/icons/artifacts/artifact_vital_siphon.png` | `docs/design/references/icons/artifacts/vital_siphon/vital_siphon_source.png` | `(75, 34, 181, 222)` | 0 | PASS |
| `powder_charge` | `assets/sprites/ui/icons/artifacts/artifact_powder_charge.png` | `docs/design/references/icons/artifacts/powder_charge/powder_charge_source.png` | `(55, 34, 200, 222)` | 0 | PASS |
| `bulwark_echo` | `assets/sprites/ui/icons/artifacts/artifact_bulwark_echo.png` | `docs/design/references/icons/artifacts/bulwark_echo/bulwark_echo_source.png` | `(67, 34, 188, 222)` | 0 | PASS |
| `duelist_spur` | `assets/sprites/ui/icons/artifacts/artifact_duelist_spur.png` | `docs/design/references/icons/artifacts/duelist_spur/duelist_spur_source.png` | `(55, 34, 201, 222)` | 0 | PASS |
| `sacrifice_seal` | `assets/sprites/ui/icons/artifacts/artifact_sacrifice_seal.png` | `docs/design/references/icons/artifacts/sacrifice_seal/sacrifice_seal_source.png` | `(45, 34, 210, 222)` | 0 | PASS |
| `hungry_amulet` | `assets/sprites/ui/icons/artifacts/artifact_hungry_amulet.png` | `docs/design/references/icons/artifacts/hungry_amulet/hungry_amulet_source.png` | `(81, 34, 175, 222)` | 0 | PASS |
| `berserk_totem` | `assets/sprites/ui/icons/artifacts/artifact_berserk_totem.png` | `docs/design/references/icons/artifacts/berserk_totem/berserk_totem_source.png` | `(65, 34, 190, 222)` | 0 | PASS |
| `focus_lens` | `assets/sprites/ui/icons/artifacts/artifact_focus_lens.png` | `docs/design/references/icons/artifacts/focus_lens/focus_lens_source.png` | `(36, 34, 220, 222)` | 0 | PASS |
| `stone_hide` | `assets/sprites/ui/icons/artifacts/artifact_stone_hide.png` | `docs/design/references/icons/artifacts/stone_hide/stone_hide_source.png` | `(52, 34, 203, 222)` | 0 | PASS |

Notes:
- Source IDs were not present in `scripts/progression_data_content.gd` on the checked `origin/dev` baseline; this batch adds the expected icon paths ahead of the data patch.
- Background removal uses edge-connected light matte detection, then keeps the largest alpha component and centers it with readable padding.
