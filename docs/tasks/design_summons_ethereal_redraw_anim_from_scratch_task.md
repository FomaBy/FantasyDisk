# ART/ANIM: Перерисовать призывных существ С НУЛЯ — эфирный голубой стиль + анимация

Статус: in_progress
Приоритет: high
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Связано: SCRUM-353 (анимации призывов — этот таск ЗАМЕНЯЕТ их арт на эфирный), SCRUM-324 (asset-skill), animation-director
Jira: SCRUM-399

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Перерисовать призывных саммонов С НУЛЯ вместе с анимацией. Важно: призывные
существа должны быть ЭФИРНОГО плана — например голубого оттенка, как призраки —
и легко отличимы от монстров».

Призывные существа (ally_minion.gd, ANIMATED_ALLY_VISUALS 12-33):
- `druid_beast` (волк), `druid_pack_spirit`, `homunculus`, `leadership_echo`.
Сейчас у них «обычный» арт; нужен полностью новый эфирный.

## ОБЯЗАТЕЛЬНО — скиллы
Арт — `fantasydisk-asset-generator` (gpt-image-2, PNG, ПРОЗРАЧНЫЙ фон).
Анимация — `fantasydisk-animation-director` (SpriteFrames/манифест/контакт/GIF,
валидатор, animation_smoke). Full-frame, без cutout-фейка. Биллинг OK.

## Требования
1. **Перерисовать С НУЛЯ всех 4 призывных существ** в **эфирном/призрачном стиле**:
   - **голубой/циановый призрачный оттенок**, полупрозрачность, мягкое внутреннее
     свечение, дымчатые/«потусторонние» края, лёгкий ауро-глоу;
   - сохранить узнаваемость каждого (волк / дух стаи / гомункул / эхо-лидерства),
     но как **духов эфирного плана**, а не плотных существ.
2. **Чёткое отличие от монстров**: призывы визуально мгновенно читаются как
   «союзные духи» (голубое свечение/прозрачность), монстры — плотные/тёмные.
   Не путать с врагами на поле боя.
3. **Анимация** (через animation-director): `move`/`walk` (5+ кадров, loop —
   парение/левитация для эфирных, плавный дрейф), `attack`/`attack_primary` (5+,
   no-loop), `death` (5+, развоплощение/рассеивание духа). Эфирная пластика
   (мягкое колыхание, шлейф).
4. Сохранить пути/интеграцию SpriteFrames (ally_*_spriteframes.tres,
   ANIMATED_ALLY_VISUALS), чтобы код не менять; если меняешь scale/position —
   обновить и проверить (не тонут, flip по направлению).
5. Старые ассеты призывов — в бэкап. Координация с SCRUM-353 (его арт заменяется
   этим эфирным; анимационный контракт переиспользовать).
6. Тест: animation_smoke + runtime_smoke зелёные; заспавнить каждого — move/attack/
   death играют; визуально голубые-призрачные, отличимы от врагов. Контактлисты/GIF
   в build/qa/. Манифест валиден.
7. CHANGELOG; docs/design/systems/animation.md; content_registry; current_game_state.

## Files / Assets / IDs
- scripts/ally_minion.gd (ANIMATED_ALLY_VISUALS 12-33; ALLY_VISUAL_PATHS; _apply_visual)
- scripts/summoner_weapon.gd (146-152 выбор визуала)
- assets/sprites/allies/ (новые эфирные листы + SpriteFrames) + бэкап старых
- docs/design/references/summons_ethereal/ (исходники скилла)
- tests/animation_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Все 4 призыва перерисованы С НУЛЯ в эфирном голубом-призрачном стиле (прозрачность/свечение), легко отличимы от монстров.
- [ ] move(5+)/attack(5+)/death(5+) через animation-director, эфирная пластика; пути SpriteFrames сохранены.
- [ ] Старое в бэкап; манифест валиден; animation+runtime smoke зелёные; контактлисты/GIF; CHANGELOG+animation.md.

## Документация
docs/design/systems/animation.md, content_registry, current_game_state.

## Progress Log

- 2026-06-14 — Взято в работу Design/Codex. Role boundary decision: Design will
  replace the summon visual source/frame PNGs with an ethereal blue repaint using
  `fantasydisk-asset-generator` references while preserving current SpriteFrames
  paths and animation timing. Any new motion staging beyond this visual pass
  remains Animator scope.
