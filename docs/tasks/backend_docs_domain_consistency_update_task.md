# Back-end Task: Domain Docs Consistency Update

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4

## Done (2026-06-13, Claude)

Рефреш доменных доков под 0.1.4 (commit 203fb398, только документация):
- `combat.md` (06-11→06-13): boss-ростер (rift_warden + ashen_colossus/
  bone_archon/brood_mother) с hazard-зонами, мини-элитки, секция elite/boss
  escalation (hit-stop/camera shake/фазы), обновлённые тесты (фокус-сьюты
  SCRUM-202, projectile/hazard смоки, балансовые харнессы).
- `progression_balance.md` (06-12→06-13): доменный сплит progression_data
  (SCRUM-198) как source-of-truth, древо умений (SCRUM-150) + патч-ноуты
  (SCRUM-159), секция Balance Validation (харнессы).
- Кросс-линк `reviews/mechanics_balance_audit_2026_06.md` добавлен в оба.
- `characters_weapons.md` / `menus_ui.md` / `audio.md` — уже актуальны (06-13);
  `current_game_state.md` / `technical_architecture.md` уже отражают сплит и
  древо умений (поддерживаются актуальными). Доки именуются `progression_balance`/
  `menus_ui` (а не `progression_economy`/`ui_menus` из scope — это те же файлы).
- Content ID использованы из верифицированного кода; канонический реестр —
  `content_registry.md`. Gameplay/код не менялись.
Создано: 2026-06-13
Автор: Back-end audit SCRUM-175
Jira: SCRUM-195
Эпик: epic_full_project_quality_pass

## Scope

Refresh domain docs after the 0.1.4 class/content/UI growth.

## Documents

- `docs/design/systems/characters_weapons.md`
- `docs/design/systems/combat.md`
- `docs/design/systems/progression_balance.md`
- `docs/design/systems/menus_ui.md`
- `docs/design/systems/audio.md`
- `docs/design/systems/enemies_bosses.md`
- `docs/design/systems/technical_architecture.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/current_game_state.md` as concise index/current summary.

## Requirements
QA: in_progress (2026-06-13)

- No gameplay/code changes.
- Cross-link reports from `docs/design/reviews/`.
- Keep content IDs aligned with `content_registry.md`.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## Blocked / Serialized (2026-06-13)

Blocked until the active content/UI queue stops moving the facts this task must
summarize. SCRUM-192 is closing character sprite registry drift, SCRUM-193 is
blocked on safe asset cleanup, and SCRUM-222 is blocked on a rejected UI kit.
Running the broad domain-doc refresh now would produce stale docs immediately.

Next unblock: resume after the active content/UI blockers above are either done
or explicitly deferred. Narrow task-local docs updates continue inside each
implementation task.

## PM Override / Redispatch (2026-06-13)

Пользователь уточнил: всю текущую board нужно доделать в версии `0.1.4`.
Redispatch в существующий Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` как финальный последовательный queue item
после SCRUM-230, SCRUM-198, SCRUM-199 и SCRUM-193. Keep reasoning High/no low.
Задача должна закрыть оставшиеся domain-doc расхождения текущей board, затем
обновить task/board/Jira sync.

## Back-end Follow-up Verification (2026-06-13, Codex)

После Claude refresh дополнительно выровнены оставшиеся stale-строки:

- scope-файлы исправлены на фактические доменные документы:
  `progression_balance` и `menus_ui`
  (старые имена `progression_economy` / `ui_menus` больше не указаны как
  реальные файлы);
- `current_game_state`, `content_registry`, `audio`, `characters_weapons`,
  `enemies_bosses`, `technical_architecture`, `visual_style_assets` выровнены
  под текущий `dev` stabilization target 0.1.4;
- убраны stale `0.2` формулировки из текущего ростера/branching docs;
- `enemies_bosses` обновлен под 5 боссов и 6 mini-elite kinds, с явной пометкой,
  что SCRUM-193 cleanup не удаляет pending source PNG новых boss/mini-elite;
- `CHANGELOG.md` обновлен.

Проверки:
- text grep for stale release/version wording and phantom doc names — passed
  (оставшиеся совпадения только в именах smoke-тестов и numeric timing values);
- `tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 361e45c7 (ветка dev)

Проверено (фактически, docs-задача — без Godot, кроме content-ID alignment):
- **8/8 domain-доков** существуют (`characters_weapons`, `combat`,
  `progression_balance`, `menus_ui`, `audio`, `enemies_bosses`,
  `technical_architecture`, `visual_style_assets`) + `current_game_state.md`
  (индекс).
- **Нет phantom-имён в живых доках**: `progression_economy.md`/`ui_menus.md` как
  реальные файлы не упоминаются в `docs/design/systems/` (только корректные
  `progression_balance`/`menus_ui`).
- **Нет stale-версий**: grep `0.1.2` / phantom `0.2` по системным докам и
  `current_game_state` — чисто (остатки только числовые тайминги вида `0.2с`).
- **No gameplay/code changes**: `git status` code/scenes/assets = 0 изменений
  (docs-only, commit 203fb398).
- **Content-ID alignment**: `content_registry_consistency_test` — passed
  (0 allowlisted), IDs выровнены с `content_registry.md`.

Acceptance:
- [x] Domain-доки обновлены/выровнены; current_game_state — индекс.
- [x] No gameplay/code changes.
- [x] Content IDs выровнены с content_registry.

Примечание (не блокер, вне scope): историчный `docs/design/reviews/
content_docs_audit_2026_06.md:83-84` всё ещё перечисляет старые scope-имена
`progression_economy.md`/`ui_menus.md` — это замороженный audit-артефакт, не
живой системный док; на консистентность текущих доков не влияет.

Баги: нет.
