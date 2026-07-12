# BUG: SCRUM-912 Storm Longbow VFX шире игрового конуса

Статус: done
Приоритет: p1
Роль: Design / Animator
Контур: Codex
Owner: Codex Design/Animator `/root/fix_scrum1038`
Thread: `/root/fix_scrum1038`
Версия: 0.2.1
Jira: SCRUM-1038
Источник QA: SCRUM-912

Locked paths при claim:

- `docs/design/references/weapon_attack_animations/storm_longbow_pixellab_scrum912/`
- `docs/design/previews/weapon_attack_animations/storm_longbow_pixellab_scrum912_contact.png`
- `assets/sprites/effects/vfx_weapon_storm_longbow.png`
- `assets/sprites/effects/storm_longbow/`
- `scenes/vfx/StormLongbowVolleyVfx.tscn`
- `scripts/vfx/storm_longbow_volley_vfx.gd`
- `scripts/vfx/storm_longbow_volley_vfx.gd.uid`
- `tests/scrum912_storm_longbow_vfx_test.gd`
- `tests/scrum912_storm_longbow_vfx_test.gd.uid`
- этот task mirror

Shared gameplay files, `scripts/class_weapon.gd`, progression/player scripts и
общие runtime smokes в scope не входят.

## Воспроизведение

1. Открыть `assets/sprites/effects/vfx_weapon_storm_longbow.png` или committed
   contact sheet SCRUM-912.
2. Взять authored pivot `(26,128)` и измерить центры пяти alpha clusters на
   нескольких срезах `x=96..192`.
3. Сравнить углы с gameplay authority
   `-17°/-8.5°/0°/+8.5°/+17°` из SCRUM-911.

## Ожидание / Реальность

Ожидание: пять визуальных коридоров следуют exact `34°` cone и не обещают
попадания вне gameplay geometry.

Реальность: на `x=128` центры дают примерно
`+27.7/+13.6/+0.8/-14.2/-29.0°`; на `x=176` внешние центры находятся около
`+28.8/-30.7°`. Полный визуальный fan составляет примерно `58–62°`. На
contact-sheet outer cyan arrows также заметно выходят за yellow `±17°` authority
lines.

## Причина false green

`tests/scrum912_storm_longbow_vfx_test.gd` сравнивает exact offsets только в
manifest/scene metadata и считает пять vertical alpha clusters лишь на `x=96`.
Положение cluster centers и их углы не проверяются.

## Требуемое исправление

1. PixelLab-first пересобрать source и все восемь runtime frames так, чтобы
   центры пяти визуальных стрел следовали `±17/±8.5/0°` с разумным допуском на
   толщину/электрические искры.
2. Пересобрать signature, manifest/static report/contact sheet и убедиться, что
   geometry overlay совпадает с реальными arrow centers.
3. Расширить focused test: multi-x проверка центров/углов, не только count.
4. Закоммитить созданные чистым Godot import task-owned `.gd.uid`; все UID
   должны оставаться уникальными. Восемь PNG import UID уже уникальны и их
   source/dest paths корректны.
5. Не внедрять shared gameplay hook в этой bug-задаче; SCRUM-1037 остаётся
   отдельным backend handoff.

## Окружение и QA evidence

- Base: `origin/dev` `d2cb3976d`, Godot `4.7`.
- Автоматические проверки: focused VFX, unique weapon VFX, attack VFX,
  animation, Ranger kit, weapon mechanics и full runtime — PASS, но не ловят
  визуальное расхождение углов.
- Fresh import генерирует untracked
  `scripts/vfx/storm_longbow_volley_vfx.gd.uid` и
  `tests/scrum912_storm_longbow_vfx_test.gd.uid`.
- Jira link: SCRUM-1038 blocks SCRUM-912; SCRUM-912 остаётся в
  `Контроль качества` до фикса и независимого retest.

## Результат SCRUM-1038

Исправление подготовлено как QA-ready fix candidate; независимый QA ещё
обязателен. PixelLab MCP config smoke повторно прошёл через `get_balance`, а
исходные PixelLab object/animation IDs сохранены. Immutable raw source и восемь
raw release exports сохранены в reference pack. Принятый source, signature и
все восемь reference/runtime кадров пересобраны детерминированным centerline
remap без нового hand-drawn raster content: нейтральный лук и pivot `(26,128)`
не менялись, ремапились только стрелы/электричество.

Image-derived oracle измеряет реальные alpha-weighted центры на пяти срезах:

| x | Реальные углы центров, ° |
| --- | --- |
| `96` | `-16.670 / -8.019 / -0.104 / +7.411 / +16.522` |
| `128` | `-17.603 / -8.625 / -0.457 / +8.744 / +17.358` |
| `160` | `-18.380 / -8.751 / +0.624 / +8.632 / +18.087` |
| `176` | `-17.526 / -9.008 / +0.191 / +8.717 / +17.708` |
| `192` | `-16.384 / -8.124 / -0.046 / +8.036 / +17.496` |

Максимальная target-specific ошибка `1.380°` при допуске `1.5°`. На
`x=96/128/160/176` дополнительно доказаны ровно пять раздельных alpha clusters,
поэтому один широкий клин не может дать false green через midpoint bands.
Старый raw source тем же измерением выходит примерно на `58–62°` и новый oracle
не проходит.

Проверки Godot 4.7 через `tools/godot_gate.py` — PASS:

- `scrum912_storm_longbow_vfx_test.gd`;
- `unique_weapon_vfx_assets_test.gd` (`51` plates);
- `attack_vfx_smoke_test.gd`;
- `animation_smoke_test.gd`;
- `ranger_kit_test.gd` (`SCRUM-909..913`);
- `runtime_smoke_weapon_mechanics_test.gd`;
- `runtime_smoke_test.gd`.

Полный runtime/weapon smoke сохранил известные non-fatal headless diagnostics
про freed lambda/null dummy-renderer texture, но оба завершились exit `0` и
явным `PASS`. Task-owned `.gd.uid` для VFX script и focused test добавлены и
уникальны; случайные UID sidecars от общего импорта удалены. Shared gameplay
hook и общие gameplay/runtime файлы не менялись. Parent `SCRUM-912` и bug
`SCRUM-1038` направляются в `Контроль качества`, не в `Готово`.

## QA-Вердикт (2026-07-10, независимый retest)

Статус: PASSED

Проверено на `origin/dev` `86a084c0d` в изолированном QA worktree. Независимый
alpha-derived замер accepted source и runtime signature вокруг pivot `(26,128)`
на `x=96/128/160/176/192` воспроизвёл максимальную target-specific ошибку
`1.380°` при hard tolerance `1.5°`; на representative flight slices сохранены
ровно пять раздельных коридоров. Accepted source и signature побайтно совпадают.
В runtime animation пять коридоров независимо измерены на нескольких срезах в
release/flight/through-hit фазах.

Негативный raw fixture доказал различающую способность oracle: тот же алгоритм
на `storm_longbow_pixellab_source_raw.png` получает ошибки примерно до `8.6°`
и пустой inner corridor на одном из срезов, поэтому прежний широкий fan не может
дать false green. Contact sheet визуально принят на dark/light и
`96/64/48 px`; у всех пяти lanes сохраняется ненулевая alpha mass. Neutral bow
остаётся привязан к исходной позиции, а scene переводит authored pivot в local
origin без неравномерного scale.

PixelLab object/project/animation/export IDs присутствуют; immutable raw source
и восемь raw exports сохранены. Восемь accepted/reference/runtime кадров —
`256x256 RGBA` с настоящей прозрачностью, каждый accepted кадр побайтно совпадает
с runtime. Восемь PNG import UID и task-owned `.gd.uid` глобально уникальны,
source/dest import paths корректны. Initial SCRUM-912 и SCRUM-1038 commits не
вносят gameplay hook или изменения в shared gameplay/runtime paths.

Godot 4.7 через `tools/godot_gate.py` — PASS:

- `scrum912_storm_longbow_vfx_test.gd`;
- `unique_weapon_vfx_assets_test.gd` (`51` plates);
- `attack_vfx_smoke_test.gd`;
- `animation_smoke_test.gd`;
- `ranger_kit_test.gd` (`SCRUM-909..913`);
- `runtime_smoke_weapon_mechanics_test.gd`;
- `runtime_smoke_test.gd` (`14581` files scanned after final latest-origin rebase).

Оба runtime suites достигли явных PASS markers; известные headless diagnostics
про freed lambda/null dummy texture остались non-fatal. Jira `SCRUM-1038` и
parent `SCRUM-912` переведены в `Готово`. `SCRUM-1037` остаётся отдельным
backend handoff для playback hook.

Disk cleanup: QA `.godot`, временные логи/UID sidecars и disposable worktree
удалены после push QA evidence; `git worktree prune` выполнен.
