# BUG: HEAD не компилируется — экономика SCRUM-153 (drop_class_rewards) не закоммичена, а её потребители уже в HEAD

Статус: done
Приоритет: critical (broken HEAD / release blocker)
Роль: Back-end
Создано: 2026-06-13
Jira: SCRUM-171 (QA-агент, при попытке прогнать smoke на закоммиченном HEAD)

Dispatcher note 2026-06-12: not dispatched yet. Task is critical, but it has no
`Jira: SCRUM-*` key and the board row has no Jira link. Per dispatcher boundary,
PM/QA-owner must create/sync the existing Jira issue first; dispatcher must not
create Jira issues itself.

## Воспроизведение
1. `git worktree add /tmp/wt HEAD` (чистый чекаут e206bd7, без рабочего дерева).
2. Прогнать `runtime_smoke_test` headless.
3. `SCRIPT ERROR: Parse Error: Static function "drop_class_rewards()" not found in
   base "ProgressionData"` → smoke красный на ЛЮБОМ чистом клоне/CI/релизной сборке.

## Ожидание / Реальность
- Ожидание: задача SCRUM-153 (drop economy) в статусе done = код в git; HEAD компилируется.
- Реальность: HEAD `combat_director.gd` ВЫЗЫВАЕТ `drop_class_rewards` (:429, :642 —
  уехало в коммит боссов b7b450e/SCRUM-155), но в HEAD `progression_data.gd` НЕТ ни
  `drop_class_rewards`, ни `DROP_CLASS_MULTIPLIERS` (0 вхождений). Вся экономика
  SCRUM-153 живёт в НЕЗАКОММИЧЕННОМ рабочем дереве (+229 строк progression_data.gd).

## Влияние
- HEAD сломан: чистый чекаут не проходит runtime/attack_vfx smoke (Parse Error).
- Релизная сборка/CI с e206bd7 — красные.
- `progression_data.gd` прямо сейчас правится add-character-конвейером (SCRUM-169+):
  высокий риск, что экономика SCRUM-153 уедет смешанной в чужой коммит или потеряется
  при reset/stash.

## Предлагаемое направление фикса (для исполнителя)
1. НЕМЕДЛЕННО закоммитить drop-economy часть рабочего дерева (progression_data.gd
   + сопутствующее: enemy/ui если есть) отдельным коммитом «feat(SCRUM-153): …».
   Если в файле уже смешан add-character мид-эдит — согласовать с активным агентом
   и закоммитить совместно/частями (`git add -p`), но HEAD обязан компилироваться.
2. Прогнать все 6 smoke на ЧИСТОМ worktree HEAD (именно worktree, не рабочее дерево).
3. Процессно: правило «done = закоммичено, HEAD зелёный» — рассмотреть пост-коммит
   проверку smoke на HEAD в release-гейте (этот разрыв жил незамеченным, т.к. все
   гоняли smoke только на рабочем дереве).

## Окружение
HEAD e206bd7, Godot 4.6.3. Найдено QA через git worktree (рабочее дерево в этот
момент имело собственный несвязанный мид-эдит Parse Error от add-character).


## Result (PM, 2026-06-13)
HEAD восстановлен. Незакоммиченное рабочее дерево (215 файлов от нескольких
агентов) было зелёным по всем 6 smoke — сведено тремя коммитами:
- 66ea456: scripts/ + assets/ — экономика дропа SCRUM-153 (drop_class_rewards/
  DROP_CLASS_MULTIPLIERS) + данные/арт новых классов;
- 7199bcc: scenes/ оружия 8 классов + tests/ + tools/ (HEAD ссылался на
  незакоммиченные .tscn — вторая причина красного чистого чекаута);
- docs-коммит (этот).
Верификация: чистый `git worktree HEAD` + `--import` + все 6 smoke зелёные.
Процессный вывод: правило «done = закоммичено И чистый worktree HEAD зелёный»
— добавить пост-коммит smoke на worktree HEAD в релиз-гейт (см. release_versioning).
