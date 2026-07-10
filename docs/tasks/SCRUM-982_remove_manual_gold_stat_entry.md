# SCRUM-982 — убрать ручной вход платной докачки

Статус: done
- Контур: `Codex`
- Owner: `/root/scrum982_remove_gold_stat`
- Combined scope: `SCRUM-982` + `SCRUM-987` + `SCRUM-988`
- Locked paths: `scripts/ui_screens.gd`, `scripts/route_map_screen.gd`, focused tests, Attribute Shop/Route Map documentation and evidence.

## Контракт

- Удалить повторный вход Attribute Shop с Route Map, Rest, Shop, Event и Escape/menu paths.
- Сохранить обязательный Attribute Shop после обычной/элитной победы.
- Сохранить `LevelUpPlusButton` при непотраченных level-up на Route Map и Rest.
- Не удалять save-поля `attribute_offer`/`attribute_rerolls_left`: старые сохранения должны загружаться безопасно.

## Evidence

- Removed the only live manual entry points from Route Map and Rest; Shop/Event/Escape already had none.
- Route Map now calls `_update_level_up_button()` directly; Rest retains it through `_create_menu_run_hud()`.
- Mandatory normal/elite post-combat `_show_attribute_shop` flow and legacy save fields remain intact.
- Focused combined test, Route Map shell test, runtime smoke, progression/economy smoke and UI no-overlap matrix: PASS.
- Independent read-only code review: PASS after gold-shell Level Up descendant containment fixes.
- Disk cleanup: removed task `.godot` import cache; disposable worktree retained only through `dev` landing.
