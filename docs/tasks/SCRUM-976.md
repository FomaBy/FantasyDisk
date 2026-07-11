# SCRUM-976 — Gameplay sandbox runtime layer

Статус: done
Jira: SCRUM-976

Owner: root-next9
Thread/Worker: `/root`
Контур: Codex
Ветка/worktree: `codex/scrum976-gameplay-sandbox` / `FantasyDisk_worktrees/scrum-976-gameplay-sandbox`

## Решение

- Единый `scripts/gameplay_sandbox.gd` задаёт пять canonical keys, диапазоны,
  шаг `0.1`, normalize/reset/snapshot/metadata API.
- `GameSettings` хранит configured values; `Main.begin_new_run_session()` на
  подтверждении оружия создаёт отдельный immutable active-run snapshot.
- Autosave сохраняет active snapshot; старые autosave без поля читаются как
  нейтральные. Сброс Settings не меняет уже активный забег.
- Игрок получает final exact damage/attack-speed слой вне release softcaps;
  summon deploy/ally cadence также покрыты.
- Общий `Enemy` применяет HP/урон один раз ко всем ordinary/summoned/elite/boss
  путям. Attack speed меняет только cooldown countdown, не телеграфы/windup.
- Любой custom snapshot блокирует achievements, Codex и boss/meta/Ascension
  writes и публикует eligibility metadata; run-local экономика остаётся.

## Проверка

- `tests/gameplay_sandbox_scrum976_test.gd`: persistence, corrupt/clamp/snap,
  neutral/easier/harder/custom, immutable snapshot, autosave, player/enemy exact
  factors, summon cadence, cooldown-vs-windup, progression guards.
- Регрессионные и runtime-gates выполняются перед routing в QA.

Результат:

- focused SCRUM-976 — PASS;
- settings/autosave/achievements/meta/damage/contact/boss/elite/mini-elite/
  summon/Ascension — PASS;
- runtime boss+elite и progression+economy suites — PASS;
- global damage и global survivability balance — PASS;
- полный `tests/runtime_smoke_test.gd` на финальном диффе — PASS (известная
  безвредная dummy-renderer диагностика null texture при headless screenshot);
- независимый pre-land review — PASS после исправления neutral summon parity,
  final exact flat-damage, custom victory truth и elite reflect-thorns bypass.

## Jira/Git evidence

Implementation complete; commit/push `origin/dev`, Jira QA routing and cleanup
are performed at the task boundary.
