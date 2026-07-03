# UI: Кодекс — object-first дизайн-пакет с крупными изображениями

Статус: new
Приоритет: P1
Роль: Design
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Jira: SCRUM-849
Создано: 2026-07-03
Автор: Codex PM по прямому запросу пользователя
Locked paths: `docs/design/mockups/codex_object_first_redesign/`, `docs/design/references/codex_object_first_redesign/`, `docs/design/previews/codex_object_first_redesign_*`, `assets/sprites/ui/frames/codex_object_first/` если будут production assets

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

- [ ] Mockup/spec package лежит в
      `docs/design/mockups/codex_object_first_redesign/` с base geometry
      1920x1080 или 2560x1440 и targets 1280x720, 1920x1080, 2560x1440.
- [ ] Preview/contact PNGs сохранены в `docs/design/previews/`, включая полный
      экран и safe-zone/debug overlay.
- [ ] Левое меню покрывает все существующие секции: Персонажи, Монстры,
      Артефакты, Характеристики, Глоссарий, Возвышения.
- [ ] Центральная область содержит только краткий контент выбранной/list записи:
      image + title + one short summary, без дубля длинного body-текста.
- [ ] Правая область содержит full detail text и самое крупное изображение
      объекта на экране; длинный текст имеет явную scroll-зону и не перекрывает
      изображение.
- [ ] Не добавлены бессмысленные extra frames; визуальная плотность ближе к
      Atlas/Settings v6, чем к текущему ornate Codex.
- [ ] Каждый generated frame/button/background asset textless там, где текст
      рисует runtime, имеет documented margins и держит контент только в пустой
      safe-area.

## Заметки Для Исполнителя

Это Design-задача. Runtime-интеграция выделена отдельно в SCRUM-850 /
`backend_codex_object_first_runtime_integration_task.md`.
