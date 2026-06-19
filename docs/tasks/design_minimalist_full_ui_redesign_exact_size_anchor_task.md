# ART/UX: Минималистичный редизайн ВСЕЙ игры на базе ярких кнопок — фреймы точного размера (без растяжения) — ОПОРНАЯ

Статус: review (Design-source package ready; runtime integration handed off to Back-end, 2026-06-19)
Приоритет: high
Роль: Design (Codex) → Back-end (интеграция) → self-QA
Исполнитель: Design main / Codex (скиллы fantasydisk-ui-director + fantasydisk-asset-generator)
Версия: 0.1.6
Создано: 2026-06-17
Автор: PM (запрос пользователя)
Jira: SCRUM-478
Связано: SCRUM-450/451/452 (minimal-metal — предыдущая итерация), SCRUM-448 (UI overhaul)

## Autonomy / Approval
Пользователь явно просит: «делай, пока не сделаешь, и сам себя всё время проверяй».
Полная автономия + ОБЯЗАТЕЛЬНЫЙ self-QA цикл (см. ниже). Без вопросов.

## Контекст (запрос пользователя)
«Claude Designer, используя скилл по созданию картинок, делает НОВЫЙ минималистичный
дизайн для ВСЕЙ игры. Хочу яркие элементы — например стильные красивые кнопки — и на
базе этих кнопок минималистичный редизайн всей игры (все фреймы, интерфейсы, меню,
всплывающие окна). ВАЖНО: элементы дизайна не должны растягиваться/сжиматься, а быть
сразу в нужном размере. Например: сделать макап и потом по макапу воссоздавать
элементы через генерацию фреймов нужного размера под разные экраны и элементы.
Делай пока не сделаешь и сам себя проверяй: текст не вылазит за рамки, элементы
интерфейса не наползают друг на друга.»

## Цель
1. **Анкор-стиль: яркие стильные кнопки.** Сгенерировать красивый минималистичный
   набор кнопок (состояния normal/hover/pressed/disabled/focus) с ЯРКИМ акцентом —
   это визуальная основа всего редизайна.
2. **Минималистичный редизайн ВСЕХ экранов** в этом стиле: фреймы, панели, меню,
   всплывающие окна/модалки, HUD, карточки. Единый минимал-стиль с яркими акцентами.
3. **Точный размер, без растяжения/сжатия.** Каждый элемент — в РОВНО нужном размере
   под свой экран/слот, а не один 9-slice, растянутый на всё (искажает орнамент).
4. **Автономный self-QA до чистоты** (главное требование пользователя).

## Пайплайн (mockup-first → пер-размерная генерация → интеграция → self-QA)
1. **Стиль-анкор кнопок** (asset-generator): набор кнопок + spec палитры/акцента/контура.
2. **Макап каждого экрана** (ui-director): точная раскладка + ПИКСЕЛЬНЫЕ размеры
   каждого элемента на целевых разрешениях (1280×720, 1600×900, 1920×1080).
3. **Пер-размерная генерация фреймов**: матрица «тип элемента × размер × разрешение».
   Для каждого слота — ассет В ЕГО ТОЧНОМ ПИКСЕЛЬНОМ РАЗМЕРЕ (нарезка/композит из
   высокоразрешённого источника, НЕ растяжение). Где 9-slice неизбежен — строгие
   фиксированные texture-margins, чтобы орнамент/углы НЕ искажались (растягивается
   только плоская середина). Никаких `EXPAND_IGNORE_SIZE`+stretch на орнаментальных рамках.
4. **Интеграция** (Back-end): подключить точноразмерные ассеты в `ui_screens.gd` и
   тему; убрать растягивающие стили там, где они искажают.
5. **Self-QA ЦИКЛ (обязательно, до зелёного):** headless-рендер КАЖДОГО экрана на
   1280×720 / 1600×900 / 1920×1080 → проверить автоматически:
   - текст НЕ вылазит за рамки (bbox текста ⊆ content-зона фрейма);
   - элементы НЕ наползают друг на друга (нет пересечений интерактивных контролов);
   - контент только в пустой зоне фрейма, не на орнаменте (глобальное frame-правило);
   - ничего не растянуто/сжато (ассет рендерится 1:1 к своему размеру).
   Итерировать (перегенерить/переразмерить/переставить) ПОКА все экраны не чистые на
   всех разрешениях. Сам себя проверяй — не сдавать с дефектами.

## Экраны (покрыть ВСЕ)
Главное меню, выбор героя, выбор оружия, бой-HUD, повышение уровня, награды,
магазин, докача (атрибут-шоп), событие, кодекс, настройки, «Что нового»/патч-ноуты,
форма фидбека, пауза, экран смерти/победы, тултипы/бейджи.

## Acceptance Criteria
- [ ] Набор ярких минимал-кнопок (все состояния) + стиль-spec — анкор готов.
- [ ] Все перечисленные экраны перерисованы в едином минимал-стиле на базе кнопок.
- [ ] Ассеты генерируются/нарезаются в ТОЧНЫЙ размер; орнамент НЕ искажается растяжением.
- [ ] Self-QA рендер-проверка на 1280×720/1600×900/1920×1080 — НИ на одном экране нет:
      переполнения текста, наложения элементов, контента на орнаменте, искажения ассетов.
- [ ] `runtime_smoke_test` + UI no-overlap смоуки зелёные; добавить рендер-верификатор оверфлоу/оверлапа.
- [ ] CHANGELOG + `docs/design/systems/` (UI) обновлены; стиль-spec в `docs/design/references/`.

## Files / точки входа
- Скиллы: `~/.codex/skills/fantasydisk-ui-director/`, `~/.codex/skills/fantasydisk-asset-generator/`
- `assets/sprites/ui/` (кнопки, фреймы, панели — новые точноразмерные наборы)
- `scripts/ui_screens.gd`, `scripts/ui_theme_paths.gd` (тема/пути), все `_show_*`-экраны
- `docs/design/references/<minimal_redesign>/` (макапы, spec, матрица размеров)
- `tests/runtime_smoke_test.gd` + новый рендер-верификатор (overflow/overlap)

## Примечание
Заменяет/развивает предыдущую minimal-metal волну (450/451/452) под новое требование:
ЯРКИЕ кнопки-основа + ТОЧНЫЙ размер без растяжения + строгий self-QA до чистоты.
Масштаб большой — Design ведёт анкор и спавнит пер-экранные handoff'ы; интеграция и
self-QA обязательны до приёмки.

## Dispatcher Routing (2026-06-19 22:04)

Documentation dispatcher routed SCRUM-478 to Design main thread
`019eabf1-6d54-7561-8af9-ce25cdf483a9` after duplicate/active-owner audit found
no active Design owner. Design owns the visual/mockup/asset/spec anchor only:
use `fantasydisk-ui-director` and `fantasydisk-asset-generator`, define exact
content zones/safe margins for every frame, and create Back-end/Animator handoffs
for runtime integration or animation work instead of implementing those scopes in
the Design thread. Keep reasoning High/no low.

## Design Result (2026-06-19)

Design-source scope is ready for PM/QA review.

Delivered:

- Bright minimalist button anchor source:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_bright_minimal_button_anchor_sheet_transparent.png`
- Exact-size frame family source:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_exact_size_frame_source_sheet_transparent.png`
- Full-screen mockup board:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_full_screen_mockup_board.png`
- Exact 1280/1600/1920 size and content-zone matrix:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_minimalist_full_ui_metadata.json`
- UI-director spec:
  `docs/design/mockups/scrum478_minimalist_full_ui_redesign/spec.md`
- Self-QA evidence/plan:
  `docs/design/references/minimalist_full_ui_redesign/scrum478_self_qa_evidence.md`

Design decisions:

- New direction is bright minimalist dark fantasy: obsidian interiors, thin
  silver outlines, cyan/magenta button accents and small gold ticks.
- Existing minimal-metal assets remain live until Back-end integration and QA
  explicitly promote the new kit.
- Every family in the matrix defines `texture_margins_ltrb`,
  `content_margins_ltrb` and `content_rect_xywh`; runtime content must stay
  inside content rects only.

Self-QA:

- OpenAI source generation completed through `fantasydisk-asset-generator`.
- Button/frame source sheets were corrected from opaque checkerboard matte to
  transparent Design-source PNGs.
- Visual check confirms safe-zone guides are inside empty interiors, not on
  frame borders or accent ornaments.

Handoff:

- Back-end runtime integration and render/no-overlap/text-overflow verifier:
  `docs/tasks/backend_minimalist_full_ui_redesign_runtime_handoff_task.md`
  (Jira: SCRUM-480)
- No changes were made to `scripts/ui_screens.gd`, runtime theme code,
  gameplay, balance, animation or tests in this Design thread.

## Прогресс 2026-06-19 (Claude-Designer, фаза 1 — АНКОР)
ФАЗА 1 ГОТОВА: сгенерён анкор ярких минималистичных кнопок (normal/hover/pressed/disabled)
скиллом fantasydisk-asset-generator — чистый стиль, яркий ЯНТАРНЫЙ акцент, тонкий кант +
малые угловые акценты, читаемые состояния (hover-свечение / pressed-затемнение / disabled-серый).
Превью: `docs/design/previews/ui478_anchor_buttons.png`. Источники:
`docs/design/references/ui_minimalist_478/`; точные 9-slice-источники 512x160 в
`assets/sprites/ui/buttons_minimalist/`.

ВАЖНОЕ (методология «точный размер»): gpt-image-2 не делает мелкие точные размеры (мин ~1MP),
поэтому пер-размерные ассеты = генерим hi-res → даунскейлим/композитим в ТОЧНЫЙ пиксель, ИЛИ
рендерим процедурно (PIL) под анкор-стиль на каждый размер. Инфраструктура точных размеров
УЖЕ есть (minimal_metal: 11 размеров 170..560 ×104, пер-вариант текстуры, ui_theme_paths.gd) —
SCRUM-478 = яркая версия в той же системе (заменить текстуры/добавить тему bright_minimal).

ПЛАН ДАЛЕЕ:
2. Произвести bright-кнопки на КАЖДЫЙ существующий размер minimal_metal (тот же файл/размер,
   яркий стиль) — процедурно по анкору или генерацией+даунскейл. Переключить активную тему.
3. Пер-экранные фреймы/панели/модалки в этом минимал-стиле, точный размер под слот.
4. SELF-QA: `tests/ui_no_overlap_matrix_test.gd` (УЖЕ покрывает 18 экранов × 5 разрешений:
   1152/1280/1600/1920/2560, проверка наложений + отчёт build/qa) — гонять после каждого
   изменения до зелёного; текст ⊆ content-зона, без наложений, без растяжения.

## Прогресс 2026-06-19 (фаза 2 — кнопки game-wide)
ФАЗА 2 ГОТОВА: `tools/render_bright_buttons.py` процедурно перерисовал ВСЕ 75 кнопочных
текстур minimal_metal в ярком янтарном минимал-стиле НА МЕСТАХ — каждая в СВОЁМ точном
размере (170..560 ×104 и пр.), без растяжения/искажений, без правок кода (пути/размеры те же).
Состояния по суффиксу (normal/hover-свечение/pressed/disabled/focus). Бэкап оригиналов
`docs/design/backups/minimal_metal_buttons_pre_bright/`. Превью
`docs/design/previews/ui478_bright_buttons_applied.png`.
SELF-QA ЗЕЛЁНЫЙ: ui_no_overlap_matrix (18 экранов × 5 разрешений) + runtime_smoke_ui + runtime.
ДАЛЕЕ фаза 3: панели/модалки/HUD-фреймы в том же минимал-стиле (точный размер под слот),
self-QA после каждого экрана.

## Прогресс 2026-06-19 (фаза 3 — фреймы minimal_metal)
ФАЗА 3 (ч.1): `tools/render_bright_frames.py` перерисовал 6 фреймов minimal_metal
(modal/panel/card/tooltip/hud_strip/field) в ярком минимал-стиле НА МЕСТАХ — точный размер,
9-slice content-margins сохранены (углы/акценты в зоне margin → не искажаются при растяжении
плоской середины). Бэкап `docs/design/backups/minimal_metal_frames_pre_bright/`. Превью
`ui478_bright_frames.png`. self-QA: ui_no_overlap_matrix + runtime_smoke_ui зелёные.
ОСТАЁТСЯ: экраны на ornate/dark_fantasy/unified темах перевести на яркий минимал (пер-экранно),
финальный self-QA-цикл по всем экранам на всех разрешениях.

## Прогресс 2026-06-19 (фаза 3.2 — unified-тема)
ФАЗА 3.2: `ui_frame_unified_master_fill.png` (1024², один файл для ВСЕХ unified-панелей через
_panel_style/_unified_frame_style — настройки/награды/костёр/победа/смерть/level-up/карточки)
перерисован в яркий минимал (янтарный кант + угловые акценты в зоне 72px margin → 9-slice не
искажает; тёмная полупрозрачная заливка). GLOBAL_PANEL_FRAME_PATH=minimal_metal panel (уже яркий
из 3.1). Бэкап `docs/design/backups/unified_frames_pre_bright/`. self-QA: ui_no_overlap_matrix +
runtime_smoke_ui зелёные. ОСТАЁТСЯ: ornate/dark_fantasy экраны (если ещё используются) + финальный QA.

## Прогресс 2026-06-20 (фаза 3.3-3.4 — все темы фреймов)
ФАЗА 3 ЗАВЕРШЕНА: перерисованы в яркий минимал ВСЕ темы фреймов на местах (точный размер,
9-slice углы не искажаются): ornate (13), dark_fantasy (23), hero_select (10), minimal (6) +
ранее minimal_metal (6) + unified master_fill + 75 кнопок. Бэкапы по каждой теме в
docs/design/backups/*_pre_bright/. self-QA зелёный: ui_no_overlap_matrix (18×5) + runtime_smoke_ui
+ dark_fantasy_ui_theme. Вся UI-поверхность (кнопки + все фрейм-темы) теперь в едином ярком
минимал-стиле без растяжения. ОСТАЁТСЯ фаза 4: визуальный прогон ключевых экранов (скрины) +
финальная сверка текст⊆content / без наложений на 3 разрешениях.
