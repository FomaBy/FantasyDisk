# Artifact System: универсальный артефакт-пул с rarity-скейлингом (32 семьи)

Статус: done
Приоритет: p1
Роль: Back-end
Версия: 0.2.1
Создано: 2026-07-09
Jira: SCRUM-960
Контур: Claude
Owner: claude-fable-orchestrator
Thread/Worker: claude-backend-scrum960-universal-pool-20260709
Locked paths: `scripts/progression_data_content.gd`, `scripts/progression_data.gd` (сэмплеры), `scripts/player.gd:1230`, `tests/*`, docs.

## Context / Problem

Старый универсальный пул — неровный рукописный набор (`+5 стата`, `+50% урона`,
`+37% скорости атаки`), редкость не масштабирует значения, 18 tier-1 записей носят
английские title. Нужен чистый универсальный пул, доступный каждому классу, где
бонусы к базовым статам и производным атрибутам скейлятся редкостью по единому
задокументированному правилу. Контракт значений финализирован SCRUM-959:
`docs/design/systems/artifact_system_matrix.md` (§1 правила/схема/ролл, §2 семьи,
§3 сохранённые, §7.1 объём этой задачи).

## Required Change

- `scripts/progression_data_content.gd`: универсальный блок `ARTIFACTS` → 32 семьи
  по схеме §1.3 (`rarity_scaling: true` + `tiers {1,2,3}`, корень = т1-база для
  legacy-читателей); значения строго §1.2 (стат +2/+4/+7; процент ×1.10/×1.18/×1.30;
  долевой флет +0.10/+0.18/+0.30; плоский флет ≈0.75×/1.25×/2.0× level-up карточки);
  русские названия из §2 (Warrior Charm → «Оберег воина» и т.д.); `swift_ink`
  удаляется (поглощён семьёй `fast_boots`, §1.6); 37 сохранённых (§3) без изменений;
  16 легаси классовых не трогать (их удаляет SCRUM-961). Итог: 85 записей.
- `scripts/progression_data.gd`: static `materialize_family_offer(family, tier)`
  (плоский оффер `{id, title, tier, cost=COST_BY_TIER[tier], description, stats|mods,
  rarity_scaling}`); ролл тира при выдаче в `reward_pool()`, `shop_items()`,
  `elite_artifact_choices()` (тир-ролл × depth-weight), `boss_completion_*` (семьи
  фиксированно т3); распределение — нормализованные `TIER_WEIGHTS`;
  `artifact_definition(id)` возвращает запись семьи как есть. Сигнатуры сэмплеров
  не меняются (ascension-параметры добавит SCRUM-961) — ролл прозрачен для старых
  вызовов.
- `scripts/player.gd:1230`: `artifacts.append` дописывает `tier` из reward, если
  присутствует; читатели переживают записи без tier.
- Тесты §7.1: интегрити-тесты знают `tiers`-схему; новый
  `tests/artifact_family_roll_test.gd`.
- Доки: `progression_balance.md` `## Artifacts` (модель семей/ролла/тир-канона),
  `content_registry.md` §Артефакты (32 семьи со значениями т1/т2/т3 + retained +
  легаси с пометкой «удаляются в SCRUM-961»).

## Acceptance Criteria (Jira)

- Минимум один универсальный артефакт на каждый базовый стат и каждый производный
  атрибут (8 + 24 = 32 семьи).
- Значения скейлятся редкостью по единому задокументированному правилу, не
  случайными числами.
- Универсальные артефакты доступны каждому классу.
- Классовые (class-only) артефакты не попадают в универсальный пул по ошибке.
- Существующие источники наград по-прежнему выдают три уникальных выбора.
- Focused progression/economy и artifact-pool тесты зелёные.
- Обновлены `docs/design/systems/progression_balance.md` и content registry.

## Result / Evidence

**Данные** (`scripts/progression_data_content.gd`): 32 семьи (8 стат-семей +2/+4/+7,
24 атрибут-семьи по §2.2 с ключами level-up карточек) + 37 сохранённых + 16 легаси
классовых = 85 записей; `swift_ink` удалён. Корень каждой семьи зеркалит tiers[1]
(гейт от дрейфа в интегрити-тесте). Русские title мигрированных доноров — из §2
дословно.

**Ролл** (`scripts/progression_data.gd`): `roll_artifact_family_tier(weights={})`
(нормализация даёт ≈0.64/0.29/0.08) + `materialize_family_offer(family, tier)`;
`reward_pool`/`shop_items` — ролл по TIER_WEIGHTS, вес семьи в пуле 1.0;
`elite_artifact_choices` — ролл по `TIER_WEIGHTS × _elite_tier_depth_weight`
(существующая формула глубины); `boss_completion_artifact_rewards/choices` — семьи
фиксированно т3 (cost 95). `artifact_definition` без изменений поведения.

**player.artifacts** (`scripts/player.gd`): запись `{id, title[, tier]}`; tier > 0
пишется из reward, legacy-награды без tier дают запись без ключа. Читатели
(`ui_screens.gd:12561 _player_artifacts`, снапшоты `main.gd:652/713`,
`combat_director.gd:1189`, `pause_stats_menu.gd:808`) читают id/title через `.get()`
— tier опционален, совместимость подтверждена тестом (е).

**Иконки**: 15 новых семей получили placeholder-копии существующих PNG + `.import`
(battle_fan, iron_scale, arcane_prism, ram_horn, executioner_edge, ghost_ribbon,
venom_vial, plague_metronome, falcon_feather, wide_halo, war_banner, aegis_shard,
troll_blood, thirsty_ruby, overcharge_rune) — прецедент SCRUM-500; уникальный арт
рисует SCRUM-962 (§6: эти 15 в списке NEW).

**Тесты** (все через `python3 tools/godot_gate.py --headless --path . --script res://tests/<name>.gd`, все PASS):

- `rewards_data_integrity_test` — PASS (85 артефактов; tiers-схема: корень зеркалит
  т1, каждый тир непустой; дубли id/tier/cost по корню записи)
- `content_rewards_integrity_test` — PASS (85; численные значения и валидные статы
  по каждому тиру семьи)
- `artifact_family_roll_test` (НОВЫЙ) — PASS: (а) 32 семьи × 3 тира материализуются
  с валидными tier/cost/description и непустыми stats|mods; (б) правило §1.2 на
  warrior_charm 2/4/7, splinter_gloves 1.10/1.18/1.30, sturdy_amulet 15/25/40;
  (в) elite_artifact_choices(0,3,"berserk") → 3 уникальных id (20 прогонов);
  (г) boss-пул: 32 семьи только т3; (д) reward_pool: все семьи материализованы,
  ролл на 300 выборках даёт все три тира с убыванием т1>т2>т3; (е) apply_reward
  пишет tier, legacy-награда без tier — запись без ключа
- `route_chest_artifact_test` — PASS (1-из-3 сундук жив)
- `null_artifacts_snapshot_test` — PASS
- `runtime_smoke_progression_economy_test` — PASS (16 событий EV-инварианта)
- `event_random_artifact_empty_pool_test` — PASS (стаб дополнен
  `record_codex_artifact_discovery` — контракт ui_screens.gd:8964 добавлен
  2026-06-28 ПОСЛЕ написания гейта; пре-существующий red, не регрессия 960)
- `weapon_integrity_test` — PASS (17 классов, 51 оружие)
- `progression_data_api_surface_test` — PASS
- `runtime_smoke_test` (полный смок, гейт autoland) — PASS
- бонус: `content_registry_consistency_test` — PASS (иконки всех 85 id на месте);
  `codex_data_smoke_test` — PASS (92 артефакта = 85 + 7 shop)

**Коммиты** (origin/dev):

- `24fb768f` — SCRUM-960 универсальный пул: 32 семьи артефактов с роллом редкости
  (данные + сэмплеры + player.tier + тесты + placeholder-иконки)
- доки + зеркало задачи — следующий коммит этой ветки работ

**Заметки для SCRUM-961** (следом трогает те же файлы): сигнатуры сэмплеров не
менялись — добавлять `ascension_level`/`cross_class_ids` опциональными параметрами;
`is_reward_relevant` всё ещё только doctor-фильтр; легаси-блок помечен комментарием
в `ARTIFACTS` (после 32 семей); ролл семей уже отделён от плоских записей ветками
`rarity_scaling` во всех четырёх сэмплерах — гейт по возвышению вставлять ДО
материализации. Для SCRUM-963: `player.artifacts[].tier` уже пишется; TIER_LABELS
канон «Обычный/Редкий/Эпический»; reward-карточки всё ещё берут иконку стата
(`_reward_icon_id`), а не `artifact_<id>.png`.

## QA-Вердикт (SCRUM-964)

Статус: PASSED
Дата: 2026-07-09
Проверил: claude-fable-orchestrator (claude-qa-scrum964-artifact-validation-20260709).
32 семьи материализуются на всех трёх тирах по §1.2 (сверены warrior_charm 2/4/7,
splinter_gloves ×1.10/1.18/1.30, sturdy_amulet +15/+25/+40, fast_boots — дословно);
доля т3 в reward_pool = 7.7% на 2705 роллах (коридор §8.5: 5-12%), t1/t2 = 64.4/27.9%.
Батарея зелёная: artifact_family_roll, rewards/content integrity (154+7),
progression_economy (EV-порог обновлён под пак-12 SCRUM-995, фикс 2c2d30de), смоук.
Латиницы в title ARTIFACTS+SHOP_ITEMS ноль. Evidence: docs/tasks/SCRUM-964.md.
