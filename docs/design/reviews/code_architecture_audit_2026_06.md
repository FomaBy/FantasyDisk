# Code Architecture Audit — 2026-06

Дата: 2026-06-13  
Версия аудита: 0.1.4  
Источник: SCRUM-174 / `docs/tasks/audit_code_architecture_refactor_plan.md`  
Scope: read-only audit; gameplay/UI code was not changed.

## Summary

Проект уже держит вертикальную версию core loop, но архитектура перегружена тремя монолитами:

| File | Lines | Main Risk |
| --- | ---: | --- |
| `scripts/ui_screens.gd` | 4320 | все экраны, HUD, настройки, магазин, level-up, кодекс и стили в одном классе |
| `scripts/progression_data.gd` | 2320 | персонажи, оружие, награды, артефакты, экономика, ascension, formulas и budget harness в одном файле |
| `scripts/class_weapon.gd` | 1969 | 48 non-Berserk weapon modes, deployables, VFX, damage helpers и cleanup в одном runtime script |
| `tests/runtime_smoke_test.gd` | 4824 | один mega-smoke блокирует быстрый targeted feedback и повышает риск случайных конфликтов |

Главный риск не в одном конкретном баге, а в стоимости изменений: любая новая UI/weapon/progression задача сейчас почти неизбежно трогает общий файл, создает merge-конфликты и приводит к parse/type regressions.

## Findings

### P1 — `ui_screens.gd` стал god-object экранами всего проекта

Evidence:
- Main menu, Codex, settings, pause, character select, weapon select, level-up, elite reward, shop, event/rest/upgrade, victory/death and HUD are all in `scripts/ui_screens.gd` (`_show_main_menu` at line 110, `_show_codex_screen` at 827, `_show_settings_menu` at 1066, `_show_level_up_screen` at 1589, `_show_shop_screen` at 1923, `_create_hud` at 3799).
- The same file also owns style helpers, runtime HUD snapshots, artifact tooltips, input rebinding, cursor setup and video settings.

Impact:
- UI regressions have repeatedly appeared as layout/parse issues because unrelated screens share the same file.
- Tests must instantiate large portions of UI to validate a small widget.
- Feature ownership between Back-end UI logic and Design visual integration is harder to enforce.

Recommended split:
- `scripts/ui/main_menu_screen.gd`: main menu, version label, "What New" entry, global background.
- `scripts/ui/hero_select_screen.gd`: character select, ascension selector, radar, weapon entry.
- `scripts/ui/settings_screen.gd`: video/audio/input tabs and persistence bridge.
- `scripts/ui/codex_screen.gd`: codex tabs/builders.
- `scripts/ui/level_up_screen.gd`: level-up cards, defer logic, elite artifact reward.
- `scripts/ui/shop_screen.gd`: shop wall item placement and purchase flow.
- `scripts/ui/noncombat_screens.gd`: rest/upgrade/event.
- `scripts/ui/run_hud.gd`: resource HUD, timer, artifact row, damage flash.
- `scripts/ui/common_styles.gd`: shared StyleBox builders and constants.

Acceptance for refactor tasks: preserve node names used by runtime smoke, no gameplay changes, all existing smoke suites green.

### P1 — `class_weapon.gd` mixes weapon identity with shared engine concerns

Evidence:
- `_attack()` dispatches by string `attack_mode` and routes into dozens of `_fire_*` functions (`scripts/class_weapon.gd:143-180`).
- New class weapons are implemented as methods inside the same script (`soldier` at 726, `thief` at 824, `sniper` at 1060, `engineer` at 1434).
- Effects/deployables cleanup is also local to the monolith (`_register_effect`, `_release_effect`, `_alive_effects` at 1925-1948).

Impact:
- Adding one weapon can break parse/type inference for every weapon.
- Reusable mechanics such as corridor scan, delayed telegraph, chain target, deployable lifetime and heal-on-hit are duplicated across modes.
- Behavior identity is data-driven at `progression_data`, but runtime implementation is still method-driven and centralized.

Recommended split:
- Keep a thin `ClassWeapon.gd` facade for scene compatibility.
- Move shared target/damage helpers to `scripts/weapons/weapon_runtime_helpers.gd`.
- Move mode executors to domain files:
  - `scripts/weapons/modes/beam_modes.gd`
  - `scripts/weapons/modes/zone_modes.gd`
  - `scripts/weapons/modes/chain_modes.gd`
  - `scripts/weapons/modes/deployable_modes.gd`
  - `scripts/weapons/modes/class_special_modes.gd`
- Replace the long `match attack_mode` with a registry map `{attack_mode: Callable}`.

### P1 — `progression_data.gd` is both registry and formula engine

Evidence:
- Character configs start at `scripts/progression_data.gd:134`.
- Weapon dictionaries and `WEAPONS_BY_CLASS` span line 305 through 1023.
- Rewards/artifacts/ultimates/ascensions/shop all live in the same file from 1025 onward.
- Formula and budget code lives in the same file (`derived_parameters` at 2117, budget hit model around 1947-2053).

Impact:
- Small content changes to a class, artifact, shop item or formula all conflict in one file.
- Balance harness depends directly on production config and auto-tuning, making it harder to distinguish live balance from model balance.
- Docs drift is harder to audit because the source contains several domains.

Recommended split:
- `scripts/data/character_data.gd`
- `scripts/data/weapon_data.gd`
- `scripts/data/reward_data.gd`
- `scripts/data/artifact_data.gd`
- `scripts/data/shop_data.gd`
- `scripts/data/ascension_data.gd`
- `scripts/stat_formulas.gd` remains formula owner; move budget-only estimators to `tools/balance_model.gd` or `scripts/data/balance_model.gd`.
- Keep `progression_data.gd` as compatibility facade for existing callers until tests and references are migrated.

### P2 — hot-path group scans are common in weapon/player/boss logic

Evidence:
- `class_weapon.gd` repeatedly scans `get_tree().get_nodes_in_group("enemies")` for targeting, AoE, pull/compress, chain and DoT helpers.
- `player.gd` scans enemies for counter/thorns/ultimates.
- `boss.gd` checks summoned groups during boss behavior.

Impact:
- Current enemy counts are likely acceptable for prototype size, but dense waves plus deployables can create frame spikes.
- Repeated array allocation from `get_nodes_in_group` is avoidable in hot combat paths.

Recommended fix task:
- Introduce a combat target registry owned by combat director or main scene.
- Provide cached live enemy arrays per frame and typed helper queries: nearest, radius, corridor, line segment.
- Preserve group membership for compatibility and tests.

### P2 — UI layout tests are improving, but layout logic remains screen-local

Evidence:
- HUD no-overlap and shop wall no-overlap tests exist in runtime smoke.
- Layout helpers are local methods in `ui_screens.gd` rather than a reusable UI test/helper module.

Impact:
- Future screens may repeat older mistakes unless no-overlap helpers become reusable and easier to call.

Recommended fix task:
- Extract no-overlap/global-rect assertions into a shared test helper script.
- Add per-screen no-overlap fixtures for main menu, settings, codex, patch notes, shop, level-up, route map, victory/death.

### P3 — asset and style fallback paths are scattered

Evidence:
- Runtime UI icon/asset paths exist across `ui_screens.gd`, `ui_icon_registry.gd`, `progression_data.gd`, scenes and docs.
- Dynamic asset patterns such as `artifact_%s.png` are intentional, but not centrally declared for audit tooling.

Impact:
- Cleanup tools can produce false positives or false negatives.

Recommended fix:
- Maintain one backend-owned dynamic resource manifest for generated/dynamic path patterns and critical fallback assets.

## Proposed Child Tasks

Created in `docs/tasks/`:

1. `backend_refactor_ui_screens_domain_split_task.md`
2. `backend_refactor_class_weapon_mode_registry_task.md`
3. `backend_refactor_progression_data_domain_split_task.md`
4. `backend_refactor_combat_target_query_cache_task.md`

All are versioned 0.1.4 and should be serialized because they touch shared files.
