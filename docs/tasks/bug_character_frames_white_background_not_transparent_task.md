# BUG(critical): Кадры анимаций персонажей на БЕЛОМ фоне — нужна настоящая прозрачность

Статус: in_progress
Приоритет: high
Роль: Designer (Codex) → Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-15
Автор: PM (отчёт пользователя + диагностика)
Jira: SCRUM-412
Связано: SCRUM-411 (анимспрайт скрыт за ригом), SCRUM-324 (asset-skill)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatch
- 2026-06-15T06:08Z — Board dispatcher routed Design/Codex phase to Design main
  thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` with reasoning High/no low.
  Active-owner audit: Back-end, Design main, Designer 2 and Animator threads were
  idle; no recent dispatch note existed. Design phase owns alpha cleanup,
  de-fringe/de-halo, import/pipeline fix, and QA evidence. Back-end/Animator
  follow-up should be created only after Design records a precise handoff.

## Контекст (отчёт пользователя + диагностика)
«Все анимации персонажей НЕ на прозрачном фоне, надо все переделать».

ДИАГНОСТИКА (PM, по пикселям `assets/sprites/characters/full_frame/<class>/*.png`):
- формат RGBA, но фон **БЕЛЫЙ/почти-белый НЕпрозрачный**: ~40% площади кадра
  opaque; в краевом кольце 3500-4600 пикс цвета (253-255, 253-255, 253-255);
  прозрачны только самые углы (alpha=0), а подложка за персонажем белая.
- gpt-image-2 сгенерил героев на белом фоне; шаг alpha-clean убрал лишь углы.
Касается ВСЕХ 17 классов.

## Требования
1. **Сделать фон по-настоящему прозрачным у ВСЕХ кадров всех 17 персонажей**
   (`full_frame/<class>/*_idle/walk/attack_primary_*.png`):
   - удалить белую/светлую подложку, СОХРАНИВ белые детали САМОГО персонажа
     (броня/блики/глаза) — НЕ глобальный white-key, а **заливка прозрачности от
     краёв** (flood-fill связной фоновой области) + аккуратный порог;
   - убрать белый ореол/окантовку по контуру (de-fringe/de-halo на полупрозрачных
     пикселях), чтобы не было белой каёмки на тёмном фоне арены.
   Допустимо перегенерировать скиллом с явным прозрачным фоном, если чистка не даёт
   качества — но результат: чистая альфа, без белого фона и каймы.
2. Сохранить пути/нейминг кадров и `<class>_spriteframes.tres` (код/.tres не менять),
   **переимпортировать** PNG (обновить .import) — чтобы игра увидела прозрачность.
3. **Починить корень в пайплайне**: шаг интеграции/alpha-clean (asset-generator →
   full_frame) должен вырезать фон ПОЛНОСТЬЮ (flood-fill от краёв + de-fringe), а не
   только углы — чтобы будущие перерисовки (призывы и т.д.) не повторяли баг.
4. Проверка: для каждого класса доля «фоновых» непрозрачных пикселей в краевом
   кольце ≈ 0; на тёмном фоне арены нет белого прямоугольника/каймы.
5. Тест: визуальная проверка на реальном фоне арены (скрин в build/qa/), плюс
   автопроверка прозрачности (углы/кольцо alpha≈0) в animation/runtime smoke.
   Координация с SCRUM-411 (чтобы анимспрайт был ВИДЕН и проверять на экране).
6. CHANGELOG; visual_style_assets; current_game_state.

## Files / Assets / IDs
- assets/sprites/characters/full_frame/<class>/*.png (все 17 классов) + .import
- scripts/ (интеграция листов / alpha-clean шаг), ~/.codex/skills/fantasydisk-* (пайплайн)
- tests/animation_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] У ВСЕХ кадров всех 17 персонажей фон полностью прозрачный (белая подложка и кайма убраны, детали персонажа целы).
- [ ] PNG переимпортированы; пути/.tres не менялись; в игре персонаж без белого фона на арене (скрин).
- [ ] Пайплайн alpha-clean чинит фон целиком (flood-fill+de-fringe) — будущие генерации без белого фона.
- [ ] Автопроверка прозрачности в smoke; animation+runtime smoke зелёные; CHANGELOG.

## Документация
docs/design/systems/visual_style_assets.md, docs/design/systems/animation.md, current_game_state.
