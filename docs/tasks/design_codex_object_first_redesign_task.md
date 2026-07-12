# UI: Кодекс — object-first дизайн-пакет с крупными изображениями

Статус: done
Приоритет: P1
Роль: Design
Контур: Codex
Owner: design/codex-scrum-849-object-first-design
Thread/Worker: current Codex control thread + subagents as needed
Jira: SCRUM-849
Версия: 0.2.1
Создано: 2026-07-03
Автор: Codex PM по прямому запросу пользователя
Locked paths: `docs/design/mockups/codex_object_first_redesign/`, `docs/design/references/codex_object_first_redesign/`, `docs/design/previews/codex_object_first_redesign_*`, `assets/sprites/ui/frames/codex_object_first/` если будут production assets

Claim note 2026-07-03: Jira current-sprint labels include `codex`, issue was
returned by the Codex lane helper, and PM cleanup moved the task into active
sprint. Mirror updated from the original `Контур: Claude` draft to live Codex
ownership after Jira claim-first.

## Контекст

Текущий внутриигровой Кодекс после SCRUM-725 всё ещё воспринимается как
перегруженный рамками экран: объект записи теряется, изображения мелкие, а
чтение требует слишком много визуального шума. Нужно подготовить новый
минимальный UI-дизайн по принципам экрана «Атлас героев» и Settings v6:
сильный фокус на объекте, читаемые панели, красивые кнопки категорий слева и
минимум рамок, которые не несут смысловой нагрузки.

Визуальные якоря:
- текущий Кодекс: `build/qa/design_review/codex_1920x1080.png`;
- текущая карта Codex: `docs/design/mockups/codex_redesign_2026_06/layout_map.md`;
- Атлас героев: `docs/design/previews/meta40_atlas_mockup.png`;
- Settings v6: `docs/design/previews/settings_v6_contact.png`,
  `build/qa/scrum847_v6/settings_v6_screen_1920x1080.png`;
- будущая runtime-точка: `scripts/ui_screens.gd::_show_codex_screen`.

## Что Нужно Сделать

1. Через `fantasydisk-ui-director` подготовить mockup/spec package для нового
   Codex layout: PixelLab-first mockup/spec, safe zones, responsive rules и
   production-ready textless frame/background/button assets, если они нужны.
2. Композиция обязательна:
   - слева вертикальное меню категорий красивыми кнопками;
   - в центре краткая выбранная запись или обзор: крупное изображение, title и
     очень короткое описание;
   - справа развернутое описание с самым крупным изображением объекта.
3. Убрать лишние декоративные фреймы. Оставлять только рамки/разделители, которые
   реально отделяют логические части: навигация, центральный обзор/list, detail
   panel, back/action controls.
4. Изображения объектов должны быть заметными и чёткими: герои, монстры, боссы,
   артефакты и статы не должны выглядеть как маленькие иконки внутри текста.
   Использовать текущие canonical art sources; если объекту не хватает качества,
   записать отдельный asset follow-up, а не маскировать проблему новой рамкой.
5. Зафиксировать все content zones: текст, иконки, портреты, список, scrollbar и
   кнопки не накладываются на орнамент, борта, углы, самоцветы или металл.

## Acceptance Criteria

- [x] Mockup/spec package лежит в
      `docs/design/mockups/codex_object_first_redesign/` с base geometry
      1920x1080 или 2560x1440 и targets 1280x720, 1920x1080, 2560x1440.
- [x] Preview/contact PNGs сохранены в `docs/design/previews/`, включая полный
      экран и safe-zone/debug overlay.
- [x] Левое меню покрывает все существующие секции: Персонажи, Монстры,
      Артефакты, Характеристики, Глоссарий, Возвышения.
- [x] Центральная область содержит только краткий контент выбранной/list записи:
      image + title + one short summary, без дубля длинного body-текста.
- [x] Правая область содержит full detail text и самое крупное изображение
      объекта на экране; длинный текст имеет явную scroll-зону и не перекрывает
      изображение.
- [x] Не добавлены бессмысленные extra frames; визуальная плотность ближе к
      Atlas/Settings v6, чем к текущему ornate Codex.
- [x] Каждый generated frame/button/background asset textless там, где текст
      рисует runtime, имеет documented margins и держит контент только в пустой
      safe-area.

## Заметки Для Исполнителя

Это Design-задача. Runtime-интеграция выделена отдельно в SCRUM-850 /
`backend_codex_object_first_runtime_integration_task.md`.

## Result 2026-07-03 — ready_for_integration

Owner: design/codex-scrum-849-object-first-design
Thread/Worker: current Codex control thread + Confucius read-only inventory
subagent

Delivered:
- PixelLab MCP mockup: `docs/design/mockups/codex_object_first_redesign/pixellab_mockup_v1.png`
  (`e55602bb-9328-4427-bbad-f3df60aa1e82`, `688x384` UI panel).
- Spec: `docs/design/mockups/codex_object_first_redesign/spec.md`
  (`Status: ready_for_integration`).
- Machine-readable zones:
  `docs/design/mockups/codex_object_first_redesign/layout_zones.json`.
- Prompt/provenance:
  `docs/design/mockups/codex_object_first_redesign/pixellab_prompt.md`.
- Handoff for SCRUM-850:
  `docs/design/mockups/codex_object_first_redesign/handoff_to_scrum850.md`.
- Previews:
  `docs/design/previews/codex_object_first_redesign_mockup_v1.png`,
  `docs/design/previews/codex_object_first_redesign_mockup_v1_1920.png`,
  `docs/design/previews/codex_object_first_redesign_safe_zones_v1.png`,
  `docs/design/previews/codex_object_first_redesign_contact_v1.png`.

Design decisions:
- No new production frame/button sprites are promoted in this Design task.
  SCRUM-850 should first reuse existing Codex/Settings-family assets and only
  generate a targeted production sprite follow-up if those cannot preserve the
  safe-zone contract.
- Right detail object stage is the largest image zone; center area stays concise
  and must not duplicate full body text.
- Monster/boss image quality issues are follow-ups, not layout workarounds.

Verification:
- PixelLab MCP generation completed and preview was shown in chat.
- JSON layout validates with `python3 -m json.tool`.
- Preview dimensions validated with PIL.
- Disk cleanup: none created beyond committed package files; transient `.import`
  and `.uid` sidecars from prior Godot runs were removed before work.

## QA-Вердикт 2026-07-03

Статус: PASSED

Evidence:
- Jira QA comment verified `origin/dev` contained required design commits
  `676fc3cf` and `6759ecac`.
- `docs/design/mockups/codex_object_first_redesign/spec.md` is
  `ready_for_integration`.
- `layout_zones.json` validates as JSON and defines the 1920x1080 base plus
  responsive zones.
- `handoff_to_scrum850.md` exists and is ready for runtime integration.
- PixelLab mockup and previews exist with expected dimensions: mockup 688x384,
  1920 preview 1920x1080, safe overlay 1920x1080, contact sheet 1920x620.
- Visual inspection confirms the left category rail, center concise overview,
  and right larger object/detail stage; the safe overlay keeps runtime content
  zones off ornaments and borders.
- Godot runtime was not run by scope: this was design-source QA only.

Disk cleanup: no QA worktree/cache created.
