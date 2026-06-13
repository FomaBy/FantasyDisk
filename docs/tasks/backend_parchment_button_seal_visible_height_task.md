# Задача Для Back-end-Агента: Кнопка пергамент+печать — печать должна быть видна (увеличить высоту, не сжимать)

Статус: in_progress
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя)
Jira: SCRUM-227

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Везде, где используется стиль кнопки пергамента с печатью, надо сделать так,
чтобы печать была видна — кнопку сделать с большей высотой, чтобы не сжимало».

Сейчас кадр кнопки — текстуры `assets/sprites/ui/frames/dark_fantasy/ui_df_button_*`
(primary/secondary/danger × idle/hover/pressed/disabled), сургучная печать
ВШИТА в кадр слева. Применяется через `_apply_fantasy_button_theme` / `_make_button`
(GLOBAL_BUTTON_FRAME_PATH:17). При низкой высоте кнопки 9-slice сжимает кадр по
вертикали → печать сплющивается/обрезается и плохо читается (видно на level-up,
коротких кнопках 48px, и др.).

## Требования
1. **Аудит всех кнопок** с этим пергамент+печать-стилем (по `_make_button` /
   `_apply_fantasy_button_theme`): где высота слишком мала и печать сжимается.
   Основные точки: меню (76px — проверить достаточно ли), «Назад» (48px),
   asc +/- (38px), level-up/reward, магазин, события и т.п.
2. **Поднять минимальную высоту** кнопок с печатью так, чтобы печать
   отображалась в правильной пропорции и читалась целиком. Подобрать высоту
   (ориентир ≥ 64-72px для кнопок с печатью; мелкие служебные «-»/«+» —
   решить: либо своя высота, либо отдельный кадр БЕЗ печати, чтобы не плющить).
3. **9-slice / поля кадра**: проверить nine-patch margins кадра кнопки — зона
   печати слева не должна растягиваться; если печать плющится даже при высоте —
   поправить patch_margin или вынести печать в фиксированный (не растягиваемый)
   левый сегмент. Зафиксировать решение в отчёте.
4. Текст внутри кнопки не должен налезать на печать (отступ слева под печать).
5. Не ломать раскладки: правило «UI не наползает» (qa_protocol) — кнопки с новой
   высотой не пересекаются с соседями на 1280x720 и 2560x1440.
6. Тест (smoke): фактические размеры — кнопки с печать-темой имеют высоту ≥
   порога; (если возможно) зона печати не сжата; ключевые экраны без overlap.
7. Скриншот/дамп в build/qa/ (level-up + меню как наглядные); CHANGELOG.

## Files / Assets / IDs
- scripts/ui_screens.gd (_make_button, _apply_fantasy_button_theme,
  GLOBAL_BUTTON_FRAME_PATH:17, все custom_minimum_size кнопок)
- assets/sprites/ui/frames/dark_fantasy/ui_df_button_*.png (+ .import nine-patch)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Печать видна целиком и читаема на всех кнопках с этим стилем.
- [ ] Высоты кнопок подняты до достаточных; мелкие служебные кнопки не плющат печать (своя высота/кадр без печати).
- [ ] Текст не налезает на печать; no-overlap на 2 разрешениях.
- [ ] 6 smoke зелёные; скрин в build/qa/; CHANGELOG.

## Документация
docs/design/current_game_state.md (UI-кнопки), visual_style_assets.md (если кадр меняется).

## Dispatcher Note (2026-06-13)
Dispatched to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as an addition to the serialized `scripts/ui_screens.gd` UI batch with SCRUM-224/SCRUM-225/SCRUM-226. Work with reasoning set to High; do not switch the run/model effort to low. Keep Jira live-synced: in-progress now, then update task/board/Jira on completion, with QA left to the board worker. If fixing small buttons requires new/reworked frame art rather than layout/theme integration, create/update a Design handoff instead of doing visual asset work in Back-end. If any motion/timing/animation scope appears, create/update an Animator handoff instead of doing animation work in Back-end.
