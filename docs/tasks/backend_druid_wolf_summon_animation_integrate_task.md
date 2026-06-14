# Backend: Интеграция анимации волка-призыва друида (move/attack в AllyMinion)

Статус: blocked
Приоритет: high
Роль: Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-279
Блокируется: SCRUM-280 (нарезка SpriteFrames волка)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Надо сделать анимацию призыва волка у друида» — волк-союзник `druid_beast`
сейчас статичный (Sprite2D "Body" в AllyMinion.tscn, scripts/ally_minion.gd
`_apply_visual` 62-69). Нужно оживить: бег при движении, атака при ударе.
Ассеты (SpriteFrames "move"=8к / "attack"=6к) готовит парная задача
design_druid_wolf_summon_animation_slice (SCRUM-280).

## Требования
1. Для визуала `druid_beast` (волк) заменить статичный показ на анимированный:
   AnimatedSprite2D (или совместимый с текущим rig-подходом) с анимациями
   из переданного SpriteFrames.
   - Сохранить совместимость для остальных ally_visual_id (druid_pack_spirit,
     homunculus, leadership_echo) — у них остаётся статичный путь, без регрессов.
2. Логика состояний в AllyMinion (_physics_process):
   - **"move"** (loop) когда волк перемещается к цели/владельцу;
   - **"attack"** (no-loop) в момент атаки (когда срабатывает _attack_cooldown
     / нанесение урона в attack_range), затем возврат в move/idle;
   - простаивание — последний кадр move или отдельный idle, без дёрганья.
3. **flip_h по направлению движения** (волк нарисован влево): velocity.x>0 → flip.
   Корректный pivot, волк не «тонет» в землю и не телепортируется при смене анимы.
4. Призыв (spawn в player.gd ~997 ALLY_MINION_SCENE) — опционально короткий
   акцент при появлении (можно проиграть attack как «рык», по согласованию).
5. Тест (smoke/animation): заспавнить druid_beast, убедиться что AnimatedSprite2D
   присутствует, "move"/"attack" существуют и проигрываются без ошибок; флип
   меняется по velocity; прочие визуалы союзников не сломаны.
6. CHANGELOG; current_game_state; скрин/гиф в build/qa/.

## Files / Assets / IDs
- scripts/ally_minion.gd (_apply_visual 62; _physics_process 70+; ALLY_VISUAL_PATHS)
- scenes/AllyMinion.tscn (узел Body → AnimatedSprite2D или гибрид)
- scripts/player.gd (~997 спавн ally), scripts/summoner_weapon.gd (149-152 выбор визуала)
- assets/sprites/allies/ (SpriteFrames из парной задачи)
- tests/animation_smoke_test.gd / runtime_smoke_test.gd

## Acceptance Criteria
- [ ] Волк друида анимирован: бег при движении, атака при ударе, flip по направлению.
- [ ] Остальные союзники не сломаны (статичные визуалы работают).
- [ ] 6 smoke + анимационный тест зелёные; скрин/гиф; CHANGELOG.

## Документация
docs/design/systems/combat.md (союзники/призывы), current_game_state.
