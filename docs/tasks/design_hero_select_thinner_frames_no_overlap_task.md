# ART/UX: Hero Select thinner frames + no-overlap visual fix

Статус: in_progress
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-355
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
