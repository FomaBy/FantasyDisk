# Баг: описание апгрейд-карточки вылезает за safe rect на 1536×864 (флаки матрицы)

Статус: done
Роль: Back-end
Контур: Claude
Lane: claude
Версия: 0.2.0
Создано: 2026-07-02
Автор: QA-наблюдение при прогонах SCRUM-806
Labels: foma, backend, claude

## Симптом

`tests/ui_no_overlap_matrix_test.gd` интермиттентно красный на экране
`upgrade_economy` при 1536×864:

```
ERROR: upgrade_economy (1536, 864): expected UpgradeChoiceButton{0,1} child
UpgradeChoiceButton{N}Description to stay inside scaled wide-card safe rect
[P: (241.9|625.9, 416.6), S: (284.3, 186.7)].
```

Флакует, потому что карточки берутся из `_random_level_up_rewards(3)`
(`_show_upgrade_screen`, scripts/ui_screens.gd:5939) с `rng.randomize()` —
падает только когда выпадает апгрейд с достаточно длинным описанием.
Наблюдение 2026-07-02: 1 красный из 3 прогонов на одной ревизии
(упавшая кнопка меняется: Button0/Button1 — зависит от выпавших наград).

## Что сделать

1. Воспроизвести детерминированно: перебрать пул level-up/upgrade наград
   (`_random_level_up_rewards` источник) и найти награды, чьё описание при
   scale 0.6 (1536×864) не влезает в safe rect карточки 284×187.
2. Починить вёрстку: автоперенос/уменьшение шрифта описания (или clip с
   тултипом) в карточке `UpgradeChoiceButtonNDescription`, НЕ растягивая
   генерённый фрейм по одной оси (правило размеров UI-ассетов).
3. Прогнать `ui_no_overlap_matrix_test` несколько раз (флаки!) — все зелёные.

## Где

- `scripts/ui_screens.gd:5939` `_show_upgrade_screen()` + билдер карточек
  (`UpgradeChoiceButton*`, `_economy_choice_card_contract_error` в матрице).
- `tests/ui_no_overlap_matrix_test.gd` — контракт safe rect (строки ~479-487).


## Исправление (2026-07-02, claude-backend)

Коммиты c31e18c2 + 91feb291 (scripts/ui_screens.gd). `_make_economy_choice_card`
+ `_fit_economy_choice_card_content` (ready-callback, CONNECT_ONE_SHOT,
Callable.bind — без freed-lambda): описание ужимается по шрифту (до 9px), затем
режется по строкам с многоточием (OVERRUN_TRIM_ELLIPSIS) до влезания в safe-зону
карточки по реальному `content.get_combined_minimum_size()`; полный текст — в
tooltip. Фрейм по осям не растягивается (правило UI-ассетов соблюдено).

## QA-Вердикт (2026-07-02, claude-qa) — PASSED

Статус: PASSED

Проверено на origin/dev @ 4c005582 (фиксы c31e18c2/91feb291 — ancestors) в
изолированном worktree.

- `ui_no_overlap_matrix_test` (флаки по RNG наград) прогнан 5× подряд через
  godot_gate (fdengine, SLOTS=1) — 5/5 exit 0, «UI no-overlap matrix test passed».
  upgrade_economy @1536×864 (упавший ранее срез) больше не продавливает safe rect.
- Фикс детерминирован (fit-callback от реального minimum size), не зависит от
  выпавших наград → устраняет саму флак-причину, а не маскирует RNG.
- Код-ревью: ready.connect(method.bind(button), CONNECT_ONE_SHOT) — канонический
  безопасный Callable, не lambda-capture; null/valid-гварды на месте.

Статус → Готово.
