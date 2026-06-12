# Задача Для Back-end-Агента: Переделка Настроек — Вкладки, Полные Слайдеры Громкости, Биндинги Клавиш

Статус: done
Создано: 2026-06-12
Автор: PM
Приоритет: высокий (пользователь видит сломанный экран настроек прямо сейчас).
Dispatch note: 2026-06-12 routed by dispatcher to Back-end Codex thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

## Autonomy / Approval
Пользователь заранее одобрил все изменения.

## Контекст (отчет пользователя)
1. Экран настроек НЕ помещается в окно (контент вылезает/обрезается).
2. Слайдеры громкости не видны — хотя задача settings_display_audio помечена done
   (шины Master/Music/SFX и слайдеры реализованы). Значит либо регрессия после
   UI-редизайна (texture frames могли сломать layout), либо слайдеры скрыты
   из-за переполнения. РАЗОБРАТЬСЯ И ПОЧИНИТЬ, а не реализовывать заново вслепую.
3. Пользователь хочет стандартные «как в играх» слайдеры громкости НА ВСЮ ширину.

## Требования

### Структура: вкладки, всё в одно окно
1. Экран настроек — вкладки (TabContainer или свои кнопки-табы в стиле UI-кита):
   **«Экран»** (монитор, режим окна, разрешение), **«Звук»**, **«Управление»**.
2. Каждая вкладка ЦЕЛИКОМ помещается в окно на ВСЕХ поддерживаемых разрешениях
   (включая минимальное 1280x720) — без вылезания и без вертикального скролла.
   Это главный баг — проверять буквально на каждом разрешении из списка.
3. Стиль — текущий UI-кит (рамки/иконки из ui/frames/global, ui/icons/system),
   Escape = назад.

### Звук (вкладка)
4. Три горизонтальных слайдера НА ПОЛНУЮ ширину контентной зоны: **Общая громкость**,
   **Музыка**, **Эффекты** (0-100, с текущим значением числом рядом), стандартное
   поведение как в играх: перетаскивание, клик по треку, стрелки клавиатуры.
5. Чекбоксы mute для музыки и эффектов рядом со слайдерами (значение слайдера
   сохраняется при mute).
6. Применение мгновенное (играющая музыка реагирует сразу), персист в user://.

### Управление (новая вкладка)
7. Таблица биндингов: **Движение** (вверх/вниз/влево/вправо, дефолт WASD + стрелки
   как альтернатива), **Пауза**, и **Ультимейт** (новое действие, дефолт — R;
   сама способность реализуется в parallel-задаче
   `backend_ultimate_ability_framework_task.md` — экшен `ultimate` завести в
   InputMap уже сейчас).
8. Ребиндинг: клик по полю → «нажмите клавишу» → захват; конфликт с другим
   действием подсвечивается и не сохраняется молча; кнопка «Сбросить по умолчанию».
9. Персист биндингов в user://, применение через InputMap при старте.

### Регрессия
10. Найти причину «не видно слайдеров/не влезает»: проверить, что texture-frames
    UI-редизайна не задали фиксированные размеры панелям; зафиксировать причину в отчете.

## Files / Assets / IDs
- `scripts/ui_screens.gd` (экран настроек), `scripts/game_settings.gd` (персист),
  `scripts/audio_manager.gd`, `project.godot` (InputMap: ultimate, переименования
  при необходимости), `scripts/main.gd`/`scripts/player.gd` (чтение движения —
  убедиться, что идет через InputMap-экшены, а не хардкод клавиш).

## Acceptance Criteria
- [x] Настройки: 3 вкладки, каждая влезает в окно на всех разрешениях вплоть до 1280x720.
- [x] Слайдеры громкости видны, на всю ширину, работают мышью и клавиатурой, применяются сразу.
- [x] Вкладка «Управление»: ребиндинг движения/паузы/ультимейта с конфликт-чеком и сбросом.
- [x] Все сохраняется и восстанавливается при перезапуске.
- [x] Причина регрессии описана в отчете; smoke зеленые + тест переключения вкладок и ребиндинга.

## Документация
- current_game_state (настройки/управление), CHANGELOG (Unreleased).

## Результат 2026-06-12

Back-end implementation complete:
- Settings screen rebuilt into `TabContainer` tabs: «Экран», «Звук», «Управление».
- Audio tab now has full-width 0-100 sliders for master/music/sfx with live percent labels; music/sfx mute checkboxes preserve slider value and apply immediately through `AudioManager`.
- Controls tab now supports movement, pause and `ultimate`; `ultimate` InputMap action defaults to `R`.
- Rebinding captures key input, rejects conflicts with another action, persists to `user://settings.cfg`, and reset defaults restores WASD+arrows, Escape and R.
- Runtime smoke expanded with settings tabs / sliders / ultimate rebind / conflict / persistence checks.

Root cause: the previous settings screen was a single centered vertical menu. After the global UI texture-frame redesign increased panel/content margins and control heights, the combined Screen + Audio + Controls sections exceeded the fixed 1120x660 menu panel at 1280x720. The audio rows were implemented, but pushed below the visible area. Splitting the same content into tabs fixes the overflow without adding vertical scroll.

Checks:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- Result: passed.
