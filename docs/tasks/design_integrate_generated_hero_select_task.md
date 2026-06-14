# Задача Для Design-Агента: Внедрить сгенерированный ассет hero select

Статус: new
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: pending sync

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/hero_select/hero_select_mockup.png`
- Model: `gpt-image-2`
- Size: `1536x864`
- Quality: `high`
- Prompt:

```text
Full-page UI MOCKUP for a dark-fantasy D&D roguelite CHARACTER SELECT screen, 16:9. Unified style: D&D + Dark Fantasy Dragon — aged dark forged metal, deep worn parchment, smoked glass, muted gold, ruby accents, claw-notched corners, subtle dragon/scale cues, restrained ornament. LAYOUT (no overlap, clean safe zones): LEFT one-third = large vertical hero PORTRAIT inside an ornate forged-metal-and-parchment frame, centered. RIGHT two-thirds = a DOSSIER panel framed in dark metal: hero name title bar at top, description text block area, a row of small trait/weapon icon slots, an ASCENSION tier selector row, and a wide ornate Choose button at the bottom. TOP-RIGHT floating COMPASS wind-rose STAT RADAR widget (hexagonal stat web) in a round compass frame with gold ticks. BOTTOM full-width CAROUSEL rail framed in ornate dark metal holding a row of square hero icon slots, one highlighted as selected. Empty internal content zones (placeholder blocks, minimal text), ornament only on frame borders not on content. Cohesive muted palette, high readability, game UI concept art, crisp.
```

## Что Нужно Сделать
1. Проверить визуальное качество, соответствие текущему dark fantasy art direction и читаемость в целевом размере.
2. Подготовить финальный ассет в нужной runtime-папке `assets/sprites/...` или оставить как approved reference, если прямое внедрение пока не требуется.
3. Если нужны Godot-сцены, скрипты, импорт, theme mapping или логика подключения — создать/передать Back-end handoff с точными путями и acceptance criteria.
4. Обновить `docs/design/content_registry.md`, релевантные domain docs и `CHANGELOG.md`, если ассет вошел в игру.

## Acceptance Criteria
- [ ] PNG из `docs/design/references/` просмотрен и принят/доработан перед runtime-интеграцией.
- [ ] Финальный ассет, если создается, имеет стабильное имя и лежит в правильной `assets/sprites/...` папке.
- [ ] Не тронуты `.import` файлы без необходимости.
- [ ] При runtime-интеграции пройдены релевантные Godot smoke/UI checks.
- [ ] Jira и task-файл синхронизированы после смены статуса.

## Design Spec / 2026-06-14 (Claude-Designer, через fantasydisk-ui-director skill)

Запрос пользователя: переделать экран выбора персонажа новым UI-скиллом.
Workflow скилла соблюдён: СНАЧАЛА полностраничный мокап через OpenAI Images API.

### Мокап (показан в чате)
`docs/design/references/hero_select/hero_select_mockup.png` (gpt-image-2, 1536x864, high).
Лейаут точно по мастер-спеке SCRUM-333: ЛЕВО 1/3 портрет, ПРАВО 2/3 досье
(титул+описание+слоты черт/оружия+селектор возвышения+кнопка Выбрать), СВЕРХУ-СПРАВА
компас-радар (роза ветров), СНИЗУ карусель во всю ширину. Стиль D&D + Dark Fantasy Dragon.

### Целевая интеграция (без правок кода — замена ассетов по существующим путям)
Экран уже грузит рамки из `assets/sprites/ui/frames/hero_select/` (SCRUM-333 done).
Заменяемые рамки (сохранять РАЗМЕРЫ для совместимости с 9-slice content-полями):
- `ui_frame_hero_select_portrait.png` (734x1162) <- frame_portrait
- `ui_frame_hero_select_dossier.png` (1120x1140) <- frame_dossier
- `ui_frame_hero_select_radar.png` (1024x1024) <- frame_compass
- `ui_frame_hero_select_thumbnail_strip.png` (1536x255) <- frame_carousel
Прозрачный центр (chroma-key magenta -> alpha), кант сопоставимой толщины с текущими
(иначе подкрутить HERO_SELECT_*_CONTENT_BASE — это Back-end).

### Роль/handoff
Design: мокап + рамки (генерация скиллом) + подгонка размеров + визуальная сверка.
Back-end: финальная выверка content-полей и no-overlap на 1280x720/1920x1080/2560x1440,
UI/anim/runtime smoke, скрины в build/qa/ (handoff если поля поедут).
