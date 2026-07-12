# SCRUM-1017 — Codex Navigation And Enlarged Icons Design Handoff

Статус: done

Контур: Codex

Owner: Designer2/Codex

Thread/Worker: `/root/audit_qa`

Jira: SCRUM-1017

Backend dependencies: SCRUM-954, SCRUM-958

Locked writes: `docs/design/mockups/scrum1017_codex_navigation_icons/**`,
`docs/design/references/scrum1017_codex_navigation_icons/**`,
`docs/design/previews/scrum1017_codex_navigation_icons_*.png`, this mirror,
scoped SCRUM-1017 sync-map entry.

Read-only: runtime code/tests/data and all current runtime images.

## Цель

Подготовить единый PixelLab-first Design source package для двух Backend-задач:
новой навигации/геометрии Кодекса (SCRUM-954) и крупных реальных изображений
персонажей, монстров и артефактов (SCRUM-958). Runtime UI не изменяется.

## Обязательный контракт

- Anchor: `1920x1080`; responsive targets: `1280x720`, `2560x1440`.
- Шесть вкладок: `Персонажи`, `Монстры`, `Артефакты`, `Характеристики`,
  `Атрибуты`, `Возвышение`.
- Центральные строки: только реальное изображение записи и центрированное
  русское display-name; без raw ID, English duplicate, category emblem и
  micro-icon.
- Правая панель: крупный preview, русское имя и читаемые секции описания,
  умений/способностей, черт и gameplay notes.
- Две случайные вертикальные полосы под preview отсутствуют и запрещены.
- Контент располагается только внутри пустых content zones; frame ornament,
  rails, gems, claws и углы остаются полностью видимыми.

## Pipeline

1. Полный inventory текущего Codex/data/image contract.
2. `ui_plan.json` + planning validator; генерация разрешена только при
   `decision=ready_for_image`.
3. Exact `layout.json` и pre-generation guide.
4. PixelLab MCP textless RGBA frame/layout layer с provenance manifest.
5. Bundled compositor добавляет только runtime-like текст и реальные
   существующие изображения внутрь объявленных зон.
6. Character / monster / artifact state previews, debug overlays и fit reports.
7. Responsive/frame-safe validation и runtime smoke без runtime edits.

## Решение По Архитектуре

Один неизменяемый PixelLab frame layer используется для всех категорий.
Состояния отличаются только содержимым объявленных compositor zones. Это даёт
Backend один геометрический контракт и не превращает mockup в baked runtime UI.

## Статус Работы

- Jira current-sprint claim выполнен до файловых изменений.
- PixelLab MCP config smoke: PASS; `get_balance` returned `isError=false`, no
  secrets printed or stored.
- Planning gate: `ready_for_image`, `ok=true`, 51/51 elements, zero
  errors/warnings. Initial `revise_task` was resolved before generation.
- PixelLab UI asset:
  `27b4e50d-3d97-470d-bb7a-e11eecfb0c5f`,
  `scrum1017_codex_navigation_icons_v1`, direct `672x378` RGBA with true
  transparency. No OpenAI/manual/legacy fallback.
- Three final compositor states: characters, monsters and artifacts;
  `ok=true`, 22/22 zones each. All previews/debug overlays were visually
  inspected against the hard frame rule.
- Responsive geometry: PASS at `1280x720`, `1920x1080`, `2560x1440`; panel
  gaps `16/24/32 px`, row image zones `59x64 / 88x96 / 117x128`, detail
  preview zones `157x165 / 236x248 / 315x331`.
- Final validators/tests on fresh `origin/dev` `cee96169`: PASS.
  `codex_data_smoke_test.gd` (31 monsters, 17 characters, 161 artifacts,
  5 ascensions, 34 stats), `asset_reference_integrity_test.gd`,
  `dark_fantasy_ui_theme_test.gd`, `runtime_smoke_ui_test.gd`,
  `ui_no_overlap_matrix_test.gd`, `runtime_smoke_test.gd`; duplicate-artifact
  guard scanned 13931 files. Known benign dummy-render `texture_2d_get`
  screenshot-helper warning only.
- Runtime/data/test files were not modified.
- Independent Design QA: required before SCRUM-954/SCRUM-958 implementation.

## Result Paths

- Spec and Backend handoff:
  `docs/design/mockups/scrum1017_codex_navigation_icons/spec.md`
- Plan/layout/fit/debug evidence:
  `docs/design/mockups/scrum1017_codex_navigation_icons/`
- PixelLab source/provenance:
  `docs/design/references/scrum1017_codex_navigation_icons/manifest.json`
- Chat-ready previews:
  `docs/design/previews/scrum1017_codex_navigation_icons_*.png`

## Backend Handoff

SCRUM-954 owns responsive Control/navigation/list/detail integration.
SCRUM-958 owns canonical character/monster/artifact image routing and the
enlarged crop/contain policy. Both must follow the exact paths, rectangles,
fonts, scrollbar lanes and required test matrix in `spec.md`; neither may begin
runtime changes until independent Design QA accepts SCRUM-1017.

## Process Notes

- Product decision: one unchanged PixelLab frame layer is shared by every
  category; only declared content zones vary. This prevents baked runtime data
  and preserves one geometry contract for both Backend tickets.
- Skill influence: UI Director enforced mockup-first/PixelLab-only work and
  preview presentation; Content Zone Compositor enforced plan/layout gates and
  zone-only compositing; Asset Generator enforced transparent source/provenance
  and prohibited fallback.
- Disk cleanup and pushed commit IDs are recorded in the final Jira comment
  after integration to `origin/dev`.
