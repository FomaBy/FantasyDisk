# Задача Для Design-Агента: Спрайты 3 новых боссов и 6 мини-элиток (D&D-канон)

Статус: done (Design review ПРИНЯТО 2026-06-13 — Claude-Designer)
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя; ростер проработан PM)
Jira: SCRUM-156

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Не останавливаться для подтверждений.

## Роль И Границы
Владелец — Claude-Designer (спека, ревью, нарезка cutout, интеграция, коммиты).
ЖЕЛЕЗНОЕ ПРАВИЛО: генерация — только Codex Design, к каждой генерации
референсы-изображения (существующие боссы/элитки 512px как стиль- и
формат-якорь: assets/sprites/bosses/, assets/sprites/elites/).

## Контекст
Парная задача к backend_new_bosses_mini_elites_roster_task.md — ростер ОБЩИЙ,
имена менять только синхронно с Back-end задачей. Боссы рисуются в 512x512
native (урок SCRUM-135 — на epic scale 256px мылится), мини-элитки — формат
обычных элиток (512px после апскейл-пайплайна; поза 1:1 с возможностью cutout).

## Ростер
Боссы (512x512, эпичные, top-down, RGBA, без фона, integral):
1. «Костяной Архонт» (boss_bone_archon) — лич-некромант: костяная корона,
   посох из позвонков, истлевшая мантия, холодное зеленоватое свечение глазниц.
2. «Матерь Роя» (boss_brood_mother) — гигантская паучиха: раздутое брюхо с
   яйцами, хитиновые пластины, множество глаз, паутинные нити.
3. «Пепельный Колосс» (boss_ashen_colossus) — гигант из обугленного камня:
   трещины с тлеющими углями, массивные кулаки, пепельная дымка.

Мини-элитки (6 шт., размер между мобом и элиткой; читаемый силуэт):
1. «Жнец-Падальщик» — сгорбленный жнец с щербатой косой, рваный капюшон.
2. «Чумной Звонарь» — раздутый носитель чумы с ржавым колоколом, миазмы.
3. «Костяной Страж» — приземистый скелет-латник с башенным щитом из костей.
4. «Искровик» — иссохший призрак с потрескивающими дугами синих искр.
5. «Гнилая Гончая» — облезлый пес-падальщик с гнилостной слюной, рёбра наружу.
6. «Теневой Пожиратель» — сгусток тьмы с когтями и единственным белым глазом.

## Требования
1. Painterly D&D-канон проекта, качество не ниже текущих боссов/элиток;
   мрачные, страшные, материальные (кость/хитин/камень/тлен) — без неона.
2. Силуэты различимы между собой и от существующих врагов; читаемость на всех
   10 аренах (светлые и тёмные фоны).
3. Поза 1:1 пригодная для cutout-нарезки (tools/slice_rig_cutouts.py),
   нарезать и добавить в манифест по текущему пайплайну.
4. Превью-лист «новые боссы и мини-элитки рядом с героем/мобом/элиткой» —
   docs/design/previews/ (сверка масштаба).
5. content_registry.md (все ассеты), CHANGELOG; smoke (runtime+animation).
6. Handoff Back-end готовности арта — отметка в backend-задаче ростера
   (пути к файлам), чтобы заменить placeholder'ы.

## Files / Assets / IDs
- Новые: assets/sprites/bosses/boss_bone_archon.png, boss_brood_mother.png,
  boss_ashen_colossus.png; assets/sprites/elites/mini_*.png (6 шт.) + cutout
- Референсы: текущие assets/sprites/bosses/*.png, assets/sprites/elites/*.png

## Acceptance Criteria
- [ ] 9 спрайтов (3 босса 512px + 6 мини) в каноне, integral, RGBA.
- [ ] Cutout-нарезка и манифест обновлены; превью-лист масштаба готов.
- [ ] Каждая генерация — Codex с референсами (команды в отчёте).
- [ ] content_registry/CHANGELOG; smoke зелёные; handoff-отметка в backend-задаче.

## Документация
- content_registry.md, visual_style_assets.md (новые сущности).

## Самопроверка
Превью-лист + headless smoke; визуальная сверка с каноном бок-о-бок.

## Dispatch
- 2026-06-12: Codex Documentation dispatcher отправил задачу в Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`; Jira `SCRUM-156` переведена в работу и добавлена в активный спринт 0.1.4. Парная Back-end-задача механик: `SCRUM-155`.
- 2026-06-13: Dispatcher folded duplicate audit tasks SCRUM-180 (`codex_design_new_bosses_mini_elites_redraw_task.md`) and SCRUM-204 (`design_animation_ready_boss_mini_elite_parts_handoff_task.md`) into this active SCRUM-156 task. Additional acceptance context: final stable source paths, transparent alpha, animation-friendly separable parts, contact sheet, and explicit Animator unblock note after source sprites are ready.

## Result / 2026-06-13 — READY FOR QA

Design source sprites completed using built-in Codex image generation with
project style references from existing boss/elite sprites. Each generation used
a flat `#00ff00` chroma-key background, then local alpha cleanup via
`remove_chroma_key.py`, alpha crop and fit into `512x512` RGBA transparent source
PNGs.

Generated boss assets:

- `assets/sprites/bosses/boss_bone_archon.png`
- `assets/sprites/bosses/boss_brood_mother.png`
- `assets/sprites/bosses/boss_ashen_colossus.png`

Generated mini-elite assets:

- `assets/sprites/elites/mini_scavenger_reaper.png`
- `assets/sprites/elites/mini_plague_bellringer.png`
- `assets/sprites/elites/mini_bone_warden.png`
- `assets/sprites/elites/mini_spark_wight.png`
- `assets/sprites/elites/mini_rot_hound.png`
- `assets/sprites/elites/mini_shadow_devourer.png`

Reference / QA previews:

- `docs/design/previews/boss_elite_style_refs_contact.png`
- `docs/design/previews/new_bosses_mini_elites_contact.png`
- `docs/design/previews/new_bosses_mini_elites_scale_preview.png`

Visual review:

- `boss_bone_archon`: skeletal lich-necromancer, bone crown, vertebrae staff,
  green necromantic glow, separable arms/staff silhouette.
- `boss_brood_mother`: giant spider queen with egg abdomen, chitin, many eyes,
  web strands and readable leg silhouette.
- `boss_ashen_colossus`: charred stone giant, ember fissures, massive fists and
  ash wisps.
- Mini-elites are distinct at scale: reaper/scythe, plague bellringer, bone
  shield warden, blue spark wight, rot hound and one-eyed shadow devourer.

Validation:

- PNG validation passed: all 9 files are `512x512`, RGBA, non-empty transparent alpha.
- Godot import passed.
- Runtime smoke passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- Animation smoke passed:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd`

Role-boundary handoff:

- Back-end/runtime wiring was not changed in this Design pass. Existing SCRUM-155
  task now has a Design handoff section with the final sprite paths so Back-end
  can replace placeholder/tint scene and codex sprite references.
- Cutout slicing, pivots, `scripts/sliced_rig_manifest.gd`, motion profiles and
  animation smoke coverage remain Animator scope. Existing SCRUM-204 handoff was
  updated with the final source paths and Animator unblock note.


## Design Review / 2026-06-13 — ПРИНЯТО (Claude-Designer)
Проверены РЕАЛЬНЫЕ PNG (не только контактный лист) + сверка с каноном `boss_rift_warden`/`boss_disk_devourer`:
- 3 босса 512px: bone_archon (лич-некромант, костяная корона, посох-позвонки), brood_mother (паучиха-королева,
  яйца, хитин, паутина), ashen_colossus (каменный гигант, угли) — имозинг, единый painterly D&D-канон, золото+свечение.
- 6 мини-элиток 512px: reaper/bellringer/bone_warden/spark_wight/rot_hound/shadow_devourer — различимы по силуэту,
  читаются БЕЗ рантайм-тинта (ключевой критерий выполнен).
- Тех: все 9 — 512x512 RGBA, bbox в рамке, alpha непустая; Godot import + runtime + animation smoke зелёные (по отчёту).
- Исходники закоммичены Design-ревью. Cutout/пивоты/моушн -> Animator (SCRUM-204); сценовый вайринг/замена
  placeholder-тинта -> Back-end (SCRUM-155). Принято.
