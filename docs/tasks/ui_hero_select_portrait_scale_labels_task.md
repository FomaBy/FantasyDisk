# UI: Hero Select portrait scale, crop, and carousel labels

Статус: done
Приоритет: high
Роль: Back-end UI (Codex)
Версия: 0.1.7
Создано: 2026-07-02
Автор: прямой запрос пользователя
Jira: SCRUM-822
Lane: codex
Контур: Codex
Owner: Codex UI runtime
Thread/Worker: codex-direct-user-thread-2026-07-02
Locked paths/screens/assets: `scripts/ui_screens.gd`, Hero Select HS4 runtime layout, Hero Select layout tests, `docs/design/mockups/hero_select_black_minimal/`, `docs/design/systems/menus_ui.md`

## Source Request

Пользователь просит доработать экран выбора персонажа:
- на большой левой превьюшке чуть увеличить персонажей;
- выровнять больших персонажей единообразно;
- внизу на карусели оставить выравнивание, но еще чуть увеличить персонажей;
- обрезать пустое место справа/слева от персонажей, чтобы было лучше видно, кто это;
- добавить имя персонажа под или над персонажем в нижней карусели.

## Implementation Plan

- Keep the active SCRUM-798/SCRUM-421 HS4 black minimal direction: no new frame art.
- Add a layout spec amendment for preview/crop/name geometry before runtime edits.
- Reuse existing `ProgressionData` character display names for carousel labels.
- Use alpha-bbox-aware portrait placement so the left preview and carousel compare visible character bounds, not transparent `512x512` canvas size.
- Preserve no-overlap and content-only-in-safe-area rules.

## Acceptance Criteria

- [x] Big `HS4Portrait` is slightly larger and alpha-bottom aligned across selected characters.
- [x] Carousel portraits are larger, horizontally cropped/fit by visible alpha bounds, and still bottom-aligned.
- [x] Carousel slots show readable character names without covering portrait silhouettes.
- [x] Hero Select tests cover preview alignment, carousel portrait bounds, and labels.
- [x] UI docs/spec updated.
- [x] Jira result includes commit, tests, and disk cleanup.

## Result

- Added cached alpha-bbox placement for the large Hero Select preview and carousel portraits so visible silhouettes, not transparent `512x512` canvases, drive scale/center/baseline.
- Increased the preview and carousel scale caps while preserving the active black-minimal HS4 layout and major no-overlap zones.
- Added bottom `HS4CarouselLabel_*` character-name strips sourced from `ProgressionData.character_config(id).title`.
- Updated Hero Select tests and the SCRUM-798 capture helper to validate the clipped `HS4PortraitFrame` rather than the intentionally overflowing texture node.

## Verification

- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_biologist_pixellab_preview_test.gd` — passed.

## QA-Вердикт
Статус: PASSED (2026-07-02, claude-qa/оркестратор)

- Ancestry: 5d0393e9 (feat) + 898e2e03 (sync) — merge-base ancestor origin/dev OK (strand-чек codex-lane пройден).
- Изолированный worktree от origin/dev, cold --import (fdengine-семафор, 1 слот):
  hero_select_pixellab_layout_test PASSED, runtime_smoke_test PASSED,
  ui_no_overlap_matrix_test PASSED.
- PNG в коммите нет — png/.import pairing не требуется; правки ui_screens.gd
  (портреты hero select) покрыты обновлённым layout-тестом воркера.
