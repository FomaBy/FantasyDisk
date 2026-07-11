# SCRUM-1049 QA: визуальная матрица и единообразие UI

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1052
Контур: Codex
Owner: QA
Thread: /root/ui_unification_qa
Locked paths: read-only verification; QA evidence section in this file

## Scope

After SCRUM-1050 and SCRUM-1051 are QA-ready, independently verify the full screen inventory, all button states, Codex consistency, gratitude button behavior and frame content-zone safety at 1280x720, 1920x1080 and 2560x1440.

QA must not fix implementation in this issue; defects become separate bug tickets.

## QA-Вердикт (2026-07-11)

Статус: FAILED

Проверено:

- PixelLab provenance и source-reuse exception сверены по
  `manifest.json`; SHA-256 runtime/source gratitude icon совпадает
  (`48313515...64a4`). Независимый alpha-замер: PNG 256x256 RGBA,
  bbox `(55,48)-(201,208)` внутри strict safe box `(48,48,160,160)`,
  transparent/partial/opaque = `51142/3195/11199`. Reference, debug overlay
  и 32/48/64/96 contact preview просмотрены: силуэт читается
  как поддерживающие сердце ладони, content zones не пересекают
  орнамент.
- PASS `tests/scrum1051_ui_button_family_test.gd`: зарегистрированные
  semantic families, icon-only Credits, callback Credits/Back, Codex/Pause/slim
  families и стабильная геометрия состояний.
- PASS `tests/codex_scrum954_layout_test.gd`: 1280x720, 1920x1080,
  2560x1440 + live resize; frameless three-column contract, six quiet Codex
  tabs, Back/content-row families и одинаковые state margins.
- PASS `tests/scrum981_gold_menu_shell_test.gd`: Credits rects
  `(1059,137,64,64)`, `(1624,193,72,72)`, `(2173,257,88,88)`, authored-inner
  containment, peer disjointness, icon/text/tooltip/accessibility и live resize.
- PASS `tests/ui_no_overlap_matrix_test.gd`: 29 screen scenarios x 7 viewport
  sizes (1152x648…3840x2160), full visible `Button`/`TextureButton` family audit,
  overlap/text/frame/content containment gates.
- PASS `tests/dark_fantasy_ui_theme_test.gd`, `tests/runtime_smoke_ui_test.gd`
  (только известный non-fatal dummy-renderer `texture_2d_get` diagnostic),
  `tests/audio_integration_test.gd`.
- PASS regression: `tests/animation_smoke_test.gd`,
  `tests/meta_progression_smoke_test.gd`, `tests/melee_weapon_targeting_test.gd`.
- PASS gamepad: `tests/gamepad_menu_focus_test.gd`,
  `tests/gamepad_inrun_ui_test.gd`, `tests/gamepad_core_input_test.gd`,
  `tests/gamepad_full_flow_smoke_test.gd` x3.
- Full `tests/runtime_smoke_test.gd`: принято переданное root-evidence
  PASS после временного safe relocation двух чужих duplicate ` 2.uid`
  artifacts и их восстановления; QA не удалял и не перемещал
  unrelated files.

Краевые случаи: fresh 1280x720/1920x1080/2560x1440, live
2560x1440 -> 1280x720 resize, повторное Credits open/Back, все пять
button states, три последовательных gamepad full-flow прогона.

Баги: `SCRUM-1054` — focus-стиль `MainMenuCreditsButton` использует
золотую/жёлтую рамку `Color(0.96, 0.80, 0.46, 0.96)` в
`_gratitude_button_style("focus")`. Это нарушает обязательный
neutral/no-yellow focus из SCRUM-1050 и gamepad QA checklist. Ожидается
нейтральный светлый metal focus без жёлтого свечения. QA код не
исправлял.

Disk cleanup: none created (no disposable worktree/cache; standard ignored
`build/qa` test evidence only).

Thread cleanup: not a disposable worker thread (subagent of active root task).

## QA-Ретест SCRUM-1054 (2026-07-11)

Статус: PASSED (заменяет предыдущий FAILED после исправления SCRUM-1054)

Проверено:

- `_gratitude_button_style("focus")` теперь использует холодный
  светлый metal border `Color(0.84, 0.88, 0.94, 0.98)` и нейтральную
  подложку `Color(0.11, 0.12, 0.14, 0.58)`. HSV saturation border
  ≈ `0.106` (< 0.15), синий канал не ниже красного/зелёного:
  жёлтый/золотой focus устранён.
- Focus явно отличается от hover (`Color(0.82, 0.66, 0.36, 0.78)`):
  другой hue/saturation, border width 2px против 1px. Все пять
  состояний сохраняют content margins 4px; Control rect не меняется.
- PASS `tests/scrum1051_ui_button_family_test.gd`: новый прямой
  low-saturation/non-yellow/distinct-hover focus gate и semantic-family flow.
- PASS `tests/scrum981_gold_menu_shell_test.gd`: exact Credits geometry,
  shell/content-zone safety на 1280x720, 1920x1080, 2560x1440 и live resize.
- PASS `tests/dark_fantasy_ui_theme_test.gd`.
- PASS минимальная регрессия: `tests/gamepad_menu_focus_test.gd`,
  `tests/runtime_smoke_ui_test.gd` (только известный non-fatal dummy-renderer
  `texture_2d_get` diagnostic; suite PASS).

Баги: `SCRUM-1054` исправлен и независимо перепроверен; дефект
больше не воспроизводится. Новых дефектов не найдено.

Disk cleanup: none created (no disposable worktree/cache; standard ignored
`build/qa` test evidence only).

Thread cleanup: not a disposable worker thread (subagent of active root task).
