# SCRUM-980 — Hero Select ascension description responsive layout

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-980
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-scrum-980`
Branch: `codex/scrum-980-hero-select-ascension`

## Scope And Locks

Только responsive-геометрия `HS4AscensionFrame` в
`scripts/ui_screens.gd`, focused regression test, этот mirror и актуальный
Hero Select UI contract. Арт, портреты, анимации, progression/balance data и
остальные экраны read-only.

## Diagnosis And Architecture Decision

До исправления `HS4AscensionFrame` находился в узкой левой колонне между
портретом и `HS4ChooseButton`. Реальный minimum-size utility-кнопок был выше
расчётных 42 px, а однострочный `AscensionModsLabel` занимал ту же вертикаль.
На 1280×720 текст исчезал, на 1920×1080 пересекал `-`/`+`, и только на 2560×1440
частично помещался.

Принятое решение сохраняет текущий Atlas/HS4 арт и семантику выбранного уровня:

- `HS4AscensionFrame` занимает отдельную широкую правую полосу между
  `HS4DossierFrame` и `HS4Carousel`;
- счётчик карусели резервирует непересекающийся правый сегмент той же полосы;
- stepper остаётся слева внутри frame content-zone;
- `AscensionModsLabel` живёт справа внутри
  focusable `HS4AscensionDescriptionScroll`, без ellipsis и с вертикальным
  scrolling через колесо мыши или `ui_up`/`ui_down`;
- видимая строка по-прежнему является дельтой выбранного уровня через
  `ascension_level_change_line(level)`, а кумулятивный список остаётся tooltip;
- `HS4ChooseButton` остаётся в нижней части левой колонки и не делит рамку с
  текстом возвышения.

Каждый refresh уровня/героя сбрасывает описание к первой строке; focus graph
ведёт `+ → description scroll`, а из описания можно вернуться в степпер влево.

На 1280×720 описание прокручивается внутри 350×52 px content-zone; на
1920×1080 и 2560×1440 помещается целиком. Контент не заходит на рамку, карусель,
портрет, счётчик или CTA.

## Verification

Новый `tests/hero_select_scrum980_ascension_layout_test.gd` использует
`SubViewport` 1280×720, 1920×1080 и 2560×1440 и проверяет реальные global rects:
frame/stepper/buttons/value/description scroll/Choose, отсутствие пересечений,
полный неэллиптизированный текст, реакцию на `-` и scratch-only `user://`.
Windowed прогоны пишут transient PNG и rect matrix в `build/qa/scrum980/`.

PASS до pre-land review:

- focused SCRUM-980 test — headless и windowed;
- `hero_select_pixellab_layout_test.gd`;
- `ui_no_overlap_matrix_test.gd`;
- `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`;
- `dark_fantasy_ui_theme_test.gd`;
- полный `runtime_smoke_test.gd`.

Полный runtime smoke завершился exit 0; dummy-renderer screenshot diagnostic —
известное нефатальное предупреждение headless capture.

Первый независимый read-only review обнаружил недостижимый gamepad-scroll,
сохранение старой scroll position после refresh и stale docs. После исправлений
focused test отправляет настоящие `InputEventAction ui_down`, доходит до низа,
проверяет boundary focus transfer в `HS4ChooseButton` и reset к первой строке.
Финальный re-review: PASS, actionable findings не осталось; `git diff --check`
чистый.

Disk cleanup: active task worktree; pending pre-land review, commit and push.

Thread cleanup: not a disposable worker thread.
