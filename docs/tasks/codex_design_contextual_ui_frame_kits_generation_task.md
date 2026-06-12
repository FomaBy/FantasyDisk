# Задача Для Codex Design: Сгенерировать Контекстные UI Frame Kits

Статус: review
Создано: 2026-06-12
Автор: Claude-Designer
Jira: SCRUM-117
Роль: Design / Codex image executor
Приоритет: high

Dispatch: отправлено в существующий Design чат `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12.

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Коммит не делать.

## Контекст

Design concept готов:

```text
docs/design/ui_contextual_concept.md
```

Нужно сгенерировать контекстные D&D/tabletop UI frame kits вместо одного универсального декоративного кита для всех экранов.

Главное правило: каждая деталь рамки должна иметь смысл для экрана. Не добавлять случайные заклепки, завитки, виньетки, драгоценные точки и орнамент ради орнамента.

## Референсы / Mood Sources

Использовать как mood/reference logic, не копировать ассеты:

- D&D Beyond character sheet / builder: https://www.dndbeyond.com/characters
- D&D Beyond Maps / VTT coverage: https://www.polygon.com/tabletop-games/477300/dnd-beyond-maps-feature-open-beta-release-date-price-project-sigil-closed-beta
- Baldur's Gate 3 official site: https://baldursgate3.game/
- Larian UI commentary: https://www.gamesradar.com/games/rpg/divinity-lead-says-were-taking-notes-on-all-of-the-ui-mods-for-baldurs-gate-3-we-had-more-improvements-in-mind-that-we-just-couldnt-cram-into-our-releases/
- Darkest Dungeon official page: https://www.darkestdungeon.com/darkest-dungeon/
- Current FantasyDisk frame audit contact sheet: `docs/design/previews/current_ui_frames_audit_contact.png`

## Output Folder

```text
assets/sprites/ui/frames/contextual/
```

## Required Assets

Generate 4 kits. Keep file names exact.

### Wild Start Kit

For main menu, character select, weapon select.

- `ui_wild_panel_frame.png` — 256x256
- `ui_wild_button_frame.png` — 220x96
- `ui_wild_card_frame.png` — 220x180
- `ui_wild_tooltip_frame.png` — 240x140

Motif: living wood, thin vines, small leaves on corners, natural knots.

Avoid: vines crossing content, large flowers, bright saturated green, random leaves floating in the center.

### Grave Defeat Kit

For death/defeat and severe danger confirmations.

- `ui_grave_panel_frame.png` — 256x256
- `ui_grave_button_frame.png` — 220x96
- `ui_grave_card_frame.png` — 220x180
- `ui_grave_tooltip_frame.png` — 240x140

Motif: cracked bone, ash, cold stone, grave slab edges.

Avoid: gore, cartoon skull stickers, neon red, unreadably black centers.

### Laurel Reward Kit

For victory, rewards, level-up, artifact selection.

- `ui_laurel_panel_frame.png` — 256x256
- `ui_laurel_button_frame.png` — 220x96
- `ui_laurel_card_frame.png` — 220x180
- `ui_laurel_tooltip_frame.png` — 240x140

Motif: laurel branches, warm gold leaf, parchment, subtle arcane seal accents.

Avoid: casino gold, huge crowns, overbright glow, medals around every corner.

### Parchment / Codex / Map Kit

For codex, route map headers/panels and event text cards.

- `ui_parchment_panel_frame.png` — 256x256
- `ui_parchment_button_frame.png` — 220x96
- `ui_parchment_card_frame.png` — 220x180
- `ui_parchment_tooltip_frame.png` — 240x140
- `ui_parchment_tab_frame.png` — 180x72

Motif: parchment, book edge, bookmark tabs, rope/pin accents for map use.

Avoid: stains under text, illegible page texture, random metal studs.

## Art Rules

- PNG, RGBA, transparent background.
- No text, letters, labels, logo, watermark.
- Center content well must be clean and dark/light enough for existing UI text.
- Ornament must live on edges/corners; never reduce clickable/readable central area.
- 9-patch / `StyleBoxTexture` compatible: no important detail in the stretch center.
- D&D/tabletop style, painterly and polished, but practical UI asset first.
- Keep style consistent with current FantasyDisk characters/monsters/artifacts, not flat vector UI.
- Do not copy any reference image or recognizable commercial UI.

## Preview

Create:

```text
assets/sprites/ui/frames/contextual/contextual_ui_kits_preview.png
```

Preview should show all assets on a dark checker/background with labels, plus small samples over current UI dark background.

## Validation

- Verify exact dimensions for every PNG.
- Verify transparent corners/alpha.
- Verify center well is mostly unobstructed.
- Import via Godot headless after generation.

## Acceptance Criteria

- [x] 17 PNG generated at exact paths/sizes.
- [x] All PNG are RGBA with alpha.
- [x] Preview sheet exists.
- [x] Visual language is contextual: Wild, Grave, Laurel, Parchment feel clearly different.
- [x] No meaningless generic studs/curves copied across every kit.
- [x] No text/watermark.
- [x] Task file moved to `review` with result summary.

## Handoff After Generation

After assets are ready, Claude-Designer reviews them and then Back-end can integrate via:

```text
docs/tasks/backend_contextual_ui_frame_theme_integration_task.md
```

## Result Summary 2026-06-12

Generated the full contextual frame kit in `assets/sprites/ui/frames/contextual/`: Wild, Grave, Laurel and Parchment/Codex/Map variants for panels, buttons, cards and tooltips, plus the Parchment tab frame. After user feedback on the first flat/simple pass, the kit was redrawn into a more realistic D&D/tabletop raster style using current FantasyDisk artifacts, characters, weapons and backgrounds as material/style references. The preview sheet is `assets/sprites/ui/frames/contextual/contextual_ui_kits_preview.png`; the local reference contact sheet is `docs/design/previews/contextual_ui_dnd_reference_contact.png`.

Validation:
- exact dimensions verified for all 17 required PNGs;
- all required frame PNGs are RGBA with alpha and transparent corners;
- center wells remain mostly clean for text/clickable content;
- Godot headless import completed successfully.

Next owner: Claude-Designer art review, then Back-end integration via `docs/tasks/backend_contextual_ui_frame_theme_integration_task.md`.

## QA-Вердикт (2026-06-12)
Статус: PASSED

Проверено (объективный анализ + визуал):
- Состав: ровно 17 frame-PNG в `assets/sprites/ui/frames/contextual/` (Wild/Grave/
  Laurel/Parchment ×4 + parchment_tab) + preview. Имена точные. VERIFIED.
- Размеры: все 17 совпадают со спекой (panel 256², button 220×96, card 220×180,
  tooltip 240×140, tab 180×72). VERIFIED.
- Alpha: все RGBA; снаружи рамки прозрачно (краевой alpha ~6%), центр — залитый
  материал (~95%) но ЧИСТЫЙ/однородный под текст (не прозрачный вырез, а панель —
  валидный стиль; «чистый центр под текст» соблюдён). VERIFIED.
- Визуал (preview + полноразмерные wild_panel/laurel_card): 4 кита различимы
  (Wild зелёное дерево+лозы по краям, Grave тёмный сланец, Laurel тёплая бронза+
  лавры в углах, Parchment светлый пергамент). Орнамент на краях/углах, НЕ в центре.
  Лозы не пересекают контент; золото тёплое, без казино/пересвета; без неона. VERIFIED.
- Нет текста/watermark на ассетах (лейблы — только в preview-листе). VERIFIED.
- Import: 18 `.import` сгенерированы, project импортируется чисто (smoke зелёные). VERIFIED.

Багов нет. Примечание: ассеты untracked (ждут коммита Claude-Designer — «коммит не
делать» по задаче). Интеграция в экраны — отдельная задача
`backend_contextual_ui_frame_theme_integration_task.md`.
