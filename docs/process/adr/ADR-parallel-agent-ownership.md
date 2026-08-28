# ADR: домены владения для параллельной работы 3–4 агентов

Статус: accepted (FAN-3638, мандат владельца 27.08.2026 — исполнитель Fable).
Дата: 2026-08-28. База диагностики: dev@fef0e5e5c (ранняя выборка dev@948b4459).

## Контекст

3–4 агента не могут работать над игрой параллельно: почти каждая игровая
задача пишет в одни и те же центральные файлы, поэтому planned_write_set /
locked_paths пересекаются, а rebase ловит конфликты. Карта конфликтов
(касания за последние 300 коммитов dev × типы задач, которые файл правят):

| Файл | Касаний | Кто конфликтует |
| --- | --- | --- |
| `scripts/full_frame_animation_registry.gd` | 22 | каждая ACTOR ANIMATION / ART / polish-batch задача |
| `build/ultimate_effectiveness_baseline.json` | 19 | каждая ULTIMATE BALANCE / VFX RETROFIT задача (17 классов) |
| `tests/animation_smoke_test.gd` (1 998 строк) | 18 | каждая актёрная задача |
| `docs/design/systems/animation.md` | 17 | каждая актёрная/арт задача |
| `CHANGELOG.md` | 17 | все задачи |
| `scripts/ultimates/presentation/*` (schema, contract) | 10–12 | презентационные задачи ультимейтов |
| `docs/design/content_registry.md` (1 805 строк) | 11 | все контентные задачи |
| `scripts/ui_screens.gd` (16 993 строки) | — | все UI-задачи |
| `scripts/class_weapon.gd` (5 996 строк) | — | оружейные задачи 17 классов |
| `scripts/player.gd` (4 295), `scripts/enemy.gd` (1 950) | — | per-class ветвления внутри общих ядер |
| `tests/runtime_smoke_test.gd` (9 997 строк) | — | общий тестовый монолит |

Открытый бэклог подтверждает форму нагрузки: пер-актёрные ACTOR ANIMATION /
polish-batch (FAN-2593…2607, 3324…3327), пер-классовые VFX RETROFIT
(FAN-3310…3323) и ULTIMATE BALANCE (FAN-2529…2537), UI, релизные и CI-карты.
Параллельные задачи почти всегда различаются актёром/классом/экраном — а
пишут в общие файлы.

## Решение

Data-driven декомпозиция по владению: центральные реестры распадаются на
авто-обнаруживаемые фрагменты «файл-на-единицу», монолиты режутся по швам
владения, границы закрепляются картой (`docs/process/ownership_map.md`) и
гардом в `tools/quality_static_guard.py`. Поведение игры не меняется —
существующие ратчеты и контракт-тесты остаются байт-в-байт эквивалентными
по семантике.

Домены владения (полные глобы и эталонные planned_write_set — в
`ownership_map.md`):

- `actor/<actor_id>` — анимационные данные, ассеты и smoke-тест одного актёра;
- `class/<class_id>` — оружие, ультимейты, баланс и VFX одного из 17 классов
  (balance/<class> и vfx/<class> — под-срезы того же домена: у них общие файлы
  класса, поэтому отдельными доменами не являются);
- `ui/<screen>` — скрипт, сцены и тесты одного экрана;
- `core` — общие ядра (player, enemy, реестры-фасады, гейты) — по-прежнему
  один агент за раз;
- `process/docs` — процессные документы.

Целевые структуры по горячим точкам:

1. **Реестр анимаций**: `FULL_FRAME_SPRITEFRAMES` (37 актёров, чистые данные)
   переезжает в `data/animation/<kind>/<actor_id>.json`; фасад
   `full_frame_animation_registry.gd` сканирует каталог (паттерн
   `scripts/ultimates/registry/weapon_ultimate_package_discovery.gd`, уже
   проверенный в экспорте) и собирает прежнюю таблицу; весь публичный API
   (`registry_config`, `sprite_frames_for`, `configure_entity_visual`,
   `play_state`, …) и обращения тестов к `FULL_FRAME_SPRITEFRAMES` сохраняются.
   Vector2 сериализуется как `{"x":…,"y":…}` и восстанавливается загрузчиком.
2. **Baseline эффективности**: `build/ultimate_effectiveness_baseline.json`
   (51 строка = 17×3) шардируется в `build/effectiveness/<class_id>.json`
   (+ `_envelope.json` c schema_version/scenario_ids/metric_keys/tolerances);
   writer `tools/ultimate_effectiveness_report.gd` пишет шарды, читатели
   (`tests/ultimates/effectiveness_runner_test.gd`,
   `tools/check_druid_baseline_isolation.py`) собирают конверт из шардов.
   Изоляция «чужой класс не дрейфует» становится структурной: задача класса X
   трогает только свой шард.
3. **CHANGELOG**: задачи пишут фрагменты `changelog.d/<FAN-id>.md`; сборка в
   `## [Unreleased]`/`## [<version>]` происходит на релизном шаге
   (`tools/build_release.sh` + release-director), где уже живёт единственный
   парсер (`tools/release_notes_visual_claims_guard.py`).
4. **content_registry.md**: режется на `docs/design/content/<domain>.md`
   по существующим `##`-секциям + автогенерируемый индекс;
   `tests/fan1891_attack_area_contract_test.gd` перенацеливается на новый
   файл секции.
5. **Тестовые монолиты**: `animation_smoke_test.gd` и `runtime_smoke_test.gd`
   становятся тонкими раннерами; пер-актёрные проверки уезжают в
   `tests/actors/<actor_id>_smoke_test.gd` — дискавери
   `tools/quality_gate.py` уже рекурсивное (`TEST_DIR.rglob`), новая актёрная
   задача добавляет СВОЙ файл. Имена файлов-стемов уникальны
   (`_index_by_name` падает на дублях).
6. **Код-монолиты**: `ui_screens.gd` → скрипт-на-экран в
   `scripts/ui/screens/`; `class_weapon.gd` → базовый класс +
   `scripts/classes/<class_id>_weapon.gd`; из `player.gd`/`enemy.gd` выносятся
   только per-class ветвления; ядро не переписывается. Паттерн раскладки —
   уже принятый в репо re-export/фасад (`progression_data.gd` →
   `progression_data_*.gd`).

## Инварианты

- Прежние публичные API фасадов сохраняются; потребители не меняются, кроме
  явно перечисленных перенацеливаний тестов.
- Ратчеты только ужесточаются: `LEGACY_LINE_CEILINGS` монотонно сокращается,
  новые файлы живут под `NEW_SCRIPT_LINE_LIMIT` (1200).
- Каждая резка — отдельный пуш-кандидат с зелёным quality gate
  (`--profile changed --changed-ref origin/dev`, CI-эквивалент) и обычным
  конвейером QA→DevOps.
- Никакого изменения геймплея/баланса: контракт- и ратчет-тесты остаются
  зелёными без ослабления допусков.
- `.gd` всегда коммитится с парным `.gd.uid`.

## План миграции

- Фаза 0 (этот документ + `ownership_map.md`) — карта владения, PM может
  выдавать непересекающиеся planned_write_set уже по текущим глобам.
- Фаза 1 — реестры/данные: п.1–4 выше (главный выигрыш).
- Фаза 2 — тестовые монолиты: п.5.
- Фаза 3 — код-монолиты: п.6, по швам, отдельными кандидатами.
- Фаза 4 — гард доменов в `tools/quality_static_guard.py` (кросс-доменный
  дифф без пометки cross-domain падает; бюджет «общих» файлов ≤1 на PR)
  + пилот из 4 параллельных задач с метрикой: 0 пересечений write-set,
  0 конфликтов rebase.

## Последствия

- Плюс: 3–4 агента пишут в разные файлы; конфликты типа FAN-2665 (чужой
  класс дрейфует при пере-генерации baseline) исключаются структурно.
- Минус: больше мелких файлов (37 JSON актёров, 17 шардов baseline,
  фрагменты changelog); компенсируется автосканом и индексами.
- Риск: DirAccess-скан `res://` в экспортированной сборке — паттерн уже
  доказан `weapon_ultimate_package_discovery.gd`; smoke-тест реестра остаётся
  гарантией полноты (guard «registry suspiciously small» сохраняется).
