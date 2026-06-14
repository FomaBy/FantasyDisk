# BUG(critical): Новые анимации персонажей не видны — анимспрайт скрыт за cutout-ригом

Статус: new
Приоритет: high
Роль: Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя + диагностика)
Jira: SCRUM-411

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (отчёт пользователя + найденная причина)
«Почему новые анимации не применились в игре?»

ДИАГНОСТИКА (PM): перерисовки персонажей (5 move/5 attack, full-frame) полностью
интегрированы как данные — кадры в `assets/sprites/characters/full_frame/<class>/`,
импортированы, `<class>_spriteframes.tres` обновлены (2026-06-14) и грузятся через
`_character_sprite_frames` (player.gd:1568). НО на экране они НЕ видны, потому что:
- `configure_character` (player.gd) после настройки AnimatedSprite2D ставит
  **`body.visible = false`** (стр. 200);
- затем `_configure_player_rig` (1553) **БЕЗУСЛОВНО** строит и показывает старый
  **cutout-риг** (RigRoot/HeroFull — статичный спрайт + анимация конечностей).
Итог: новые full-frame анимации загружены в СКРЫТЫЙ узел, а рендерится старый риг.
(QA берсерка (283) проверял загрузку .tres/счётчики кадров, но НЕ фактическую
видимость на экране — отсюда ложный PASS.)

## Требования
1. **Показывать новый AnimatedSprite2D, когда у персонажа есть full-frame
   анимации** (`_character_resource_sprite_frames`/`_character_sheet_sprite_frames`
   вернул не-null): `body.visible = true`, и **НЕ строить/НЕ показывать cutout-риг**
   (или скрыть RigRoot) для таких персонажей.
2. **Fallback**: если full-frame листа/.tres нет — прежнее поведение (cutout-риг
   виден, body скрыт). То есть переключение слоя по наличию full-frame frames.
3. Проигрывание состояний на AnimatedSprite2D: **walk** при движении, **attack**
   при ударе (по оружейному триггеру), **idle** в покое, **death** при гибели (см.
   SCRUM-370); flip_h по направлению; WeaponSocket/позиция оружия согласованы с
   новым слоем (оружие следует, не висит на старом риге).
4. Проверить ВСЕХ персонажей с готовыми листами (assassin/berserk/dark_mage/...
   все 17) — на экране видны НОВЫЕ перерисованные анимации, без оружия в руках,
   старый риг не перекрывает.
5. Тест: добавить в animation/runtime smoke проверку **видимости** (body.visible==true
   при наличии full-frame .tres; RigRoot скрыт/не построен) — чтобы такой регресс
   ловился. Скрин/гиф из реального запуска в build/qa/.
6. CHANGELOG; systems/animation.md; current_game_state.

## Files / Assets / IDs
- scripts/player.gd (configure_character ~183-200 body.visible; _configure_player_rig
  1553; _character_sprite_frames 1568; _animated_sprite 1545; _cutout_rig)
- scripts/cutout_rig_2d.gd (HeroFull 380; RigRoot visible)
- assets/sprites/characters/full_frame/*, *_spriteframes.tres
- tests/animation_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] У персонажей с full-frame анимациями на экране ВИДЕН новый AnimatedSprite2D (walk/attack/idle/death), cutout-риг скрыт/не строится.
- [ ] Fallback на cutout-риг для персонажей без full-frame листа сохранён.
- [ ] Оружие/позиция/flip согласованы с новым слоем; проверены все 17.
- [ ] Smoke проверяет видимость (ловит регресс); скрин/гиф из игры; animation+runtime smoke зелёные; CHANGELOG.

## Документация
docs/design/systems/animation.md, current_game_state.
