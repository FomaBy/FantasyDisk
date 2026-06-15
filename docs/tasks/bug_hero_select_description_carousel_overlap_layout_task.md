# BUG/UI: Hero Select description + carousel overlap after frame redesign

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-354
QA: in_progress (2026-06-14)
Unblocked by: `design_hero_select_thinner_frames_no_overlap_task.md` / SCRUM-355
Связано: SCRUM-320, SCRUM-323, SCRUM-333, SCRUM-342, SCRUM-347

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пользовательский QA-фидбек 2026-06-14: на экране выбора персонажа описание героя
и нижняя карусель визуально наслаиваются друг на друга, а рамки выглядят слишком
толстыми. Design должен сначала обновить/облегчить frame assets и выдать точные
safe margins. После этого Back-end должен интегрировать результат и закрыть
фактическое layout overlap.

## Design Handoff — SCRUM-355
Design result is ready; this task is no longer blocked.

Final runtime assets:
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png`
  (`1120x1140`, RGBA);
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`
  (`1536x255`, RGBA).

Strict source-space content margins:
- dossier: `Vector4(126, 160, 126, 172)`;
- thumbnail strip: `Vector4(132, 62, 132, 62)`.

Scaled runtime targets:
- dossier:
  - `1280x720`: frame `387x394`, margins `Vector4(44, 55, 44, 59)`, content `300x279`;
  - `1920x1080`: frame `581x591`, margins `Vector4(65, 83, 65, 89)`, content `450x419`;
  - `2560x1440`: frame `774x788`, margins `Vector4(87, 111, 87, 119)`, content `600x559`;
- thumbnail strip:
  - `1280x720`: frame `1024x170`, margins `Vector4(88, 41, 88, 41)`, content `848x87`;
  - `1920x1080`: frame `1536x255`, margins `Vector4(132, 62, 132, 62)`, content `1272x131`;
  - `2560x1440`: frame `2048x340`, margins `Vector4(176, 83, 176, 83)`, content `1696x175`.

QA/reference files:
- `build/qa/scrum355/hero_select_thin_frames_qa.md`;
- `build/qa/scrum355/hero_select_thin_frames_runtime_rects.md`;
- `docs/design/previews/hero_select_thin_frames_content_zones.png`.

Current runtime rect dump shows the old layout still uses unsafe margins, e.g.
`HeroSelectInfoTitle` starts at y=153 inside a 720p dossier frame whose strict
safe y starts at 185. Back-end should update the runtime margin constants/layout
and add an assertion for content-vs-ornament safe-zone, not only rect-vs-rect
overlap.

## Scope — Back-end После Разблокировки
1. Обновить Hero Select layout так, чтобы:
   - `HeroSelectDossierContent` полностью помещал описание, черты, оружие,
     ascension controls и start button во внутреннюю content-zone frame;
   - `HeroThumbnailStripContent` полностью помещал миниатюры/hover/selected state
     во внутреннюю content-zone carousel frame;
   - dossier/radar/portrait/carousel не пересекались между собой;
   - контент не заходил на декоративные borders/gems/crests/metal/seals.
   - `HeroSelectDossierContent` uses the SCRUM-355 strict dossier margins above
     instead of `Vector4(96, 66, 96, 54)`.
   - `HeroThumbnailStripContent` uses the SCRUM-355 strict thumbnail margins
     instead of compact `Vector4(72, 36, 72, 36)`.
   - `HeroSelectDossierFrame` and `HeroThumbnailStripFrame` keep at least a
     16px vertical gap at 1280x720, 1920x1080 and 2560x1440.
2. Поддержать 1280x720, 1920x1080, 2560x1440 и узкие окна из no-overlap matrix.
3. При нехватке места использовать runtime layout решения: уменьшение внутренних
   отступов только в пределах safe-zone, scroll/clip для длинного текста,
   переносы, adaptive carousel item sizing. Не класть контент поверх рамок.
4. Сохранить hover/tooltip/selection behavior карусели, выбор персонажа, радар,
   ascension controls и кнопку старта.
5. Обновить automated QA/rect dump так, чтобы тест ловил именно этот класс бага:
   overlap между description/dossier content, carousel content and frame ornaments.

## Out Of Scope
- Не перерисовывать frame assets.
- Не менять gameplay, balance, персонажей, оружие или прогрессию.
- Не делать художественные решения вне интеграции готовых frame assets.

## Acceptance Criteria
- [x] Description/ascension/start button and carousel thumbnails do not overlap
  each other or decorative frame borders.
- [x] UI no-overlap matrix passes for 1280x720, 1920x1080, 2560x1440 and narrow
  supported windows.
- [x] Runtime smoke passes.
- [x] QA rect dump/screenshot saved under `build/qa/`.
- [x] `docs/design/current_game_state.md` and `docs/design/systems/menus_ui.md`
  updated with final runtime rects/margins.
- [x] Jira synced; task moves out of blocked only after Design result is recorded.

## Result — Back-end SCRUM-354
Done 2026-06-14.

- Runtime Hero Select now uses SCRUM-355 strict source-space margins:
  - dossier `Vector4(126, 160, 126, 172)`;
  - thumbnail strip `Vector4(132, 62, 132, 62)`, scaled from the actual `1536x255` source PNG.
- Dossier inner content was compacted to fit the stricter safe field without putting labels, ascension controls or the `Выбрать` button on frame ornament.
- `HeroSelectLayout` now keeps a 16px+ frame gap between dossier and carousel at 1280x720, 1600x900 and 2560x1440.
- Runtime smoke now asserts computed safe-zone containment for dossier/carousel content and writes the QA dump to `build/qa/hero_select_radar_rects.md`.
- Verification:
  - `runtime_smoke_ui_test.gd` — PASS;
  - `ui_no_overlap_matrix_test.gd` — PASS;
  - `runtime_smoke_test.gd` — PASS.

## Suggested Files
- `scripts/ui_screens.gd`
- `tests/runtime_smoke_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `docs/design/current_game_state.md`
- `docs/design/systems/menus_ui.md`

## Dispatcher Notes
- 2026-06-14: Documentation dispatcher created this as the Back-end half of the
  user-reported Hero Select overlap defect. It remains blocked until Design
  produces thinner frame assets and exact safe-zone margins.
- 2026-06-14: SCRUM-355 Design pass delivered thinner runtime PNGs, strict
  margins, previews and rect dumps. Task moved back to `new` for Back-end pickup.

## QA-Вердикт (2026-06-14)
Статус: PASSED

Проверено (фактически) — это рантайм-интеграция, закрывающая видимый overlap из
пользовательского QA-фидбека (Design-половина = SCRUM-355):
- **Margins реально сменены** (ui_screens.gd): `HERO_SELECT_DOSSIER_CONTENT_BASE`
  = `Vector4(126,160,126,172)` (стр.64, старые 96/66/96/54 УШЛИ);
  `HERO_SELECT_CAROUSEL_CONTENT_BASE` = `Vector4(132,62,132,62)` (стр.67, старые
  compact 72/36 УШЛИ).
- **Safe-zone containment ассерт** в runtime_smoke (`HERO_SELECT_DOSSIER_SAFE_MARGINS`
  стр.15) — тест ловит именно overlap контента с орнаментом (не только rect-vs-rect).
- **QA-dump** `build/qa/hero_select_radar_rects.md`: `HeroSelectDossierSafeRect`
  и `HeroThumbnailStripSafeRect` на 1280/1920/2560 (dossier content 300×279 @1280
  — точно по спеке 354); зазор dossier-safe-bottom(470.6)↔strip-safe-top(587.3) =
  **116.8px** (≫16px требования).
- **Визуал** `build/qa/cap_hero_select_354.png`: описание/черты/оружие/возвышение/
  «Выбрать» компактно ВНУТРИ content-зоны dossier (контент ниже навершия), карусель
  отделена зазором, ничего не лежит на декоративном орнаменте; портрет/радар/«Назад»
  на месте.
- **Тесты**: `runtime_smoke_test`, `ui_no_overlap_matrix_test`,
  `runtime_smoke_ui_test` — все passed; доки `menus_ui.md`/`current_game_state.md`
  обновлены.

Acceptance:
- [x] Описание/возвышение/start + миниатюры не накладываются друг на друга и на рамки.
- [x] no-overlap matrix зелёный (1280/1920/2560 + узкие окна).
- [x] runtime smoke зелёный (с safe-zone ассертом); QA rect dump/скрин сохранены.
- [x] Доки обновлены финальными rects/margins; Jira синкан.

Вывод: пользовательский дефект Hero Select overlap **устранён фактически** (тонкие
рамки 355 + строгие margins в рантайме 354). Баги: нет.
