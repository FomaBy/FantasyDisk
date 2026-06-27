# ART/ANIM: Перерисовка персонажей — мультяшно/аниме, очень разные (ресерч) — ОПОРНАЯ

Статус: done
Приоритет: high
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-456
QA: in_progress (2026-06-17)
Связано: SCRUM-442 (Берсерк — первый класс под этот стиль), asset/animation-skill

## Dispatch
2026-06-17 — передано в Design main (`019eabf1-6d54-7561-8af9-ce25cdf483a9`).
Скоуп: Design-source/research/style-sheet + эталон Берсерка; Animator получает
только accepted source handoff после завершения Design-пакета.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Перерисовать персонажей, сделать их СИЛЬНО более РАЗНЫМИ. Уйти чуть от реализма —
более МУЛЬТЯШНО, как из аниме или современных мультфильмов (сделать РЕСЕРЧ).
Анимации простые, ПОКАДРОВЫЕ: перемещение ног и рук; стойка-простой тоже
анимирована; атаки НЕ анимировать — за это отвечает оружие».

Это ОПОРНАЯ задача стиля персонажей. Берсерк (SCRUM-442) — первый класс под неё.

## Требования
1. **РЕСЕРЧ стиля**: изучить современные мультяшно/аниме-стили (cel-shading, жирный
   контур, насыщенные плоские цвета, выразительные пропорции — напр. Arcane/Hades/
   аниме-cel). Зафиксировать style-sheet (палитра, контур, пропорции, уровень
   стилизации) в docs/design/references/chars_cartoon/ + visual_style_assets.
2. **Сильно разные персонажи**: каждый класс визуально РЕЗКО отличается силуэтом,
   палитрой, образом (не «одинаковые в разных цветах»). Список 16 классов.
3. **Прозрачный фон** обязателен (чистый, без белого/каймы/карманов).
4. **Анимации — простые покадровые** (animation-director):
   - **move/walk**: видимое перемещение НОГ и РУК (читаемый шаг), 5+ кадров loop;
   - **idle**: стойка-простой ТОЖЕ анимирована (дыхание/покачивание), 2-5 кадров loop;
   - **attack НЕ делать** (USE_ATTACK_ANIMATION=false) — атака визуализируется ОРУЖИЕМ.
5. Эталон: довести 1 класс (Берсерк, 442) под новый стиль как образец.
6. Тест: эталон строится, мультяшный, прозрачный, move/idle анимированы. Превью-гиф.
7. CHANGELOG; visual_style_assets; animation.md; content_registry.

Арт — `fantasydisk-asset-generator` (gpt-image-2, прозрачный фон); анимация — `fantasydisk-animation-director`. Прозрачность чистить `tools/strip_white_background.py`.

## Acceptance Criteria
- [x] Ресерч + style-sheet мультяшно/аниме; персонажи задуманы СИЛЬНО разными по силуэту/палитре.
- [x] Правила анимации: move (ноги+руки) + idle анимированы как source-preview/handoff, attack НЕ делается; прозрачный фон.
- [x] Эталон-класс (Берсерк) доведён; превью-гиф; CHANGELOG.

## Документация
docs/design/systems/visual_style_assets.md, animation.md, content_registry.

## Design Result (Design main / 2026-06-17)

Design-source пакет SCRUM-456 готов к QA/PM acceptance. Подготовлен новый
`chars_cartoon` style anchor: D&D dark fantasy + modern cartoon/anime/cel-shaded
направление, более крупные читаемые формы, сильный контур, насыщенные
class-specific палитры и обязательное сильное различие классов по силуэту.

Артефакты:
- style sheet: `docs/design/references/chars_cartoon/character_cartoon_anime_style_sheet.md`
- Berserk handoff: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_design_handoff.md`
- corrected transparent source: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_raw.png`
- alpha-clean source: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_source_clean.png`
- normalized 512 cell: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_idle_cell_512.png`
- source sheet handoff: `docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
- contact preview: `docs/design/previews/scrum456_chars_cartoon_anchor_contact.png`
- dark-bg preview: `docs/design/previews/scrum456_berserk_cartoon_anchor_dark_bg.png`
- idle source GIF: `build/qa/scrum456_chars_cartoon/berserk_cartoon_idle_source_preview.gif`
- walk source GIF: `build/qa/scrum456_chars_cartoon/berserk_cartoon_walk_source_preview.gif`
- QA report: `build/qa/scrum456_chars_cartoon/scrum456_chars_cartoon_alpha_motion_report.json`
- source manifest: `build/qa/scrum456_chars_cartoon/animation_manifest.json`

Validation summary:
- `fantasydisk-asset-generator` used for the Berserk exemplar. The API returned
  RGB with baked checkerboard; the source/raw path was corrected to transparent
  RGBA to satisfy this task's transparent-PNG-only rule.
- Source/cell/sheet alpha range is `[0,255]`, edge-visible pixels `0`,
  semi-neutral checker/matte pixels `0`.
- Berserk exemplar is unarmed, 3/4-right, suitable for horizontal flip, with
  visible arms/legs and offset feet.
- Source sheet uses `512x512` cells, pivot `(256,470)`, two rows (`idle`,
  `walk`), five frames per row and `48px` transparent gutters/outer padding.
- The GIFs/source sheet are Design-source motion previews and handoff material,
  not final Animator runtime SpriteFrames.

Documentation updated:
- `docs/design/systems/visual_style_assets.md`
- `docs/design/systems/animation.md`
- `docs/design/content_registry.md`
- `CHANGELOG.md`

Animator handoff:
- Created `docs/tasks/animation_chars_cartoon_anime_berserk_anchor_task.md`
  / Jira SCRUM-461.
- Status is `blocked` until SCRUM-456 QA/PM accepts the source package.
- Animator next scope: real `idle` + `walk/move` keyframes with visible arm/leg
  motion, no `attack_primary`, no gameplay/balance changes.

## QA-Вердикт (2026-06-17)
Статус: PASSED (Design-source: мультяшно/аниме style-anchor + эталон Берсерк)

Проверено (фактически): source_clean (1024²) + idle_cell_512 — RGBA, edge_alpha_max=0
(прозрачный фон, без каймы), transparent+opaque. Эталон Берсерк: unarmed, 3/4-right (flip),
видимые руки/ноги, смещённые ступни; 512-ячейка pivot (256,470), 2 ряда (idle/walk),
source-preview GIF'ы (motion = Animator handoff). Style-sheet «D&D dark fantasy + cartoon/anime/
cel-shaded», классы задуманы сильно разными. Anchor для пер-классовых задач.
⚠️ Анимации/SpriteFrames/runtime — отдельный Animator-этап (не в Design-source scope). done → Готово.
