# SCRUM-496: [HOLD] Скелетный риг мага/рыцаря: сборка idle/walk и рантайм-интеграция

Jira: SCRUM-496 · Роль: animator (Codex) · Контур: claude · Приоритет: P2 · foma · Эпик: SCRUM-474 (carry-over)
Статус: К выполнению / **USER HOLD — не начинать без явного go**

> ⚠️ БЛОКЕР. Тикет помечен `hold`. В описании и acceptance прямо: «[USER HOLD — не начинать без явного go]», «USER HOLD "анимацию пока не делать" действует и подтверждён». Эта спека — заготовка плана; **активную работу НЕ начинать**, пока пользователь/PM явно не скажет «делай анимацию». Снятие hold = поменять статус в Jira+.md и убрать метку `hold`.

## Что и зачем

Маг (`dark_mage`) и рыцарь (`knight`) — cartoon-классы, которые сейчас в рантайме показываются как «целый кадр» (full-frame AnimatedSprite2D) либо legacy cutout-риг. Цель — заменить это на покостный скелетный риг Skeleton2D/Bone2D с процедурными клипами idle/walk (петля, ≥5 ключей, **без attack**), собранными из уже доставленных Design-частей (SCRUM-475). Это:
- даёт «живой» idle (дыхание/покачивание) и шаговый walk вместо статичного спрайта у двух эталонных героев;
- сохраняет принятую cartoon-идентичность (части вырезаны из принятого cartoon2-источника, прозрачные RGBA);
- задаёт **воспроизводимый конвейер** для остальных 15 классов (manifest частей → Skeleton2D/Bone2D + AnimationPlayer → интеграция в player.gd);
- атака тела намеренно вне скоупа: визуал удара принадлежит оружейным сценам, оружейный сокет продолжает орбитировать (см. SCRUM-474).

Ожидаемый результат для игрока: при выборе мага/рыцаря персонаж покачивается в idle и переставляет конечности при ходьбе, оружие крутится вокруг как и раньше, при попадании — короткая красная вспышка.

## Текущое состояние в коде

**ВАЖНО: значительная часть работы уже лежит в дереве** (закоммичена в `205fe13e "Fix skeletal rig bone rest setup"` и `c55610c0 "checkpoint local WIP"`). Описание тикета («непринятый WIP», «остаётся собрать Skeleton2D/Bone2D») **устарело** относительно текущего состояния. По факту:

### Рантайм-риг — готов
- `scripts/skeleton_player_rig_2d.gd` (Node2D, 372 строки) — полноценный процедурный риг:
  - `configure(manifest_path, entity_id, base_scale)` → `_load_manifest()` → `_build_rig()` → `_build_animation_player()`.
  - `_build_rig()` (стр. 87–125): строит иерархию `Skeleton2D/Root → Pelvis → Torso → Head`, конечности через `_spawn_limb()` (upper/lower arm + hand, thigh/shin/foot для `l`/`r`), опциональные части (robe/cape/cloak/hood) через `_spawn_optional_parts()`. Спрайты частей крепятся `_attach_part_sprite()` с пивотами из манифеста, z-order — из `z_order_hint_back_to_front`. Маркер `WeaponSocketMarker` (`runtime_orbit_preserved`) на torso.
  - `_finalize_bone_setup()` (стр. 178–196): считает length/angle костей из child-offset либо leaf-extent, `set_rest(...)`, мета `rest_det_safe` — фикс из коммита 205fe13e.
  - `_build_animation_player()` (стр. 248–259): `AnimationPlayer` с клипами `idle`, `walk` и алиасом `move` (=walk). `root_node = ".."`.
  - `_make_idle_animation()` (стр. 262–278): LOOP_LINEAR, length 1.0, 5 ключей по root.position + покачивание torso/head + плащ/мантия.
  - `_make_walk_animation()` (стр. 281–300): LOOP_LINEAR, length 0.8, 5 ключей (0/0.2/0.4/0.6/0.8), root-движение + противофазные конечности через `_add_walk_limb_tracks()` (phase +1 для `l`, −1 для `r`).
  - `play_action()` (стр. 62–65): **намеренно no-op** — атака тела вне скоупа (комментарий ссылается на SCRUM-474).
  - `play_hit()` (стр. 56–59): красная вспышка через tween.
  - `update_animation(delta, velocity, facing)` (стр. 43–53): выбирает walk/idle по `velocity`, зеркалит по `facing.x` через знак `scale.x`, гонит `_animation_player.advance(delta)`.

### Сцены — готовы
- `scenes/characters/DarkMageSkeletonRig.tscn` и `KnightSkeletonRig.tscn` — Node2D со скриптом `skeleton_player_rig_2d.gd`, `entity_id`, `manifest_path` (= `res://assets/sprites/characters/skeleton_parts/<id>/skeleton_source_manifest.json`), `base_scale = (0.5, 0.5)`.

### Источники частей — готовы и валидны
- `assets/sprites/characters/skeleton_parts/{dark_mage,knight}/parts/` — по 19 PNG (38 файлов с .import каждый), плюс `skeleton_source_manifest.json` (parts/pivots/source_pivots/z_order/checks). Валидатор PASS для обоих (проверено).
- Зеркало для Design: `docs/design/references/chars_cartoon/skeleton_parts/{dark_mage,knight}/`.
- Маг: 19 частей (+robe_front, cloak_back_l/r, hood_shadow). Рыцарь: 19 частей (+shoulder_armor_l/r, cape_l/r).

### Интеграция в player.gd — присутствует, но `player.gd` НЕ закоммичен (` M scripts/player.gd`)
- Стр. 17–18: `preload` обеих скелетных сцен.
- Стр. 239–252 (в `configure_character`): `_character_skeleton_rig_scene(character_id)` → если не null, `_uses_skeletal_visual = true`, full-frame и legacy скрываются (`body.visible=false`), вызывается `_configure_skeletal_player_rig(scene)`.
- `_skeletal_rig()` (стр. 1730): узел `VisualRoot/SkeletalRigRoot`.
- `_configure_skeletal_player_rig()` (стр. 1760–1783): удаляет старый, инстанцирует сцену под `SkeletalRigRoot`, зовёт `rig.configure(manifest, character_id, BASE_SPRITE_SCALE)`.
- `_character_skeleton_rig_scene()` (стр. 1786–1792): match `dark_mage`→DarkMage, `knight`→Knight, иначе null.
- В `_update_movement_animation()` (стр. 1616–1618): каждый кадр зовёт `skeletal_rig.update_animation(delta, velocity, _facing_direction)`.
- В `_play_hit_feedback()` (стр. 1677–1679): зовёт `skeletal_rig.play_hit()`.
- Оружейный сокет (`_weapon_socket()`/`_apply_sprite_transform()` стр. 1639–1646) орбитирует независимо — **сохранён**.

### Тесты — покрытие уже написано
- `tests/animation_smoke_test.gd`: в основном проходе (стр. 288–299) для `dark_mage`/`knight` проверяет, что Body и legacy RigRoot скрыты, и зовёт `_assert_skeletal_player_rig()` (стр. 792–846): живой `SkeletalRigRoot`; есть `Skeleton2D`+`AnimationPlayer`; клипы idle/walk/move есть, attack/attack_primary НЕТ; цепочка костей `Root/Pelvis/Torso/Head`, `UpperArmL/R`, `ThighL/R`; torso-спрайт берёт текстуру из `assets/sprites/characters/skeleton_parts/<id>/parts/`; при velocity→walk root.y смещается и бёдра в противофазе; зеркало `scale.x` по направлению; возврат в idle; weapon socket с `weapon_orbit_radius`.

### Что фактически осталось
1. **Принять/закоммитить `player.gd`** (сейчас рабочая копия, не в HEAD) — после снятия hold.
2. **Прогнать green-gate**: validate + animation_smoke + runtime_smoke на чистом дереве.
3. **Чинить расхождение пути валидатора** (см. подводные камни): тикет говорит `validate_skeleton_source_manifest.py`, но в репо он только под `skills/codex/fantasydisk-animation-director/scripts/`.
4. **Задокументировать воспроизводимый путь** для остальных 15 классов.
5. Визуальная вычитка idle/walk на маге и рыцаре (пивоты/z-order/без артефактов на стыках).

## Что сделать — по шагам

> Только после явного «делай анимацию».

1. **Снять hold**: статус в Jira → «В работе»/«К выполнению», убрать метку `hold`, синхронизировать `.md`. Зафиксировать в task_board.
2. **Привести дерево в зелёное на коммит**: убедиться, что незакоммиченные правки `scripts/player.gd` — это именно скелетная интеграция (стр. 17–18, 239–252, 1616–1618, 1677–1679, 1730–1792). Прогнать тесты ДО коммита (green-gate).
3. **Валидатор**: прогнать `python3 skills/codex/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py <manifest>` для обоих манифестов (сейчас PASS). Если по acceptance нужен путь `tools/validate_skeleton_source_manifest.py` — добавить тонкую обёртку/симлинк в `tools/`, импортирующую логику из скилла (НЕ дублировать код), и обновить упоминания в acceptance/доке.
4. **animation_smoke**: прогнать `tests/animation_smoke_test.gd` headless (Godot 4.6.3 в `~/Downloads/Godot.app`, см. QA-память). Убедиться, что `_assert_skeletal_player_rig` зелёный для мага и рыцаря.
5. **runtime_smoke**: прогнать `tests/runtime_smoke_test.gd` (и связанные `runtime_smoke_*`). Если красный — изолировать причину; известная ловушка: ложные red'ы из-за реального мета-сейва (см. память `godot-userdatadir-not-isolating-real-save`) и stale-тесты, не связанные с ригом. Не эскалировать несвязанное в critical.
6. **Визуальная проверка**: запустить игру, выбрать мага и рыцаря, проверить idle-покачивание, walk-переступание, зеркало при движении влево, орбиту оружия и hit-flash. Проверить стыки частей (нет «разрывов» суставов, корректный z-order — голова/капюшон поверх, плащ/мантия позади).
7. **Документация воспроизводимого пути для 15 классов**: написать короткий ран-бук (в `docs/design/` или в скилле `fantasydisk-animation-director`): Design отдаёт `skeleton_source_manifest.json`+`parts/` (валидатор PASS) → создать `scenes/characters/<Class>SkeletalRig.tscn` (скрипт `skeleton_player_rig_2d.gd`, `entity_id`/`manifest_path`/`base_scale`) → добавить класс в `_character_skeleton_rig_scene()` (player.gd) и `preload` сцены → расширить покрытие в animation_smoke. Перечислить требования к манифесту (15 обязательных humanoid-частей из валидатора).
8. **Коммит** явным `git add` своих файлов (player.gd + новая обёртка валидатора + докбук), сообщение `feat(SCRUM-496): ...`. Обновить Jira/доску, прогнать `jira_board_sync.py`.

## Acceptance Criteria

Из тикета:
- [ ] **НЕ выполнять до явного user/PM go «делай анимацию» (USER HOLD).** Перед стартом — подтверждение снятия hold.
- [ ] На маге и рыцаре собран Skeleton2D/Bone2D риг с idle + walk (loop, ≥5 ключей, **без attack**).
- [ ] Рантайм `player.gd` использует скелетный риг вместо legacy для cartoon-классов; оружейный сокет сохранён.
- [ ] `validate_skeleton_source_manifest.py` + `animation_smoke_test` + `runtime_smoke` зелёные.
- [ ] Задокументирован воспроизводимый путь для остальных 15 классов.

Дополнено по коду:
- [ ] `scripts/player.gd` закоммичен (сейчас рабочая копия) и проходит green-gate ДО коммита.
- [ ] Расхождение пути валидатора устранено: либо acceptance ссылается на фактический путь под `skills/codex/...`, либо есть тонкая обёртка `tools/validate_skeleton_source_manifest.py` без дублирования логики.
- [ ] `_assert_skeletal_player_rig` зелёный для `dark_mage` и `knight` (idle/walk/move есть, attack нет, цепочка костей, asset-side parts, root-motion, противофаза бёдер, зеркало, возврат в idle).
- [ ] Body (full-frame) и legacy `RigRoot` скрыты, когда `SkeletalRigRoot` активен (см. стр. 294–296 теста).
- [ ] Визуально: idle покачивается, walk переступает, зеркало влево, оружие орбитирует, hit-flash работает; нет разрывов суставов и ломаного z-order.
- [ ] Метка `hold` снята, статус обновлён в Jira+.md, доска синхронизирована.

## Files / точки входа

- `scripts/skeleton_player_rig_2d.gd` — риг готов; правки только если визуальная вычитка выявит проблемы пивотов/длин костей (`_finalize_bone_setup`, `_attach_part_sprite`) или клипов (`_make_idle_animation`/`_make_walk_animation`).
- `scripts/player.gd` — **закоммитить** текущие правки интеграции: `_character_skeleton_rig_scene` (1786), `_configure_skeletal_player_rig` (1760), вызовы `update_animation`/`play_hit` (1616/1677), preload (17–18). При добавлении новых классов — расширять `_character_skeleton_rig_scene` match и preload.
- `scenes/characters/DarkMageSkeletonRig.tscn`, `KnightSkeletonRig.tscn` — готовы; шаблон для новых классов.
- `assets/sprites/characters/skeleton_parts/{dark_mage,knight}/` — `skeleton_source_manifest.json` + `parts/*.png` (валидны).
- `tests/animation_smoke_test.gd` — `_assert_skeletal_player_rig` (792) и проход (288–299); при добавлении классов расширять список.
- `skills/codex/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py` — фактический валидатор; решить вопрос обёртки в `tools/`.
- `docs/design/` или скилл `fantasydisk-animation-director` — место для ран-бука по 15 классам.

## Замечания / подводные камни

- **HOLD первичен.** Всё выше — план; без явного go не трогать. При снятии — обязательно сменить статус (память `reopen-change-status`).
- **Описание тикета устарело.** Он называет WIP «непринятым», но `skeleton_player_rig_2d.gd`, обе сцены, части и тест уже в HEAD (коммиты 205fe13e, c55610c0); незакоммичен только `player.gd`. Исполнителю: сверить реальное дерево, не делать заново — основная работа сделана.
- **Расхождение пути валидатора.** Acceptance ждёт `validate_skeleton_source_manifest.py`, но он лежит под `skills/codex/fantasydisk-animation-director/scripts/`, а `tools/validate_skeleton_source_manifest.py` НЕ существует. Не плодить копию — тонкая обёртка/симлинк либо правка формулировки acceptance.
- **Anti-collision / locked paths.** `scripts/ui_screens.gd` и `scripts/progression_data.gd` — за Claude/изолированы, эта задача их НЕ трогает. Основной конфликтный файл — `scripts/player.gd` (часто меняется несколькими воркерами): коммитить явным `git add scripts/player.gd`, НЕ `git add -A` (память `commit-explicit-add-during-churn`, `fleet-workers-git-add-all`), green-gate ДО коммита; после коммита перепроверить HEAD в worktree 2–3 прогона (память `qa-verify-head-isolated-coupled-fix`).
- **runtime_smoke ложные red'ы.** Известны false-red из-за реального dev мета-сейва (`--user-data-dir` не изолирует death_save/unlocks — память `godot-userdatadir-not-isolating-real-save`) и stale-тестов, не связанных с ригом. Проверять с нейтрализованным мета, не эскалировать несвязанное в critical.
- **Манифест-имя файла.** Сцены ссылаются на `skeleton_source_manifest.json` (не на абстрактный «manifest.json»). При добавлении классов сохранять это имя и структуру (parts/pivots/source_pivots/z_order_hint_back_to_front/checks). Валидатор требует 15 обязательных humanoid-частей + `checks.{transparent_rgba,no_background,joint_overlap,empty_hands}=true` + `style_anchor`.
- **Атака тела вне скоупа** (SCRUM-474): `play_action()` — no-op, attack-клипов быть НЕ должно (тест это проверяет). Визуал удара — на оружейных сценах, сокет орбитирует независимо.
- **Связанные тикеты:** SCRUM-474 (родитель/эпик, закрыт PM-чисткой 2026-06-27, runtime-анимация перенесена сюда), SCRUM-475 (Design доставил части — done, оба манифеста PASS).
- **Foma/рутины.** Тикет теган `foma`, но `hold` — авто-рутины не должны его подхватывать; брать только вручную после go.
- **Среда QA.** Godot 4.6.3 в `~/Downloads/Godot.app`, headless smoke (память `qa-test-runner`).
