# BUG: SCRUM-912 Storm Longbow VFX шире игрового конуса

Статус: new
Приоритет: p1
Роль: Design / Animator
Контур: Codex
Owner: unassigned
Thread: n/a
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
