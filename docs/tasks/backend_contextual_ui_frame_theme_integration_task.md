# Задача Для Back-end-Агента: Интегрировать Контекстные UI Frame Themes

Статус: blocked
Создано: 2026-06-12
Версия: 0.1.4
Перенесено PM 2026-06-12: feature freeze — незавершённая фича уходит в следующий релиз; прогресс (концепт, сгенерированные киты) сохранён.
Автор: Claude-Designer handoff
Jira: SCRUM-118
Роль: Back-end
Приоритет: high

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Подтверждение не требуется.

## Блокер

Ждет Design/Codex generation task:

```text
docs/tasks/codex_design_contextual_ui_frame_kits_generation_task.md
```

Не начинать интеграцию, пока PNG из `assets/sprites/ui/frames/contextual/` не существуют и не прошли Design review.

## Контекст

Концепт и screen mapping:

```text
docs/design/ui_contextual_concept.md
```

Текущий UI подключает единый global kit через `scripts/ui_screens.gd`:

- `GLOBAL_PANEL_FRAME_PATH`
- `GLOBAL_BUTTON_FRAME_PATH`
- `GLOBAL_CARD_FRAME_PATH`
- `GLOBAL_LEVEL_PANEL_FRAME_PATH`
- `GLOBAL_HUD_PANEL_FRAME_PATH`
- `GLOBAL_HUD_CARD_FRAME_PATH`
- `GLOBAL_TOOLTIP_FRAME_PATH`
- `_global_texture_style()`

Нужно не ломать существующий fallback, а добавить context theme selection.

## Что Нужно Сделать

1. Добавить theme-path layer в `scripts/ui_screens.gd`, например:
   - `UI_THEME_UTILITY`
   - `UI_THEME_WILD`
   - `UI_THEME_GRAVE`
   - `UI_THEME_LAUREL`
   - `UI_THEME_PARCHMENT`
2. Подключить готовые PNG:
   - `assets/sprites/ui/frames/contextual/ui_wild_*`
   - `assets/sprites/ui/frames/contextual/ui_grave_*`
   - `assets/sprites/ui/frames/contextual/ui_laurel_*`
   - `assets/sprites/ui/frames/contextual/ui_parchment_*`
3. Назначить экраны:
   - main menu / hero select / weapon select -> Wild
   - death -> Grave
   - victory / reward / level-up -> Laurel
   - codex / event / route map panels -> Parchment
   - shop / settings / generic fallback -> existing Utility/Tavern
   - combat HUD -> existing minimal HUD unless Design provides a new HUD kit
4. Сохранить fallback behavior: если контекстного PNG нет, использовать current global kit.
5. Проверить, что `StyleBoxTexture` margins не режут углы и не съедают кликабельные зоны.
6. Сделать/обновить runtime smoke и visual QA screenshots при возможности.

## Files / Assets / IDs

- `scripts/ui_screens.gd`
- `scripts/route_map_screen.gd` if route panels need theme hook
- `scripts/pause_stats_menu.gd` only if Escape stats should adopt parchment later; default is no change
- `assets/sprites/ui/frames/contextual/*.png`
- `docs/design/ui_contextual_concept.md`

## Acceptance Criteria

- [ ] Contextual frame assets are used by the assigned screens.
- [ ] Existing fallback/global kit still works.
- [ ] Text remains readable at 1280x720 and 2560x1440.
- [ ] Clickable button/control areas do not shrink.
- [ ] Runtime smoke passes.
- [ ] Documentation/CHANGELOG updated after integration.

## Notes For Back-end

This is UI integration, not art direction. Do not redraw frame PNGs in Back-end. If assets fail visually, return a Design/QA note instead.
