# ART/ТЕХ: Единый стиль персонажей + система анимаций (5 move + 5 attack) — ОПОРНАЯ

Статус: in_progress
Приоритет: high
Роль: Designer (Codex) + Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-298

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## АНИМАЦИЯ — СКИЛЛОМ (директива пользователя 2026-06-14)
Анимацию (move/walk 5+ кадров loop, attack_primary 5+ кадров non-loop; элитки/боссы
— full-frame sprite-sheet без cutout-разрезания) делать скиллом
`fantasydisk-animation-director`
(`~/.codex/skills/fantasydisk-animation-director/`): он строит SpriteFrames/
AnimationPlayer, манифест, контакт-лист/GIF, валидирует
`scripts/validate_animation_manifest.py` и гоняет animation_smoke. Источник арта —
через `fantasydisk-asset-generator`. См. AGENTS.md (раздел анимаций).

## Контекст (запрос пользователя)
«Надо перерисовать всех персонажей в едином стиле (отдельными тасками). Каждому
персонажу — 5 кадров анимации движения и 5 кадров анимации атаки, всё плавно и
естественно. Все персонажи БЕЗ оружия в руках».

Это ОПОРНАЯ задача инициативы «Единый визуал персонажей» (0.2.0). Она задаёт
единый художественный стиль, единый формат спрайт-листа и расширяет техническую
систему анимаций ПЕРЕД тем, как делать 16 пер-персонажных задач (каждая блокируется
этой).

## Текущее состояние (для исполнителя)
- Персонаж = AnimatedSprite2D в VisualRoot/Body; кадры строит
  `_character_sprite_frames` (scripts/player.gd:1508).
- Только у берсерка реальный лист: `_berserk_sprite_frames` (1514), ячейка
  384×384 (BERSERK_ANIMATION_FRAME_SIZE:29), row0=idle(2), row1=walk(6),
  лист berserk_walk_sheet_v2.png 2304×768.
- У остальных — `_single_texture_sprite_frames` (статичная картинка, idle=walk=1
  кадр). Анимации **attack НЕТ** ни у кого.
- 6 классов делят чужой спрайт (thief→assassin, elementalist→dark_mage,
  sniper→ranger, priest→doctor, biologist→chemist, engineer→druid) — в едином
  стиле у каждого будет СВОЙ.

## Требования — ХУДОЖКА (единый стиль)
1. Зафиксировать единый стиль персонажей (тёмное фэнтези, канон D&D): ракурс
   (как сейчас в игре), пропорции, толщина контура, палитра/освещение, уровень
   детализации, тень под ногами. Оформить как style-sheet в
   docs/design/references/ + раздел в menus_ui/content_registry.
2. Правило: **все персонажи БЕЗ оружия в руках** (руки пустые/жесты; оружие — у
   класс-оружий отдельно).

## Требования — ФОРМАТ ЛИСТА (единый для всех 16)
3. Единый спрайт-лист на персонажа: ячейка 384×384, прозрачный фон, единый
   pivot «ступни по центру низа», без обрезки по краям.
   - Ряд **walk**: 5 кадров (плавный цикличный шаг, без рывков/проскальзывания).
   - Ряд **attack**: 5 кадров (замах→удар→возврат, естественно, без петли).
   - (idle опционально: 1-2 кадра дыхания; если нет — деривировать из walk[0]).
   - Лист 1920×768 (5×384 на 2 ряда) либо 1920×1152 с idle. Зафиксировать в спеке.
4. Путь и нейминг ассетов: assets/sprites/characters/<id>_sheet.png (единый
   шаблон, чтобы пер-персонажные задачи только клали файл).

## Требования — ТЕХ (система анимаций)
5. Обобщить `_character_sprite_frames`: вместо хардкода берсерка — общий построитель
   листов по данным (id→путь листа, число кадров walk/attack, fps, размер ячейки).
   Добавить анимацию **"attack"** в SpriteFrames (loop=false).
6. Проигрывание состояний в player.gd: walk при движении, attack при атаке
   (по факту удара оружия/анимационный триггер), затем возврат в walk/idle; flip
   по направлению; не ломать берсерка и rig-систему (cutout_rig_2d/sliced_rig_manifest).
7. Сделать берсерка ЭТАЛОНОМ: привести к новому формату 5 walk + 5 attack в едином
   стиле (берсерк уже без оружия — berserk_unarmed). Это образец для 16 задач.
8. Тест (animation): для эталона существуют "walk"(5)/"attack"(5), проигрываются
   без ошибок; деградация для ещё-не-перерисованных классов безопасна (fallback на
   статичную картинку, без краша).

## Acceptance Criteria
- [ ] Style-sheet единого стиля + формат листа (5 walk/5 attack, 384, pivot, пути) задокументированы.
- [ ] Система анимаций обобщена, добавлена анимация attack, проигрывание walk/attack/flip.
- [ ] Берсерк-эталон в новом формате; fallback для неперерисованных безопасен.
- [ ] animation + 6 smoke зелёные; превью-гиф эталона в build/qa/; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md,
docs/design/systems/technical_architecture.md, current_game_state.

## Progress — 2026-06-14
- Design/Codex взял опорную задачу в работу как Design-owned style/format spec.
- Scope correction: task mixes Design, Back-end and Animator ownership. Design
  will define art direction, sprite-sheet format, naming, pivots, content
  registry notes and handoff boundaries. Runtime SpriteFrames builder,
  `player.gd` attack playback, AnimationPlayer/AnimationTree, motion timing and
  actual animated sheet production remain Back-end/Animator scope per
  `docs/process/agent_role_boundaries_and_handoffs.md`.

## Design Result — 2026-06-14
- Added Design standard:
  `docs/design/references/character_animation_style_sheet_0_1_5.md`.
- Standard fixes the playable hero visual canon: polished D&D/tabletop dark
  fantasy, expressive full hero silhouettes, no blocky placeholder look, and
  base character sheets without weapons in hands.
- Standard fixes sheet format for per-character tasks:
  `assets/sprites/characters/<class_id>_sheet.png`, `384x384` cells, preferred
  `1920x1152` sheet with rows `idle`, `walk`, `attack_primary`, 5 frames each.
  Minimum early-production fallback is `1920x768` with `walk` + `attack_primary`.
- Recorded pivot/safe-area rules: bottom-center foot anchor `(192,348)`,
  transparent padding, stable feet baseline, no crop in attack follow-through.
- Added class-by-class visual identity notes for all 17 playable classes.
- Updated docs: `animation.md`, `content_registry.md`, `current_game_state.md`,
  `CHANGELOG.md`.

## Remaining Non-Design Scope
- Back-end: data-driven character sheet registry/runtime loading, safe fallback,
  and `player.gd` attack playback integration.
- Animator: actual motion production/validation with
  `fantasydisk-animation-director`, SpriteFrames/AnimationPlayer/manifest/GIFs,
  fps/loop/non-loop verification and animation smoke.
- Asset generation for final production sheets still depends on
  `fantasydisk-asset-generator`; current shell has no `OPENAI_API_KEY`, so
  Design did not generate final `<class_id>_sheet.png` assets in this pass.

## Back-end Progress — 2026-06-14
- Back-end phase started after Design standard review. Scope is limited to
  runtime sheet registry/loading, player SpriteFrames fallback and attack
  playback hooks; no art generation and no motion polish.
