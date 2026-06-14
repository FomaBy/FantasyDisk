# ART/UX: Возвышение +/- — маленькие кнопки по референсам, по центру, вниз фрейма + «Выбрать»

Статус: review
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-346
Связано: SCRUM-321/323/333 (выбор героя), SCRUM-324 (скилл), SCRUM-327 (стиль)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Переключение возвышений + и − сделать маленькими кнопками по референсам
интерфейса. Выровнять по центру и вместе с кнопкой "Выбрать" опустить вниз фрейма
описания героя».

Сейчас (ui_screens.gd, dossier): `AscensionSelectorRow` (525) = [−][label][+]
(asc_minus 529 / asc_label 535 / asc_plus 542, ASCENSION_BUTTON_SIZE,
_apply_hero_select_button_frame "asc_button"), затем asc_mods (560) и
`HeroSelectChooseButton` «Выбрать» (569, 260×72). Кнопки +/- крупноваты и не у
низа фрейма.

## ОБЯЗАТЕЛЬНО — скилл (директива пользователя)
Маленькие рамки кнопок +/- СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`generate_asset.py ... --output hero_select/asc_button_small ...`, gpt-image-2,
PNG, прозрачный фон) по референсам интерфейса (docs/design/references/Buttons +
общий стиль D&D + Dark Fantasy Dragon, опорная SCRUM-327). Старый ассет — в бэкап.

## Требования
1. Кнопки возвышения «+»/«−» — маленькие, аккуратные, по референсам интерфейса
   (новые рамки скиллом), единый размер, читаемый знак по центру; hover без
   жёлтого свечения (SCRUM-318), контент в content-зоне рамки.
2. Ряд возвышения (−, label, +) **выровнять по центру** по горизонтали.
3. **Опустить блок возвышения вместе с кнопкой «Выбрать» вниз фрейма описания**
   героя (прижать к низу dossier): добавить распорку/spacer так, чтобы
   возвышение + «Выбрать» были внизу content-зоны досье, по центру, не наезжая на
   орнамент рамки; описание/черты/оружие остаются сверху.
4. Не ломать логику возвышения (refresh_asc, clamp уровней) и выбор героя.
5. Тест (smoke + no-overlap): экран строится; +/- маленькие и по центру;
   возвышение и «Выбрать» внизу фрейма; no-overlap на 1280×720/1920×1080/2560×1440.
   Скрин в build/qa/. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (AscensionSelectorRow 525-560; HeroSelectChooseButton 569;
  ASCENSION_BUTTON_SIZE; _apply_hero_select_button_frame "asc_button";
  HERO_SELECT_FRAME_* "asc_button" )
- assets/sprites/ui/frames/hero_select/ (маленькая asc-кнопка, скиллом) + бэкап
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Кнопки возвышения +/- маленькие, по референсам (скиллом), по центру, hover без жёлтого.
- [ ] Возвышение + «Выбрать» прижаты к низу фрейма описания, по центру; описание сверху.
- [ ] Логика цела; no-overlap на 3 разрешениях; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, current_game_state.

## Blocker History — 2026-06-14
Design/Codex проверил задачу на ветке `dev` и прочитал skill
`fantasydisk-asset-generator`. Задача требует создать новые маленькие рамки
`asc_button_small` именно через этот skill (`gpt-image-2`). В текущем окружении
нет `OPENAI_API_KEY`, а Python-пакет `openai` также недоступен, поэтому
обязательный генерационный шаг не может быть выполнен корректно.

Дальнейшая UI-посадка кнопок в `scripts/ui_screens.gd` относится к runtime/UI
интеграции и должна идти после готовности production PNG; частичный layout без
нового ассета не закрывает acceptance criteria. Задача заблокирована до появления
`OPENAI_API_KEY`/доступного `fantasydisk-asset-generator`.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved; task is
eligible for Design/Codex execution after the currently active Design task.


## Ключ настроен — блокер снят (2026-06-14)
`OPENAI_API_KEY` фактически сохранён в `~/.codex/.env` (права 600, вне git) +
автозагрузка в `~/.zshrc` — доступен в окружении автоматически в каждом новом
shell (включая shell Codex-воркеров). Скилл `fantasydisk-asset-generator`
(gpt-image-2) готов к вызову. Блокер по отсутствию `OPENAI_API_KEY` снят
окончательно; задача готова к исполнению через скилл.

## Blocked Again — 2026-06-14
Design picked the task after SCRUM-352 and rechecked scope. The required Design
deliverable is still a new `asc_button_small` PNG generated specifically through
`fantasydisk-asset-generator`/OpenAI Images (`gpt-image-2`); old/random/local
generators are explicitly disallowed, and runtime repositioning belongs to
Back-end only after the production PNG exists.

The current approved env source is available, but the SCRUM-352 pilot against
OpenAI Images returned:

```text
billing_hard_limit_reached
```

Because this is an account/billing hard limit, Design did not retry another paid
image request for the same mandatory generator path. SCRUM-346 is blocked until
OpenAI image generation billing is available again or PM provides an approved
alternative generation source.

## Covered By SCRUM-356 — 2026-06-14
The required compact ascension button asset was produced in the broader unified
Hero Select frame task:

- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_asc_button_small.png`
- source: `docs/design/references/hero_select_unified_panel/ui_frame_hero_select_asc_button_small_source.png`
- margins: `[76, 74, 76, 76]`

The positioning requirement (ascension row plus `HeroSelectChooseButton` at the
bottom of the unified frame) is runtime/UI layout scope and is now handed off to
Back-end in:

- `docs/tasks/backend_hero_select_unified_portrait_description_frame_integration_task.md`

This task is left in `review` as covered by SCRUM-356 rather than duplicated.
