# Задача (Codex Design → Claude-Designer): Перерисовать элиток и боссов в высоком разрешении (анти-мыло при epic-масштабе)

Дата: 2026-06-12

Статус: review

Версия: 0.1.4
Jira: SCRUM-135

Dispatch: отправлено в существующий Design чат `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12.

Роль: Design (Codex) — генерация арта; затем Claude-Designer — интеграция в риг-пайплайн.

## Краткая суть

После `backend_elite_boss_size_epic_terror` элитки рендерятся при node scale **1.4** (~1.73x моба), боссы при **1.9** (~2.35x моба) — `EPIC_ELITE_SCALE` / `EPIC_BOSS_SCALE`, `enemy._apply_epic_scale` в [scripts/enemy.gd:115](../../scripts/enemy.gd). Исходные спрайты всех элиток и боссов — **256x256**. При epic-увеличении 256px-арт выходит за нативное разрешение и мылится (мягкие контуры, расплыв деталей).

Мыло **подтверждено** количественно и визуально (см. ниже). Задача: перерисовать/апскейлить арт в нативном высоком разрешении в существующем D&D-каноне, сохранив позу/силуэт, затем переинтегрировать в cutout-риг.

## Autonomy / Approval

Пользователь заранее одобрил перерисовку и интеграцию в рамках этой задачи (Codex-генерация в этом месяце фактически бесплатна). Не спрашивать подтверждения на сам арт и его интеграцию. Спрашивать только при реальном блокере, обязательной security/sandbox-эскалации или разрушительном действии вне scope. **Перевод задачи в активную работу** регулируется Feature Freeze (ниже) — это отдельное от арт-апрува решение.

## Доказательство мыла (playtest-гейт пройден)

Цепочка масштабов до device-пикселей (источник 256px → body.scale → epic scale → camera zoom 1.12 → window stretch):

| Сущность | viewport px (design 1600w) | vs native | QHD 2560w | Retina ~2880w |
| --- | --- | --- | --- | --- |
| Элитка (body 0.52, epic 1.40) | 209px (x0.82, crisp) | downscale | 334px (**x1.30 BLUR**) | 376px (**x1.47 BLUR**) |
| Босс (body 0.52, epic 1.90) | 283px (**x1.11 soft**) | **upscale уже на базовом vp** | 453px (**x1.77 BLUR**) | 510px (**x1.99 BLUR**) |

Вывод:
- **Боссы** превышают нативные 256px уже при боевом зуме 1.12 на дизайн-разрешении 1600x900, и доходят до ~x2 на Retina-фуллскрине — мыло гарантировано.
- **Элитки** на дизайн-разрешении ещё чёткие (x0.82), но на QHD/Retina-фуллскрине дают x1.3–1.5 — мылятся на распространённых конфигурациях.
- Импорт-фильтр канваса — linear (mipmaps off), т.е. апскейл идёт билинейно → мягкость, а не честный пиксель-арт.

Визуальный пруф (нативные 256px vs реальный вывод GPU): [docs/design/previews/elite_boss_blur_proof.png](../design/previews/elite_boss_blur_proof.png).

## Целевое разрешение

- **Элитки** (`iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`): **512x512** (x2 от текущих 256).
- **Боссы** (`boss_rift_warden`, `boss_disk_devourer`): **512x512** (x2).

Обоснование 512:
- Максимальный device-размер боссов ~510px (Retina-фуллскрин) ≈ 512px native → ровно чётко, без запаса в мыло и без лишнего VRAM.
- 512 — это **тот же нативный тир, что у играбельных персонажей** (`size: Vector2(512,512)` в [scripts/sliced_rig_manifest.gd](../../scripts/sliced_rig_manifest.gd)). Риг-пайплайн уже доказан на 512px.
- Ровный множитель **x2** делает переинтеграцию почти механической (см. ниже).
- 768px брать только если планируется 4K-фуллскрин или дальнейший рост epic scale — тогда множитель x3 (тоже целый). По умолчанию — 512.

## ГЛАВНОЕ ОГРАНИЧЕНИЕ ДЛЯ ГЕНЕРАЦИИ: сохранить позу 1:1

Каждая элитка/босс уже нарезана на cutout-части руками: пиксельные боксы `crop/pivot/socket/foot_y/erase` в `CONFIG` файла [tools/slice_rig_cutouts.py](../../tools/slice_rig_cutouts.py) (все в 256px-пространстве, art смотрит влево, `base_facing = -1`).

Чтобы интеграция была почти автоматической, новый арт ОБЯЗАН повторять текущий спрайт:
- та же поза, тот же силуэт, те же позиции и пропорции конечностей/щита/оружия/вихря;
- та же ориентация (взгляд влево);
- центрирование/кадрирование как в оригинале (ступни на той же относительной высоте — `foot_y` оригинала ÷ 256 даёт долю кадра).

Тогда все боксы переносятся умножением на 2 — ре-тюнинг минимален. **Если поза/композиция меняется свободно — потребуется ручной ре-тюнинг ~5–7 боксов на каждую из 6 сущностей** против rig-debug вывода, это дороже и дольше.

Метод: предпочтительно взять текущий 256px-спрайт как референс/основу и поднять детализацию до 512 (img2img / upscale-with-detail), а не рисовать с нуля.

## Канон стиля (обязательно соблюдать)

Тёмное фэнтези в духе D&D, как у текущих врагов/героев: сильные читаемые контуры, объёмная покраска (painterly), приглушённая палитра с акцентами. Перед работой прочитать:
- `AGENTS.md`
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/systems/visual_style_assets.md`
- `docs/design/content_registry.md`

Идентичность сущностей сохранить:
- `iron_bastion` — тяжёлый щитоносец (есть отдельный `shield` part);
- `night_stalker` — быстрый ассасин-силуэт;
- `plague_prophet` — чумной заклинатель;
- `shard_marshal` — кристаллический командир;
- `boss_rift_warden` — есть вращающийся `vortex` part;
- `boss_disk_devourer` — босс-пожиратель.

Референсы — текущие спрайты: `assets/sprites/elites/*.png`, `assets/sprites/bosses/*.png`.

## Runbook интеграции (Claude-Designer, после готовности арта)

1. Положить новые 512px PNG поверх исходников (`assets/sprites/elites/<name>.png`, `assets/sprites/bosses/<name>.png`).
2. В `CONFIG` ([tools/slice_rig_cutouts.py](../../tools/slice_rig_cutouts.py)) для каждой из 6 сущностей обновить пиксельные боксы под 512px:
   - при сохранённой позе — умножить все `crop`, `pivot`, `socket`, `foot_y`, `erase`-координаты на **2**;
   - при изменённой позе — перетюнить боксы вручную по rig-debug выводу.
3. Прогнать слайсер из корня проекта: `python3 tools/slice_rig_cutouts.py`. Он перенарежет `assets/sprites/<group>/cutout/*` и перегенерирует [scripts/sliced_rig_manifest.gd](../../scripts/sliced_rig_manifest.gd) (там `size` станет `Vector2(512,512)`).
4. Проверить debug-сборки `build/rig_debug/cut_<entity>.png` (original | reassembled | exploded) — реассембл должен совпадать с оригиналом, части не разъезжаются, нет дыр после erase.
5. Сверить bbox/alpha частей и общий силуэт; убедиться, что `foot_y`/`socket` дают корректную постановку на землю и точку крепления.
6. Прогнать smoke: animation smoke + runtime smoke (Godot 4.6.3 headless, `~/Downloads/Godot.app` — см. [memory qa-test-runner]). Элитки/боссы должны спавниться, анимация ходьбы/атак и уникальные фазы (windup/strike/recover, vortex swirl) — без ошибок.
7. `enemy._apply_epic_scale` и `EPIC_*_SCALE` НЕ трогать — node scale остаётся прежним; нативное разрешение арта меняет только чёткость, не геометрию хитбокса/contact_range.
8. Обновить документацию: `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/visual_style_assets.md` (новое нативное разрешение элиток/боссов), CHANGELOG, статус на доске.

## Acceptance

- Все 4 элитки и 2 босса в native 512px, поза/идентичность/канон сохранены.
- Cutout-части перенарезаны, манифест `size = Vector2(512,512)`, rig-debug реассембл чистый.
- На Retina/QHD-фуллскрине боссы и элитки визуально чёткие (нет билинейного мыла на контурах).
- animation smoke + runtime smoke зелёные.
- Хитбоксы/contact_range/health-bar не изменились (epic scale нетронут).
- Документация и доска обновлены.

## Классификация по Feature Freeze 0.1.3

С 2026-06-12 действует FEATURE FREEZE спринта 0.1.3: новые не-баговые запросы (включая **арт/UI/контент**) оформляются в backlog `0.1.4` и не переводятся в `in_progress` без отдельного решения PM/пользователя. Эта задача — улучшение качества арта, не баг-фикс, поэтому по умолчанию заведена в **backlog 0.1.4**.

Развилка для PM/пользователя:
- Если мыло гигантов считать **регрессией от epic-scale фичи / release blocker для 0.1.3** — поднять в активный спринт.
- Иначе — оставить в `0.1.4` и брать после разморозки.

## Progress Log

2026-06-12 — взято в работу после снятия feature block и старта спринта 0.1.4.

- Подтверждена ветка `dev`.
- Проверены target source PNG: `assets/sprites/elites/{iron_bastion,night_stalker,plague_prophet,shard_marshal}.png` и `assets/sprites/bosses/{boss_rift_warden,boss_disk_devourer}.png`.
- Проверен текущий cutout pipeline в `tools/slice_rig_cutouts.py` и manifest `scripts/sliced_rig_manifest.gd`: все 6 target entity пока используют `size = Vector2(256, 256)`.

2026-06-12 — Design/Codex pass завершен, задача передана в review.

- 4 элитки и 2 босса заменены на native `512x512` RGBA PNG поверх активных путей:
  `assets/sprites/elites/{iron_bastion,night_stalker,plague_prophet,shard_marshal}.png`,
  `assets/sprites/bosses/{boss_rift_warden,boss_disk_devourer}.png`.
- Поза, ориентация влево, силуэт, foot/socket пропорции и идентичность сохранены 1:1; изменения направлены на анти-мыло при epic scale, не на смену дизайна.
- `tools/slice_rig_cutouts.py` обновлен под 512px координатное пространство target-сущностей; cutout-части перенарезаны, `scripts/sliced_rig_manifest.gd` теперь хранит `size = Vector2(512.0, 512.0)` для всех 6 target entity.
- Debug QA previews:
  - before: `docs/design/previews/elite_boss_upscale_before_contact.png`;
  - after: `docs/design/previews/elite_boss_upscale_after_contact.png`;
  - rig reassemble/exploded: `docs/design/previews/elite_boss_upscale_rig_debug_contact.png`.
- Godot import: passed.
- Animation smoke: passed (`tests/animation_smoke_test.gd`).
- Runtime smoke: blocked by unrelated current worktree UI/pause changes, not by SCRUM-135. Failure: `Expected Esc to defer (close) the level-up without keeping it paused. at tests/runtime_smoke_test.gd:788`. Dirty files involved are outside Design sprite scope (`scripts/main.gd`, `scripts/ui_screens.gd` and related Escape/level-up work). No gameplay/UI logic was changed in this Design task.
