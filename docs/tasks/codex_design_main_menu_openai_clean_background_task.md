# Main Menu OpenAI Clean Background Refresh

Статус: done
Версия: 0.2.1
Контур: Codex
Owner: Design/Codex current thread
Thread: current Codex user chat
Locked paths: assets/backgrounds/main_menu_epic_battle_v3.png; docs/design/mockups/main_menu_openai_clean_background/; docs/design/references/main_menu_openai_clean_background/; docs/design/previews/main_menu_openai_clean_background_preview.png; docs/design/systems/menus_ui.md; docs/design/systems/visual_style_assets.md; docs/design/current_game_state.md
Jira: SCRUM-1001

## Контекст

Прямой пользовательский запрос 2026-07-09: используя генерацию картинок OpenAI,
сделать новую картинку на главный экран игры, уменьшить зернистость и использовать
как референсы текущие спрайты персонажей и монстров/боссов. Требуемое визуальное
направление: чисто, мультяшно-реалистично и красиво.

## Process Override

- `OpenAI Images override`: пользователь явно запросил OpenAI image generation
  для production main-menu background. Поэтому задача использует OpenAI/imagegen
  вместо PixelLab-first redraw path, с фиксацией override в Jira/task evidence.
- UI hard rule сохраняется: фон без baked UI text/buttons/frames; левая колонка
  под logo/actions остается спокойной и не занята важными персонажами.

## Scope

- Сгенерировать новый clean cartoon-realistic 2560x1440 main-menu background.
- Использовать текущие runtime спрайты персонажей, врагов, элиток и боссов как
  style/subject references.
- Снизить зернистость относительно предыдущего фона: гладкие чистые формы,
  без шумного film grain, без чрезмерного pixel-art/noise texture.
- Сохранить runtime path `assets/backgrounds/main_menu_epic_battle_v3.png`, чтобы
  не менять кодовый контракт `MAIN_MENU_BACKGROUND`.
- Сохранить предыдущий runtime background в backup/evidence.
- Обновить mockup/spec, preview/reference paths и domain docs.

## Acceptance Criteria

- Runtime main-menu background PNG существует по
  `assets/backgrounds/main_menu_epic_battle_v3.png` и имеет размер 2560x1440.
- Изображение не содержит baked UI text, buttons, logos, labels or watermarks.
- Левая колонка и верхняя title-safe зона остаются читаемыми для существующего
  `MainMenuTitleLabel` и шести runtime-кнопок.
- Визуальный стиль: clean cartoon-realistic D&D/dark fantasy, current-sprite-inspired
  characters/monsters/bosses, reduced grain/noise, smoother lines and less ragged
  contours, without extra orange spark/ember dot noise.
- Есть spec/evidence under `docs/design/mockups/main_menu_openai_clean_background/`
  и preview under `docs/design/previews/`.
- Godot smoke/UI checks run or blocker recorded.

## Результат

Done 2026-07-09.

- Создан новый main-menu background через OpenAI Images по прямому пользовательскому
  override и текущим runtime sprite references.
- Runtime asset обновлён без изменения code path:
  `assets/backgrounds/main_menu_epic_battle_v3.png` (`2560x1440`, RGB PNG).
- После пользовательского фидбека применён усиленный edge-aware smoothing pass:
  зернистость в sky/clouds/magic haze/stone texture снижена, силуэты героев и
  боссов сохранены.
- После follow-up фидбека `убрать неровности краев / сделать более плавные линии /
  картинку менее рваную` выполнена отдельная smooth-lines ревизия через OpenAI
  edit текущей композиции + лёгкий anti-ragged postprocess. Финальный runtime
  source:
  `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_smooth_lines.png`.
- После follow-up фидбека `убрать оранжевые точки / сделать без лишнего шума`
  выполнена локальная cleanup-ревизия: мелкие isolated orange/yellow
  ember/spark components найдены по цвету/размеру и нейтрализованы в более
  тёмную холодную палитру без размытия текстуры; крупные golden portal/music
  linework сохранены. Финальный runtime source:
  `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_no_orange_noise.png`.
- Старый runtime background сохранён:
  `docs/design/backups/main_menu_openai_clean_background/main_menu_epic_battle_v3_pre_scrum1001.png`.
- Evidence/spec:
  `docs/design/mockups/main_menu_openai_clean_background/spec.md`.
- Preview:
  `docs/design/previews/main_menu_openai_clean_background_preview.png`.
- Safe-zone overlay:
  `docs/design/previews/main_menu_openai_clean_background_safe_zones.png`.
- Sprite reference sheet:
  `docs/design/references/main_menu_openai_clean_background/current_sprite_reference_contact_sheet.png`.
- Smooth-lines comparison:
  `docs/design/previews/main_menu_openai_smooth_lines_comparison.png`.
- Orange-noise mask/comparison:
  `docs/design/previews/main_menu_openai_orange_noise_mask.png`,
  `docs/design/previews/main_menu_openai_no_orange_noise_comparison.png`.

## Проверки

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
  (known dummy-render `texture_2d_get` warning in weapon-select screenshot helper;
  suite passed).
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  (same known dummy-render `texture_2d_get` warning; suite passed).

Disk cleanup: none created (no disposable worktree/clone; Godot import/cache
sidecars were not staged).
