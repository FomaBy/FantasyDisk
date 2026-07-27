# Провенанс git-tracked эталона баланса

Дата расследования: 2026-07-27. Карточка: FAN-1778.

## Вывод и рекомендация

**Гипотеза о том, что текущий эталон создан merged-live-веткой
`tools/run_balance_validation.sh`, опровергнута.** На момент последнего изменения
обоих эталонных файлов этой обёртки ещё не существовало. Текущий CSV — намеренно
собранный live-эталон: основа является средним четырёх live-прогонов v9, а шесть
строк Soldier/Priest затем заменены средними точечных двойных live-прогонов.
Текущий band — более старый полный live-снимок v3 и не соответствует ни
финальному CSV v9, ни более поздней перекалибровке comfort-весов.

Рекомендация PM: **(а) оставить git-tracked эталон без изменений и не
пересобирать его в `--mode=fast`.** Fast-режим — другой, формульный инструмент:
он заменил бы live-данные детерминированными бюджетными оценками, изменил все 51
строку CSV и 39 вердиктов «в полосе / вне полосы» по трём срезам. Если PM нужен
актуальный нормативный band, это отдельное балансно-видимое решение: следует
сначала определить live/multi-run протокол его пересборки вместе с CSV v9 или
новее. Текущая карточка такую пересборку не выполняет.

## Свежий `--mode=fast` на актуальном tip

Измерение выполнено на чистом `origin/dev`:
`e3f5e7c9fe733046afa4afa91fc15e3134e6656b`.

Команда:

```text
FSD_GODOT_EXCLUSIVE=1 FSD_GODOT_RUN_TIMEOUT=1200 \
python3 tools/godot_gate.py --headless --path . \
  --script res://tools/character_balance_csv.gd -- --mode=fast
```

Прогон выполнен один раз в detached временном worktree. Перед запуском
`pgrep` не обнаружил процессов Godot; после завершения процессов Godot также не
было. `tools/godot_gate.py` держал machine-wide exclusive lease
(`FSD_GODOT_EXCLUSIVE=1`) на протяжении import и измерения, поэтому параллельный
gated Godot-прогон был невозможен. Использован Godot
`4.7.stable.official.5b4e0cb0f`; exit code — `0`.

| Артефакт | git-tracked SHA-256 | свежий fast SHA-256 | Diff |
| --- | --- | --- | --- |
| `build/character_balance_dps.csv` | `0c9fe45267330d8a79d47a9eae2402869137c1169755f89953d006c3412e2735` | `29a9387df01b074272f1e27bd47da8d1a876f9e3e43b9417bb2d8b8311d1d37c` | 51 вставка / 51 удаление; изменены все 51 строки данных |
| `build/character_balance_band.md` | `21aca90910404a7ea9d52f28bd6bf8f9f5febab4d4d4db36117940fe80541f75` | `a300985a6289f9db01e3b4abbe94205a3fb51dcc34a1c3bc1b4aa7e59245fad4` | 128 вставок / 125 удалений |

Это **в точности та же картина**, что на `e4bbc13139ed871e68a44665b561de27c359cb39`
в FAN-1732: совпали обе пары SHA-256 и обе сводки diff. Изменения `dev` между
`e4bbc131` и `e3f5e7c9` на fast-вывод не повлияли.

## История обоих файлов

История проверена через `git log --follow`, `git blame`, `git show` и
`git rev-parse <commit>:<path>`.

| Путь | Последний изменивший commit | Автор и дата | Сообщение | Ревизия генератора в том commit | Обёртка в том commit |
| --- | --- | --- | --- | --- | --- |
| `build/character_balance_dps.csv` | `f4fbd121a1ec4eebf5a4e3524ba5331bc5cdf528` | Sergey Fomin, `2026-07-14T03:51:30+03:00` | `docs(FAN-1031): ФИНАЛЬНАЯ приёмка Stage 3 — коридор достигнут в пределах точности замера` | последний commit генератора `8dd7e4fb4efbef86230083522046ff83e84e4454`; blob `83c230c5b95a307a1c8e78d042d26b7780ab1d34` | отсутствует |
| `build/character_balance_band.md` | `346c0d211951b5d6e3a442409e3a88db9f80b2c7` | Sergey Fomin, `2026-07-13T02:15:25+03:00` | `docs(FAN-1031): CSV v3 — калибровочная база после пакета 3a` | последний commit генератора `411f1f1ff814c3198c2d1381996b593403f3aa0e`; blob `deac17a957e3dc449259bf7ef37471c7045dd877` | отсутствует |

`git blame` уточняет состав текущего CSV: заголовок происходит из
`cdb2909a72e0b21de50c7f9b8692f3c4bb243c45`, 45 строк — из
`ffd635897a0a0df012d8320c999ba5a4c8ba5913`, а шесть строк Soldier/Priest — из
`f4fbd121a1ec4eebf5a4e3524ba5331bc5cdf528`. Сообщение `ffd635897...` прямо
называет источник «приёмка v9 (4-прогонное среднее)»; diff `f4fbd121...`
заменяет по три строки Soldier и Priest, а сообщение называет их «точечные
двойные прогоны».

Commit `ffd635897...` также сохраняет четыре полных исходных снимка
`character_balance_dps_v9a..v9d.csv`. Read-only проверка всех 459 числовых ячеек
показала, что основной CSV этого commit равен их арифметическому среднему с
точностью округления до двух знаков (максимальная дельта `0.005`).

Band последний раз массово обновлялся commit `346c0d211...`; его сообщение прямо
говорит «Живой пересъём на ветке 3a (51 пара, изолированный worktree)».
Последующие v6/v7/v8/v9/final commits меняли CSV, но не band. Поэтому
git-tracked band — исторический live-v3 снимок, а не производная текущего
git-tracked CSV.

## Проверка merged-live-гипотезы

Для обоих baseline commits и их непосредственных родителей
`tools/run_balance_validation.sh` отсутствует:

- CSV commit `f4fbd121...`, parent
  `a1f977e2f903cddc68a6cea61b86444d45456c0a`;
- band commit `346c0d211...`, parent
  `0bc12b89c12fcab0327a8abaeade26e0031e6fab`.

Сама обёртка появилась позже, в
`b527fadbf37881897f1d80e6092295281db8647a` от
`2026-07-14T05:32:09+03:00`. Merge live-чанков появился ещё позже, в
`f573628c279e4e1c5d42bb64083512e19f448af4` от
`2026-07-14T06:57:35+03:00`
(`fix(FAN-1062): live-CSV в контракте — чанки по классам...`). Оба события
произошли после финального CSV в `03:51:30+03:00`; per-pair вариант был добавлен
в `b27330f7a97fe41b7b0b9a805694db5db1181d68` в `07:52:25+03:00`.

Дополнительные факты:

- `build/character_balance_dps_README.md` никогда не был git-tracked:
  `.gitignore` игнорирует `build/`. Генератор пишет в README строку `Mode`, но
  ни CSV, ни band маркера режима не содержат.
- В baseline trees нет `csv_chunk_*`; эти файлы также находятся под игнорируемым
  `build/`.
- Сообщения baseline commits и v9-истории прямо фиксируют live-пересъём и
  multi-run averaging.
- `build/ascension_viability_report.md` в обоих provenance revisions прямо
  называет входом CSV команду `tools/character_balance_csv.gd --mode=live`.

В истории есть старый runner `1190db1d1de10ab90e21d2cdea32be908efbeada`
от `2026-07-12T23:48:31+03:00`, но он находится на расходящейся ветке и не
является предком baseline commits. Кроме того, он запускает один полный
`--mode=live`, без чанков и merge.

Итог: **merged-live-путь обёртки опровергнут**, но более широкая гипотеза
«эталон имеет live-происхождение» подтверждена.

## Альтернативные объяснения расхождения

### Изменения формул и данных после baseline

Они действительно есть и влияют на современный fast-результат, поэтому эту
составляющую исключать нельзя:

- `ac55ea0cba6b782b05ae5c9303f10adf9b2d5661` меняет fast-зеркало и конфиг
  орбитального дрона Engineer (`max_summons`, радиус орбиты);
- `57927177036a1c64697ddf3b3410626ed00fc718` меняет
  `summon_wave_radius` гомункула Chemist; это поле читает fast-модель
  `wave_targets`;
- `78447cdca051127869340dedb626df038a4508ca` меняет
  `drone_contact_radius`; это поле читает fast-модель `ring_coverage`;
- `fa4663d8ff19d1fb3432a62ac6dfa48a161e3601` перекалибровывает
  `CLASS_LEVEL_STAT_GROWTH_SCALARS`, которые участвуют в ideal/random
  `derived_parameters`.

После CSV anchor нет изменений `scripts/stat_formulas.gd`. Прочие найденные
изменения на пути зависимостей являются механическим extraction, описаниями,
facade-рефакторингом или комментариями и не меняют fast-математику.

Эти commits могут затронуть не более 28 из 51 fast-пар: все оружия девяти
классов из новой таблицы growth плюс `engineer_repair_drone`. На lvl1 меняться
могут только `chemist/homunculus_vial` и
`engineer/engineer_repair_drone`. Следовательно, они вносят вклад, но не могут
быть единственной причиной расхождения всех 51 строк. Даже на одной ревизии
live измеряет реальный Player/scenes, а fast вызывает бюджетные оценки
`ProgressionData`.

Между более старым band anchor `346c0d211...` и финальным CSV anchor формульные
данные дополнительно меняли commits `53c14f545ea8792273df78bd090ee7fd424e6a9f`,
`8116e122f5593be898d115d7da235080668e81bd`,
`375aa03d0f10cb970e9dda690c372040bb86a10b`,
`51b079c37fc931136a78610b8f7db7b36510c8cd`,
`a906caaebff2adf7ae025d71e50fd2eb76d63985`,
`693db2610256682653a1ab33ac296d52a792d7c7`,
`09eb076134219f20bf1d6e4c6430346f3150e2d9` и
`a1f977e2f903cddc68a6cea61b86444d45456c0a`. Это ещё одно доказательство, что
старый band нельзя трактовать как актуальный fast-результат.

### Изменение самого `--mode=fast`

Исключено. Fast-ветка появилась до обоих baseline anchors, в
`a3680cda6bc80c49b822ad72c23aaf57b929505f`. После старого band anchor
генератор меняли `8dd7e4fb4efbef86230083522046ff83e84e4454` и
`a791df07fbbcdacb24ca70de76fb9418dc16c625`; после CSV anchor — только второй
из них. Оба commit меняют исключительно live-функцию `_measure_dps`
(временную базу и фиксированное восьмисекундное игровое окно).
`_generate_fast_rows`, `_add_fast_metrics` и fast build selection не менялись.

### Смена порога или нормировки полосы

Литеральный допуск не менялся: `COMFORT_BAND_TOLERANCE = 0.20` введён в
`1ce43fa439fe3955d7cf83ac8a0373d022a5f360` и остаётся тем же.

Зато сразу после финального CSV, в
`90352a6c288c6dba7e5aced56629d05d31da6973` от
`2026-07-14T03:55:26+03:00`, были полностью перекалиброваны
`COMFORT_BAND_SLICE_WEIGHTS` и overrides по CSV v9. Этот commit не пересобрал
git-tracked band. Поэтому различие band объясняется сразу тремя факторами:
исторический band v3, финальный live CSV v9 и новая нормировка; это не смена
±20%-порога. `_validate_band()` и `_median()` между band anchor и HEAD также не
менялись.

## Балансная цена fast-пересборки

| Срез | Текущий tracked median / band | Свежий fast median / band | Нарушения tracked → fast | Пар со сменой вердикта |
| --- | --- | --- | --- | ---: |
| `ideal_1` | `318.2`, `[254.6 .. 381.9]` | `209.8`, `[167.8 .. 251.7]` | `38/51 → 37/51` | 15 |
| `ideal_5` | `1100.1`, `[880.1 .. 1320.1]` | `578.9`, `[463.1 .. 694.7]` | `37/51 → 36/51` | 11 |
| `ideal_20` | `5006.1`, `[4004.9 .. 6007.4]` | `646.0`, `[516.8 .. 775.2]` | `41/51 → 46/51` | 13 |

### `ideal_1`

- В полосе → вне полосы: `berserk/sword`, `chemist/homunculus_vial`,
  `dark_mage/cursed_skull`, `elementalist/elementalist_orb_ring`,
  `ranger/moon_crossbow`, `robot/robot_hydraulic_press`,
  `sniper/sniper_deadeye_rifle`.
- Вне полосы → в полосе: `assassin/chakrams`, `berserk/axe`,
  `biologist/biologist_sample_injector`, `biologist/biologist_spore_lens`,
  `chemist/blast_powder`, `doctor/bone_saw`, `priest/priest_reliquary`,
  `sniper/sniper_shatter_rounds`.

### `ideal_5`

- В полосе → вне полосы: `assassin/shadow_daggers`,
  `chemist/homunculus_vial`, `priest/priest_chime`,
  `sniper/sniper_deadeye_rifle`, `thief/thief_coin_pouch`.
- Вне полосы → в полосе: `berserk/axe`, `chemist/blast_powder`,
  `druid/raven_totem`, `engineer/engineer_sentry_wrench`,
  `robot/robot_reactor_core`, `thief/thief_smoke_bomb`.

### `ideal_20`

- В полосе → вне полосы: `chemist/homunculus_vial`,
  `dark_mage/dark_wand`, `druid/briar_staff`, `priest/priest_chime`,
  `robot/robot_hydraulic_press`, `robot/robot_magnetic_anchor`,
  `robot/robot_reactor_core`, `soldier/soldier_bayonet`,
  `soldier/soldier_rifle`.
- Вне полосы → в полосе: `assassin/venom_wire`, `doctor/bone_saw`,
  `guitarist/sound_amp`, `sniper/sniper_spotter_scope`.

## Ограничения безопасности

- Ветка `FSD_FULL_CSV=1` **не запускалась**.
- Рабочие `build/character_balance_dps.csv` и
  `build/character_balance_band.md` не использовались как место вывода; fast
  писал только во временном detached worktree.
- Их контрольные SHA-256 до и после расследования совпадают со значениями в
  таблице выше.
