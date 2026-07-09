# Artifact System: классовые артефакты Возвышения-5 (85 = 17 × 5)

Статус: done
Приоритет: p1
Роль: Back-end
Версия: 0.2.1
Создано: 2026-07-09
Jira: SCRUM-961
Контур: Claude
Owner: claude-fable-orchestrator
Thread/Worker: claude-backend-scrum961-class-artifacts-20260709
Locked paths: `scripts/progression_data.gd` (гейт+сэмплеры), `scripts/progression_data_content.gd` (ARTIFACTS), `scripts/player.gd`, `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `scripts/summoner_weapon.gd`, `scripts/sentry_turret.gd`, `scripts/ally_minion.gd`, `scripts/combat_director.gd`, `scripts/ui_screens.gd` (call sites сэмплеров), `assets/sprites/ui/icons/artifacts/` (удаление легаси), `tests/artifact_ascension_gate_test.gd`, `tests/class_artifacts_test.gd`, `tests/runtime_smoke_test.gd` (:тир-гейт, :affinity-note), `tests/runtime_smoke_triggered_artifacts_test.gd`, `tests/event_random_artifact_empty_pool_test.gd` (стаб), docs.

## Context / Problem

Каждому классу нужна своя артефакт-идентичность. Классовые артефакты не должны
быть доступны на Возвышении 0 и попадают в пулы только после прогресса класса.
Контракт финализирован SCRUM-959: `docs/design/systems/artifact_system_matrix.md`
(§1.4 гейтинг, §1.6 удаление легаси, §4 — 85 строк механик ДОСЛОВНО, §5 контракт
`stolen_crest`, §7.2 объём, §8.4 анти-runaway капы).

## Required Change (сделано)

- **Гейт (§1.4):** `is_reward_relevant(reward, character_id, ascension_level := 0,
  cross_class_ids := [])` — пустой affinity → true; id в cross_class_ids → true;
  иначе класс∈affinity И мета-Возвышение ≥ `requires_ascension`. Опциональные
  хвосты у всех 5 сэмплеров (`reward_pool`/`shop_items`/`elite_artifact_choices`/
  `boss_completion_artifact_rewards`/`boss_completion_artifact_choices`); call
  sites `ui_screens.gd` передают `game.ascension_level_for(...)` (метовый уровень)
  и `cross_class_artifact_ids` забега (live player либо `run_player_snapshot`).
- **Данные:** 85 записей §4 в `ARTIFACTS` (id/title/tier/cost=COST_BY_TIER/
  affinity/requires_ascension:5/mods; 7 активных с триггерами, включая новый
  `on_battle_start`); удалены 16 легаси классовых записей и 17 иконок
  (16 легаси + `swift_ink`) с source-референсами и строками манифеста SCRUM-340.
- **Хуки (69 NEW-ключей §4):** `player.gd` (rage-стаки по образцу kill_momentum,
  тень-двойник, метка охотника, longshot, ремонтный щит по образцу priest_ward,
  lowhp-защита, триаж-прайм drain-хила, рифф-темп, молитва on_battle_start +
  `_effective_healing_multiplier`), `combat_director.gd` (диспетч `on_battle_start`,
  transient-ключи снапшота), `class_weapon.gd` (боомеранг-возврат, споры/сеть/
  колония/расщепление, монета/дым/паралич, ампы/ритм-эхо/резонанс, пила/пар,
  дрон/мины-персист/утилизация/чертёж, луна/капканы, дальнобой/наводчик/осколки,
  дубль-выстрел (кап 0.65)/шрапнель/фитиль/штык, палочка/зеркало книги, пыль/
  кислота/прозрачная лужа, земля-орбита/крест/метеор-кратер/отдачник, пресс/якорь/
  реактор-ротация, кадило/реликварий/двойной колокол), `berserk_weapon.gd`
  (спектральный топор, вес молота, тройной укол, спираль кистеня),
  `summoner_weapon.gd` (волчий состав стаи, гомункул-танк, гомункул-реактор вне
  лимита), `sentry_turret.gd` (магазин 14+6+чертёж), `ally_minion.gd` (taunt-пульс).
- **Cross-class (§5):** `stolen_crest` — `apply_reward` роллит 2 случайных чужих
  классовых id в `run_modifiers["cross_class_artifact_ids"]` (Array напрямую,
  мимо float-коэрции), сэмплеры пропускают ровно их до конца забега.
- **Анти-runaway (§8.4):** duplicate ≤0.65 суммарно; take_hit_pulse кламп ≤1.0;
  DoT-спреды extend без рекурсии; взрывы (wand/mirror/twin bell/дубль) бьют
  напрямую и не порождают взрывов; капы стаков: rage 5, acid 5, resonance 3,
  inhibitor 3, мины 5, капканы 4, спираль кистеня +36%.

## Acceptance (проверено)

- Возвышение 0: ни один классовый не попадает в reward/shop/chest/elite/boss
  пулы; Возвышение 5+: все 5 своих во всех сэмплерах; чужому классу — никогда
  (кроме явного cross-class ролла) — `tests/artifact_ascension_gate_test.gd`.
- 85 записей requires_ascension=5 по 5 на класс, mods ложатся в run_modifiers,
  17 удалённых id отсутствуют, рискованные хуки капятся —
  `tests/class_artifacts_test.gd`.
- Батарея зелёная: runtime_smoke, artifact_family_roll, rewards/content integrity,
  triggered_artifacts (нов. триггеры), weapon_integrity, api_surface, route_chest,
  event_random_artifact, progression_economy, codex_data, content_registry
  consistency, asset_reference_integrity.

## QA-Вердикт (SCRUM-964)

Статус: PASSED
Дата: 2026-07-09
Проверил: claude-fable-orchestrator (claude-qa-scrum964-artifact-validation-20260709).
Гейт-свип 17 классов × {asc0, asc4-spot, asc5} × 4 сэмплера — 2 прогона PASSED:
asc0/asc4 чисты (0 утечек, включая исчерпывающие elite/boss-пулы), asc5 — все 5
своих в reward/shop/elite, boss-пул t3 2/2 (chemist 3/3), чужих ноль; cross-class
(`stolen_crest`-контракт) пропускает ровно перечисленные id, в т.ч. на asc0.
Найден и исправлен баг: `mine_satchel` — чурн кап-5 вытеснял мины до армирования
2.5с (0 урона в бою); фикс skip-при-капе `2c2d30de`, верификация ×2 (888/898 урона
за 9с, кап держится, тайм-аут освобождает слот). Кит-баланс §8.1: berserk +35.6%,
engineer +31.5% (в коридоре); dark_mage +58.8/+66.5/+73.3% — зафиксированное
отклонение слайса замера (декомпозиция в SCRUM-964.md), warning по §8.3-паттерну.

## Files

- `scripts/progression_data.gd`, `scripts/progression_data_content.gd`
- `scripts/player.gd`, `scripts/combat_director.gd`, `scripts/ui_screens.gd`
- `scripts/class_weapon.gd`, `scripts/berserk_weapon.gd`, `scripts/summoner_weapon.gd`,
  `scripts/sentry_turret.gd`, `scripts/ally_minion.gd`
- `assets/sprites/ui/icons/artifacts/` (−17 легаси PNG/import, +85 import новых),
  `docs/design/references/icons/artifacts/` (−17 source, манифест 53→36)
- `tests/artifact_ascension_gate_test.gd` (new), `tests/class_artifacts_test.gd` (new),
  `tests/runtime_smoke_test.gd`, `tests/runtime_smoke_triggered_artifacts_test.gd`,
  `tests/event_random_artifact_empty_pool_test.gd`
- `docs/design/content_registry.md`, `docs/design/artifact_shop_cursor_visual_kit.md`,
  `docs/design/systems/progression_balance.md`
