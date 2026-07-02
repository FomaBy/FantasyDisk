# Мета 4.1d (SCRUM-837): behavioral smoke реальных боевых эффектов keystone

Статус: done
Приоритет: medium
Роль: Back-end/QA (Codex)
Версия: 0.2.0
Создано: 2026-07-02
Jira: SCRUM-837
Контур: Codex
Owner: backend/QA Codex subagent Hooke
Thread/Worker: 019f23d3-ff17-70e2-b0ef-f8970bc7e894
Branch/worktree: `codex/scrum-837-behavioral-gate` / `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-837-behavioral-gate`
Locked paths: `tests/meta_skill_tree_smoke_test.gd`, `tests/` (новый behavioral-тест), `tools/` (хелперы сценариев)

## Контекст

QA-фейл SCRUM-834, блокер 3: conditional-smoke проверял синтетические словари
модификаторов, а не реальное поведение в бою. После 834a (существующие хуки)
и 834b (новые подсистемы) нужен гейт, который ловит «ключ разведён, но в бою
не работает» и защищает СМЫСЛ PM-таблицы от регрессий/повторного сплющивания.

## Scope

1. Новый behavioral-тест (SceneTree, headless): мини-арена, спавн игрока
   нужного класса с купленным keystone, симуляция условия, ассерт на фактический
   исход боя (урон по врагу-болванке / полученное лечение / скорость атаки /
   количество целей), а не на словарь модификаторов. Минимум 1 сценарий на
   КАЖДЫЙ тип условия из таблицы: HP-порог, стойка, окно-после-события,
   счёт-в-радиусе, on-hit дебафф, gold-scaling, метка стихии, жар, темп
   устройств, DoT-распространение, невидимость, пробой, drain, детонация, баффы
   питомцев.
2. Downside-проверки: негативный эффект тоже реален (лечение лавки режется,
   max HP ниже и т.д.) — по одному ассерту на пару.
3. Анти-сплющивание: ассерт, что у пары k0/k1 каждого класса СИГНАТУРЫ эффектов
   различаются и содержат класс-специфичный ключ (не только 4 generic).
4. Встроить в QA-протокол: прогон через godot_gate, grep SCRIPT ERROR, флаки
   максимум 2 ретрая; тяжёлые сценарии — по одному инстансу.

## Acceptance

1. Тест зелёный на dev и падает при намеренном отключении разводки любого
   ключа (самопроверка «гейт ловит потерю»: минимум 3 мутационных прогона в
   Evidence).
2. Гейты зелёные; CHANGELOG; сдача `Статус: done` + Jira → «Контроль качества».

## Claim / старт

- 2026-07-02: SCRUM-837 переведён в Jira `В работе` по пользовательскому
  dispatcher override для Codex subagent.
- Locked paths: `tests/meta_skill_tree_smoke_test.gd`,
  `tests/meta_keystone_behavioral_smoke_test.gd`, `docs/process/qa_protocol.md`,
  `docs/design/systems/meta_constellations.md`, `CHANGELOG.md`, этот task mirror.
- Dependency: финальный green/QA-ready статус остаётся gated SCRUM-835. 837
  может готовить тестовую архитектуру, но финальные assertions должны пройти
  только поверх commit/push SCRUM-835 с реальными semantic combat subsystem keys.

## Evidence / QA PASSED

- Добавлен новый planned gate `tests/meta_keystone_behavioral_smoke_test.gd`:
  SceneTree mini-arena с real Player/Enemy/ClassWeapon/SummonerWeapon nodes.
  Сценарии покрывают HP threshold, stance, post-event/rush window,
  count-in-radius, on-hit debuff, gold scaling, elemental mark, reactor heat,
  device tempo, DoT spread, invisibility, pierce, drain, cloud detonation и pet
  buffs. Downside checks: healing reduction, max HP reduction, reactor incoming
  damage. Mutation/self-check safe equivalent: disabled on-hit debuff,
  disabled gold scaling, disabled pierce wiring.
- `tests/meta_skill_tree_smoke_test.gd` теперь содержит lightweight contract:
  semantic SCRUM-835 keys должны быть wired и присутствовать в k0/k1 целевых
  классов, иначе gate ловит generic flattening до тяжёлого behavioral smoke.
- 2026-07-02 WIP branch `codex/scrum-837-behavioral-gate` обновлён поверх
  SCRUM-834 fix `acd8e023` и текущего `origin/dev` (`4d8ef831`). Validation:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_keystone_behavioral_smoke_test.gd`
  = expected dependency-red, 162 errors, no `SCRIPT ERROR`;
  `meta_skill_tree_smoke_test.gd` = expected dependency-red on
  `enemy_hit_damage_down`, no `SCRIPT ERROR`; `skill_tree_per_hero_test.gd` =
  passed; `runtime_smoke_test.gd` = passed. Final QA handoff still waits for
  SCRUM-835 final commit/push and green behavioral assertions.
- 2026-07-02 finalization: branch rebased onto `origin/dev@0e6cdaab`
  (SCRUM-835 hardening). Rebase conflicts were bookkeeping-only
  (`CHANGELOG.md`, `docs/process/jira_sync_map.json`); production runtime was
  not changed in the final pass.
- Minimal final test updates in `tests/meta_keystone_behavioral_smoke_test.gd`:
  anti-flattening now treats SCRUM-835 class semantic keys as semantic even when
  their names end with `_mult`; conditional tests reapply weapon scaling after
  changing live meta conditions; gold scaling asserts the real `_damage_enemy`
  multiplier path; reactor downside compares hot incoming damage against a cold
  baseline with random dodge/invulnerability disabled.
- Final validation, all green via `python3 tools/godot_gate.py`:
  `tests/meta_keystone_behavioral_smoke_test.gd`,
  `tests/meta_skill_tree_smoke_test.gd`,
  `tests/skill_tree_per_hero_test.gd`,
  `tests/runtime_smoke_test.gd`.
- Log grep: no `SCRIPT ERROR`, no `Parse Error`, no `ERROR:` in
  `/tmp/scrum837_meta_keystone_behavioral.log`,
  `/tmp/scrum837_meta_skill_tree.log`,
  `/tmp/scrum837_skill_tree_per_hero.log`,
  `/tmp/scrum837_runtime_smoke.log`. `git diff --check` passed.
- Mutation/self-check evidence: the behavioral gate includes disabled-wiring
  checks for on-hit debuff, gold scaling, and pierce wiring; the final green run
  proves those self-checks still execute successfully on top of SCRUM-835.

## QA-Вердикт

Статус: PASSED
Дата: 2026-07-02
Проверка: финальный Codex QA/finalization subagent.

- Branch/commit: `origin/codex/scrum-837-behavioral-gate-final@d2fa25a1`
  поверх `origin/dev@0e6cdaab`.
- Production runtime changes: none in the final pass.
- Tests: `meta_keystone_behavioral_smoke_test.gd`,
  `meta_skill_tree_smoke_test.gd`, `skill_tree_per_hero_test.gd`,
  `runtime_smoke_test.gd` — PASSED via `python3 tools/godot_gate.py`.
- Log grep: no `SCRIPT ERROR`, no `Parse Error`, no `ERROR:`.
- Static check: `git diff --check` PASSED.
