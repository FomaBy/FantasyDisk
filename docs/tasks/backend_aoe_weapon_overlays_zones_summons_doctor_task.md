# AOE Weapon Overlays, Persistent Zones, Summons, And Doctor Sustain

Статус: done
Версия: 0.2.1
Контур: Codex
Owner: backend/codex-aoe-summons-doctor-orchestrator
Thread/Worker: 019f29dd-7939-71f1-a89e-41acb59793a4
Locked paths: `scripts/attack_vfx.gd`, `scripts/berserk_weapon.gd`, `scripts/class_weapon.gd`, `scripts/progression_data.gd`, `scripts/progression_data_characters.gd`, `scripts/summoner_weapon.gd`, `scripts/main.gd`, `scripts/ui_screens.gd`, focused combat/balance tests, relevant design docs
Jira: SCRUM-854
Исполнитель: Codex

## Контекст

Пользовательская задача 2026-07-04: атаки всех персонажей должны понятнее показывать выбранное оружие и логичную область удара. Текущие weapon overlays в атаках слишком прозрачные, а некоторые melee/AOE формы визуально читаются как перевернутый серп, летящий в персонажа, вместо взмаха от персонажа наружу.

Одновременно нужно исправить длительные ground effects и призывы: лужи, мины и аналогичные зоны не должны исчезать при новой атаке, должны жить несколько секунд, тикать урон по врагам внутри и скейлиться от подходящих атрибутов. Summon-оружия должны лучше зависеть от Лидерства: максимальное количество, старт боя примерно с половиной лимита, темп добора, скорость движения/атаки и малое AOE у ударов.

Doctor sustain слишком сильный, если поверх его собственных drain-оружий выпадают внешние regeneration/vampirism rewards. Нужно убрать такие награды из roll-пула Доктора и обновить описание: Доктор лечится только собственными weapon mechanics.

## Требования

- [x] Все runtime attack weapon overlays сделать читаемее: целевой alpha около `0.60` для оружия/силуэта, где сейчас используется слишком прозрачный фон/текстура.
- [x] Пересмотреть направление и shape visuals для melee/AOE, особенно `berserk` sword/axe sweep: зона должна выглядеть как взмах наружу, с логикой "основание/концы у персонажа", без инверсии в сторону героя.
- [x] Ground pools/zones для acid/thorns/smoke/cloud-like атак живут по duration, тикают урон по врагам внутри и не заменяются новой атакой, если лимит не превышен.
- [x] Mines/traps не удаляются пачкой при следующей атаке; каждая мина/ловушка имеет собственный lifetime, trigger/tick behavior и cleanup group.
- [x] Duration lingering effects мягко скейлится от тематического атрибута: `Knowledge`/`dot_speed` для DoT-зон, `Perception`/`aura_radius` для больших областей, `Leadership`/`summon_amount` для deploy/summon-зон.
- [x] Summons/deploy minions: лимит зависит от `Leadership`/`summon_amount`; при старте боя появляется примерно половина текущего лимита, затем остальные добираются штатным темпом.
- [x] Permanent/non-expiring summons получают Leadership-scaled move speed, attack speed и маленький AOE/splash на hit, с капами против runaway.
- [x] Doctor не получает внешние level-up rewards/artifacts/shop rolls на regeneration/vampirism/lifesteal; собственный sustain `restore_potion`, `plague_syringe`, `bone_saw` остается.
- [x] Описания/tooltip data/docs явно говорят, что Doctor sustain идет от его оружия, а не от общих vampiric/regeneration роллов.
- [x] Обновить relevant docs: `docs/design/mechanics_extract.md`, `docs/design/current_game_state.md`, `docs/design/systems/characters_weapons.md`, `docs/design/systems/combat.md`, `docs/design/systems/progression_balance.md`.

## Acceptance Criteria

- [x] Focused weapon/VFX tests покрывают alpha/geometry contract для weapon overlays и berserk sweep orientation.
- [x] Focused zone/trap tests подтверждают: две последовательные зоны/мины сосуществуют, тикают damage, чистятся по lifetime/cleanup.
- [x] Focused summon tests подтверждают Leadership-scaled max count, стартовую half-quota и summon splash/tempo caps.
- [x] Focused Doctor reward tests подтверждают отсутствие external `regeneration`, `vampiric_amount`, `vampiric_chance` rewards for Doctor level-up/shop/artifact-like roll paths, если они применимы.
- [x] Required smokes pass through `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`; balance/director-required damage/survivability smokes run or blocker documented.

## Evidence

- Code:
  - `scripts/attack_vfx.gd`: weapon signature now has a normal body sprite at alpha `0.60`, shadow alpha `0.34`, subtle rim alpha `0.20`.
  - `scripts/berserk_weapon.gd`: exact `sweep` overlay is named and asserted as an outward wedge with alpha `0.60`.
  - `scripts/class_weapon.gd`: damage pools keep up to 6 active instances with `pool_duration`/tick metadata; Engineer pressure mines persist for lifetime and tick enemies inside instead of disappearing on first trigger.
  - `scripts/summoner_weapon.gd`: summon cap remains the existing Leadership-driven `Player` contract; `summon_amount` scales profile strength/tempo/lifetime/splash, summon weapons prefill about half the current cap at battle start and scope owned minions by weapon owner.
  - `scripts/progression_data.gd`, `scripts/ui_screens.gd`, `scripts/main.gd`: Doctor rolls filter external regeneration/vampiric/lifesteal sustain from level-up, artifacts, shop, elite choices, and start boons while preserving weapon self-sustain.
  - `scripts/progression_data_characters.gd`: Doctor description now states self-sustain only through weapon drain mechanics.
- Focused tests PASS:
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/attack_vfx_smoke_test.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/persistent_hazard_contract_test.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/summoner_strengthening_test.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/doctor_drain_softcap_test.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/attribute_relevance_test.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/start_boons_test.gd`
- Balance/director-required checks PASS:
  - `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd`
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd`
- Runtime smoke:
  - PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
- Review:
  - Subagent `Raman` performed read-only diff QA. Blocking pressure-mine lifetime finding was fixed in `scripts/class_weapon.gd` and covered by the stronger `tests/persistent_hazard_contract_test.gd` lifetime assertion; docs drift findings were fixed.
- Docs updated:
  - `docs/design/mechanics_extract.md`
  - `docs/design/current_game_state.md`
  - `docs/design/systems/characters_weapons.md`
  - `docs/design/systems/combat.md`
  - `docs/design/systems/progression_balance.md`
- Known local noise excluded from commit:
  - `source_docs/FantasyDisk_GDD.txt` has line-ending-only working-tree noise from the disposable checkout and is not part of this task.

## Execution Log

- 2026-07-04: Jira `SCRUM-854` created in active sprint and claimed by
  `backend/codex-aoe-summons-doctor-orchestrator`; working branch
  `codex/aoe-summons-doctor`, disposable checkout
  `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/aoe-summons-doctor`.
- 2026-07-04: Implemented backend/runtime changes, focused tests, balance checks,
  docs, subagent review fixes, and final runtime smoke. Backend scope is ready
  for QA after commit, push, and Jira transition to `Контроль качества`.

## QA-Вердикт 2026-07-04

Статус: PASSED

Evidence:
- Verified `origin/dev` at `7a9912da98e03975e9c2b1dfa1bca945b73130a3`
  contains `c6634fac` and `6228eac2`.
- Main-thread validation PASS:
  - `tests/attack_vfx_smoke_test.gd`
  - `tests/persistent_hazard_contract_test.gd`
  - `tests/summoner_strengthening_test.gd`
  - `tests/doctor_drain_softcap_test.gd`
  - `tests/attribute_relevance_test.gd`
  - `tests/start_boons_test.gd`
  - `tools/balance_harness.gd`
  - `tests/global_damage_balance_smoke_test.gd`
  - `tests/global_survivability_balance_smoke_test.gd`
  - `tests/runtime_smoke_test.gd`
- Independent read-only QA subagent `Godel` reran the same required set with
  `FSD_GODOT_SLOTS=1` and returned PASS.
- Residual non-blocking note: runtime smoke still logs the known Godot
  CallbackTweener `_apply_dot_tick` conversion errors, but exits 0 and reports
  `Runtime smoke test passed`.

Disk cleanup: main-thread temporary QA logs removed after final sync/commit;
subagent created no disposable clone/cache.
