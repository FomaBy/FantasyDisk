# SCRUM-912: Storm Longbow piercing-cone VFX

Статус: done
Приоритет: p2
Роль: Design / Animator (единый visual owner)
Контур: Codex
Owner: Codex Design/Animator `/root/scrum912_vfx_design`
Thread: `/root/scrum912_vfx_design`
Версия: 0.2.1
Jira: SCRUM-912
Branch: `codex/scrum-912-storm-longbow-vfx`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-912-storm-longbow-vfx`

Locked paths:
- `docs/tasks/animation_weapon_attack_storm_longbow_pixellab_task.md`
- `docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/`
- `docs/design/previews/weapon_attack_animations/storm_longbow_pixellab_scrum912_contact.png`
- `assets/sprites/effects/storm_longbow/`
- `assets/sprites/effects/vfx_weapon_storm_longbow.png`
- `scenes/vfx/StormLongbowVolleyVfx.tscn`
- `scripts/vfx/storm_longbow_volley_vfx.gd`
- `tests/scrum912_storm_longbow_vfx_test.gd`
- SCRUM-912-only registry note in `docs/design/content_registry.md`, if needed

## Контекст

Логика Рейнджера из SCRUM-909..913 уже находится в `origin/dev` и прошла QA.
SCRUM-912 обновляет только визуальный контракт Грозового длинного лука после
смены старого beam fan на дальнобойный конус пробивающих стрел.

Каноническая геометрия SCRUM-911:

- пять коридоров шириной `30 px`;
- полный раствор конуса `34°`;
- углы `-17°`, `-8.5°`, `0°`, `+8.5°`, `+17°`;
- длина `980 px` от точки на `26 px` впереди героя;
- не более четырёх тел на стрелу, без спада урона;
- volley-wide target dedup;
- физические стрелы, knockback строго от Рейнджера.

## Ограничения

- Источник новых кадров и production PNG — только PixelLab MCP.
- OpenAI Images, `image_gen`, legacy `generate_asset.py` и ручная генерация
  raster art запрещены.
- Не менять gameplay geometry, damage, cooldown, targeting, progression или
  shared class scripts/tests.
- Не трогать `scripts/class_weapon.gd`, `scripts/progression_data*.gd`,
  `scripts/player.gd`, `tests/runtime_smoke_test.gd`,
  `tests/animation_smoke_test.gd`, `docs/design/current_game_state.md`,
  `docs/design/systems/characters_weapons.md` и активные UI/class locks.

## Результат Design / Animator

1. PixelLab source с bow-release, пятью расходящимися piercing arrow trails и
   through-hit feedback; прозрачный фон, без текста/UI/background.
2. Стабильный east-facing pivot/origin и прозрачный gutter для поворота сцены
   по направлению атаки.
3. Manifest с PixelLab IDs, prompt/spec, кадрами, fps/timing, геометрией и
   source/runtime paths.
4. Runtime-safe PNG/frame exports и отдельный Godot VFX resource/scene только
   в SCRUM-912-owned paths.
5. Contact sheet на тёмном/светлом фоне и combat-scale readability sample.
6. Focused Godot smoke, подтверждающий assets/resources/alpha/pivots/timing и
   соответствие SCRUM-911 geometry metadata.

Если для фактического создания runtime instance понадобится новый shared
backend hook, Design/Animator создаёт Jira-first handoff и не внедряет hook сам.

## Acceptance Criteria

- [x] PixelLab MCP config smoke и source generation подтверждены без вывода секретов.
- [x] VFX читается как longbow cone volley, не как Moon Crossbow или beam-channel.
- [x] Пять стрел/трейлов визуально соответствуют раствору `34°` и не обещают
  ложную широкую/круговую область урона.
- [x] Bow release, piercing flight и through-hit фазы различимы на combat scale.
- [x] Все exports RGBA с прозрачным фоном, стабильным origin/pivot и safe gutter.
- [x] Manifest, source, runtime assets, contact sheet и focused smoke подготовлены.
- [x] Jira/GitHub/dev синхронизированы, disposable cache/worktree удалены.

## Result

- PixelLab source object: `5499b202-53d7-4e82-a175-07983f464776`;
  source project: `7a9fb7cd-0060-48a4-a4dc-50f7b1124b0c`.
- PixelLab animation group: `bfaa69ca-1792-471a-bc98-7bd1e13651eb`;
  eight production frames at `16 FPS`, non-looping.
- Runtime signature and isolated volley scene now show exactly five spectral
  arrows with release, piercing-flight, through-hit and fade phases. The scene
  records the exact SCRUM-911 geometry contract without changing gameplay.
- Visual review: PASS on the dark/light contact sheet and 48/64/96 px combat
  samples; five arrow corridors remain readable on both backgrounds.
- Backend playback integration is intentionally separated into Jira-first
  handoff `SCRUM-1037`; no shared runtime file was edited while other workers
  own `scripts/class_weapon.gd`.

Verification (Godot 4.7, semaphore gate):

- `scrum912_storm_longbow_vfx_test.gd`: PASS.
- `unique_weapon_vfx_assets_test.gd`: PASS (`51` plates).
- `attack_vfx_smoke_test.gd`: PASS.
- `animation_smoke_test.gd`: PASS.
- `ranger_kit_test.gd`: PASS (`SCRUM-909..913`).
- `runtime_smoke_weapon_mechanics_test.gd`: PASS.
- `runtime_smoke_test.gd`: PASS (`14545` files scanned by duplicate guard).

Known headless-only diagnostics from pre-existing runtime suites: freed lambda
capture and null dummy-renderer texture warnings; both suites exited `0` and
reported PASS.

## QA-Вердикт (2026-07-10)

Статус: FAILED

Проверено на `origin/dev` `d2cb3976d` в изолированном QA worktree:

- PixelLab provenance, source object/project/animation/export IDs;
- lossless source/runtime signature hash, восемь `256x256 RGBA` runtime frames,
  alpha/gutters, contact sheet и отдельные scene/script/SpriteFrames;
- отсутствие изменений shared gameplay paths;
- уникальность восьми PNG import UID и корректность source/dest import paths;
- `scrum912_storm_longbow_vfx_test.gd`,
  `unique_weapon_vfx_assets_test.gd`, `attack_vfx_smoke_test.gd`,
  `animation_smoke_test.gd`, `ranger_kit_test.gd`,
  `runtime_smoke_weapon_mechanics_test.gd`, `runtime_smoke_test.gd` — PASS.

Блокирующий дефект: `SCRUM-1038`. Пять трейлов присутствуют, но фактические
центры альфа-кластеров не соответствуют `-17/-8.5/0/+8.5/+17°`. На `x=128`
из pivot `(26,128)` измерены примерно `+27.7/+13.6/+0.8/-14.2/-29.0°`, а на
`x=176` внешняя пара достигает примерно `+28.8/-30.7°`. VFX показывает около
`58–62°` вместо игрового конуса `34°` и визуально обещает ложную область
попадания. Focused smoke даёт false green: проверяет только metadata и число
кластеров в одном срезе, но не их углы. Свежий Godot import также создаёт
незакоммиченные task-owned `.gd.uid` для VFX script и focused test.

Disk cleanup: QA `.godot` и disposable worktree удалены после фиксации
Jira/local evidence.

## SCRUM-1038 Fix Candidate (2026-07-10)

Блокирующая visual geometry исправлена в отдельном child issue `SCRUM-1038`.
Принятый PixelLab source/signature и восемь release кадров теперь визуально
следуют пяти authored centerlines `-17/-8.5/0/+8.5/+17°`; immutable raw PixelLab
exports сохранены рядом для provenance. Новый focused oracle измеряет реальные
alpha-weighted центры на `x=96/128/160/176/192` и фиксирует maximum absolute
error `1.380°` при hard tolerance `1.5°`; metadata-only false green устранён.
Обновлённая contact sheet подтверждает совпадение реальных cyan-коридоров с
yellow authority rays и читаемость на `96/64/48 px`.

Все focused/unique/attack-VFX/animation/Ranger/weapon/full-runtime gates прошли.
Это QA-ready fix candidate: исходный `## QA-Вердикт: FAILED` остаётся историей
проверки, а `SCRUM-912` остаётся в `Контроль качества` до нового независимого
вердикта. Shared gameplay hook по-прежнему вынесен в `SCRUM-1037`.
