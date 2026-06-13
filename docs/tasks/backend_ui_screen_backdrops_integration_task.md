# Задача Для Back-end-Агента: Подключить Dark Fantasy Screen Backdrops

Статус: in_progress
Версия: 0.1.4
Создано: 2026-06-12
Связано: SCRUM-158, SCRUM-147
Jira: SCRUM-170

Dispatcher note 2026-06-13: Jira/task linkage is valid (`SCRUM-170`) and the
feature block is lifted. Added to the local board queue and dispatched to
Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Подтверждение не спрашивать.

## Контекст

Design/Codex SCRUM-158 подготовил dark fantasy screen backdrops для экранов с центральными окнами и новый active main menu art.

Уже подключено Design-only заменой существующих PNG путей:

- `assets/backgrounds/main_menu_epic_battle.png` - новый главный экран;
- `assets/sprites/ui/screens/screen_shop_background.png` - копия merchant/archive backdrop;
- `assets/sprites/ui/screens/screen_event_background.png` - копия arcane/lab backdrop;
- `assets/sprites/ui/screens/screen_campfire_background.png` - копия system/cathedral backdrop.

Новые canonical role backdrops лежат отдельно:

- `assets/backgrounds/ui/ui_backdrop_system_cathedral.png`;
- `assets/backgrounds/ui/ui_backdrop_merchant_archive.png`;
- `assets/backgrounds/ui/ui_backdrop_arcane_lab.png`;
- `assets/backgrounds/ui/ui_backdrop_reward_hall.png`;
- `assets/backgrounds/ui/ui_backdrop_defeat_crypt.png`.

## Что Нужно От Back-end

1. Расширить `SCREEN_BACKGROUND_PATHS` / screen background helper так, чтобы центральные окна могли использовать role-specific IDs:
   - `system` / `settings` / `codex` / `hero_select` / `weapon_select` / `pause_stats` / `meta_tree` -> `ui_backdrop_system_cathedral.png`;
   - `shop` -> `ui_backdrop_merchant_archive.png`;
   - `event` / `upgrade` / `level_up` / `meta_progression` -> `ui_backdrop_arcane_lab.png`;
   - `elite_reward` / `victory` / `artifact_reward` -> `ui_backdrop_reward_hall.png`;
   - `death` / `defeat` / `end_run_confirm` / danger confirmations -> `ui_backdrop_defeat_crypt.png`;
   - `campfire` can stay `system_cathedral` unless Design later provides a dedicated rest/campfire variant.
2. Ensure all central-window screens call `_add_screen_background()` or equivalent full-rect `TextureRect` with `STRETCH_KEEP_ASPECT_COVERED`.
3. Keep central panels readable: do not add extra opaque junk layers or decorative abstract lines/circles/squares.
4. Capture QA screenshots for at least: main menu, settings, hero select, level-up, shop, event, victory/death at 1280x720 and 2560x1440 if practical.

## Files / Assets / IDs

- `scripts/main.gd`
- `scripts/ui_screens.gd`
- `scripts/pause_stats_menu.gd`
- `assets/backgrounds/ui/*.png`
- `assets/backgrounds/main_menu_epic_battle.png`
- `assets/sprites/ui/screens/screen_*_background.png`

## Acceptance Criteria

- All screens with central windows have a dark fantasy backdrop behind the panel.
- Backdrops use cover scaling without distortion.
- Text/buttons remain readable.
- Existing route map/combat backgrounds are not replaced by these UI backdrops.
- Runtime smoke and relevant UI screenshots pass.

## Документация

Update `docs/design/current_game_state.md`, `docs/design/systems/menus_ui.md` and `docs/design/content_registry.md` if runtime mappings differ from this handoff.
