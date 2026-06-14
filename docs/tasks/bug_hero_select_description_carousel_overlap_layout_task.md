# BUG/UI: Hero Select description + carousel overlap after frame redesign

Статус: blocked
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-354
Blocked by: `design_hero_select_thinner_frames_no_overlap_task.md` / SCRUM-355
Связано: SCRUM-320, SCRUM-323, SCRUM-333, SCRUM-342, SCRUM-347

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пользовательский QA-фидбек 2026-06-14: на экране выбора персонажа описание героя
и нижняя карусель визуально наслаиваются друг на друга, а рамки выглядят слишком
толстыми. Design должен сначала обновить/облегчить frame assets и выдать точные
safe margins. После этого Back-end должен интегрировать результат и закрыть
фактическое layout overlap.

## Blocker
Ждёт Design result по `design_hero_select_thinner_frames_no_overlap_task.md`:
финальные PNG paths/dimensions/content-zone margins/runtime rect targets для
dossier/carousel frames. До этого нельзя стабильно править layout, чтобы не
переделывать те же `HeroSelect*` rects дважды.

## Scope — Back-end После Разблокировки
1. Обновить Hero Select layout так, чтобы:
   - `HeroSelectDossierContent` полностью помещал описание, черты, оружие,
     ascension controls и start button во внутреннюю content-zone frame;
   - `HeroThumbnailStripContent` полностью помещал миниатюры/hover/selected state
     во внутреннюю content-zone carousel frame;
   - dossier/radar/portrait/carousel не пересекались между собой;
   - контент не заходил на декоративные borders/gems/crests/metal/seals.
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
- [ ] Description/ascension/start button and carousel thumbnails do not overlap
  each other or decorative frame borders.
- [ ] UI no-overlap matrix passes for 1280x720, 1920x1080, 2560x1440 and narrow
  supported windows.
- [ ] Runtime smoke passes.
- [ ] QA rect dump/screenshot saved under `build/qa/`.
- [ ] `docs/design/current_game_state.md` and `docs/design/systems/menus_ui.md`
  updated with final runtime rects/margins.
- [ ] Jira synced; task moves out of blocked only after Design result is recorded.

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
