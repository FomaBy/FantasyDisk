# ART: Рамка описания героя (центр) из референса DescriptionHS — на всё свободное место

Статус: new
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-323
Связано: SCRUM-281 (Hero Select kit, слот dossier), SCRUM-320/321/322 (карусель/превью/роза)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Возьми фрейм из DescriptionHS в references и создай таску для замены фрейма
описания героя по центру экрана. Этот фрейм должен занимать всё оставшееся место
на экране».

Описание героя по центру = панель досье `HeroSelectDossierPanel`
(PanelContainer, ui_screens.gd:424-431; внутри HeroSelectDossier с заголовком,
описанием, чертами, оружием, возвышением, кнопкой «Выбрать») со стилем
`_hero_select_frame_style("dossier")`. Стоит в центре `HeroSelectContent`
(content_row, 392-397) между превью слева и розой ветров справа,
size_flags_vertical = EXPAND_FILL, stretch_ratio 0.62. Сейчас рамка из SCRUM-281
(ui_frame_hero_select_dossier.png) — заменить на референс из DescriptionHS.

## Исходник (референсы, уже в репо)
docs/design/references/DescriptionHS/ — 8 PNG. Использовать как reference/source
pack для геометрии фрейма и технической нарезки:
- `ChatGPT Image Jun 14, 2026, 11_12_12 AM (1).png` — `1467x1072`
- `ChatGPT Image Jun 14, 2026, 11_12_12 AM (2).png` — `1120x1404`
- `ChatGPT Image Jun 14, 2026, 11_12_12 AM (3).png` — `2172x724`
- `ChatGPT Image Jun 14, 2026, 11_12_13 AM (4).png` — `2172x724`
- `ChatGPT Image Jun 14, 2026, 11_12_13 AM (5).png` — `2172x724`
- `ChatGPT Image Jun 14, 2026, 11_12_13 AM (6).png` — `2172x724`
- `ChatGPT Image Jun 14, 2026, 11_12_14 AM (7).png` — `2172x724`
- `ChatGPT Image Jun 14, 2026, 11_12_14 AM (8).png` — `2172x724`

Не добавлять новое художественное ТЗ в task result: фиксировать только source
file, размеры, alpha, margins, content-zone, backup и QA artifacts.

## Требования
1. Рамка описания героя должна закрывать центральную область экрана между превью
   слева и розой ветров справа, но не ценой one-axis stretch. Пользовательская
   директива 2026-06-14: при изменении разрешения frame art масштабируется
   пропорционально, с одинаковым scale factor по X/Y.
2. Не растягивать основной орнаментальный dossier frame только по высоте или
   только по ширине. Использовать цельный `TextureRect`/aspect-preserving frame
   layer, proportional source resize или другой pipeline, где углы/гребни/края
   сохраняют исходный аспект. 9-slice допустим только для плоской внутренней
   подложки без нерастяжимых деталей. При необходимости подправить геометрию
   `HeroSelectDossierPanel` (custom_minimum_size 426, stretch_ratio 429), чтобы
   рамка и content-layer масштабировались пропорционально.
3. Подключить как рамку слота `dossier`: заменить ассет
   (HERO_SELECT_FRAME_DIR/ui_frame_hero_select_dossier.png) и/или значения
   HERO_SELECT_FRAME_* для "dossier" (ui_screens.gd:59/69/79). Старый ассет — в
   бэкап, не удалять.
4. Весь контент досье (заголовок/описание/черты/оружие/возвышение/кнопка «Выбрать»)
   — в content-зоне рамки, отцентрован, без наезда на орнамент; описание читаемо.
5. Не менять художественное направление в рамках этой задачи: использовать
   только existing Hero Select/reference pack как источник, а в результате
   описывать технические параметры, не новый стиль.
6. Тест (smoke): экран строится; рамка досье = новый ассет, занимает всю
   центральную область; контент в content-зоне, no-overlap на 1280×720 /
   1920×1080 / 2560×1440. Скрин в build/qa/.
7. CHANGELOG; content_registry; menus_ui.

## Files / Assets / IDs
- docs/design/references/DescriptionHS/*.png (исходники; основной — «(2)» 1120×1404)
- scripts/ui_screens.gd (HERO_SELECT_FRAME_* "dossier" 59/69/79;
  HeroSelectDossierPanel 424-431; content_row 392-397; _hero_select_frame_style)
- assets/sprites/ui/frames/hero_select/ (нарезанный ассет + бэкап старого)
- tests/runtime_smoke_test.gd

## Технические Размеры И Safe-Area

### Outer-frame `ui_frame_hero_select_dossier.png`
- Текущий source PNG: `1347x984`, RGBA.
- Целевой runtime rect после SCRUM-320:
  - `1280x720`: `383x428` px.
  - `1920x1080`: `383x775` px.
  - `2560x1440`: `383x1116` px.
- Ширина фактически фиксирована около `383px`; высота сильно растягивается.
  Current layout дает диапазон высоты `428..1116px`, но main frame art нельзя
  тянуть по одной оси. Если frame масштабируется от 1280x720 base rect `383x428`,
  proportional target sizes для 1920x1080/2560x1440: примерно `575x642` и
  `766x856`. Остальная доступная область может быть content/layout padding, но
  не растянутый орнамент.
- Текущие texture margins для fallback StyleBox/inner flat layer:
  `Vector4(92, 86, 92, 90)` = left/top/right/bottom.
- Текущие content margins:
  `Vector4(28, 18, 32, 18)` = left/top/right/bottom.
- На 1280x720 полезная content-zone должна оставаться не уже `320px`.
  Визуально плотные элементы фрейма не должны заходить в эту content-zone.
- PNG должен быть RGBA с прозрачными внешними углами; без baked checkerboard,
  текста, иконок, персонажей, кнопок или лейблов.

### Внутренние элементы Возвышения
- `AscensionMinusButton` / `AscensionPlusButton`:
  - runtime `54x62`.
  - source `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button.png`
    сейчас `1053x1320`.
  - texture margins `Vector4(58, 58, 58, 62)`.
  - content margins `Vector4(14, 12, 14, 14)`.
- `AscensionLevelLabel`:
  - runtime `190x46`.
  - source `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_label.png`
    сейчас `2058x430`.
  - texture margins `Vector4(86, 36, 86, 38)`.
  - content margins `Vector4(24, 8, 24, 8)`.
- `AscensionModsLabel`:
  - runtime на 1280x720 примерно `323x34`.
  - source `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_mods.png`
    сейчас `2018x197`.
  - texture margins `Vector4(96, 30, 96, 32)`.
  - content margins `Vector4(28, 6, 28, 6)`.

### Start / choose button `HeroSelectChooseButton`
- Runtime size: `260x72`.
- Source-state files:
  `assets/sprites/ui/frames/red_gold/ui_btn_red_gold_hero_confirm.png`,
  `ui_btn_red_gold_hero_confirm_hover.png`,
  `ui_btn_red_gold_hero_confirm_pressed.png`,
  `ui_btn_red_gold_hero_confirm_disabled.png`.
- Current source size for each state: `320x104`, RGBA.
- texture margins `Vector4(78, 30, 78, 32)`.
- content margins `Vector4(54, 14, 54, 14)`.
- Сохранять 4 состояния normal/hover/pressed/disabled. Не bake-ить кнопку в
  общий dossier PNG. Hover не должен требовать baked glow: runtime уже использует
  normal texture + neutral hover tint.

### Runtime text/control constraints
- Не требовать изменения runtime fonts/sizes:
  `HeroSelectInfoTitle` 29px, `HeroSelectInfoDescription` 15px,
  `HeroSelectTraits`/`HeroSelectWeapons` 14px, `AscensionLevelLabel` 15px,
  `AscensionModsLabel` 11px.
- `HeroSelectRadarPanel` остается отдельным floating top-right widget outside
  dossier frame; новая рамка не должна занимать/перекрывать radar area.

## Acceptance Criteria
- [ ] Рамка описания героя = референс DescriptionHS; основной frame art масштабируется пропорционально, без one-axis stretch.
- [ ] Весь контент досье в content-зоне, не наезжает на орнамент; описание читаемо (закрывает SCRUM-276).
- [ ] Task result фиксирует финальные source size, texture margins, content margins и фактические runtime rects.
- [ ] Возвышение и start button остаются отдельными controls/assets; они не bake-ятся в outer-frame PNG.
- [ ] Старый ассет в бэкап; no-overlap на 3 разрешениях; 6 smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/content_registry.md, docs/design/systems/menus_ui.md, current_game_state.
Обновлять только фактические technical docs/registry записи: paths, source sizes,
runtime sizes, margins, backup location, QA artifact paths.
