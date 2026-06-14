# Аудит: мёртвый код, дублирование, ошибки/ворнинги (SCRUM-267, Quality Pass v2)

Дата: 2026-06-14. Роль: Back-end (Claude). READ-ONLY (Фаза 1) — только находки +
порождённые execution-задачи; ничего не удаляется/рефакторится в этой задаче.

Окружение: Godot 4.6.3 headless, ветка `dev` HEAD `061f1457`. Runtime smoke +
animation smoke + global balance-гейты — зелёные на момент аудита.

## Сводка приоритетов

| P | Находка | Объём | Действие |
| --- | --- | --- | --- |
| **P1** | Дубли-артефакты `«… N.ext»` (случайная копия дерева) | **275 файлов** | Удалить (file-изолированно) |
| P2 | GDScript-ворнинги | не извлекаемы headless | Прогон в редакторе / включить вывод |
| P3 | Глубокий мёртвый код (unused funcs/consts) | требует ручного прохода | Отдельная задача после балансового патча |

---

## P1 — Дубликаты-артефакты `« N.ext»` (275 файлов) — КРИТИЧНО

Случайная операция копирования (Finder «копия 2» / `cp`) продублировала большую
часть дерева с суффиксом ` 2` (и редкими ` N`). Дубли **никем не ссылаются**
(реальные файлы ссылаются по базовому имени; ` 2`-версии — мёртвые копии),
раздувают репозиторий и дают ложные срабатывания asset-аудита.

Разбивка по расширениям: `import` 70, `png` 64, `uid` 46, `gd` 46, `tscn` 27,
`md` 13, `py` 5, `sh` 2, `json` 2.

Разбивка по областям: `docs/` 125, `tests/` 56, `scripts/` 28, `scenes/` 27,
`assets/` 24, `tools/` 15.

Примеры code-дублей (полный список — `git ls-files | grep -E ' [0-9]\.(gd|py)$'`):
- ВСЕ доменные файлы: `scripts/progression_data_{characters,weapons,content,shop,ascension,enemies,balance} 2.gd`, `scripts/ui/{hero_select_constants,hero_stat_radar,shop_ui_constants,ui_theme_paths} 2.gd`, `scripts/{combat_target_query,glossary,patch_notes_data} 2.gd`.
- ВСЕ мои smoke/integrity тесты: `tests/*_test 2.gd` (audio/codex/event/stat_formulas/rewards/projectile/… — ~24 шт).
- Инструменты: `tools/{live_combat_harness,survivability_harness,survivability_scenarios,route_economy_xp_model} 2.gd`, `tools/*_2.py`.

**Безопасность удаления**: все ` N.` файлы проверены как НЕссылаемые
(`combat_target_query 2.gd` и т.п. отсутствуют в preload/load/class_name/tscn).
`.import`/`.uid` ` N.` — сайдкары несуществующих/дублированных источников.

**Execution-задача порождена**: `cleanup_remove_duplicate_artifact_files_task`
(file-изолированно, статус `new` — НЕ блокируется балансовым патчем, т.к.
удаляются только ` N.`-копии, реальные файлы балансовый патч правит отдельно).
Рекомендация: `git rm` всех `git ls-files | grep -E ' [0-9]\.[a-z]+$'` после
быстрой выборочной проверки + runtime/animation smoke.

---

## P2 — GDScript-ворнинги

Извлечь полный список headless НЕ удалось: в `--headless --script` режиме
ворнинги парсера подавляются, а `--editor --quit-after` не эмитит их в stderr
в этой сборке. Все 6 smoke + import проходят без `ERROR`/`Parse Error` —
парс-ошибок и сломанных скриптов НЕТ.

Рекомендация (execution): однократный прогон в GUI-редакторе (или включить
`debug/gdscript/warnings/` → stderr) и собрать unused var/param, shadowing,
narrowing/inferred-type, unreachable. До этого — «парс чистый, runtime-ворнингов
в smoke-прогоне не зафиксировано».

---

## P3 — Мёртвый код (глубокий)

Очевидного мёртвого кода вне ` N.`-дублей в беглом проходе не выявлено
(после Quality Pass v1 и доменных сплитов фасад/реэкспорты используются).
Глубокий проход (неиспользуемые static-функции/константы/сигналы по всему
графу вызовов) — отдельная execution-задача ПОСЛЕ балансового патча 0.1.5
(общие файлы `progression_data*/player/class_weapon/stat_formulas/ui_screens`
сейчас в активной правке — `blocked`).

## P-perf — смеллы (отметить, не чинить)

Горячие пути target-lookup уже вынесены в `CombatTargetQuery` (SCRUM-197) с
per-frame кэшем — критичных новых перф-смеллов в этом проходе не отмечено.

## Acceptance

- [x] Подтверждение по ворнингам/ошибкам: парс чистый, ERROR/Parse нет; полный
      ворнинг-лист требует GUI-редактора (P2).
- [x] Дубли перечислены по приоритету с точными ссылками (P1, 275 файлов).
- [x] Порождена execution-задача (P1 file-изолированная `new`; P2/P3 — после патча).
