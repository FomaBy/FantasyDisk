# Main Menu OpenAI Clean Background Refresh

Статус: done
Версия: 0.2.1
Контур: Codex
Owner: Design/Codex reconciliation
Thread: /root/audit_repo
Locked paths: `docs/tasks/codex_design_main_menu_openai_clean_background_task.md`; `docs/process/jira_sync_map.json` only if scoped sync changes it. Runtime PNG, preview/spec, design docs, UI and code are read-only verification.
Jira: SCRUM-1001

## Контекст

Прямой пользовательский запрос 2026-07-09: используя генерацию картинок OpenAI,
сделать новую картинку на главный экран игры, уменьшить зернистость и использовать
как референсы текущие спрайты персонажей и монстров/боссов. Требуемое визуальное
направление: чисто, мультяшно-реалистично и красиво. Последние follow-up:
перегенерировать с нуля без референса к предыдущим экранам, но с референсами на
боссов и персонажей; затем исправить проблему, где гитарист читался спиной и
играющим на гитаре.

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
- Для последней ревизии не использовать предыдущие main-menu screens/backgrounds
  как generation reference; входной visual reference = текущие персонажи и боссы.
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
- Latest from-scratch pass uses current character/boss sprite references only and
  does not use previous screen/background images as input references.
- Guitarist must read as front/3/4 side with guitar visible naturally across the
  torso, not as a back-facing figure playing backwards.
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
- После follow-up фидбека `перегенерируй с нуля без референса к предыдущим
  экранам, но с референсами на боссов и персонажей` выполнена новая OpenAI
  Images generate-ревизия: предыдущие main-menu/background/screen изображения не
  использовались как входные референсы.
- Первый локальный from-scratch кандидат был отклонён до push из-за позы
  гитариста. После follow-up `Гитарист Спиной играет на гитаре` выполнена
  переосмысленная generate-ревизия: единственный visual reference input =
  clean board из текущих runtime персонажей и боссов, без карточек/сетки/старых
  фонов. Новый активный runtime source:
  `docs/design/references/main_menu_openai_clean_background/main_menu_openai_final_reimagined_character_boss_refs.png`.
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
- From-scratch character/boss reference sheets:
  `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_generation_clean.png`,
  `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_annotated.png`,
  `docs/design/references/main_menu_openai_clean_background/current_character_boss_reference_sheet_manifest.md`.
- Smooth-lines comparison:
  `docs/design/previews/main_menu_openai_smooth_lines_comparison.png`.
- Orange-noise mask/comparison:
  `docs/design/previews/main_menu_openai_orange_noise_mask.png`,
  `docs/design/previews/main_menu_openai_no_orange_noise_comparison.png`.
- Reimagined source/runtime comparison:
  `docs/design/previews/main_menu_openai_reimagined_comparison.png`.

## Проверки

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
  (known dummy-render `texture_2d_get` warning in weapon-select screenshot helper;
  suite passed).
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`
  (same known dummy-render `texture_2d_get` warning; suite passed).

Disk cleanup: none created (no disposable worktree/clone; Godot import/cache
sidecars were not staged).

## Completion Reconciliation 2026-07-09

- Verified the full implementation chain `4709d8b4` -> `670a9570` ->
  `423ba3ec` -> `1d59c23d` -> `47aef079` -> `b979bbba`; every commit is an
  ancestor of `origin/dev`.
- Visually inspected the active runtime PNG and safe-zone overlay. The party,
  bosses and readable front/3/4 guitarist remain center-right/right; the title
  and six-button left zones stay dark, calm and free of key silhouettes. No
  baked UI/text/logo/label/watermark or distracting orange speck noise is
  visible in the content-safe zones.
- Runtime, preview and final reimagined source are byte-identical
  (`SHA-256 160e3bc07f01a0120833aba882426f89dc72b94023d6e7de9f87e4f4bfec023e`).
  All are `2560x1440`, 8-bit RGB PNGs with no alpha channel or textual metadata.
- Pixel sanity: left safe-zone luminance `mean=16.57`, `std=2.86`, edge mean
  `0.58`, versus right-art `mean=33.43`, `std=27.76`, edge mean `11.13`;
  title/actions warm-pixel ratio is `0`, with zero tiny warm components.
- Confirmed the current-character/boss-only reference board, manifest and
  from-scratch prompt are tracked and explicitly exclude previous screens and
  backgrounds as generation inputs.

### Reconciliation Checks

- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`.
- The known headless dummy-render `texture_2d_get` warning occurred in the
  weapon-select screenshot helper; both affected suites exited `0` and passed.
- Runtime image/UI/code/spec/previews/design docs were not modified during
  reconciliation. Independent QA remains required; no self-QA verdict added.
