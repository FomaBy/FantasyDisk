# Test Coverage Audit — 2026-06

Дата: 2026-06-13  
Версия аудита: 0.1.5  
Источник: SCRUM-178 / `docs/tasks/audit_test_coverage_quality.md`  
Scope: read-only audit; tests were inspected but not modified.

## Existing Test Suites

| Suite | Approx Lines | Coverage Strength |
| --- | ---: | --- |
| `tests/runtime_smoke_test.gd` | 4824 | broad integration, many factual UI/node/data assertions |
| `tests/animation_smoke_test.gd` | 535 | sliced rigs, motion hooks, weapon pose variants |
| `tests/meta_progression_smoke_test.gd` | 134 | save/load, ascension data, player application |
| `tests/meta_skill_tree_smoke_test.gd` | 142 | tree integrity, purchase, save/load, power cap |
| `tests/melee_weapon_targeting_test.gd` | 175 | Berserk hit geometry and targeting |
| `tests/attack_vfx_smoke_test.gd` | 73 | VFX helper spawn and player fire paths |
| `tests/hazard_vfx_smoke_test.gd` | 38 | hazard VFX textured helper checks |

## System-To-Test Map

| System | Current Coverage | Gap |
| --- | --- | --- |
| Main menu / route map | Runtime smoke checks background, route generation, icons, limited paths | Patch notes not yet covered; route interaction could use mouse event tests after pan/scroll |
| Hero select | Runtime smoke checks v3 layout, thumbnails, radar, no labels | Needs no-overlap fixture across all supported viewport sizes after 17 heroes |
| Settings/audio/input | Runtime smoke checks tabs, sliders, persistence, reset audio, ultimate key | Good factual coverage; add isolated suite to reduce mega-smoke cost |
| Level-up | Runtime smoke checks pause, three reward cards, defer/reopen, icons | Current comments still mention three choices; if level-up five-options task resumes, tests need update |
| Shop | Runtime smoke checks frameless wall slots, purchase/hook states, no-overlap | Good; screenshot capture is skipped in headless, rect dump remains substitute |
| Codex | Runtime smoke checks sections, counts, monster abilities | Needs coverage for patch notes once implemented; codex image richness is not tested |
| Combat core | Runtime smoke covers pickups, damage, death/victory, boss timer omission | Missing long-running deterministic combat simulations |
| 51 weapons | Runtime smoke equips all and has focused mechanics tests for new classes | Many tests verify node/effect spawn and damage counts, but not measured live DPS/TTK |
| Balance/economy | Balance harness exists and runtime checks some data | No live route economy simulation; XP tempo and shop buying power rely on model |
| Content registry/assets | Animation smoke checks selected sprite paths; runtime checks some icons/backgrounds | No full registry-vs-code-vs-assets consistency suite |

## Findings

### P1 — runtime smoke is too broad and too expensive as the primary safety net

Evidence:
- `runtime_smoke_test.gd` calls dozens of independent checks from one `_initialize()` flow (`tests/runtime_smoke_test.gd:1040-1082`).
- The file is 4824 lines and mixes UI layout, combat, progression, settings, economy, class weapons and bosses.

Impact:
- One parse/runtime failure blocks visibility into unrelated systems.
- Developers are incentivized to run only the mega-smoke and skip targeted checks.
- Regressions can be hard to localize.

Recommended split:
- `tests/ui_smoke_test.gd`
- `tests/combat_smoke_test.gd`
- `tests/progression_smoke_test.gd`
- `tests/weapon_mechanics_smoke_test.gd`
- Keep `runtime_smoke_test.gd` as thin orchestrator or legacy umbrella.

### P1 — balance is model-tested, not live-tested

Evidence:
- `tools/balance_harness.gd` estimates DPS/EHP from formulas and deterministic hit counts.
- Runtime weapon tests instantiate weapons and enemies, but do not measure 30-second live DPS against moving targets for all 51 pairs.

Impact:
- Overkill, missed projectiles, delayed telegraphs, player movement, target switching and deployable lifetime can diverge from the model.

Recommended child task:
- Add live simulation tests for representative solo, 5-target and survival scenarios.

### P1 — content registry consistency has no automated gate

Evidence:
- `content_registry.md` lists 17 classes, 51 weapons, enemies, mini-elites, bosses, artifacts and UI assets.
- Tests validate some counts (`codex_data.monsters() == 26`, artifacts match progression data), but there is no full registry-to-file-to-resource resolver.

Impact:
- Docs can claim assets are active while code uses another path.
- Cleanup tools can report false positives for dynamic paths.

Recommended child task:
- Add a registry consistency smoke that checks canonical IDs, `ResourceLoader.exists` for static paths, dynamic pattern allowlists, and docs/code count parity.

### P2 — UI no-overlap checks are screen-specific

Evidence:
- Runtime smoke includes HUD and shop wall no-overlap checks, but not every modal/screen.

Impact:
- Past UI regressions were off-center/overlap bugs. New screens need cheaper reusable checks.

Recommended child task:
- Extract reusable `assert_no_overlap(nodes, ignored_pairs)` helper and add screen fixtures.

### P2 — tests still contain stale comments/messages in places

Evidence:
- Runtime route generation comment says "3 choice rows plus boss row" while assertion expects 11 rows (`tests/runtime_smoke_test.gd:49-53`).
- Level-up comments mention exactly 3 options in a project that also has a five-options task queued.

Impact:
- Stale test text slows triage and can hide outdated expectations.

Recommended child task:
- Test wording cleanup pass after active UI/progression tasks settle.

## Proposed Child Tasks

Created in `docs/tasks/`:

1. `backend_test_runtime_smoke_suite_split_task.md`
2. `backend_test_live_balance_simulation_task.md`
3. `backend_test_content_registry_consistency_task.md`
4. `backend_test_ui_no_overlap_matrix_task.md`
