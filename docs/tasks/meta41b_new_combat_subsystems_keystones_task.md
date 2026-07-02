# Мета 4.1b (SCRUM-835): keystone-пары на НОВЫХ боевых подсистемах

Статус: done
Приоритет: high
Роль: Back-end (Codex)
Версия: 0.2.0
Создано: 2026-07-02
Jira: SCRUM-835
Контур: Codex
Owner: Codex backend subagent Gauss
Thread/Worker: `019f23d3-fd1f-7483-be4f-676550f3b319`
Branch/worktree: `codex/scrum-835-combat-keystones` / `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-835-combat-keystones`
Locked paths: `scripts/player.gd`, `scripts/class_weapon.gd`, `scripts/enemy.gd`, `scripts/meta_progression_tree_data.gd`, `scripts/summoner_weapon.gd`, `scripts/ui_screens.gd`, `tests/meta_skill_tree_smoke_test.gd`, `tests/skill_tree_per_hero_test.gd`, `docs/design/systems/meta_constellations.md`, `CHANGELOG.md`

## Контекст

Продолжение SCRUM-834 (834a — keystone на существующих хуках). Остались пары
PM-таблицы (docs/tasks/meta41_conditional_keystones_task.md, раздел
«PM-таблица»), чьи условия/эффекты требуют НОВЫХ боевых подсистем в player.gd.
QA-урок 834: generic-ключи вместо смысловых механик = FAIL; каждая пара обязана
вести себя по описанию таблицы.

## Scope — по подсистеме за коммит (сдавать инкрементально!)

1. On-hit дебафф врага (soldier «Подавление»: −урон врагам, поражённым за 2с).
2. Gold-scaling (thief «Джекпот»: +урон от текущего золота, cap; downside цены).
3. Метка/резонанс стихий + орбы (elementalist «Резонанс»/«Монолит»).
4. Конверсия лечения в урон + ward-усиление (priest «Мученик»/«Заступник»).
5. Жар реактора + магнит-радиус (robot «Перегрев»/«Сверхпроводник»).
6. Темп устройств + лимит/взвод мин (engineer «Автоматизация»/«Минёр»).
7. Распространение DoT по смерти + длительность луча (dark_mage).
8. Ширина ауры/отброс + ритм-серия (guitarist — если не закрыт в 834a).
9. Окно невидимости после shadow_burst (assassin «Теневой шаг»).
10. Пробой заряженного выстрела + капканы (ranger).
11. Drain-цели + surgical-удар в упор (doctor).
12. Площадь детонации облаков + усиление гомункула (chemist).
13. Бафф питомцев/briar-зон (druid — сверить с существующими pet-ключами,
    возможно мапится без новой подсистемы).
14. Провокация «Бастиона» (knight) — если не закрыта в 834a.

## Правила

- Каждая подсистема: разводка ключей в player.gd + строка приложения B +
  поведенческий тест (эффект есть ТОЛЬКО при условии) + коммит с зелёными
  гейтами (godot_gate сериализованно, grep SCRIPT ERROR). Push после каждого
  куска — частичная сдача ЖЕЛАТЕЛЬНА (PM-решение), финальная QA-приёмка по
  полноте таблицы.
- Бюджет §6: коридор [0.10..0.40] и спред ≤1.25 держать зелёными после каждой
  подсистемы (веса условных ключей = аптайм × вес урона, как в 834-базе).
- Числа таблицы — якоря ±30%.

## Acceptance

1. Все пары PM-таблицы, не закрытые 834a, ведут себя по описанию (поведенческие
   тесты по типу условия).
2. Приложения A/B актуальны; CHANGELOG; гейты зелёные; сдача `Статус: done` +
   Jira → «Контроль качества».

## Claim / старт

- 2026-07-02: Codex worker взял SCRUM-835 по dispatcher-директиве пользователя.
  SCRUM-834/834a уже в Jira `Контроль качества`, активного owner у SCRUM-835 не
  было; Jira label `hold` снят, задача переведена в `В работе`.
- Locked paths: `scripts/player.gd`, `scripts/meta_progression_tree_data.gd`,
  `tests/meta_skill_tree_smoke_test.gd`, `docs/design/systems/meta_constellations.md`,
  `CHANGELOG.md`, этот task mirror.

## Blocked / upstream QA failure

- 2026-07-02: parent reported and live Jira confirmed SCRUM-834/834a re-check
  failed QA (`origin/dev` includes `e70ebc35 qa(SCRUM-834): record 834a recheck failure`);
  SCRUM-834 returned to `К выполнению`.
- SCRUM-835 is not eligible to continue/finalize until Jira explicitly clears the
  dependency. Implementation stopped before tests/commit/push/QA status.
- WIP retained only as local useful draft in worktree
  `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-835-combat-keystones`
  on branch `codex/scrum-835-combat-keystones`; branch is behind `origin/dev` by
  the SCRUM-834 QA failure commit and was not rebased to avoid disturbing WIP.

## Result / evidence

- 2026-07-02: dependency cleared by SCRUM-834 subagent; branch rebased on
  `origin/codex/scrum-834-real-node-smoke` (`acd8e023`, main fix `4180468e`),
  then integrated `origin/codex/scrum-836-hidden-feats` (`86f0c7ae`) and latest
  `origin/dev` (`60f90ae7`, SCRUM-834 QA re-check cherry-pick) before final tests.
- Implemented SCRUM-835 semantic PM-table effects for the new combat subsystem
  slice: soldier suppression, thief gold cap/shop downside, elementalist
  resonance/orbs, priest heal→holy chain/ward, robot reactor heat/magnet,
  engineer devices/mines, dark_mage DoT spread/beam, guitarist aura/riff,
  assassin execute/invisibility, ranger charged pierce/traps, doctor drain/
  surgery, chemist cloud/homunculus, druid pets/briars, knight Bastion defense
  + taunt.
- Added `tests/meta_skill_tree_smoke_test.gd` SCRUM-835 semantic behavioral gate
  and adjusted `tests/skill_tree_per_hero_test.gd` downside accounting for
  signed semantic penalties.
- Updated `docs/design/systems/meta_constellations.md` Appendix A/B and
  `CHANGELOG.md`.
- Verification:
  `tests/meta_skill_tree_smoke_test.gd` PASS;
  `tests/skill_tree_per_hero_test.gd` PASS;
  `tests/meta_progression_smoke_test.gd` PASS;
  `tests/meta_points_per_ascension_test.gd` PASS;
  `tests/global_damage_balance_smoke_test.gd` PASS;
  `tests/global_survivability_balance_smoke_test.gd` PASS;
  `tests/survivability_scenario_test.gd` PASS;
  `tools/balance_harness.gd` PASS/report generated;
  `tools/survivability_harness.gd` PASS/report generated;
  `tests/runtime_smoke_test.gd` PASS.
- Disk cleanup: transient untracked `.import` sidecars removed; ignored `.godot/`
  cache and generated ignored harness reports removed before final report.

## QA-Вердикт (2026-07-02, Claude QA)

Статус: PASSED

- Доставка: реализация со стрэнд-ветки `origin/codex/scrum-835-combat-keystones`
  (`fa5ca1f3`) влита в dev cherry-pick'ом ОДНОГО коммита поверх `f48bd5f9` —
  без чужих веточных коммитов (SCRUM-836 hidden feats и 834-веточные SHA в dev
  не тащились). Конфликт CHANGELOG разрулен: убран 836-блок, формулировка про
  «integrating SCRUM-836» заменена на фактическую (cherry-pick поверх 834);
  auto-merge tree_data/per_hero_test/meta_constellations проверен на чистоту от
  836-контента (hidden-звёзды в dev остались 834-версии).
- QA-фикс в поставке: `ui_screens._random_shop_items` — `skill_modifiers_for_class`
  включает Атлас + созвездие, прямое умножение дублировало аккаунтную скидку
  лавки (atlas_m4/m5/n1, до −6%) для ВСЕХ классов без keystone; заменено на
  классовую дельту (retro-поведение сохранено, downside thief «Джекпот» +20%
  к ценам работает).
- Ревью diff: 25 semantic keystone-пар по PM-таблице (14 подсистем scope);
  retro-compat — все новые ключи спят при отсутствии (default 0.0 →×1.0);
  `enemy.take_damage(amount, feedback:={})` совместим с Dictionary-фидбеком
  execute/holy-chain; зависимости (`StatusEffects.snapshot`/`apply_status`
  stack_mode=extend, `skill_modifiers_for_class`, `_find_nearest_enemy_from`,
  `_vfx_parent`) существуют в dev.
- Гейты в изолированном worktree от dev после `--import` (fdengine-семафор,
  1 слот, все exit 0, 0 SCRIPT ERROR): `meta_skill_tree_smoke_test` ×2 PASSED
  (анти-флак, включая новый `_test_semantic_combat_keystones_835` и
  `_test_shop_discount` поверх QA-фикса), `skill_tree_per_hero_test` PASSED
  (signed downside accounting), `runtime_smoke_test` PASSED
  (duplicate-artifact guard 14552 файлов).
- Примечания (не блокеры): «Бастион»-taunt в single-player контексте = маркер +
  ускорение подхода врагов (провокация «к игроку» присуща архитектуре);
  `medkit_healing_mult` доктора применяется в drain-heal тракте (downside
  реален и тематичен); generic `extra_projectile` теперь добавляет цепи
  drain-link (ранее мёртвый для drain-оружия апгрейд — улучшение).
