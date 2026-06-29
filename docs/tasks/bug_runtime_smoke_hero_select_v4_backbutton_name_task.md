# BUG: runtime_smoke_test падает — back-button ноду переименовали в v4 (HS4BackButton), тест ищет старое имя HeroSelectBackButton

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.6
Создано: 2026-06-19
Jira: SCRUM-479
Найдено QA: при тестировании SCRUM-475
  (`docs/tasks/design_skeleton_friendly_dark_mage_knight_parts_task.md`)
Связано: SCRUM-343 (back-button frame), hero-select v3→v4 миграция

## Симптом

`tests/runtime_smoke_test.gd` детерминированно падает (exit 1):

```
ERROR: Expected hero select v4 to expose a back button.
   at: _fail (res://tests/runtime_smoke_test.gd) <- _test_back_button_frame_safety
```

Падает и на committed dev HEAD (проверено через stash всех несвязанных
WIP-правок рабочего дерева), то есть это не следствие незакоммиченных изменений
SCRUM-474/475, а регресс на самом dev.

## Корень

- `_test_back_button_frame_safety` (`tests/runtime_smoke_test.gd`) вызывает
  `_show_character_select()` и ищет `find_child("HeroSelectBackButton", ...)`.
- Активный экран выбора героя теперь строится в
  `scripts/ui_screens.gd:_build_character_select_v4()` (вызывается из
  `_show_character_select()` → `ui_screens.gd:985`), и его кнопка «Назад»
  называется **`HS4BackButton`** (`ui_screens.gd:745`).
- Имя `HeroSelectBackButton` принадлежит старому v3-билдеру
  (`ui_screens.gd:1225`), который `_show_character_select()` больше не вызывает.
- Итог: тест не находит ноду и падает. Сама кнопка «Назад» в v4 есть и работает
  (`pressed → _show_main_menu`), то есть функционально UI в порядке — красный
  даёт именно рассинхрон имени ноды в тесте после миграции v3→v4.

## Воспроизведение

1. На ветке dev (committed HEAD достаточно):
   `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_smoke_test.gd`
2. Тест валится на `_test_back_button_frame_safety` с
   «Expected hero select v4 to expose a back button.»

## Ожидание / Реальность

- Ожидание: umbrella `runtime_smoke_test` зелёный на dev.
- Реальность: красный, т.к. проверяется back-button по устаревшему имени ноды.

## Предлагаемый фикс (Back-end решает)

Один из двух (на усмотрение исполнителя, оба валидны):
- Обновить тест: искать `HS4BackButton` (каноническая v4-нода), а не
  `HeroSelectBackButton`; либо
- В `_build_character_select_v4()` присвоить back-кнопке стабильное канон-имя,
  ожидаемое тестом (и зафиксировать его как контракт).
Затем прогнать `runtime_smoke_test` + `animation_smoke_test` (оба зелёные).

## Окружение

- Ветка dev, commit 27e225d5 (+ незакоммиченный WIP SCRUM-474, но баг
  воспроизводится и без него — на чистом HEAD).
- Godot 4.6.3 headless, разрешение по умолчанию теста.
- Класс/уровень: не зависит (экран меню выбора героя).

## Dispatcher Routing (2026-06-19 22:29)

Documentation dispatcher routed SCRUM-479 to Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` as an eligible QA/runtime-smoke blocker.
Back-end owns the UI/test contract fix only: keep Hero Select v4 behavior intact,
avoid visual redesign scope, and run `runtime_smoke_test` plus relevant focused/UI
smoke before closing. Keep reasoning High/no low.

## Result (Back-end, 2026-06-19)

Done in Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

- Fixed the smoke contract in `tests/runtime_smoke_test.gd` to target the active
  native Hero Select v4 nodes (`HS4BackButton`, `HS4Portrait`, `HS4Radar`,
  `HS4Carousel`, `HS4ChooseButton`) instead of stale v3/mockup-era names.
- Kept a legacy fallback for `HeroSelectBackButton` in the dedicated
  back-button safety check, so old-compatible builders can still satisfy the
  guard.
- Updated stale v3-only runtime checks uncovered after the back-button fix:
  carousel selection, ascension class switch, canonical `hero_select` backdrop,
  v4 button-size exceptions, and responsive thumbnail size tolerance.
- Updated the focused UI overlap matrix to assert the native v4 controls without
  touching PM-owned `_build_character_select_v4()` or any visual redesign scope.

Verification:

- PASS — `runtime_smoke_test.gd`
  (`build/qa/scrum479_runtime_smoke_after.log`)
- PASS — `ui_no_overlap_matrix_test.gd`
  (`build/qa/scrum479_ui_no_overlap_matrix_after.log`)
- PASS — `animation_smoke_test.gd`
  (`build/qa/scrum479_animation_smoke_after.log`)

Note: the runtime log still includes unrelated Skeleton2D/Bone2D warnings from
concurrent SCRUM-474/475 WIP files, but the suite exits 0 and SCRUM-479 is no
longer blocking runtime smoke.

## QA-Вердикт (2026-06-23)

Статус: PASSED (follow-up commit recorded; PM closed 2026-06-27)

Исторический блокер 2026-06-23: фикс был **верифицирован зелёным на рабочем
дереве**, но на тот момент **НЕ был закоммичен**:

- `tests/runtime_smoke_test.gd` показан `git status` как `M` (unstaged).
- На committed HEAD тест всё ещё ищет только `HeroSelectBackButton`
  (HEAD:6135/7090/7123), а живой `ui_screens.gd._build_character_select_v4`
  (закоммичен) строит кнопку как `HS4BackButton` → `_test_back_button_frame_safety`
  падает «Expected hero select v4 to expose a back button.». То есть на чистом
  HEAD `runtime_smoke_test` красный.
- Диф `tests/runtime_smoke_test.gd` изолирован: только переименования v3→v4
  (HS4Portrait/HS4Radar/HS4Carousel/HS4ChooseButton/HS4BackButton), без следов
  скелетона/SCRUM-474. То есть его можно закоммитить отдельным `git add
  tests/runtime_smoke_test.gd` без втягивания held-WIP SCRUM-474.

Прогон на рабочем дереве: `tests/runtime_smoke_test.gd` → EXIT=0, «Runtime smoke
test passed.» (лог `build/qa/qa_session_20260623/runtime_smoke.log`).

Исторический вывод QA 2026-06-23 был «не закрывать» до изолированного коммита.
Этот блокер снят follow-up commit `d59f80a9`, записанным ниже.

## Dispatcher Sync (2026-06-23)

Back-end follow-up completed after the QA block:

- Commit `d59f80a9` (`fix(SCRUM-479): commit hero select v4 runtime smoke contract`)
  contains the isolated `tests/runtime_smoke_test.gd` fix.
- Back-end reran `runtime_smoke_test.gd` successfully after the commit.

Task no longer remains in «Контроль качества»: Jira moved to `Готово` during
the 2026-06-27 Sprint 0.1.6 cleanup after the follow-up commit was recorded.

## PM Closure (2026-06-27)

SCRUM-479 закрыт в Jira по cleanup-директиве для `Спринт 0.1.6`.
Follow-up commit `d59f80a9` уже записан выше как изолированный clean-HEAD фикс,
поэтому тикет больше не должен оставаться в «Контроль качества».
