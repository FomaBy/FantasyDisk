# ART/UX: Настройки v3 — полный PixelLab redraw всех 3 страниц после OpenAI mockup

Статус: blocked
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Контур: Codex
Owner: unassigned
Thread: n/a
Locked paths: scripts/ui_screens.gd, assets/sprites/ui/frames/settings_v3/, assets/backgrounds/ui/, docs/design/mockups/settings_v3_full_redraw/, docs/design/references/settings_v3_full_redraw/, docs/design/previews/settings_v3_full_redraw/, docs/design/systems/menus_ui.md, docs/design/current_game_state.md, docs/design/ui_screens_inventory.md
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-694
Связано: SCRUM-439, SCRUM-575, SCRUM-674 (старые Settings redraw/integration закрыты; этот тикет задает новый полный pipeline)

## Autonomy / Approval

Пользователь заранее одобрил in-scope работу. Не спрашивать подтверждений по обычным repo/Jira/Git/Godot/asset операциям. Jira остается источником статуса; локальный файл — spec/evidence mirror.

## Контекст

Нужно полностью перерисовать интерфейс настроек в меню в новом стиле. Все визуальные элементы настроек должны быть созданы заново: фон при необходимости, main frame, таб-свитчер, страницы `Экран`, `Звук`, `Управление`, control rows, dropdown/button states, sliders, toggles/checkboxes, scroll area, bottom actions. Старые Settings v2/v2.5 ассеты не использовать как production-основу, кроме как reference/negative comparison.

Пользователь явно просит pipeline: сначала Codex разбирает все элементы и весь текст настроек и определяет, где что находится и в каких размерах; затем OpenAI image generation делает красивый mockup всех трех страниц настроек по рассчитанным размерам; после этого PixelLab делает финальный интерфейс меню настроек по нужным размерам с reference mockup от OpenAI.

Project rule: финальные runtime UI assets создаются через PixelLab MCP / `$fantasydisk-asset-generator`. OpenAI Images в этом тикете разрешен только как пользовательски заданный предварительный visual mockup/reference stage; production frame/layout/background/button assets должны быть PixelLab exports.

## Обязательный Порядок Работы

1. **Инвентаризация live Settings**: из `scripts/ui_screens.gd::_show_settings_menu()` и связанных helper-ов выписать все видимые элементы, runtime node names, тексты, states, tooltips, disabled states, scroll behavior и return/apply/revert semantics.
2. **Геометрия до картинки**: создать `ui_plan.json`/`layout.json` под базу `2560x1440` и responsive matrix `1280x720`, `1920x1080`, `2560x1440`, при необходимости `3840x2160`. В плане должны быть точные rects, min/max font sizes, gaps, scroll зоны, content margins и texture margins для каждого frame/control типа.
3. **Fit gate**: прогнать layout/zone validator до генерации. Если не помещается, сначала уменьшить/разнести/прокрутить контент; не решать fit проблемой декоративным overlap.
4. **OpenAI mockup stage**: сгенерировать три textless high-quality mockup/reference PNG: `Экран`, `Звук`, `Управление`. Mockups должны соблюдать утвержденные rects и оставлять пустые content zones под runtime text/controls. Сохранить в `docs/design/mockups/settings_v3_full_redraw/` и показать preview в чате/отчете.
5. **PixelLab final stage**: по утвержденным размерам и OpenAI mockup reference создать финальные PixelLab source/final layers: settings background if needed, main modal frame, tab switcher, section/control rows, button states, dropdown states, slider track/handle, toggle/checkbox states, scroll bar/art. Экспортировать sources в `docs/design/references/settings_v3_full_redraw/`, previews в `docs/design/previews/settings_v3_full_redraw/`, accepted runtime assets в `assets/sprites/ui/frames/settings_v3/` и при необходимости `assets/backgrounds/ui/`.
6. **Back-end integration handoff or implementation**: если Design owner не правит runtime, создать отдельный Back-end handoff with exact asset paths, rects, margins, node IDs and tests. Если тикет исполняет UI runtime owner, собрать Godot screen строго по spec.
7. **QA and docs**: сравнить runtime screenshots with mockup/spec, пройти no-overlap/smoke, обновить docs/changelog/task evidence.

## Current Settings Inventory Seed

Исполнитель обязан перепроверить список по коду перед mockup, но стартовый набор такой:

- Root/containers: `SettingsV2Root`, `SettingsV2Modal`, `SettingsV2MainModalFrame`, `SettingsV2Title`, `SettingsTabSwitcher`, `SettingsTabs`, `SettingsContentPanel`, `SettingsContentSafe`, `SettingsBottomActions`.
- Page/tab labels: `Настройки`, `Экран`, `Звук`, `Управление`.
- Screen page: optional `Монитор` / `SettingsScreenOption` with labels like `Экран N (WxH)`, `Разрешение` / `SettingsResolutionOption`, `Режим окна` / `SettingsWindowModeOption`, `Тряска камеры` / `ScreenShakeToggle`, pending status text `Есть непримененные изменения.` / `Экранные настройки применены.`.
- Sound page: `Общая громкость` / `VolumeSlider_master_volume`, `Музыка` / `VolumeSlider_music_volume` + `VolumeToggle_music_enabled`, `Эффекты` / `VolumeSlider_sfx_volume` + `VolumeToggle_sfx_enabled`, percent labels, `Сбросить звук по умолчанию`.
- Controls page: `ControlsScroll`, `Прицеливание` / `SettingsAimModeOption` with `Автонаводка на ближайшего` and `По курсору`, `Дебаг-режим` / `DebugModeToggle` with `Вкл. (ПКМ / Shift+ЛКМ)` / `Выкл.`, `Боевой фидбек` / `CombatFeedbackToggle` with `Вкл.` / `Выкл.`, all `game.INPUT_ACTIONS` binding rows/buttons, hint `Клик по биндингу, затем нажми клавишу. Esc отменяет.`, `Сбросить управление по умолчанию`.
- Bottom actions: `Применить`, `Отменить`, `Назад`, including disabled/enabled states.
- Preserve behavior: video changes are pending until `Применить`; `Отменить` reverts pending video changes; sound and toggles persist live; key rebind conflict handling remains intact; Settings returns to main menu or pause menu according to origin.

## Visual Direction

- Style: unified D&D + Dark Fantasy Dragon, beautiful, premium, restrained, brutal, not noisy.
- Use the current best game button/style family as mood reference, but redraw settings-specific assets from scratch.
- No baked Russian labels in production art. All labels/text remain runtime text unless a debug/reference preview explicitly marks otherwise.
- Optional background: if the existing settings backdrop does not match the new menu, generate a matching PixelLab background or overlay layer, preserving readability and not fighting the modal.
- Global frame rule is hard acceptance: no text, buttons, tabs, focus rings, dropdown labels, slider handles, icons, scrollbars or click zones may overlap frame ornaments/borders/gems/dragon motifs.

## Hard Rule: Native-Size UI Assets

- The Settings UI must not rely on non-uniform stretching, squashing, or "fit by stretch" for generated interface elements.
- Generate every final PixelLab UI element in its actual target aspect and size for the supported layouts: preferred `2560x1440` and `1920x1080`; acceptable fallback is one native `2560x1440` / 2K source package that is only downscaled proportionally to 1080p.
- Any 1080p output derived from 2K must preserve the same aspect ratio and content-zone proportions; no one-axis scaling, no widened/narrowed buttons, no distorted frame ornaments.
- For repeated/control assets (buttons, tabs, dropdowns, sliders, toggles, scrollbars), generate exact-size families/states for their intended runtime slots. If 9-slice/tiled centers are used, only the flat/tileable center may adapt; corners, borders, icons and ornaments must remain native/proportional and have documented texture/content margins.
- `ui_plan.json`, `layout.json`, manifests and QA evidence must record source size, 1080p target size or scale factor, aspect ratio, allowed scaling mode, and a PASS note that no generated UI asset is stretched or squeezed.

## Files / Assets / IDs

- Runtime: `scripts/ui_screens.gd`, maybe shared UI helpers only if needed.
- Settings assets: `assets/sprites/ui/frames/settings_v3/`, optional `assets/backgrounds/ui/`.
- Mockup/spec: `docs/design/mockups/settings_v3_full_redraw/`.
- PixelLab references/manifests: `docs/design/references/settings_v3_full_redraw/`.
- Previews/QA: `docs/design/previews/settings_v3_full_redraw/`, `build/qa/settings_v3_full_redraw/`.
- Docs: `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`, `docs/design/ui_screens_inventory.md`, `docs/design/content_registry.md`, `CHANGELOG.md`.
- Tests: `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd`, `tests/runtime_smoke_test.gd`, `tests/video_settings_apply_test.gd`, `tests/display_resolution_test.gd`, `tests/game_settings_smoke_test.gd`, relevant rebind/settings tests.

## Acceptance Criteria

- [ ] Jira claim comment from executor includes Owner, Thread/Worker, Lane, Locked paths/screens/assets, branch/worktree and next verification step before any implementation.
- [ ] Complete inventory of all Settings text/elements/states exists and matches current code; unknown/dynamic entries are explicitly listed.
- [ ] `ui_plan.json`/`layout.json` and safe-zone guide/report exist before image generation; report decision is `ready_for_image`.
- [ ] Three OpenAI-generated reference mockups exist for `Экран`, `Звук`, `Управление`, using the approved geometry and with empty content zones.
- [ ] PixelLab final source/final UI assets exist for every Settings visual element, plus background if needed; manifest records PixelLab IDs/tags/export paths and no secrets.
- [ ] Generated UI assets are native-size for `2560x1440` and `1920x1080`, or are native `2560x1440` assets downscaled only proportionally to 1080p; QA evidence confirms no one-axis stretch/squash.
- [ ] Runtime or handoff uses only PixelLab final assets for production, not the OpenAI mockup images.
- [ ] All production art is textless where runtime text is expected; transparent PNG/9-slice/content margins are documented.
- [ ] Runtime integration, if included, preserves Settings behavior: tabs, pending video apply/revert, audio persistence, toggles, controls scroll, key rebind flow, main/pause return origin.
- [ ] No content overlaps decorative frame art at `1280x720`, `1920x1080`, `2560x1440`; screenshots of all three tabs are saved.
- [ ] Required tests pass, or any failure is recorded as out-of-scope blocker with Jira evidence.
- [ ] Docs and local task evidence updated; Jira status/comment truthful; disk cleanup recorded.

## Notes For Dispatcher

This is a new full Settings v3 redesign request, not a duplicate reopen of SCRUM-439/575/674. Those tickets are closed and describe previous Settings v2/2K passes. This task requires a stricter staged pipeline and new PixelLab production redraw of every Settings visual element.

## Blocker — Codex Design 2026-06-30

SCRUM-694 был claim-first взят `codex-design-board-watcher` из Jira current
sprint. Перед mockup/asset генерацией проверены обязательные UI skills:
`fantasydisk-ui-director`, `fantasydisk-asset-generator` и
`content-zone-image-compositor`. Для этой задачи PixelLab MCP обязателен не
только для production assets, но и для FantasyDisk UI mockup/art layer; OpenAI
mockup в Jira разрешён только как промежуточный reference stage, но не как
fallback вместо PixelLab final package.

Live PixelLab check:
- direct Codex tool discovery для `pixellab` вернул 0 exposed tools;
- локальный PixelLab MCP bridge из Codex config стартует, `initialize` успешен;
- `tools/list` возвращает 49 tools, включая `create_ui_asset`,
  `get_ui_asset`, `list_ui_assets`;
- реальный UI endpoint check `list_ui_assets(limit=5)` возвращает
  `401: Missing Authorization header`;
- stderr bridge указывает на отсутствующий `AUTH_HEADER`.

Из-за этого нельзя создать обязательные PixelLab source/final assets для
Settings v3 и нельзя честно выполнить acceptance criteria. Runtime файлы,
layout/mockup assets и docs implementation sections не менялись; Godot smoke не
запускался, потому что runtime/code/assets не изменялись. Jira возвращена в
`К выполнению` с labels `blocked` + `pixellab-blocked`; stale `В работе` claim не
удерживается.

Unblock: настроить PixelLab MCP auth для Codex (`AUTH_HEADER="Bearer ..."` или
эквивалентный безопасный секрет в окружении) либо добавить явный Jira override
на non-PixelLab production pipeline с обновлёнными acceptance criteria.
