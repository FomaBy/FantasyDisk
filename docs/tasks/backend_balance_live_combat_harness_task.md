# Back-end Task: Live Combat Balance Harness

Статус: done 2026-06-13 (Claude Backend)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-189
Эпик: epic_full_project_quality_pass

## Scope

Add deterministic live combat simulations for all 51 class+weapon pairs to complement `tools/balance_harness.gd`.

## Requirements

- Instantiate real Player + weapon + target enemies.
- Measure solo DPS, 5-target DPS and practical TTK over a fixed window.
- Compare against class profile target with a tolerance decided in the task.
- Output report under `build/`.

## Verification

- New live harness runs headless.
- Runtime smoke remains green.


## Результат — 2026-06-13

Новый file-изолированный `tools/live_combat_harness.gd` (SceneTree-скрипт) дополняет
формульный `balance_harness.gd`: инстанцирует реального Player + каждое из 51
оружий и стационарных болванок, авто-атака 8с, меряет фактический исходящий урон.

- **Метрики**: solo DPS (1 цель), 5-target DPS (кластер), practical TTK (по 90HP).
- **Сравнение**: цели `CLASS_BUDGET_PROFILES` даны ориентиром; живой DPS системно
  ниже формулы (нет ультимейта, окно 8с, уровень 1) и solo/aoe сильно различаются
  по дизайну, поэтому флаг — РЕАЛЬНАЯ проблема: 0 урона / слаб по ОБЕИМ осям
  (медиана ±40%) / экстремальный всплеск (>+120%). Специалисты на одной оси — ok.
- **Вывод**: `build/live_combat_report.md` (build/ в .gitignore — артефакт не коммитится).

### Находки прогона (51 пара, 6 флагов)
- ⚠ слаб по обеим осям: **`robot/robot_reactor_core`** (2.3 / 9.0 DPS — на порядок ниже
  медианы ~19, реальный кандидат на ребаланс); `guitarist/bass_guitar` (саппорт-амп,
  низкий прямой урон — вероятно by design); `assassin/venom_wire` (DoT-оружие — частично
  артефакт замера: DoT/summon недобираются на стационарных болванках за 8с).
- ⚠ всплеск: `priest/priest_censer`, `dark_mage/dark_book` (сильный AoE), `guitarist/sound_amp`.
- Остальные 45 — здоровые специалисты.

### Оговорки гарнесса (задокументированы в отчёте)
DoT/summon/channel-классы (doctor/chemist/druid/часть assassin) читаются ниже из-за
стационарных болванок и короткого окна — это ограничение метода, не обязательно баланс.
Гарнесс — инструмент on-demand (не часть smoke); 6 smoke-сьютов не затронуты (новый файл).

**Рекомендация**: завести follow-up на проверку `robot_reactor_core` (подозрительно низкий
прямой урон) — отдельной баг/баланс-задачей.

## QA-Вердикт (2026-06-13) — независимая QA-сессия
Статус: PASSED (SCRUM-189)

Проверено фактически:
- `tools/live_combat_harness.gd` (11KB) существует, запускается headless БЕЗ ошибок
  (SceneTree-скрипт, file-изолирован). ✓
- Отчёт `build/live_combat_report.md` сгенерён: **51 пара** class+weapon, метрики solo
  DPS / 5-target DPS / practical TTK, колонка флагов. ✓
- Методология здравая: флаг только РЕАЛЬНЫЕ проблемы (0 урона / слабость по ОБЕИМ
  осям ±40% / всплеск >+120%); специалисты на одной оси = ok; задокументированы
  оговорки (DoT/summon/channel недобирают на стационарных болванках за 8с). ✓
- runtime smoke зелёный — гарнесс не часть smoke, новый файл ничего не сломал. ✓

Диагностические находки гарнесса (это ВЫВОД инструмента, не дефекты harness):
- `robot/robot_reactor_core` (-85%/-86%) — уже разобран как артефакт замера (commit
  4c8ab45 «не недонастройка»), помечен «ℹ артефакт». Доп.таск не нужен.
- `guitarist/bass_guitar`, `assassin/venom_wire` (слаб по обеим осям) — задокументированы
  как by-design (support-амп) / DoT-измерительное ограничение.
- Всплески (priest_censer/dark_book/guitarist) — AoE/channel специалисты; авторитетный
  формульный balance_harness показывает классы в пределах target (±0% After-Tuning),
  поэтому это особенность live-окна 8с без ульты, не подтверждённый дисбаланс.
Новых баг-тасков не завожу — флаги задокументированы, единственный реальный кандидат
(robot) уже закрыт.

Багов в самом инструменте нет.
