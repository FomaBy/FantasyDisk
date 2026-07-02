# Skill Tree v2 — Верификация дерева умений (экономика, связность, экран, миграция) — QA

Статус: done
Роль: QA
Контур: Claude
Lane: claude
Owner: unassigned
Версия: 0.2.0
Создано: 2026-06-30
Автор: User request (PM)
Jira: SCRUM-699
Labels: foma, qa, claude
Связано: SCRUM-696 (data ✓done), SCRUM-698 (ui), SCRUM-697 (art ✓done)

> Unblocked 2026-06-30 (по запросу PM). Данные/арт (696/697) сданы. Финальный прогон
> запускать после влития UI SCRUM-698 в origin/dev — проверять live-статус 698 перед судом.

## Контекст

Финальная QA-верификация редизайна «Древо умений» (общее дерево умений PoE-стиля). Объединяет
проверку бэк-модели/экономики, UI-экрана и интеграции арта. **ЗАВИСИТ от** сдачи трёх тасков:
`codex_skill_tree_v2_data_model_economy` (данные/экономика), `skill_tree_v2_ui_redesign` (UI),
`design_skill_tree_v2_art_pack` (арт). Снять blocked, когда все три в origin/dev.

## Что проверяем

### Экономика метаочков
- [ ] Формула начисления за первое закрытие возвышения: 0→1, 1→1, 2→2, 3→3, 4→4, 5→5; макс 16 с класса.
- [ ] Жёсткий cap суммарного заработка = 100 метаочков; сверх — не начисляется.
- [ ] Нельзя фармить один уровень возвышения (повторное закрытие не даёт метаочков).
- [ ] Глобальный уровень = числу выделенных узлов; доступные метаочки = заработано − потрачено.

### Дерево и связность
- [ ] Общее дерево (единый `skill_nodes`), узлы с координатами и рёбрами.
- [ ] Точки входа классов: у каждого класса свой стартовый узел (разные места); все id валидны.
- [ ] Выделение растёт от входа открытого класса по связности (`adj`); locked-узлы недоступны.
- [ ] Бюджет полного дерева ≈ 100 (cap = эндгейм); 3–6 keystone, есть notable/minor.
- [ ] `skill_modifiers()` — боевые эффекты выделенных узлов применяются в бою без регрессий.

### Миграция сейва
- [ ] Старый `user://fantasydisk_meta.cfg` грузится без краша; метаочки пересчитаны из `ascension_levels`;
      старые `skill_nodes` безопасно сброшены/перенесены; идемпотентно.

### Экран (UI + арт)
- [ ] Экран открывается без ошибок (headless smoke).
- [ ] Граф рисуется (узлы + коннекторы), пан/зум работают, состояния узлов различимы.
- [ ] Клик по доступному узлу выделяет (трата метаочка), счётчики/сейв обновляются; reset работает.
- [ ] Селектор класса центрирует/подсвечивает разные точки входа.
- [ ] Арт-ассеты привязаны (с `.import`), контент в безопасной зоне, единый стиль.
- [ ] Generated UI assets are not stretched/squeezed: verify native `2560x1440` and `1920x1080` sizes where provided, or a native 2K source downscaled only proportionally to 1080p. Check source/display aspect ratios, 9-slice margins, frame ornaments, node frames, connectors, buttons and badges.
- [ ] Общие UI-гейты зелёные: `ui_no_overlap_matrix_test`, `runtime_smoke_test` на 1152…3840.

## Прогон

- Godot 4.6.3 (`~/Downloads/Godot.app`), headless, см. [[qa-test-runner]] и сериализатор
  `tools/godot_gate.py`. Тяжёлые/параллельные прогоны — по одному (см. godot single-instance заметки).
- Тесты: `tests/meta_skill_tree_smoke_test.gd`, `tests/runtime_smoke_test.gd`,
  `tests/ui_no_overlap_matrix_test.gd` (+ любые новые из бэк/UI тасков).
- Проверять HEAD в изолированном worktree от origin/dev (свежий — с `--import`), 2–3 прогона;
  убедиться что все три таска реально влиты в origin/dev (не на feature-ветке).
- По вердикту: дописать `## QA-Вердикт / Статус: PASSED|FAILED` в .md КАЖДОГО проверяемого таска
  (иначе board_sync реверт-ит, см. [[board-sync-md-qa-block-revert]]) и прогнать `jira_board_sync.py`.

## Files

- `tests/meta_skill_tree_smoke_test.gd`, `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd`
- `build/qa/<id>/` — артефакты/скриншоты верификации.

## QA-Вердикт

Статус: PASSED

Проверено на `dev == origin/dev` (HEAD `945823ff`), все три деливерабла влиты в origin/dev:
- SCRUM-696 (данные/экономика/миграция) — feat влит, компонентный QA PASS (`021ad6b1`).
- SCRUM-697 (арт-пак) — ассеты влиты, QA PASS (`6a9fe5fb`).
- SCRUM-698 (UI-экран, граф PoE) — `dd3bdaa8`, компонентный QA PASS (`d1b89d80`).

Интеграционный прогон (Godot 4.7 headless, сериализатор `tools/godot_gate.py` со
fdengine-семафором `FSD_GODOT_SLOTS=1`, под нагрузкой живого флота) — все зелёные:
- `tests/meta_skill_tree_smoke_test.gd` — «Meta skill tree smoke test passed.»
  (формула начисления 0→1/1→1/2→2/3→3/4→4/5→5, cap 100, связность выделения, точки входа
  классов, миграция старого сейва, бюджет дерева).
- `tests/runtime_smoke_test.gd` — «Runtime smoke test passed.» (+ duplicate-artifact guard,
  11252 файла; экран открывается, frame-paths валидны).
- `tests/ui_no_overlap_matrix_test.gd` — «UI no-overlap matrix test passed.» (нет перекрытий,
  безопасная зона фрейма на всех разрешениях).

Дефектов не найдено. Фича «Древо умений v2» (общее PoE-дерево, метаочки за возвышения,
точки входа классов, глобальный уровень) принята целиком. Disk cleanup: ничего не создано;
чужой untracked WIP/flot-worktree не трогались (blanket pkill не применялся).
