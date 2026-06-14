# Backend: Интеграция анимации волка-призыва друида (move/attack в AllyMinion)

Статус: done
Приоритет: high
Роль: Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-279
Блокер снят: SCRUM-280 подготовил SpriteFrames волка.
Dispatch: 2026-06-14 -> Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.

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
- [x] Волк друида анимирован: бег при движении, атака при ударе, flip по направлению.
- [x] Остальные союзники не сломаны (статичные визуалы работают).
- [x] 6 smoke + анимационный тест зелёные; скрин/гиф; CHANGELOG.

## Документация
docs/design/systems/combat.md (союзники/призывы), current_game_state.

## Design Handoff Update 2026-06-14

SCRUM-280 готов. Использовать:

- SpriteFrames: `res://assets/sprites/allies/ally_druid_wolf_spriteframes.tres`
- Source frame PNGs: `res://assets/sprites/allies/druid_wolf/`
- Animations:
  - `move`: 8 frames, loop=true, 12fps;
  - `attack`: 6 frames, loop=false, 14fps.
- Canvas: 256x224.
- Pivot handoff: bottom-center `(128, 204)`.
- Runtime scale recommendation: `0.34` on `AnimatedSprite2D`.
- Source art faces left; flip horizontally for right-facing movement/attack.
- Static `ally_druid_beast.png` remains fallback and must not be deleted.
- QA previews: `build/qa/druid_wolf_summon_animation/`.

## Dispatcher Note 2026-06-14

SCRUM-279 dispatched to existing Back-end thread
`019eabd9-780b-78a2-9f4b-e7203d659ef2` after SCRUM-280 recorded ready
SpriteFrames. Back-end owns technical integration/tests/docs; if the integration
reveals movement naturalness, pivot retiming, attack pose polish,
AnimationPlayer/AnimationTree setup, or VFX timing sync beyond simple
SpriteFrames playback, create/update an Animator handoff.

## Result 2026-06-14

Done by Back-end runtime integration:
- `scenes/AllyMinion.tscn` keeps static `Body` fallback and adds hidden
  `AnimatedBody` for animated variants.
- `scripts/ally_minion.gd` enables `AnimatedBody` only for `druid_beast`,
  loads `ally_druid_wolf_spriteframes.tres`, plays looping `move`, one-shot
  `attack` on actual hit, and flips right by movement/attack direction.
- `druid_pack_spirit`, `homunculus` and `leadership_echo` stay static via
  `Body`; `ally_druid_beast.png` remains fallback.
- `tests/animation_smoke_test.gd` now asserts druid wolf SpriteFrames,
  move/attack frame counts, loop flags, playback, flip and static visual
  compatibility.
- QA contact: `build/qa/druid_wolf_backend_integration/druid_wolf_backend_runtime_contact.png`.

Verification:
- PASS: `tests/summoner_strengthening_test.gd`
- PASS: `tests/status_effects_aura_test.gd`
- PASS: `tests/animation_smoke_test.gd`
- PASS: `tests/runtime_smoke_combat_test.gd`
- PASS: `tests/runtime_smoke_weapon_mechanics_test.gd`
- PASS: `tests/runtime_smoke_test.gd`

Docs updated: `CHANGELOG.md`, `docs/design/current_game_state.md`,
`docs/design/content_registry.md`, `docs/design/systems/combat.md`.
