# ART/UX: Hero Select thinner frames + no-overlap visual fix

Статус: review
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-355
QA: in_progress (2026-06-14)
Связано: SCRUM-320, SCRUM-321, SCRUM-322, SCRUM-323, SCRUM-333, SCRUM-342, SCRUM-347

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пользовательский QA-фидбек 2026-06-14: на экране выбора персонажа описание героя
и нижняя карусель всё ещё выглядят плохо, элементы визуально наслаиваются друг на
друга, рамки слишком тяжёлые. Нужно исправить и перерисовать интерфейс: сделать
рамки чуть тоньше, но сохранить стиль существующих Hero Select reference packs.

Ранее были закрыты SCRUM-320/321/322/323/333/342/347, но текущий визуальный
фидбек считается новым дефектом: прошлые PASS не закрывают фактическое восприятие
экрана пользователем.

## Scope — Design
1. Пересобрать/облегчить Hero Select visual frame kit для проблемных зон:
   - `ui_frame_hero_select_dossier.png` — frame описания героя/возвышения/кнопки;
   - `ui_frame_hero_select_thumbnail_strip.png` — нижняя рамка карусели;
   - при необходимости согласовать толщину `portrait`, `radar`, `thumbnail`,
     `asc_button`, `asc_label`, `asc_mods`, чтобы экран выглядел единым.
2. Сделать рамки визуально тоньше и легче, но сохранить D&D dark fantasy стиль
   существующих референсов:
   - `docs/design/references/DescriptionHS/`;
   - `docs/design/references/carusel/`;
   - `docs/design/references/herouiframe/`;
   - `docs/design/references/windrose/`.
3. Не добавлять runtime text/icons/buttons into PNG. Все frame assets должны быть
   RGBA/transparent where applicable, без baked labels, персонажей, текста,
   кнопок или иконок.
4. Для каждого изменённого frame asset зафиксировать:
   - source/reference;
   - final PNG path and dimensions;
   - visible decorative border thickness;
   - strict content-zone / safe margins;
   - runtime intended rects at `1280x720`, `1920x1080`, `2560x1440`;
   - backup path for replaced assets.
5. Глобальное правило: контент не должен накладываться на декоративную рамку.
   Safe-zone должна быть реально пустой внутренней областью, не bounding box.
6. Если `fantasydisk-asset-generator` недоступен (`OPENAI_API_KEY`/Python
   `openai` missing), использовать только уже утверждённые reference/source packs
   и воспроизводимый локальный pipeline для thinning/recomposition. Старые
   генераторы или случайную процедурную графику не использовать. Если без нового
   generation невозможно сделать качественно — поставить точный blocker.

## Out Of Scope
- Не менять gameplay, баланс, классы, прогрессию.
- Не делать Back-end layout logic глубже технических preview/metadata changes.
- Если для реального устранения overlap нужен layout/code pass, обновить/разблокировать
  Back-end handoff `bug_hero_select_description_carousel_overlap_layout_task.md`.

## Acceptance Criteria
- [ ] Dossier and carousel frames visually thinner/lighter while preserving reference style.
- [ ] Description, ascension controls, start button, carousel thumbnails and labels have
  documented empty content zones and do not sit on frame ornaments.
- [ ] No visual overlap between dossier area and carousel frame at 1280x720,
  1920x1080, 2560x1440.
- [ ] Backups and QA previews/rect notes saved under `build/qa/` and
  `docs/design/previews/`.
- [ ] `docs/design/current_game_state.md`, `docs/design/content_registry.md`, and
  `docs/design/systems/menus_ui.md` updated with final paths/sizes/margins.
- [ ] Jira synced; linked Back-end layout handoff updated with exact asset data.

## Suggested Files / Assets
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`
- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_*.png`
- `docs/design/references/DescriptionHS/`
- `docs/design/references/carusel/`
- `docs/design/references/herouiframe/`
- `docs/design/previews/`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`
- `docs/design/systems/menus_ui.md`

## Dispatcher Notes
- 2026-06-14: Documentation dispatcher created this as a new active 0.1.5 QA
  defect from user feedback and routed it to existing Design window
  `019eabf1-6d54-7561-8af9-ce25cdf483a9`. Keep reasoning High/no low.

## Result — 2026-06-14

Design pass completed and ready for Back-end integration/QA:

- Rebuilt the two problematic runtime frame assets in place:
  - `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png`
    (`1120x1140`, RGBA) from the accepted DescriptionHS pipeline;
  - `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`
    (`1536x255`, RGBA) from the accepted Carusel pipeline.
- Added deterministic local builder:
  - `tools/build_hero_select_thin_frames.py`
  - no image API/random generator; it recomposes only approved existing
    Hero Select sources and thins the center/border treatment.
- Added backup/QA artifacts:
  - backup zip: `build/qa/scrum355/hero_select_pre_scrum355_frame_assets.zip`;
  - strict content-zone QA: `build/qa/scrum355/hero_select_thin_frames_qa.md`;
  - runtime rect dump copy: `build/qa/scrum355/hero_select_thin_frames_runtime_rects.md`;
  - preview: `docs/design/previews/hero_select_thin_frames_content_zones.png`.
- Strict safe margins for Back-end:
  - dossier source margins `Vector4(126, 160, 126, 172)`;
  - thumbnail strip source margins `Vector4(132, 62, 132, 62)`.
- Runtime intended rects documented in `build/qa/scrum355/hero_select_thin_frames_qa.md`
  for `1280x720`, `1920x1080`, and `2560x1440`.
- Verification:
  - Godot import: PASS;
  - `tests/runtime_smoke_ui_test.gd`: PASS;
  - `tests/ui_no_overlap_matrix_test.gd`: PASS;
  - `tools/capture_hero_select_qa.gd`: PASS / headless rect dump saved.

Important handoff note: current runtime layout still uses older margins
(`HERO_SELECT_DOSSIER_CONTENT_BASE = Vector4(96, 66, 96, 54)` and compact
carousel margins `Vector4(72, 36, 72, 36)`), so actual text/thumbnails can still
violate the new strict ornament-safe zones until SCRUM-354 integrates these
numbers. SCRUM-354 has been updated/unblocked with exact paths, dimensions,
margins and runtime gap requirements.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: тоньше ассеты + строгая content-zone спека + handoff)

Проверено (фактически):
- **Ассеты пересобраны** (md5 ИЗМЕНИЛИСЬ vs backup): `ui_frame_hero_select_dossier.png`
  `1120×1140` RGBA, `ui_frame_hero_select_thumbnail_strip.png` `1536×255` RGBA.
- **Реально облегчённые рамки** (превью `hero_select_thin_frames_content_zones.png`):
  орнаментально-тонкие границы (угловые кресты + филигрань) с большими пустыми
  интерьерами; зелёные зоны = строгие пустые content-zone (dossier: контент ниже
  крест-навершия и выше нижнего орнамента; strip: миниатюры внутри зелёной зоны).
- **Строгие margins задокументированы**: dossier `Vector4(126,160,126,172)`,
  strip `Vector4(132,62,132,62)` (`build/qa/scrum355/hero_select_thin_frames_qa.md`
  + runtime rects на 1280/1920/2560).
- **Бэкап/превью/доки**: backup-zip + контакт + rect-dump; `menus_ui.md`,
  `current_game_state.md`, `content_registry.md` обновлены.
- **Тесты**: `ui_no_overlap_matrix_test` + `runtime_smoke_test` — passed (rect-уровень
  без наложений); визуал `build/qa/cap_hero_select_355.png` — грубых наложений нет.

⚠️ **Видимый no-overlap fix ещё НЕ в рантайме** (acceptance стр.65): рантайм всё ещё
использует СТАРЫЕ margins (`HERO_SELECT_DOSSIER_CONTENT_BASE=Vector4(96,66,96,54)`
ui_screens.gd:64; carousel `Vector4(72,36,72,36)` :67). Новые строгие margins
из 355 НЕ применены — контент может касаться (теперь тонкого) орнамента, пока
**SCRUM-354** (`bug_hero_select_description_carousel_overlap_layout_task.md`,
Back-end, статус **«new»** — НЕ выполнен) не интегрирует числа в layout.

Acceptance (фактическое состояние):
- [x] Dossier/carousel рамки тоньше/легче, стиль референсов сохранён.
- [x] Empty content-zones задокументированы (строгие margins для Back-end).
- [~] No-overlap @1280/1920/2560: rect-тесты зелёные, НО строгие zones вступят в
  силу только после интеграции margins в SCRUM-354 (домен Back-end, не Design-scope).
- [x] Backups/QA previews/rect-notes сохранены; доки обновлены.
- [x] Jira синкан; Back-end handoff (354) содержит точные данные ассетов (12 совпад.).

Вывод: Design-деливерабл выполнен корректно и в границах своего scope (Out Of Scope
запрещает Back-end layout logic). Видимое устранение overlap — гейтится SCRUM-354
(«new»). Деффект не потерян, делегирован с точными числами. Баги: нет (Design-часть);
follow-up = SCRUM-354 для рантайм-интеграции.
