# BUG(critical): Новые анимации персонажей не видны — анимспрайт скрыт за cutout-ригом

Статус: done
Приоритет: high
Роль: Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (отчёт пользователя + диагностика)
Jira: SCRUM-411
QA: in_progress (2026-06-15)

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
- [x] У персонажей с full-frame анимациями на экране ВИДЕН новый AnimatedSprite2D (walk/attack/idle/death), cutout-риг скрыт/не строится.
- [x] Fallback на cutout-риг для персонажей без full-frame листа сохранён.
- [x] Оружие/позиция/flip согласованы с новым слоем; проверены все 17.
- [x] Smoke проверяет видимость (ловит регресс); скрин/гиф из игры; animation+runtime smoke зелёные; CHANGELOG.

## Документация
docs/design/systems/animation.md, current_game_state.

## Dispatch Log
- 2026-06-14 — Dispatcher routed SCRUM-411 to Back-end window
  `019eabd9-780b-78a2-9f4b-e7203d659ef2` after SCRUM-410 reached QA. Eligible
  during 0.1.5 feature block because this is a critical bug/regression: accepted
  full-frame character animations are integrated but hidden behind the old
  cutout rig. Scope: runtime visibility/layer switch and smoke coverage only;
  no art regeneration, balance, unrelated animation asset work, release,
  commits, tags or pushes.

## Result
- 2026-06-14 — Back-end fixed the runtime layer switch in `scripts/player.gd`:
  playable classes with `<class_id>_spriteframes.tres` or `<class_id>_sheet.png`
  now render through visible `Player/VisualRoot/Body` full-frame SpriteFrames,
  while legacy `RigRoot` is hidden so it cannot cover the accepted redraw. The
  hidden rig remains only as a compatibility/socket/action-event anchor. Classes
  without full-frame frames keep the previous fallback: hidden Body and visible
  cutout RigRoot.
- Smoke coverage now asserts actual visibility:
  `tests/animation_smoke_test.gd` checks all 17 accepted playable SpriteFrames
  for visible Body + hidden RigRoot and checks a missing-full-frame fallback for
  visible RigRoot; `tests/runtime_smoke_test.gd` checks the spawned player in
  the live run.
- QA dump: `build/qa/scrum411/player_full_frame_visibility_dump.md`.
- Verification:
  - `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
  - `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

## QA-Вердикт (2026-06-15)
Статус: PASSED — full-frame анимация видима, cutout RigRoot скрыт

Проверено (фактически):
- **Фикс рантайм-слоя** (`scripts/player.gd`): `_uses_full_frame_visual` = есть ли
  `<class>_spriteframes.tres`/`_sheet.png`; если да — `Body.sprite_frames`=full-frame,
  `Body.visible=true`, `_configure_player_rig(config, show_cutout=false)` → `rig.visible=false`
  (легаси-риг скрыт как socket/action-anchor). Классы без full-frame → старый fallback
  (скрытый Body + видимый RigRoot).
- **animation_smoke**: проверяет видимость Body + скрытый RigRoot для всех 17 принятых
  playable SpriteFrames + fallback для missing-full-frame → **passed**.
- **runtime_smoke**: проверяет заспавненного игрока в live-run (видимый full-frame Body) +
  де-флейк ассасин — зелёный (10/10, SCRUM-410). QA-дамп
  `build/qa/scrum411/player_full_frame_visibility_dump.md`.
- **Только рантайм-слой**: арт/SpriteFrames/тайминги/баланс/таргетинг/урон не тронуты.

Acceptance:
- [x] Перерисованный full-frame персонаж виден (Body), cutout RigRoot скрыт.
- [x] Классы без full-frame сохраняют fallback; animation+runtime smoke зелёные.

Статус done. Баги: нет. Закрывает «перерисовка спрятана за старым ригом».
