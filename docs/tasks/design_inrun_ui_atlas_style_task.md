# Ин-ран UI под атлас-стиль: оружие, level-up, награды, пауза, эвенты + шрифт-аудит

- Jira: SCRUM-883
- Статус: in_progress
- Контур: Claude
- Owner: Claude Fable 5 (интерактивный чат пользователя)
- Thread: claude-fable5-ui-unify-20260708
- Worktree: /private/tmp/fsd_wt_w3_{weapon,levelup,rewards,events} + волна 2 fonts
- Branch: dev
- Locked paths: scripts/ui_screens.gd (зоны: weapon/boon; level_up; victory/attr/reward/result/economy; event/pause/quit; шрифт-полы — оркестратор),
  scripts/route_map_screen.gd + scripts/pause_stats_menu.gd + scripts/ui/ui_icon_registry.gd (волна 2, шрифты),
  tests/ui_no_overlap_matrix_test.gd (ветки weapon_select/level_up/economy*/event/pause/victory/death),
  tests/runtime_smoke_test.gd (соответствующие блоки), tests/design_review_screenshot_capture_test.gd (при необходимости)

## Source Request

Прямая директива пользователя (чат, 2026-07-08): «давай полностью переработаем
экраны при выборе оружия, повышения уровня, награды после боя и меню по нажатию
Esc в игре, так же все меню которые отвечают за эвенты. Ещё пересмотри все
размеры шрифтов в игре, они должны быть читаемы и помещаться в рамки интерфейса».
Правила волны SCRUM-879 сохраняются: ничего не растягивать; все кнопки — единый
глобальный кит (кроме выпадающих списков/полей).

## Решение

Языковая база — атлас (SCRUM-879): кожаные чипы `_atlas_chip_style`,
`_unified_apply_row_theme` для карточек/рядов, глобальный кит кнопок, золотая
типографика, полая рама только на полноэкранных пре-ран экранах.

- Оркестратор (фундамент-2): подъём шрифтовых полов — `_shrink_label_font_to_width`
  min 7→12, `_fit_economy_choice_card_content` пол 9→12, фикс аномалии
  action-кегля economy-карточки (cap 14 < base 15), полы combat HUD
  (деньги 11→14, метки баров 9→12, имя босса 14→16, ?-маркер 12→14).
- Агент weapon: выбор оружия + стартовый бун — полный атлас-шелл
  (bg_hero_hall, рама, чип-панель, карточки row-theme, кит-кнопки).
- Агент levelup: оверлей level-up с кита lu682 → чипы+кит («Позже» на ките),
  бейджи/превью эффектов сохранить; viewport-fit матрицы.
- Агент rewards: баннер победы, «Докачка» (attribute shop), «Награда за бой»,
  элитные/боссовые артефакты, итоги победа/поражение, лавка/костёр/апгрейд —
  все панели и карточки на чип-языке, кнопки на ките.
- Агент events: экран событий + пауза Esc (панель, 6 кнопок) + quit-диалог —
  чипы+кит; pause_stats сцена (SCRUM-839) не трогается.
- Волна 2 (fonts): route_map_screen, pause_stats_menu, ui_icon_registry,
  floating text enemy/player — фикс-кегли → `_readable_font_size`/полы ≥14
  (HUD-иконки ≥12), защита clip/ellipsis/autowrap где не хватает.
- Тест-контракты обновляются на новый стиль в ветках агентов; финал: полный
  runtime_smoke + матрица ×7 + focused + windowed design_review капчер.

## Acceptance Criteria

- [ ] 6 зон переведены на атлас-язык, легаси-киты overhaul_2k/lu682 в этих
      зонах не используются.
- [ ] Правило 1 (без растяжек) и Правило 2 (единый кит кнопок) соблюдены.
- [ ] Шрифты: эффективный кегль ≥12px везде (карточки/HUD), базы через
      `_readable_font_size`, длинные строки защищены clip/ellipsis/autowrap.
- [ ] Зелёные: runtime_smoke, ui_no_overlap_matrix (включая viewport-fit
      level_up/economy/event/combat_hud), gamepad_inrun_ui, gamepad_menu_focus,
      event_*/level_up_* focused.
- [ ] design_review капчер: свежие PNG всех состояний; визуальная приёмка.
- [ ] Влито в origin/dev, Jira синхронна, worktree убраны.

## Прогресс

- 2026-07-08: разведка (Explore), спека — Claude Fable 5.
