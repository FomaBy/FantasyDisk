# UI: Настройки v6 — полный редизайн в стиле Атласа (OpenAI + PixelLab)

Роль: design · Контур: claude · Приоритет: P1 · foma
Статус: in_progress
Создано: 2026-07-03
Автор: Claude (прямое поручение пользователя, полный автоном)
Исполнитель: Claude / основной чат

## Что и зачем

Пользователь поручил полностью переделать интерфейс меню «Настройки» с нуля:
старый визуал (settings_v5) удалить, собрать новый (settings_v6) в едином
стиле с экраном «Атлас Персонажа» (meta40): тёмное фэнтези, латунь/золото,
пиксель-арт орнамент. Генерация арта — OpenAI gpt-image-2 (крупные панели,
кнопки, поля; прямое указание пользователя = override PixelLab-first) +
PixelLab MCP (иконки, эмблема, чекбоксы, гем слайдера). Требования: ничего
не наслаивается, весь текст помещается, эстетично и удобно.

## Контракт (НЕ ломать)

- Геометрия v5 сохраняется: дизайн-лист 1420×1060, modal ratio 0.555,
  title (80,56,1260,62), табы 3×340×84 @y150, контент (72,258,1276,630),
  divider y910, действия 3×320×80 @y936, label-колонка 380×56, контрол 560×56.
- Имена функциональных нод неизменны (их ассертят тесты и capture-тул):
  SettingsV2Root/Modal/MainModalFrame/Title, SettingsTabSwitcher,
  SettingsTabButton_0..2, SettingsContentPanel/Safe, SettingsTabs,
  SettingsScreenOption, SettingsResolutionOption, SettingsWindowModeOption,
  ScreenShakeToggle, SettingsPendingLabel, VolumeRow/Slider/Chip/Toggle_*,
  SettingsResetAudioButton, SettingsInputModeOption/Hint, SettingsGamepadStatus,
  SettingsAimModeOption, DebugModeToggle, CombatFeedbackToggle,
  BindingButton_*/BindingRow_*, SettingsResetBindingsButton,
  GamepadBindButton_*/Row_*, SettingsGamepadDeadzoneSlider/Value,
  SettingsGamepadVibrationToggle, SettingsResetGamepadButton,
  SettingsBottomActions, SettingsApplyButton/RevertButton/BackButton.
- Функциональная логика (pending video, ребинды, геймпад-секции SCRUM-816,
  сохранение через GameSettings) не меняется.

## Что сделать — по шагам

1. Ассет-кит `assets/sprites/ui/frames/settings_v6/` (27 слотов, размеры v5):
   modal_frame 1420×1060, content_inset 512×256 (9-slice), medallion 180×72,
   tab active/hover/inactive 340×84, иконки табов 44×44 ×3,
   btn primary/neutral ×4 состояния 320×80, field ×3 состояния 560×56,
   arrow 56×56, checkbox on/off 52×52, slider track 420×18 / fill 416×12 /
   gem 36×36, value_chip 96×48.
   - OpenAI: `tools/generate_settings_v6_openai.py` (маджента-key, flood-fill,
     erode, crop-to-aspect, LANCZOS под слот) — панели/табы/кнопки/поля/чип/трек.
   - PixelLab MCP create_map_object: иконки табов, эмблема-медальон, розетка
     чекбокса, звезда (on-оверлей), сапфировый гем, стрелка.
   - Состояния hover/pressed/disabled/inactive — PIL-деривативы от базовых
     (полная геометрическая консистентность состояний).
   - Сырцы в `docs/design/references/settings_v6/`, финал + .import в assets.
2. Код: `scripts/ui_screens.gd` — блок SETTINGS_V5_* констант → SETTINGS_V6_*
   (палитра Атласа: золото #C7A870/#F0CC75, титул #F5E6AE, синий хинт #B8D6FF),
   переписать стиль-хелперы (_settings_v6_*), декоративные ноды (эмблема,
   заголовки секций с латунными линиями), фокус-стили для геймпада.
3. Удалить `assets/sprites/ui/frames/settings_v5/` (27 PNG + .import) и код v5.
4. Обновить связки: `tests/runtime_smoke_test.gd` (пути табов v5→v6),
   `tools/capture_settings_v5.gd` → `tools/capture_settings_v6.gd`.
5. QA: Godot --import; смоуки game_settings/video_settings_apply/
   gamepad_settings_rebind/runtime_smoke; ui_no_overlap_matrix (settings @
   1920/2560/3840); capture 3 вкладки × 2 разрешения; визуальная приёмка.

## Acceptance Criteria

- [ ] Новый кит settings_v6 сгенерирован (OpenAI + PixelLab), старый v5 удалён.
- [ ] Контент только в пустой зоне рамки (safe-area), не на орнаменте.
- [ ] No-overlap матрица settings: PASS на 1920×1080, 2560×1440, 3840×2160.
- [ ] Весь текст помещается (лейблы, дропдауны, кнопки, хинты) на обоих
      базовых разрешениях; скриншоты 3 вкладок приложены.
- [ ] Смоуки настроек зелёные: game_settings, video_settings_apply,
      gamepad_settings_rebind, runtime_smoke (settings-часть).
- [ ] .import сайдкары закоммичены вместе с PNG; пуш в origin/dev.

## Files / точки входа

- scripts/ui_screens.gd:195-257 — константы v5 (заменить на v6)
- scripts/ui_screens.gd:4824-4904, 4973-5404, 5444-5743 — экран и хелперы
- assets/sprites/ui/frames/settings_v5/ → settings_v6/
- tests/runtime_smoke_test.gd:54-55 — пути таб-текстур
- tools/capture_settings_v5.gd → capture_settings_v6.gd
- tools/generate_settings_v6_openai.py — новый генератор

## Замечания / подводные камни

- Locked paths: scripts/ui_screens.gd (Claude-lane), assets/.../settings_v6/,
  tools/capture_settings_v6.gd — на время задачи.
- PixelLab/OpenAI запекают фон → чинить flood-fill alpha-cleanup, не регенерацией.
- Параллельные headless Godot только через tools/godot_gate.py.
- OpenAI-путь для крупных панелей — явное указание пользователя (override
  PixelLab-first из AGENTS.md), зафиксировано в Jira-комментарии.
