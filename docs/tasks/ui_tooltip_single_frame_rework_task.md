# Тултипы: один фрейм, плотный фон, крупный шрифт, краткие тексты

Статус: done
Роль: Back-end
Контур: Claude
Lane: claude
Версия: 0.2.0
Создано: 2026-07-03
Автор: User request (PM, голосовое ТЗ по скрину hero select v4)
Labels: foma, backend, claude

## Контекст

PM по скрину тултипа «Выносливость» на hero select v4: «фрейм внутри фрейма — такое
не годится; один фрейм, менее прозрачный; крупнее шрифт; более краткая информация
везде, только необходимая; где нужны детали — окно больше, сейчас ничего не видно».

Технически двойная рамка возникает так: `GlobalTooltip.make_theme()` вешает
metal-рамку на тип `TooltipPanel` (это внешний движковый попап тултипа), а
`GlobalTooltipControl._make_custom_tooltip` возвращает ещё один PanelContainer
с той же metal-рамкой (`make_text_panel`) и скриптом самопозиционирования → рамка
в рамке, двойные content-margins (66+66 px с каждой стороны), label сжат до 328 px
при шрифте 14. Фон текстуры `ui_frame_minimal_metal_tooltip.png` полупрозрачный
(alpha 214/255) — сквозь тултип просвечивает текст под ним. Тексты статов —
простыни: «Влияет на: HealthPoint, Defense…», «Формула: Базовая характеристика…»,
«Интерпретация класса: …» дублируют человеческое описание тех-водой.

## Что сделать

1. Один фрейм: `_make_custom_tooltip` (глобальный и в pause_stats_menu) возвращает
   голый Label; рамку рисует только движковый попап через тему `TooltipPanel`.
   `make_text_panel` и скрипт самопозиционирования `global_tooltip_panel.gd` удалить
   (единственные потребители переходят на Label; глоссарий строит панель сам).
2. Плотный фон: поднять альфу внутренней зоны текстур тултипов
   `ui_frame_minimal_metal_tooltip.png`, `ui_frame_2k_gt_panel.png` с 214 до ~252
   (масштаб по не-внешним пикселям, размер PNG не меняется — .import валидны).
   `ui_frame_2k_st_panel.png` не трогаем: ассет мёртвый (только реестр путей).
3. Крупный шрифт: базовый размер тултипа 14 → 20 (тип `TooltipLabel` и Label-хелпер);
   глоссарий-тултип 16/13 → 20/16.
4. Краткие тексты: тултип стата = «Имя — значение» + описание одной строкой; убрать
   «Влияет на:»-листинг, «Формула:», «Интерпретация класса:» (hero select v4,
   pause_stats_menu). В оффере докачки убрать интерпретацию класса (дубль карточки),
   оставить «Влияет на:» и честный предпросмотр «было → станет». Кодекс не трогаем.
5. Адаптивное окно: короткий текст — окно по тексту без переноса; длиннее ~460 px —
   перенос на 460; «супердетали» (длинные тексты) — широкое окно 620 px. Реализация
   через замер строки шрифтом (`ThemeDB.fallback_font`).

## Acceptance Criteria

- [x] Нативный тултип — ровно одна рамка: custom tooltip возвращает Label
      (не PanelContainer), рамка только от `TooltipPanel`-стиля темы.
- [x] Центр текстур тултипа/глоссария: alpha 252 (замер по капче: просвет яркой
      строки под тултипом ≤ 2/255 — визуально плотный).
- [x] Базовый шрифт тултипа ≥ 20; глоссарий-тултип 20/16.
- [x] Тултипы статов без «Формула:»/«Интерпретация класса:»/тех-листинга производных.
- [x] Длинный текст переносится на ширине 460–620 px, не мельчит
      (капча: короткий 192 px по тексту, стат 460 wrap, длинный предпросмотр 460).
- [x] Смоуки зелёные: runtime_smoke, hero_select_pixellab_layout,
      hero_select_scrum798_capture, dark_fantasy_ui_theme, glossary_smoke.

## QA-Вердикт

Статус: PASSED
- runtime_smoke_test: PASS (обновлённые контракты SCRUM-851: одиночная рамка через
  «TooltipPanel», голый Label, шрифт ≥20, wrap-полоса 400–620, opacity-чек текстуры
  ≥0.93, краткие тексты статов « — » без «Формула:»; pause-тултип на stat_tooltip 2K).
- hero_select_pixellab_layout_test: PASS; hero_select_scrum798_capture_test: PASS
  (concise-тултип контракт); dark_fantasy_ui_theme_test: PASS; glossary_smoke_test:
  PASS (45 терминов).
- Визуальная капча: build/qa/scrum851_tooltip/tooltip_samples_after.png (один фрейм,
  плотный фон, три ширины окна).

## Files

- scripts/ui/global_tooltip.gd, scripts/ui/global_tooltip_control.gd
- scripts/ui/global_tooltip_panel.gd (удалить)
- scripts/ui_screens.gd (_hs4_stat_tooltip, оффер докачки, глоссарий-шрифты)
- scripts/pause_stats_menu.gd (_make_custom_tooltip, _tooltip_for_entry)
- assets/sprites/ui/frames/minimal_metal/ui_frame_minimal_metal_tooltip.png
- assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png
- assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_st_panel.png
- tests/runtime_smoke_test.gd, tests/hero_select_pixellab_layout_test.gd,
  tests/hero_select_scrum798_capture_test.gd
