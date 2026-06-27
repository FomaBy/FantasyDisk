# SCRUM-520: Level Up: показывать иконку возле персонажа при получении уровня

Jira: SCRUM-520 · Роль: backend (Codex) · Контур: codex · Приоритет: P1 · foma · Эпик: SCRUM-215
Статус: К выполнению (blocked снят — Design handoff из SCRUM-519 принят 2026-06-27)

## Что и зачем

Цель с точки зрения игрока: в момент получения уровня рядом с персонажем должен на короткое время (~0.6–1.2 с) всплывать красивый, читаемый бейдж `Level Up` — появление, лёгкий подъём + scale + fade, затем автоматическое исчезновение без ручного закрытия. Это даёт мгновенную позитивную обратную связь «я вырос» прямо в зоне внимания (у героя), не отвлекая от боя.

Почему важно: сейчас при level-up рядом с персонажем рисуется только процедурная вспышка с текстовой подписью `LEVEL UP` (Label с font-override), сделанная «на коленке» до того, как Design подготовил финальный asset. Design-тикет SCRUM-519 уже выпустил production-ready transparent PNG бейдж `assets/sprites/effects/level_up_popup_badge.png` (512×256 RGBA, чистая alpha, рекомендованный размер показа 224×112). Задача — заменить процедурную подпись на этот готовый asset, сохранив праздничный бурст, и гарантировать корректное поведение в edge-кейсах.

Ожидаемый результат: при каждом level-up возле героя кратко всплывает бейдж-иконка `Level Up` (готовый PNG), плавно поднимается/масштабируется/гаснет и сам исчезает. Механика опыта, выбор наград, пауза level-up-экрана и баланс — без изменений.

## Текущее состояние в коде

Поток level-up (заземлено по коду):

1. `scripts/player.gd:4` — `signal leveled_up`.
2. `scripts/player.gd:1416` `gain_xp(amount)` → в цикле `while xp >= xp_to_next` инкрементит `level` и на строке `scripts/player.gd:1422` делает `leveled_up.emit()` (один emit на каждый набранный уровень — важно для серии быстрых level-up подряд).
3. `scripts/combat_director.gd:46-47` — подписка: `if game.current_player.has_signal("leveled_up"): game.current_player.leveled_up.connect(game.ui._on_player_leveled_up)`.
4. `scripts/ui_screens.gd:5430` `_on_player_leveled_up()`:
   - `game._play_sfx("level_up")`
   - `game.level_up_return_to_map = not game.combat_active`
   - `game.pending_level_ups += 1`
   - `_show_level_up_toast()`  ← визуальный popup рядом с героем (наш предмет работы)
   - `_update_level_up_button()` ← угловая «+»-кнопка (НЕ трогаем, это SCRUM-278/SCRUM-519 badge на кнопке)
5. `scripts/ui_screens.gd:5446` `_show_level_up_toast()`:
   - вызывает `_spawn_level_up_effect()` (бурст-эффект в world-space)
   - при отсутствии `game.hud_layer` создаёт HUD (`_create_hud` / `_create_menu_run_hud`)
   - инстанцирует `game.LEVEL_UP_TOAST_SCENE` → нода `LevelUpToast`, `process_mode = ALWAYS`, `setup(game.current_player, game.pending_level_ups)`, добавляет в `game.hud_layer`.
6. `scripts/ui_screens.gd:5466` `_spawn_level_up_effect()`:
   - инстанцирует `game.LEVEL_UP_EFFECT_SCENE` → нода `LevelUpEffect` (Node2D), `process_mode = ALWAYS`, добавляет как child `game` (world-space), `global_position = current_player.global_position`, `setup(current_player)`.

Две существующие реализации эффекта (обе рисуют ПРОЦЕДУРНУЮ подпись, без PNG-бейджа):

- `scripts/level_up_effect.gd` (scene `scenes/LevelUpEffect.tscn`, корень Node2D):
  - `_ready()` (стр. 19–23): `process_mode = ALWAYS`, `add_to_group("level_up_effects")`, `z_index = 80`.
  - `_build_visual()` (стр. 36–65): золотая FLASH-вспышка (additive), расходящееся CYAN-кольцо, **Label с text `"LEVEL UP"`** (стр. 47–56, font_size 24, gold + outline), 16 искр.
  - `_play(...)` (стр. 68–106): root-tween `tween_interval(0.85)` → `finished.emit()` + `queue_free()`. Label поднимается до `position:y = -120` и гаснет.
  - `_physics_process` (стр. 109–111): следует за игроком (`global_position = _player.global_position`).
  - Очистка: входит в группу `level_up_effects`, которую `scripts/main.gd:859` `_clear_world()` чистит `queue_free()` при сбросе мира.

- `scripts/level_up_toast.gd` (scene `scenes/LevelUpToast.tscn`, корень Control, на `hud_layer`):
  - `setup(player, level_count)` (стр. 16–18): хранит `_player`, `_level_count`.
  - `_ready()` (стр. 21–25): `process_mode = ALWAYS`, `mouse_filter = IGNORE`, `PRESET_FULL_RECT`.
  - `_build_visual()` (стр. 39–71): центр = `_toast_center()` (стр. 110–113: `player.get_viewport_transform() * player.global_position`, экранное пространство), FLASH + ring + **Label `"LEVEL UP"` / `"LEVEL UP x%d"`** (стр. 52–61, font_size 34) + 18 искр.
  - `_play(...)` (стр. 74–107): root-tween fade-in 0.12 → `tween_interval(0.6)` → fade-out 0.25 → `finished.emit()` + `queue_free()` (итого ~0.97 с). Это единственный механизм самоудаления тоста (он НЕ в группе `level_up_effects`, поэтому `_clear_world` его не чистит — полагается на свой tween).

Design asset и handoff (SCRUM-519, статус done — `docs/tasks/design_level_up_popup_badge_task.md`):

- Финальный runtime asset: `assets/sprites/effects/level_up_popup_badge.png` (512×256 RGBA, есть `.import`).
- Layout: `docs/design/references/level_up_popup/level_up_popup_layout.json` (canvas 512×256, zone `label` = «Level Up»).
- Handoff-рекомендации (из задачи, стр. 60–68): recommended display size **224×112 px**, minimum readable **160×80 px**; pivot/anchor **center-bottom, 10–18 px над головой героя**; анимация **scale 0.92 → 1.04 → 1.0, подъём вверх 24–36 px, fade out ~0.85 с**.

Тесты:

- `tests/runtime_smoke_test.gd:776` `player.gain_xp(20)` триггерит level-up; далее проверяется ТОЛЬКО `pending_level_ups > 0` и угловая `LevelUpPlusButton` (стр. 782–814). Сам popup-бейдж/тост сейчас не проверяется.
- `tests/runtime_smoke_ui_test.gd` — UI smoke, упоминается в тикете как место для focused level-up smoke.

## Что сделать — по шагам

Подход: переиспользовать существующий путь `_on_player_leveled_up → _show_level_up_toast`. Заменить процедурную текстовую подпись на готовый PNG-бейдж в ОДНОЙ из эффект-нод, оставив праздничный бурст (искры/вспышка) для «вкуса». Рекомендуется править `scripts/level_up_effect.gd` (Node2D, world-space, уже привязан к герою и уже чистится в `_clear_world` через группу `level_up_effects`) — это даёт надёжное поведение «возле персонажа» и автоочистку при death/смене экрана. Тост (`level_up_toast.gd`) можно оставить как есть либо тоже перевести на бейдж — см. примечание о дублировании.

1. **Добавить preload бейджа** в `scripts/level_up_effect.gd`:
   `const BADGE_TEXTURE := preload("res://assets/sprites/effects/level_up_popup_badge.png")`.

2. **Заменить процедурный Label на Sprite2D-бейдж** в `_build_visual()` (`scripts/level_up_effect.gd:47-56`):
   - Вместо `Label` с `text = "LEVEL UP"` создать `Sprite2D` с `texture = BADGE_TEXTURE`.
   - Масштаб подобрать под рекомендованный размер показа: asset 512×256 → display ~224×112 ⇒ `scale ≈ Vector2.ONE * (224.0 / 512.0)` (≈0.4375). Вынести в `const BADGE_DISPLAY_WIDTH := 224.0` и считать scale от ширины текстуры.
   - Pivot center-bottom: спрайт по умолчанию центрирован (`centered = true`). Чтобы «низ бейджа» был на ~14 px над головой, выставить позицию: `sprite.position = Vector2(0, -head_offset - badge_half_height)`, где `head_offset` ≈ 64–80 px (высота героя над пивотом игрока — взять из текущего смещения Label: сейчас Label стартует на `y = -104` и уходит к `-120`, ориентир «над головой»). Достаточно `sprite.position = Vector2(0, -120.0)` как стартовая точка, далее подъём анимацией. Подобрать визуально по handoff (10–18 px над головой) — см. AC.
   - НЕ применять additive-материал к бейджу (PNG уже финальный, с тенью/обводкой) — оставить нормальный blend, чтобы не выжечь цвета. Additive оставить только для вспышки/искр.

3. **Анимировать бейдж** по handoff-кривой в `_play(...)` (`scripts/level_up_effect.gd:68-106`):
   - Появление: `modulate:a 0 → 1` за ~0.12 с.
   - Scale: `0.92 → 1.04 → 1.0` (через `tween_property(... "scale" ...).set_trans(TRANS_BACK).set_ease(EASE_OUT)` либо chain из двух шагов) от базового display-scale.
   - Подъём: `position:y` вверх на 24–36 px (`TRANS_QUAD`, `EASE_OUT`).
   - Fade out: `modulate:a → 0` с задержкой, общая длительность бейджа ~0.6–1.0 с (вписать в требование ~0.6–1.2 с). Текущий root-tween `tween_interval(0.85)` оставить как общий таймер жизни ноды / синхронизировать с длительностью бейджа (увеличить при необходимости, но держать ≤ ~1.2 с).
   - `finished.emit()` + `queue_free()` в конце — оставить.

4. **Z-order и неперекрытие HUD**: бейдж в world-space с `z_index = 80` уже выше арены. Убедиться, что он НЕ перекрывает критичные HUD-элементы (XP-бар, угловая «+»-кнопка, портрет/HP). Так как эффект — child `game` (world-слой), а HUD — отдельный `hud_layer` (CanvasLayer выше), HUD рисуется поверх — конфликта быть не должно. Проверить визуально, что бейдж над головой не залезает на верхний HUD при позиции героя у верхней кромки арены (камера обычно центрирует героя — риск низкий, но отметить).

5. **Edge-кейсы — поведение при death / pause / смене экрана / серии level-up**:
   - Death/смена экрана: `_clear_world()` (`scripts/main.gd:859`) чистит группу `level_up_effects` → нода-бейдж удаляется. Убедиться, что `add_to_group("level_up_effects")` сохранён (стр. 21).
   - Pause level-up-экрана: эффект `process_mode = ALWAYS`, tween `set_pause_mode(TWEEN_PAUSE_PROCESS)` — анимация доигрывает даже при паузе и не залипает.
   - Серия быстрых level-up: каждый emit создаёт свою ноду-бейдж. Допустимо короткое наложение (норм для +N уровней). Опционально: при наличии живого предыдущего бейджа — не плодить бесконечно (например, дать им разный小 вертикальный сдвиг или ограничить число одновременно). НЕ обязательно для приёмки, но проверить, что 3–5 подряд не ломают рендер/не залипают.

6. **Тост (`level_up_toast.gd`) — решение о дублировании**: сейчас `_show_level_up_toast` рисует И бурст-эффект (world), И тост (HUD) — оба с текстом «LEVEL UP». Чтобы не было двух подписей, выбрать ОДИН источник бейджа:
   - Вариант A (рекомендуется): бейдж в `level_up_effect.gd` (world, у героя), а `level_up_toast.gd` оставить как лёгкий бурст БЕЗ текстовой подписи (убрать его Label на стр. 52–61) либо вовсе не менять, если визуально не конфликтует. Решение зафиксировать в AC/комментарии.
   - Вариант B: бейдж в `level_up_toast.gd` (экранное пространство у героя через `_toast_center()`), тогда правки симметричны шагам 1–3 в toast-файле. Минус: тост не в группе `level_up_effects`, чистится только своим tween — при резкой смене сцены риск кратко «висящего» тоста выше; если идти этим путём — добавить тост в группу `level_up_effects` ИЛИ гарантировать `queue_free` при `_clear_world` (например, ловить через `add_to_group`).

7. **Smoke/QA evidence**: дополнить `tests/runtime_smoke_ui_test.gd` (или `tests/runtime_smoke_test.gd` рядом со стр. 776) проверкой: после `gain_xp` нода `LevelUpEffect` (или `LevelUpToast`) появилась в дереве, использует текстуру `level_up_popup_badge.png`, имеет `process_mode == ALWAYS`; прогнать кадры/таймер и убедиться, что нода самоудалилась (нет залипания). Прогнать сценарий с несколькими level-up подряд (`gain_xp` с большим amount → несколько emit). Headless Godot 4.6.3 (`~/Downloads/Godot.app`).

## Acceptance Criteria

- [ ] (из тикета) Issue стартует только после accepted Design handoff из SCRUM-519 — выполнено (asset `assets/sprites/effects/level_up_popup_badge.png` есть, SCRUM-519 done); label `blocked` снят.
- [ ] При получении уровня возле персонажа появляется `Level Up` icon/badge (готовый PNG `level_up_popup_badge.png`, НЕ процедурный текст) на короткое время (~0.6–1.2 с) и исчезает БЕЗ ручного закрытия.
- [ ] Бейдж использует готовый asset через preload `res://assets/sprites/effects/level_up_popup_badge.png` и показывается на рекомендованном размере (~224×112, не мельче 160×80), pivot center-bottom, 10–18 px над головой героя.
- [ ] Анимация: появление (fade-in) + лёгкий scale (≈0.92→1.04→1.0) + подъём (24–36 px) + fade-out, в пределах ~1.2 с.
- [ ] Popup НЕ перекрывает критичные HUD-элементы (XP-бар, угловая «+»-кнопка, портрет/HP).
- [ ] Popup НЕ залипает после death / pause / смены экрана: при `_clear_world()` нода удаляется (через группу `level_up_effects`), при паузе анимация доигрывает (`process_mode ALWAYS`, tween `TWEEN_PAUSE_PROCESS`).
- [ ] Корректная работа при нескольких быстрых level-up подряд (3–5 emit): нет залипших нод, нет визуального слома.
- [ ] НЕ дублируется текст/бейдж: только ОДИН источник подписи `Level Up` на событие (бурст-эффект и тост не показывают две подписи одновременно).
- [ ] Level-up reward flow, XP, pause/selection semantics и баланс — без изменений (`pending_level_ups`, `_open_pending_level_up`, `_show_level_up_screen`, `gain_xp` НЕ тронуты по логике).
- [ ] Есть runtime/UI smoke или QA evidence для одного level-up события и для повторных level-up подряд.

## Files / точки входа

- `scripts/level_up_effect.gd` (РЕКОМЕНДУЕМАЯ точка правок):
  - `_build_visual()` (стр. 36–65) — заменить `Label "LEVEL UP"` (стр. 47–56) на `Sprite2D` с `BADGE_TEXTURE`; добавить `const BADGE_TEXTURE` + `const BADGE_DISPLAY_WIDTH`.
  - `_play(...)` (стр. 68–106) — анимация бейджа (fade/scale/float) по handoff-кривой; синхронизировать с root-tween-таймером (стр. 69–75).
  - сохранить `add_to_group("level_up_effects")` (стр. 21) и `_physics_process` follow (стр. 109–111).
- `scripts/level_up_toast.gd` — при выборе Варианта A убрать дублирующий `Label` (стр. 52–61), чтобы не было двух подписей; при Варианте B — симметричные правки + гарантия очистки при `_clear_world`.
- `tests/runtime_smoke_ui_test.gd` (или рядом с `tests/runtime_smoke_test.gd:776`) — focused level-up smoke: бейдж появился, использует нужную текстуру, самоудалился; повторные level-up.
- `scripts/ui_screens.gd:5446-5478` — точки `_show_level_up_toast` / `_spawn_level_up_effect` (ЧИТАТЬ для контекста; логику вызова менять не требуется).
- НЕ требуют изменений (только для понимания): `scripts/player.gd:1416-1422` (`gain_xp`/`leveled_up.emit`), `scripts/combat_director.gd:46-47` (подписка сигнала), `scripts/main.gd:858-862` (`_clear_world` чистит группу `level_up_effects`).

## Замечания / подводные камни

- **Anti-collision / locked paths**: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — горячие, конфликтные файлы (правки нескольких воркеров). Эта задача их менять НЕ должна — вся логика правится в изолированных `scripts/level_up_effect.gd` / `scripts/level_up_toast.gd` + тестовый файл. Если кажется, что нужно тронуть `ui_screens.gd` (напр. флаг «не плодить тосты») — сначала свериться с активными лейнами, держать дельту минимальной, либо вынести в эффект-ноду.
- **Тикет помечен `ui`+`backend`+`codex`+`popup`** — это back-end/Codex scope (runtime-показ), а НЕ генерация графики (та закрыта SCRUM-519). Не трогать Design-source под `docs/design/references/level_up_popup/`.
- **Дублирование подписи** — главный визуальный риск: сейчас и `LevelUpEffect`, и `LevelUpToast` рисуют «LEVEL UP». После замены на бейдж убедиться, что игрок видит ОДИН бейдж, а не два (выбрать единый источник — см. шаг 6 / Вариант A).
- **Не выжигать PNG**: бейдж — финальный asset с собственной тенью/обводкой; НЕ вешать на него `CanvasItemMaterial BLEND_MODE_ADD` (additive только для искр/вспышки), иначе цвета «поплывут».
- **Очистка тоста**: `LevelUpToast` НЕ в группе `level_up_effects`, поэтому `_clear_world` его не удаляет — он полагается на собственный tween (`level_up_toast.gd:81-84`). Если выбираете Вариант B (бейдж в тосте), добавьте тост в группу `level_up_effects` или иной гарант очистки, иначе при резкой смене экрана возможен кратко «висящий» тост.
- **Серия level-up**: `gain_xp` (`player.gd:1418-1422`) emit'ит сигнал в цикле — при большом XP-пакете прилетит N событий подряд, каждое создаёт ноду. Это ожидаемо; проверить, что N=3..5 не ломает рендер и ноды чистятся.
- **Frame/safe-area rule (память проекта)**: UI-контент только в пустой зоне фрейма. Бейдж — over-the-head effect в world-space, не на HUD-рамке; убедиться, что не залезает на орнамент HUD-фрейма при крайних позициях героя.
- **Версия**: фриз 0.1.5 активен; эта работа идёт в 0.1.7 (по SCRUM-519). Версионную строку (`project.godot config/version`) не трогать в рамках этой задачи.
- **Связанные тикеты**: SCRUM-519 (Design asset, done — источник PNG/handoff), SCRUM-278 (угловая «+»-кнопка возврата к выбору — НЕ путать с popup-бейджем; кнопку не трогать), эпик SCRUM-215.
- **Verify**: Godot 4.6.3 headless (`~/Downloads/Godot.app`), smoke-тесты. Учитывать «Godot --user-data-dir не изолирует сейв» — мета-сейв читается реальный; для level-up smoke это не критично (триггерим через `gain_xp` в рантайме), но не эскалировать ложные red'ы от мета-состояния.
