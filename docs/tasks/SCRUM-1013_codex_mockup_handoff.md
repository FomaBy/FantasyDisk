# SCRUM-1013 — Codex Characteristics/Attributes Split: PixelLab Mockup Handoff

Статус: done  
Контур: Codex  
Owner: Design Main/Codex  
Thread/Worker: `/root/audit_repo`  
Jira: SCRUM-1013  
Backend dependency: SCRUM-955  
Locked writes: `docs/design/mockups/scrum1013_codex_characteristics_attributes/**`, `docs/design/references/scrum1013_codex_characteristics_attributes/**`, `docs/design/previews/scrum1013_codex_characteristics_attributes_*.png`, this task mirror, scoped SCRUM-1013 sync-map entry.  
Read-only: runtime/data/tests/product docs, especially `scripts/ui_screens.gd` and `scripts/codex_data.gd`.

## Цель

Подготовить проверяемый Design-пакет для Backend SCRUM-955: шесть русских
разделов Кодекса с отдельными `Характеристики`, `Атрибуты`, `Возвышение`,
центральным прокручиваемым списком и правым preview/detail, строго внутри
пустых content zones.

## Результат 2026-07-09

- Jira claim и write locks зафиксированы до изменений.
- PixelLab MCP config smoke: PASS; прямой namespace был stale, bridge доступен.
- `ui_plan.json` прошёл обязательный planning gate:
  `decision=ready_for_image`, `ok=true`, 0 errors, 0 warnings.
- Center list, related attributes и detail body имеют отдельные обязательные
  scrollbar lanes: `x=884..904`, `x=1242..1258`, `x=1720..1740`.
- `layout.json` и pre-generation guides созданы до PixelLab generation.
- Accepted PixelLab source: `3ace4827-cfee-439e-8545-4dc145993d2f`, tag
  `scrum1013_codex_characteristics_attributes_v3_alpha_clean`, native
  `672x378` RGBA. V1 отклонён из-за кристального арта внутри center list; V2
  исправил зоны, но сохранил checkerboard. V3 сохранил чистую геометрию и
  экспортировался с настоящей прозрачностью. OpenAI/manual fallback не
  использовался; новые frames/panels/cards после PixelLab не рисовались.
- Alpha-clean source: `141392` fully transparent pixels, `112624` opaque;
  SHA-256 `897eefe8d9b0a1e0a95d4d9712fdd735c346a3bac37e5250cc34ff2a2441d7ba`.
- Final mockup/preview: `1920x1080` RGB, byte-identical copies; SHA-256
  `424c8208c70bba44017c16aede7ad92d294ad24904c73c4b8464f5a05be08faf`.
- Bundled compositor final report: `ok=true`, 18/18 zones. Debug overlay
  visually inspected: Russian labels, stat icon, center rows, related list and
  detail copy remain inside empty interiors; no content touches dragon claws,
  gems, metal rails, button caps or frame corners.
- All six required labels are visible and distinct: `Персонажи`, `Монстры`,
  `Артефакты`, `Характеристики`, `Атрибуты`, `Возвышение`.
- Runtime/data/tests/product docs were not edited. Backend SCRUM-955 receives
  only the mockup/spec/source handoff package.

## Paths

- Spec: `docs/design/mockups/scrum1013_codex_characteristics_attributes/spec.md`
- UI plan/report/guide: `docs/design/mockups/scrum1013_codex_characteristics_attributes/ui_plan.*`
- Layout/guide: `docs/design/mockups/scrum1013_codex_characteristics_attributes/layout.*`
- PixelLab provenance: `docs/design/references/scrum1013_codex_characteristics_attributes/manifest.json`
- PixelLab base: `docs/design/references/scrum1013_codex_characteristics_attributes/pixellab_codex_characteristics_attributes_base_1920x1080.png`
- Preview: `docs/design/previews/scrum1013_codex_characteristics_attributes_preview.png`
- Debug overlay: `docs/design/mockups/scrum1013_codex_characteristics_attributes/codex_characteristics_attributes_mockup_debug_1920x1080.png`

## Verification

- Plan validator: `ready_for_image`, `ok=true`, 0 errors, 0 warnings.
- Layout guide report: `ok=true`, 18 zones.
- Final compositor report: `ok=true`, 18/18 zones.
- JSON syntax, PNG dimensions/modes/alpha and preview byte identity: PASS.
- `runtime_smoke_test.gd`: first run hit the unrelated run-autosave state flake
  (`Expected victory screen to clear run autosave`); immediate clean-cache
  repeat passed, including duplicate-artifact guard. Benign dummy-render
  `texture_2d_get` warning remained in the screenshot helper.
- Preview path was sent to the root agent for display in chat.
- Independent QA remains required; Design did not self-QA.

## Acceptance

- [x] Complete content/control/state inventory.
- [x] Exact 1920x1080 geometry, min/max fonts, scroll needs and safe margins.
- [x] Responsive contract for 1280x720 / 1920x1080 / 2560x1440.
- [x] Planning gate `ready_for_image`.
- [x] PixelLab source/export recorded; no fallback.
- [x] Final content-zone render report `ok=true`; debug overlay inspected.
- [x] Preview delivered to parent/user.
- [x] Runtime smoke green gate.
- [x] Package ready for commit/push and Jira `Контроль качества`; final hashes
  and disk cleanup are recorded in the Jira result comment after integration.

## Независимый QA-вердикт 2026-07-10

Статус: PASSED

Проверил: QA/Designer2 Codex (`/root/audit_qa`)

База финального прогона: fresh `origin/dev` `69e416c3`

- Design Main завершил и освободил locks до начала проверки; QA не менял
  mockup, PixelLab source, layout, spec, preview, runtime code или tests.
- PixelLab provenance подтверждён по manifest/request/export evidence. Accepted
  asset ID: `3ace4827-cfee-439e-8545-4dc145993d2f`; raw native export является
  настоящим `672x378` RGBA с `141392` полностью прозрачными и `112624`
  непрозрачными пикселями, без partial alpha. Его SHA-256:
  `86429a6fcc0fedd2fd1b560b2ac2e60cd11e59c40578beb1cfe78b565cbc3159`.
- Source PNG pixel-identical raw export (отличается только PNG encoding), а
  `1920x1080` base является точным nearest-neighbour upscale. SHA-256 source:
  `897eefe8d9b0a1e0a95d4d9712fdd735c346a3bac37e5250cc34ff2a2441d7ba`;
  base: `38fb3e21db0565b3490dac269e2d4ad7a4366da34cfe49d51be8e5a516bd1670`.
- Независимый повтор planning validator совпал с committed report:
  `ready_for_image`, `ok=true`, 35/35 элементов, 0 errors/warnings. Layout guide
  и final compositor совпали с committed reports: `ok=true`, 18/18 zones.
  Повторно сгенерированные final/debug изображения pixel-exact совпали с
  committed файлами (`max diff=0`).
- Все 18 content zones уникальны, попарно не пересекаются и находятся внутри
  родительских interiors. Ни одна зона не пересекает scrollbar lanes
  `884..904`, `1242..1258`, `1720..1740`; все rendered text bboxes помещаются
  в свои зоны.
- Responsive contract проверен для `1280x720`, `1920x1080`, `2560x1440`:
  панели остаются в canvas, межпанельные gaps масштабируются `16/24/32 px`.
  Preview и debug overlay визуально проверены: текст, иконка, списки и detail
  находятся только в пустых тёмных областях; dragon claws, gems, rails, button
  caps и углы рамок не перекрыты. Все шесть русских вкладок читаются; baked
  text, pseudotext и watermark отсутствуют.
- Final mockup и preview byte-identical, SHA-256
  `424c8208c70bba44017c16aede7ad92d294ad24904c73c4b8464f5a05be08faf`;
  debug overlay SHA-256
  `8164516811a621a0b636f35edfb181cc7a61fbd88b60a0ad6d190140142ba5a9`.
- `runtime_smoke_test.gd` повторно прошёл после fast-forward до актуального
  `origin/dev`, включая duplicate-artifact guard. Единственный вывод — известное
  benign dummy-render предупреждение `texture_2d_get` screenshot helper.

Вердикт: Design-пакет SCRUM-1013 соответствует PixelLab/content-zone/UI
контрактам и принят для Backend handoff SCRUM-955.
