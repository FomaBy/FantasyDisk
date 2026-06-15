# BUG: Настройки — смена разрешения не работает (Mac/HiDPI); нужны Full HD, 2K, Mac-разрешение

Статус: in_progress (core доставлен; интеграция отложена — ui_screens в ребилде)
Приоритет: high
Роль: Back-end (UI/настройки/платформа)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (прямой отчёт пользователя)
Jira: SCRUM-441

## Прогресс (2026-06-15, Claude Fable 5)
**Core req 1 доставлен изолированно** (не трогая занятый `ui_screens.gd`, который
переписывает settings-rebuild): `scripts/display_resolution.gd` + `tests/display_resolution_test.gd` (зелёный).
Pure HiDPI-логика: `physical_usable_size(usable_logical, scale)`, `resolution_fits(...)`,
`clamp_to_physical(...)`, `native_logical_resolution(...)` — считают ФИЗ.пиксели
(usable * `screen_get_scale`), на Retina Full HD/2K влезают и не клэмпаются; не-Mac не сломан.

**ИНТЕГРАЦИЯ (осталось, владельцу settings-rebuild / при свободном ui_screens):**
1. В `ui_screens.gd:2291-2310` build OptionButton: `set_item_disabled(i, not DisplayResolution.resolution_fits(res, DisplayServer.screen_get_usable_rect(screen).size, DisplayServer.screen_get_scale(screen)))`.
2. В `_apply_video_settings` (`:5005-5028`): заменить логический клэмп на
   `DisplayResolution.clamp_to_physical(res, usable.size, scale)` перед `window_set_size`.
3. `main.gd:217` `RESOLUTION_OPTIONS`: добавить Mac-native опцию из `native_logical_resolution(usable.size)` (на macOS).
4. (Опц.) `display/window/dpi/allow_hidpi=true` в project.godot.
Доступ: `const DisplayResolution := preload("res://scripts/display_resolution.gd")`.

## Контекст (отчёт пользователя)
«В настройках не работает изменение расширения экрана; должно быть Full HD, 2K и
разрешение для Mac».

## Диагностика (QA, по коду)
Разрешения заданы в `scripts/main.gd:217` `RESOLUTION_OPTIONS`:
`1280x720, 1600x900, 1920x1080 (Full HD), 2560x1440 (2K)` — Full HD и 2K в списке
ЕСТЬ, но на Mac они недоступны/не применяются:

1. **Логические точки vs физ.пиксели (Retina/HiDPI)** — корень бага.
   `scripts/ui_screens.gd:2298,2302` отключают опцию, если
   `resolution > DisplayServer.screen_get_usable_rect(screen).size`, а
   `:5021-5022` клэмпят `resolution = mini(resolution, usable.size)` при применении.
   На macOS Retina `screen_get_usable_rect()` возвращает **логический** размер
   (напр. 14" MBP ≈ `1512x982`, не `3024x1964` физических). Поэтому:
   - `1920x1080` и `2560x1440` > `1512` → **`set_item_disabled(true)`** (серые,
     нельзя выбрать);
   - даже если выбрать — `window_set_size` клэмпится до ~1512 → «не меняется».
   Итог: на Mac реально доступно только `1280x720`.
2. **Нет HiDPI-обработки**: в `project.godot` нет `display/window/dpi/allow_hidpi`,
   код не использует `DisplayServer.screen_get_scale(screen)`.
3. **Нет Mac-native разрешения**: список не содержит типичных Mac-логических
   разрешений (напр. `1512x982`, `1728x1117`) и не подстраивается под монитор.

## Требования
1. **Сравнение/клэмп считать в физ.пикселях**: при disable-проверке и применении
   учитывать `scale := DisplayServer.screen_get_scale(screen)` (Retina = 2.0) —
   доступный физ.размер ≈ `usable.size * scale`. Тогда `1920x1080`/`2560x1440`
   помещаются на Retina и реально применяются (`window_set_size` действительно
   меняет окно). НЕ отключать опции, которые влезают в ФИЗИЧЕСКОЕ пространство.
2. **Full HD (1920x1080) и 2K (2560x1440)** должны выбираться И применяться на Mac
   (окно реально меняет размер; контент через `stretch=canvas_items` масштабируется).
3. **Добавить Mac-разрешение**: детектить родное/рекомендуемое разрешение монитора
   (или добавить типичные Mac-логические `1512x982`/`1728x1117`), помеченное как
   «Mac»/native. На не-Mac платформах поведение не ломать.
4. Окно реально ресайзится при смене опции (`item_selected` → `_apply_video_settings`
   уже есть); проверить, что после клэмп-фикса размер применяется, а не остаётся прежним.
5. (Опц.) `display/window/dpi/allow_hidpi=true` в project.godot, если улучшает Retina-рендер.

## Files / IDs
- `scripts/main.gd:217` `RESOLUTION_OPTIONS`, `:223` `WINDOW_MODE_OPTIONS`
- `scripts/ui_screens.gd:2291-2310` (построение OptionButton + disable),
  `:5005-5028` `_apply_video_settings` (clamp + `window_set_size`)
- `project.godot` (`display/window/dpi/allow_hidpi`)
- сохранение: `game.selected_resolution_index` / `save_game_settings`

## Acceptance Criteria
- [ ] На Mac (Retina) Full HD и 2K выбираемы И применяются — окно реально меняет размер.
- [ ] Доступно Mac-native разрешение (детект монитора или явная Mac-опция).
- [ ] disable/clamp считают физ.пиксели (scale), не логические точки; не-Mac не сломан.
- [ ] Windowed/Borderless/Fullscreen работают; smoke (runtime_smoke_ui) зелёный; скрин настроек.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Verification
Ручная проверка на Mac: открыть настройки → выбрать 1920x1080, затем 2560x1440 →
окно ресайзится; Mac-разрешение в списке и применяется. Headless: `runtime_smoke_ui`
строит экран настроек без ошибок.

## Dispatcher Sync Note (2026-06-15)

Bookkeeping sync only: restored Jira key `SCRUM-441` in the task file and added the
row to `docs/process/task_board.md` because the core HiDPI helper work is already
recorded as delivered/in_progress while runtime integration is deferred until the
Settings/UI rebuild owner can safely touch `scripts/ui_screens.gd`. Not dispatched
this heartbeat: Back-end is active on SCRUM-437 and Designer 2 is active on
SCRUM-439. Keep reasoning High/no low when this resumes.

## Dispatcher Back-end Dispatch (2026-06-15)

SCRUM-441 is now coupled into the SCRUM-439 Settings v2 Back-end runtime pass and
sent to Back-end (`019eabd9-780b-78a2-9f4b-e7203d659ef2`). The core helper/test
already exists; remaining scope is live Settings wiring:

- use `DisplayResolution.resolution_fits(...)` with physical pixels/scale when
  enabling/disabling resolution options;
- use `DisplayResolution.clamp_to_physical(...)` before applying window size;
- expose a Mac-native/logical resolution option where applicable;
- keep window mode and settings persistence behavior intact;
- validate with `tests/display_resolution_test.gd`, Settings UI smoke/no-overlap,
  and a QA dump under `build/qa/scrum441/`.

Do this together with SCRUM-439 to avoid conflicting edits in `scripts/ui_screens.gd`.
