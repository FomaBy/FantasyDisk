# BUG: Assassin critical shadow VFX runtime smoke assertion fails

Статус: done
Приоритет: high
Роль: Back-end (VFX/runtime smoke)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Animator handoff (Codex)
Jira: SCRUM-409

## Контекст

Во время Animator-интеграции accepted character SpriteFrames для SCRUM-291 /
SCRUM-282 / SCRUM-294 animation smoke проходит, но полный runtime smoke падает
на Back-end/VFX-owned assertion Assassin critical shadow. SCRUM-291/Guitarist
был добавлен сюда только после того, как Designer 2 recorded final accepted
source-sheet handoff и Animator rebuilt runtime SpriteFrames from that final
sheet.

Команда:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Фактический результат:

```text
ERROR: Expected Assassin critical shadow hook to keep a non-moving combat/VFX effect.
GDScript backtrace:
  [0] _fail (res://tests/runtime_smoke_test.gd:7012)
  [1] _test_unique_class_identity_patterns (res://tests/runtime_smoke_test.gd:3594)
```

## Scope

Back-end/VFX:
- проверить `Player.trigger_assassin_crit_shadow()` и `AttackVfx.ring_pulse/slash`
  ownership/parenting относительно `get_tree().current_scene`;
- восстановить runtime smoke assertion без изменения урона, баланса, targeting или
  Animator SpriteFrames;
- если тест устарел из-за легитимного VFX lifecycle/parenting изменения, обновить
  тест в Back-end scope и документировать причину.

Animator не должен менять gameplay/VFX lifecycle, damage, cooldowns или targeting.

## Animator Status

Blocked Animator verification:
- SCRUM-291 `art_char_redraw_anim_guitarist_task.md`;
- SCRUM-282 `art_char_redraw_anim_assassin_task.md`;
- SCRUM-294 `art_char_redraw_anim_ranger_task.md`.

Animator-owned validation already PASS:
- animation manifest validator for `build/qa/scrum291/animation_manifest.json`;
- animation manifest validator for `build/qa/scrum282/animation_manifest.json`;
- animation manifest validator for `build/qa/scrum294/animation_manifest.json`;
- `tests/animation_smoke_test.gd`.

## Dispatcher Handoff — 2026-06-14

Documentation dispatcher accepted this as a feature-block-eligible QA/runtime
smoke blocker, not a new feature. Routed to Back-end window
`019eabd9-780b-78a2-9f4b-e7203d659ef2`.

## Result

2026-06-14 — Fixed in Back-end scope. `Player.trigger_assassin_crit_shadow()`
now parents the crit shadow ring/slash VFX to the combat-local player parent
when available, falling back to the standard player VFX parent only if needed.
No damage, balance, targeting, cooldown, SpriteFrames, manifests or Animator
assets were changed.

The failing runtime smoke assertion was also made lifecycle-safe: it now records
pre-existing VFX instance IDs and asserts that the Assassin hook spawned a new
VFX node, instead of requiring the total `*Vfx` count to increase. That old
count check was stale because unrelated short-lived VFX can expire during the
0.15s wait while Assassin VFX is created, leaving the total count unchanged.

Verification:
- PASS — `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- PASS — `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/attack_vfx_smoke_test.gd`

Unblocks Animator verification for SCRUM-291, SCRUM-282 and SCRUM-294 from this
Back-end runtime smoke blocker.


## QA-Вердикт (2026-06-14)
Статус: PASSED — assassin crit shadow VFX fix, runtime_smoke зелёный

Проверено (фактически):
- **Фикс**: `Player.trigger_assassin_crit_shadow()` репарентит crit shadow ring/slash
  VFX к combat-local родителю (`get_parent() if get_parent() is Node2D else _vfx_parent()`),
  с fallback на стандартный VFX-родитель. Тест-ассерт переписан: проверяет, что хук
  заспавнил НОВУЮ VFX-ноду (а не рост общего `*Vfx` count, который был ложно нестабилен
  из-за истечения короткоживущих VFX за 0.15s).
- **Тесты**: `runtime_smoke_test` PASS (ассасин-ассерт 7012 больше не падает),
  `attack_vfx_smoke_test` PASS, `animation_smoke_test` PASS.
- HEAD без фикса был зелёным; регресс вносил character-redraw WIP, 409 его чинит —
  едут одним батчем.

Acceptance:
- [x] Assassin crit shadow VFX спавнится и привязан к корректному родителю.
- [x] runtime_smoke + attack_vfx smoke зелёные; ассерт устойчив.

Статус done. Баги: нет.
