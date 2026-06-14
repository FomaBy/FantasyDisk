# ART: Нарезка анимации волка-призыва друида (move + attack) из референсов

Статус: review
Приоритет: high
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-280

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Надо сделать анимацию призыва волка у друида. Анимация в папке
референсы/wolfanimate — 2 файла: 1 на анимацию движения, 1 на анимацию атаки».

Волк — это союзник друида `druid_beast` (сейчас статичный Sprite2D, текстура
`res://assets/sprites/allies/ally_druid_beast.png`, см. scripts/ally_minion.gd:6-7).

## Исходники (референсы, уже в репо)
- docs/design/references/wolfanimate/Wolfmoving.png — 2508×627, **8 кадров**
  бега (горизонтальная лента, ~313×627 на кадр). Волк ориентирован ВЛЕВО.
- docs/design/references/wolfanimate/wolfattacking.png — 2172×724, **6 кадров**
  атаки (~362×724 на кадр). Волк ориентирован ВЛЕВО.

## Требования
1. Нарезать оба листа на кадры (auto-trim по прозрачности; подтвердить точное
   число кадров — ожидается move=8, attack=6 — и единый pivot: «лапы/низ по
   центру», чтобы волк не дёргался между анимациями).
2. Собрать игровой ассет анимации для волка-союзника:
   - либо `SpriteFrames` .tres с двумя анимациями: **"move"** (8 кадров, loop,
     ~10–12 fps) и **"attack"** (6 кадров, no-loop, ~12–14 fps);
   - кадры привести к разумному игровому размеру (волк ≈ как текущий
     ally_druid_beast по высоте на экране; не гигант). Сохранить пропорции.
3. Поддержать поворот: волк нарисован влево — обеспечить, чтобы flip_h вправо
   выглядел корректно (если есть асимметрия — отметить).
4. Тёмное фэнтези, канон D&D, единый стиль с остальными союзниками.
5. Выход в `assets/sprites/allies/` (атлас(ы) + .tres). Старый статичный
   `ally_druid_beast.png` оставить как fallback (не удалять).
6. Отдать Backend точные имена анимаций, путь к SpriteFrames, fps, pivot,
   игровой масштаб — для задачи интеграции (парная: SCRUM-279).

## Acceptance Criteria
- [x] SpriteFrames волка с "move"(8)/"attack"(6), trimmed, единый pivot, игровой масштаб.
- [x] Ассеты в assets/sprites/allies/; превью-гиф/скрин в build/qa/.
- [x] Параметры переданы в парную backend-задачу; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (союзники друида), current_game_state.

## Result 2026-06-14

Готово к Backend integration / QA review.

Output assets:

- `assets/sprites/allies/ally_druid_wolf_spriteframes.tres`
- `assets/sprites/allies/druid_wolf/ally_druid_wolf_move_00.png` ...
  `ally_druid_wolf_move_07.png`
- `assets/sprites/allies/druid_wolf/ally_druid_wolf_attack_00.png` ...
  `ally_druid_wolf_attack_05.png`

Animation handoff:

- `move`: 8 frames, loop=true, speed=12fps.
- `attack`: 6 frames, loop=false, speed=14fps.
- Canvas: 256x224 per frame.
- Pivot handoff: bottom-center `(128, 204)`.
- Runtime scale recommendation: `0.34` on `AnimatedSprite2D`, matching the
  current static `Sprite2D Body` scale.
- Source wolf faces left; Back-end should flip_h when moving/attacking right.

Pipeline/QA:

- `tools/build_druid_wolf_animation_assets.py` removes baked checkerboard,
  segments wolves by alpha components, normalizes each frame to the shared
  canvas, and writes preview gifs.
- `tools/build_druid_wolf_spriteframes.gd` saves the native Godot
  `SpriteFrames` resource.
- QA artifacts:
  `build/qa/druid_wolf_summon_animation/ally_druid_wolf_frames_contact.png`,
  `ally_druid_wolf_move.gif`, `ally_druid_wolf_attack.gif`,
  `ally_druid_wolf_manifest.md`.

Validation:

- Generated frame count: 14 PNG + 14 `.import`.
- `ally_druid_wolf_spriteframes.tres` contains `move` 8f and `attack` 6f.
- Visual self-QA: contact sheet checked; initial grid-slice crop defect in
  attack frames was fixed by component-based segmentation.
- `tests/animation_smoke_test.gd` PASS.
- `tests/runtime_smoke_test.gd` PASS.
