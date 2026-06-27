# SCRUM-519: Level Up — создать красивую всплывающую иконку/бейдж

Jira: SCRUM-519 · Роль: Designer 2 (designer/art) · Контур: Codex · Приоритет: P1 · foma · Эпик: SCRUM-216
Статус: Контроль качества (QA)

## Что и зачем
При получении уровня игрок должен получать яркий, мгновенно читаемый визуальный сигнал «Level Up» — короткий popup возле персонажа. Цель с точки зрения продукта: усилить петлю прогрессии (kill → XP → level up), дать игроку приятный «джус»-момент и подсказку «пора зайти в экран прокачки». Сейчас рантайм рисует процедурную текстовую плашку (Label + кольцо/вспышка/искры), что выглядит дёшево и не в стиле игры.

Это **Design-source** задача: её результат — production-ready прозрачный PNG-бейдж/иконка с текстом `Level Up` в стиле FantasyDisk (D&D + Dark Fantasy Dragon: строго, эпично, читаемо, без перегруза деталями), плюс source/reference/preview-файлы и handoff для Back-end. Сам рантайм-показ (подмена процедурной плашки на этот PNG) делает ОТДЕЛЬНЫЙ Back-end тикет **SCRUM-520** — он вне scope SCRUM-519.

Ожидаемый результат: финальный asset с чистой alpha, без белого/матового фона, не обрезанный по краям, читаемый на игровых фонах и при небольшом размере у головы персонажа; рядом сохранены варианты/source/contact-sheet; в репозитории лежит handoff с финальным путём, рекомендованным display-size, pivot/anchor и заметками по анимации.

## Текущее состояние в коде
Дизайн-работа **уже выполнена и закоммичена** (commit `bd962430` «SCRUM-519 add level up popup badge», 2026-06-27). На этой задаче от исполнителя требуется **QA-приёмка** артефактов и handoff, а не повторная генерация с нуля. Что есть сейчас:

Финальный рантайм-asset:
- `assets/sprites/effects/level_up_popup_badge.png` — 512×256, RGBA. Визуально: тёмный геральдический картуш с драконьими крыльями и красными гранёными вставками, текст `Level Up` светлым золотом. Текст занимает ВЕРХНЮЮ половину плашки; нижняя зона — крупная пустая тёмная область.

Source / evidence (каталог `docs/design/references/level_up_popup/`):
- `level_up_popup_badge_base.png` — сгенерированная пустая база бейджа (2.1 МБ).
- `level_up_popup_badge_base_alpha.png` — база с вычищенной alpha.
- `level_up_popup_badge_final.png` — финал с вкомпонованным текстом (он же копируется в `assets/.../level_up_popup_badge.png`).
- `level_up_popup_badge_final_debug.png` — debug-оверлей зон.
- `level_up_popup_layout.json` / `level_up_popup_layout_plan.json` / `*.report.json` — лейаут-план: canvas 512×256, zone `label_zone` x=92 y=83 w=328 h=88, шрифт BigCaslon, max_font 72 / min_font 42, цвет `#FFE6A6`, обводка `#26100B` 4px, `uppercase:false`.
- `level_up_popup_text_guide.png` / `level_up_popup_layout_guide.png` — гайды зон.
- `level_up_popup_badge_alpha_report.json` — QA-отчёт по alpha (см. ниже).
- `docs/design/previews/level_up_popup_badge_contact_sheet.png` — contact sheet/preview.

QA-метрики из `level_up_popup_badge_alpha_report.json` (заявленные дизайнером):
- size `[512,256]`, mode `RGBA`, alpha_extrema `[0,255]`.
- nontransparent_bbox `[66,12,447,246]`, edge_alpha_max `0` (по всем 4 краям 0 — НЕ обрезан).
- `white_matte_pixels_alpha_gt_8 = 0`, `green_spill_pixels_alpha_gt_8 = 0` (чистая alpha, без белого матового и зелёного спилла).
- safe_padding_px: left 66, top 12, right 65, bottom 10.
- content_zone_px `{x:92,y:83,w:328,h:88}`.
- recommended_display_size_px `[224,112]`; minimum_readable_display_size_px `[160,80]`.
- recommended_pivot: center-bottom, 10–18 px над головой персонажа, твин вверх + fade out.

Существующий task-файл дизайнера: `docs/tasks/design_level_up_popup_badge_task.md` (Статус: done) — содержит итог и handoff.

Рантайм-показ (для контекста, в SCOPE НЕ входит — это SCRUM-520):
- `scripts/player.gd:4` `signal leveled_up`, эмитится в `scripts/player.gd:1422`.
- `scripts/combat_director.gd:46-47` коннектит `leveled_up` → `game.ui._on_player_leveled_up`.
- `scripts/ui_screens.gd:5430 _on_player_leveled_up()` → `_show_level_up_toast()` (строка 5446) инстанцирует `LEVEL_UP_TOAST_SCENE` (`scenes/LevelUpToast.tscn`, preload в `scripts/main.gd:231`).
- `scripts/level_up_toast.gd` — текущая ПРОЦЕДУРНАЯ реализация: рисует `Label "LEVEL UP"` (строки 52-61) + additive ring/flash/sparks. **PNG-бейдж тут пока НЕ используется.** Подмена на `level_up_popup_badge.png` — задача SCRUM-520, в SCRUM-519 код НЕ трогаем.

## Что сделать — по шагам
Задача в статусе QA. Исполнитель — **QA / Designer 2**: верифицировать готовые артефакты против Acceptance Criteria, зафиксировать вердикт, при провале — вернуть на доработку дизайнеру (а не чинить код рантайма).

1. **Проверить наличие и целостность файлов**: все пути из раздела «Текущее состояние» существуют, не битые, лежат в согласованных каталогах (`docs/design/references/level_up_popup/`, `docs/design/previews/`, `assets/sprites/effects/`). `.import` присутствуют (Godot заимпортил).
2. **Перепроверить alpha/без-матовости НЕЗАВИСИМО** (не доверять только JSON дизайнера): открыть `assets/sprites/effects/level_up_popup_badge.png`, убедиться: RGBA, alpha по краям = 0 (не обрезан), нет сплошного белого/серого матового фона, нет зелёного спилла. Можно скриптом на PIL/`Image` или через Godot. Сверить фактические числа с `level_up_popup_badge_alpha_report.json`.
3. **Проверить читаемость на минимальном размере**: смасштабировать asset до `minimum_readable_display_size_px` (160×80) и до рекомендованного (224×112), проверить, что `Level Up` остаётся читаемым; наложить на 2-3 реальных игровых фона (светлый/тёмный/пёстрый — например арена + враги) и убедиться в контрасте.
4. **Проверить safe padding / не-обрезанность**: bbox `[66,12,447,246]` внутри 512×256 с воздухом по краям — крылья/орнамент не упираются в границы канваса.
5. **Проверить handoff для Back-end**: в `docs/tasks/design_level_up_popup_badge_task.md` (или в `*_alpha_report.json`) явно указаны: финальный asset path, recommended display size, pivot/anchor, animation notes. Убедиться, что SCRUM-520 разблокирован/прокомментирован.
6. **Зафиксировать вердикт и эстетическое замечание**: text занимает только верхнюю половину плашки, низ — крупная пустая тёмная зона (см. п. «Замечания»). Решить product-call'ом: (a) принять как есть (низ — намеренная зона под будущий sub-text «Level N» / число уровня), либо (b) вернуть дизайнеру на перекомпоновку текста по вертикальному центру плашки. Зафиксировать выбор в вердикте.
7. **Прогнать `jira_board_sync.py`** после вердикта (PASSED → Готово; FAILED → вернуть в работу со сменой статуса и в .md, и в Jira — см. memory «Reopen change status»).

## Acceptance Criteria
- [ ] Создан transparent PNG icon/badge с текстом `Level Up`, читаемый на игровых фонах и при небольшом размере возле персонажа. *(asset: `assets/sprites/effects/level_up_popup_badge.png`)*
- [ ] Asset имеет чистую alpha, НЕ содержит белого/матового фона и НЕ обрезан по краям (edge alpha = 0 по всем сторонам; verified независимо, не только по JSON).
- [ ] Размер и safe padding подходят для runtime popup; source/варианты сохранены рядом с финальным asset.
- [ ] Source/reference файлы и preview/contact sheet сохранены под `docs/design/references/level_up_popup/` (+ `docs/design/previews/...contact_sheet.png`).
- [ ] Добавлен краткий handoff для Back-end: финальный asset path, recommended display size (224×112, min 160×80), pivot/anchor (center-bottom, 10–18 px над головой), animation notes (scale 0.92→1.04→1.0, float up 24–36 px, fade ~0.85 s).
- [ ] (QA доп.) Фактические alpha-метрики совпадают с заявленными в `level_up_popup_badge_alpha_report.json` (size 512×256, alpha_extrema [0,255], white_matte=0, green_spill=0).
- [ ] (QA доп.) Принято product-решение по пустой нижней зоне плашки (accept / rework) и зафиксировано в вердикте.
- [ ] (QA доп.) `jira_board_sync.py` прогнан, статус Jira соответствует вердикту, `docs/tasks/SCRUM-519_*.md` и `design_level_up_popup_badge_task.md` синхронны с реальностью.

## Files / точки входа
- `assets/sprites/effects/level_up_popup_badge.png` — финальный рантайм-asset (512×256 RGBA), объект приёмки. **НЕ перегенерировать без причины** (locked path дизайнера).
- `docs/design/references/level_up_popup/` — source/base/final/debug/layout/guide/alpha-report. Каталог приёмки (locked path).
- `docs/design/references/level_up_popup/level_up_popup_badge_alpha_report.json` — эталон QA-метрик для сверки.
- `docs/design/previews/level_up_popup_badge_contact_sheet.png` — preview/contact sheet (locked path).
- `docs/tasks/design_level_up_popup_badge_task.md` — handoff дизайнера; проверить полноту, при rework обновить статус.
- (контекст, НЕ менять) `scripts/level_up_toast.gd`, `scripts/ui_screens.gd:5446 _show_level_up_toast`, `scripts/main.gd:231` — рантайм; интеграция бейджа = SCRUM-520.

## Замечания / подводные камни
- **Scope-граница**: SCRUM-519 = ТОЛЬКО Design-source + QA приёмка артефактов. Подмена процедурной плашки `level_up_toast.gd` на PNG — это SCRUM-520 (Back-end). В рамках этой задачи **код рантайма не трогаем**.
- **Anti-collision / locked paths**: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — LOCKED, в этой задаче их редактировать НЕ нужно вовсе (они только для контекста интеграции). Все правки (если потребуется rework) — внутри design-каталогов, ими владеет Designer 2.
- **Главное эстетическое замечание**: на финальном PNG текст `Level Up` сидит в верхней половине картуша, а нижняя половина — большая пустая тёмная зона (content_zone объявлен y=83 h=88 при высоте канваса 256, т.е. центр зоны ~127 — текст реально выше геометрического центра плашки). Это может выглядеть «недозаполненным» в popup. Варианты: принять (зарезервировать низ под будущий sub-text «Level N» / номер уровня) либо вернуть на вертикальное центрирование. Решение — за QA/продактом, зафиксировать.
- **Не доверять JSON слепо**: alpha-отчёт писал сам генератор; для честной приёмки перепроверить ключевые метрики (edge alpha, white matte, green spill) независимым инструментом.
- **Связанные тикеты**: SCRUM-520 (Back-end runtime-показ — потребитель этого asset), эпик SCRUM-216. Текст в `level_up_toast.gd` сейчас «LEVEL UP» (uppercase), а на бейдже «Level Up» (mixed case, `uppercase:false`) — при интеграции в SCRUM-520 проследить за консистентностью кейса.
- **Версия/спринт**: дизайнер пометил v0.1.7 / Спринт 0.1.7. Учитывать активный feature-freeze 0.1.5 (новые фичи → 0.1.6+); это полировка прогрессии, не новая механика.
- **Jira live-sync mandate**: держать Jira синхронной на каждом шаге; при reopen менять статус и в .md, и в Jira (не только метки).
