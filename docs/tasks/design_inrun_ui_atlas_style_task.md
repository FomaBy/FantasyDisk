# Ин-ран UI под атлас-стиль: оружие, level-up, награды, пауза, эвенты + шрифт-аудит

- Jira: SCRUM-883
- Статус: done
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
- 2026-07-08: фундамент-2 (шрифт-полы) влит; 5 субагентов волны влиты последовательно:
  w3/weapon (7b53eac3), w3/levelup (b0d852eb), w3/rewards (7 коммитов, 4c5b8e73),
  w3/events (ceebedba, + новая EndRunConfirm-модалка по доп-фидбеку), w3/fonts
  (f3f26c9e). Конфликты только в const-блоках тестов (взаимные удаления) —
  разрешены объединением.

## QA-Вердикт

- Статус: PASSED
- Дата: 2026-07-08, судья: Claude Fable 5 (оркестратор)
- Финальные гейты объединённого dev (godot_gate, EXIT=0): runtime_smoke (полный),
  ui_no_overlap_matrix ×7 вьюпортов (включая viewport-fit level_up/economy*/event);
  по веткам агентов: gamepad_inrun_ui, gamepad_menu_focus, level_up_advisor,
  event_data_smoke, event_choices_empty_pool, hero_select_pixellab_layout,
  route-map focused ×2 — PASS.
- Визуальная приёмка design_review-капчера 2560×1440 (weapon_select, level_up,
  pause_menu/pause_stats, event, attribute_shop): атлас-язык целостен, растяжек
  нет, кегли ≥12, легаси-киты overhaul_2k/lu682 в зонах волны не используются.
- Превью: docs/design/previews/atlas_style_{weapon_select,level_up,event,pause_menu,attribute_shop,victory}_2560x1440.png
  + полный сет build/qa/design_review/ (24 состояния ×3 вьюпорта).
- Disk cleanup: removed /private/tmp/fsd_wt_w3_{weapon,levelup,rewards,events,fonts}
  (+ .godot-кэши), ветки w3/* удалены после влития.
