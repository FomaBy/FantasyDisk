# FAN-3961 early 0.3.1 draft provenance

This is a provisional source-grounded text and poster plan, not a release candidate or an approved claim set. The 0.3.1 source files, poster image, and release branches were not edited.

## Exact comparison

| Item | Value |
| --- | --- |
| Previous published version | `v0.3.0` at `d7e516cde235adf347d511e922ab19667bf82f65`, tree `0c887fb3c3c6f551da149f923d2a21b649edea34` |
| Provisional integrated source | `origin/dev` at `e33bded444e301919dc93c8c9b9f0257e640a1ea`, tree `9a8401ca1a6dda8a4b446fe45de3fa4f97074426` |
| Range examined | `git log v0.3.0..e33bded444e301919dc93c8c9b9f0257e640a1ea` and `git diff v0.3.0..e33bded444e301919dc93c8c9b9f0257e640a1ea` |
| Local worktree | Task branch at exact pinned HEAD, `git status --porcelain=v1` empty when inspected |
| Certification gate | FAN-3877 was `in_review`, not terminal PASSED, when this draft was made |

`multica repo checkout --ref e33bded444e301919dc93c8c9b9f0257e640a1ea` reported a wrapper failure after Git populated the worktree. Direct read-back showed a clean worktree at the required commit and tree. No LFS hydration or runtime/visual verification was inferred from that read-back.

## Player-visible coverage map

| Draft content | Source evidence in the pinned tree | Publication check |
| --- | --- | --- |
| 51 distinct names/descriptions in combat HUD, Codex and pause | `data/ultimates/text/ru.json` has 51 records; `docs/design/ultimates/canonical_text.md`; `scripts/ui/ultimate_hud/ultimate_hud_runtime_adapter.gd`, `scripts/codex_data.gd`, `scripts/pause_stats_menu.gd`; introduction commit `43952a8a6` | Confirm live surfaces after final source pin. This fixes the generic class-level wording acknowledged in 0.3.0 notes. |
| 17 class ultimate trios have the newer presentation and per-target impact route | All 17 `data/ultimates/classes/<class>/presentation_v2_migration.json` have empty `migration_exemptions`; all 17 `presentation_adoption.json` have empty `adoption_gaps`; class presentation scenes/scripts under `scenes/vfx/ultimates/**` and `scripts/ultimates/classes/**`; victim impact route under `scripts/ultimates/presentation/victim_impact_player.gd`. | Source state only. Require FAN-3877 terminal PASSED on the exact immutable source and recheck changed source before publishing. |
| Ultimate reach and power changes across all heroes | All 51 weapon profile JSON files under `data/ultimates/classes/<class>/<weapon>.json` differ from `v0.3.0`. The range removes many count-shaped target limits and changes damage coefficients; the class design records under `docs/design/ultimates/**` describe the intended player effect. | The 17 hero lines describe reach and class role in player terms; recheck final profile values and live effectiveness before publication. No raw balance numbers enter player copy. |
| Class-specific presentation and combat wording | `data/ultimates/text/ru.json`, all 17 `data/ultimates/classes/<class>/**` directories, `docs/design/ultimates/{assassin,berserk,biologist,chemist,dark_mage,doctor,druid,elementalist,engineer,guitarist,knight,priest,ranger,robot,sniper,thief}.md`; Soldier is grounded in its catalog/text and class data. | Review each player line against the final 51 mechanics and QA report; adjust any line whose live appearance differs. |
| Six bosses turn in eight directions | Changed `data/animation/boss/{ashen_colossus,bloodthorn_lion,bone_archon,brood_mother,disk_devourer,rift_warden}.json`, corresponding sprite packs, introduction commit `16d478055` and Disk Devourer commit `255d2211c`. | Confirm all six visible in final runtime and the exact boss certification gate. |
| Enemy and elite directional art | Changed animation manifests for 11 regular enemies and 14 elites in `data/animation/{enemy,elite}/**`, with paired packs under `assets/sprites/{enemies,elites}/**`. | Retain the non-exhaustive wording “several”; do not imply every actor changed. |
| Hero and summon polish | `CHANGELOG.md` Unreleased entries for Elementalist and Thief; `data/animation/ally/**` and commit `6520122cd` for summon/homunculus motion; current character packs under `assets/sprites/characters/**`. | Verify any specifically named hero/ally visual claim on the final candidate. |

The 0.3.0 patch notes already announce 51 weapon ultimates and manual aim. Those are not presented here as new 0.3.1 features. The range also contains build/process/test/evidence work; it is not player copy. Basic-attack flipbook support in `scripts/attack_vfx.gd` has a static fallback and is omitted as a general art claim. Persisted accessibility flags in `scripts/settings/ultimate_accessibility_settings.gd` have no Settings UI controls according to `docs/settings/ultimate_accessibility.md`; no player-facing Settings claim is made. Performance benefits are omitted pending repeatable certification.

The poster plan copies the five established 1350 × 1350 content rectangles from `docs/design/templates/release_notes/{ui_plan.json,layout.json}`. The planning validator ran against this draft `poster/ui_plan.json` with `--report` only and returned `ok: true`, `decision: ready_for_image`, no errors or warnings. No guide image, frame generation, compositing, local poster render, Godot run or performance load was performed. `source_audit.json` records the exact source/count checks; a static artifact check confirmed four highlights, 17 hero lines, identical text and geometry across the plan/layout, and a clean source worktree.

## Open verification before final release inputs

1. FAN-3877 must record terminal independent PASSED for the exact holistic candidate. A FAILED or changed candidate requires this comparison and wording to be redone.
2. PM must restore the final release-input write set and gate; pin the new clean `origin/dev` commit/tree and re-audit every player-visible delta since `v0.3.0`, including any commits after this provisional source.
3. Review all 17 hero lines against final mechanics and live presentation. Source data and a zero-exemption manifest do not establish live readability or a performance result.
4. Choose the actual release date, run the version mapping and required gates, produce and review the final poster with source/image ID, debug overlay and fit report, then obtain independent QA and serial integration. None of these are claimed here.
