# BUG: runtime_smoke assassin crit shadow VFX assertion остаётся флейки

Статус: done
Приоритет: low
Роль: Back-end / QA tooling
Версия: 0.1.5
Создано: 2026-06-14
Автор: QA (находка при батч-QA character-animation, follow-up к SCRUM-409)
Jira: SCRUM-410
QA: in_progress (2026-06-14)
Связано: SCRUM-409

## Контекст
SCRUM-409 переписал ассерт «Assassin critical shadow hook to keep a non-moving
combat/VFX effect» (`tests/runtime_smoke_test.gd:~3602`) с count-based на
node-spawn-based, чтобы убрать флейк от истечения короткоживущих VFX за `0.15s`.
Улучшение реальное, НО ассерт **всё ещё периодически падает**: при QA-батче
character-animation HEAD-прогон runtime_smoke упал 1 раз из ~4 (≈20-25%), затем
3/3 чистых ре-рана прошли. Это привело к ложной квалификации «красного HEAD».

## Severity / Impact
Низкий по геймплею (VFX-фикс корректен), но **средний по надёжности QA-гейта**:
флейки-ассерт в runtime_smoke вызывает спорадические ложные red-гейты у всех
агентов (QA, воркеры), маскирует настоящие регрессы и заставляет перегонять тесты.

## Гипотеза причины
Окно `await create_timer(0.15).timeout` + детект «новой *Vfx Node2D» зависит от
тайминга: при медленном/загруженном headless-прогоне crit-shadow VFX может быть
создан/освобождён вне окна замера, или combat-local parent ещё не готов.

## Что нужно
1. Сделать ассерт детерминированным: например, не полагаться на 0.15s окно —
   проверять синхронно сразу после `trigger_assassin_crit_shadow()` что VFX-нода
   создана (по имени/группе/мете), либо ждать сигнала/кадра появления, а не таймера.
2. Если VFX короткоживущий — увеличить/зафиксировать его lifetime на время теста
   или проверять факт спавна, а не наличие в момент T+0.15s.
3. Прогнать runtime_smoke ≥10 раз подряд — 0 фейлов (де-флейк подтверждён).

## Acceptance Criteria
- [x] `tests/runtime_smoke_test.gd` assassin crit shadow ассерт детерминирован.
- [x] 10/10 последовательных прогонов runtime_smoke зелёные.
- [x] Геймплей/VFX-поведение не изменено (только устойчивость проверки).

## Files
- `tests/runtime_smoke_test.gd` (ассерт ~3594-3610)
- `scripts/player.gd` (`trigger_assassin_crit_shadow` — при необходимости hook для теста)

## Verification
```bash
for i in $(seq 1 10); do ~/Downloads/Godot.app/Contents/MacOS/Godot --headless \
  --user-data-dir /private/tmp/flk$i --path "$PWD" --script res://tests/runtime_smoke_test.gd \
  2>&1 | grep -c "Runtime smoke test passed"; done   # ожидается 10× "1"
```

## Dispatch Log
- 2026-06-14 — Dispatcher routed SCRUM-410 to Back-end window
  `019eabd9-780b-78a2-9f4b-e7203d659ef2`. Eligible during 0.1.5 feature block
  because this is a QA/runtime smoke flaky bug follow-up to SCRUM-409, not new
  feature work. Scope: deterministic runtime smoke assertion only; no gameplay,
  balance, art, animation, release or refactor work.

## Result
- 2026-06-14 — Back-end fixed the flaky runtime assertion in
  `tests/runtime_smoke_test.gd`: the Assassin crit-shadow smoke now disables the
  equipped weapon auto-process for this isolated hook check, clears the hook
  cooldown before the manual trigger, and asserts newly spawned VFX immediately
  after `trigger_assassin_crit_shadow()` instead of waiting through a fragile
  `0.15s` lifetime window. Gameplay/VFX code, damage, balance, class mechanics,
  art and animation assets were not changed.
- Verification:
  - `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/attack_vfx_smoke_test.gd` — PASS.
  - `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
  - `for i in $(seq 1 10); do ... --user-data-dir /private/tmp/fantasydisk_scrum410_$i ... runtime_smoke_test.gd ...; done` — PASS 10/10.

## QA-Вердикт (2026-06-14)
Статус: PASSED — ассерт детерминирован, 10/10 прогонов зелёные

Проверено (фактически):
- **10/10 runtime_smoke**: прогнал `runtime_smoke_test.gd` десять раз подряд
  (изолированные user-data-dir) — **10/10 «Runtime smoke test passed»** (было ≈20-25%
  флейк-фейлов). Де-флейк подтверждён.
- **Фикс детерминирован** (`tests/runtime_smoke_test.gd`): убран хрупкий
  `await create_timer(0.15).timeout`; теперь отключается `equipped_weapon` auto-process,
  сбрасывается `_assassin_crit_shadow_cooldown_left=0`, и spawned-VFX проверяется
  **сразу** после `trigger_assassin_crit_shadow()` (сбор имён новых *Vfx, проверка
  непустоты) — без зависимости от lifetime-окна.
- **Геймплей/VFX не тронуты**: изменён только тест (assertion), без правок
  gameplay/VFX/damage/balance/art.

Acceptance:
- [x] Assassin crit shadow ассерт детерминирован (без 0.15s окна).
- [x] 10/10 последовательных runtime_smoke зелёные.
- [x] Геймплей/VFX-поведение не изменено (только устойчивость проверки).

Статус done. Баги: нет. Флейк QA-гейта устранён (follow-up к SCRUM-409 закрыт).
