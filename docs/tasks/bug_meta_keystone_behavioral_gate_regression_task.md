# BUG: behavioral gate Meta 4.1 загрязняет reactor heat и pierce fixtures

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1029
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-1029`
Приоритет: high
Роль: Back-end
Найдено QA при тестировании: SCRUM-1024

## Scope And Locks

Claimed scope: `tests/meta_keystone_behavioral_smoke_test.gd`, this mirror and
focused meta test documentation. Production reactor, player, weapon, target
query and balance paths remain read-only: diagnosis proved fixture lifecycle
contamination rather than a production combat defect. Real outcome assertions
and thresholds remain unchanged.

## Reproduction

На fresh `origin/dev` `b243d6e26`, три из трёх прогонов с отдельным scratch
`user://`:

```bash
HOME=<scratch> XDG_DATA_HOME=<scratch> \
  python3 tools/godot_gate.py --headless --path . \
  --script res://tests/meta_keystone_behavioral_smoke_test.gd
```

## Expected

Обязательный SCRUM-837 live mini-arena gate проходит: активный reactor heat
увеличивает исходящий и входящий урон, а enabled pierce поражает ожидаемые цели.

## Actual

Детерминированно 3/3:

```text
Reactor heat did not increase real weapon damage (cold 16.30, hot 16.30).
Reactor heat downside did not increase incoming damage (cold 8.08, hot 8.08).
```

Дополнительно в двух из трёх прогонов:

```text
Pierce scenario enabled hit 0 targets.
```

SCRUM-1024 не меняет `player.gd`, weapon/meta runtime или этот гейт; дефект
зарегистрирован как отдельная baseline-регрессия.

После параллельного production batch и rebase на `origin/dev` `ee508d559`
повторная серия подтвердила reactor heat failures `3/3` с теми же значениями;
enabled pierce также упал `3/3`. Задача остаётся воспроизводимым release-gate
дефектом, отдельным от Atlas UI.

На production `b5e032ed5` pierce иногда проходил, но fresh import снова дал
`enabled hit 0`; точная диагностика ниже объясняет обе формы одним lifecycle
дефектом и не требует runtime-правки.

## Confirmed Root Cause

The live mini-arena did not own the complete lifetime of its fixtures:

- `_make_weapon()` added the custom Reactor probe and then awaited a frame while
  that probe's callbacks were live against unrelated enemies (the surrounding
  player/target fixture lifecycle was likewise not owned). The supposed cold
  sample began at heat `0.994` with `_reactor_heat_active = true`; cold and hot
  were therefore both valid hot production outcomes.
- The earlier swarm scenario left all `SwarmCounter_*` enemies alive. Beam
  corridor selection sorted those behind/contact-range leftovers before the
  three pierce probes and spent the hit limit on them, leaving the measured
  targets untouched.

Production heat accumulation, active-state damage/incoming multipliers, beam
targeting and pierce limits behaved correctly when given an isolated arena.

## Implementation Result

- Added opt-in manual-fixture isolation that pauses automatic callbacks before
  every awaited frame while keeping nodes in scene/physics space for explicit
  production method calls.
- Reactor oracle now proves zero initial heat, cold hit/incoming outcomes,
  charge above `0.70`, runtime transition to active state, then distinct hot
  outgoing and incoming outcomes.
- Swarm fixtures are released and flushed after their own assertion, so they
  cannot consume later beam hit limits.
- Pierce enabled/disabled scenarios isolate player, custom weapon and targets;
  they still call the real `_fire_single_beam()` and inspect live enemy health.
- No production script, data, threshold or balance value changed.

## Acceptance Criteria

- focused reactor scenario доказывает production active-state transition и
  разные cold/hot outgoing + incoming combat outcomes;
- focused pierce scenario детерминированно поражает ожидаемые live targets;
- обязательный `meta_keystone_behavioral_smoke_test.gd` проходит 3/3 на
  отдельных scratch `user://` без dictionary-only подмены;
- `meta_skill_tree_smoke_test.gd` и полный runtime smoke остаются зелёными;
- Jira/документация/green-gate синхронизированы, результат landed в `dev`.

## Verification

- `meta_keystone_behavioral_smoke_test.gd`: PASS 3/3 on isolated scratch
  `user://`; enabled and disabled mutation/self-check paths are green.
- `meta_skill_tree_smoke_test.gd`: PASS.
- `runtime_smoke_test.gd`: PASS (known non-fatal dummy-renderer null-texture
  screenshot diagnostic only).
- Two independent pre-land reviews: logic PASS; the second review corrected the
  root-cause wording above from an assumed equipped weapon to the actual custom
  Reactor probe. No production-code or balance finding remains.
- `git diff --check`: PASS.

Disk cleanup: pending final `.godot` and worktree removal after push/routing.
