# BUG: Настройки — смена разрешения не работает (Mac/HiDPI); нужны Full HD, 2K, Mac-разрешение

Статус: new
Приоритет: high
Роль: Back-end (UI/настройки/платформа)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (прямой отчёт пользователя)

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
