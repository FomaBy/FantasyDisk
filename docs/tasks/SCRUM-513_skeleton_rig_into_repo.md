# SCRUM-513: Tech-debt: вынести скелетный риг из незакоммиченного рабочего дерева в репозиторий

Jira: SCRUM-513 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: —
Статус: К выполнению

## Что и зачем

Скелетный риг персонажей (dark_mage, knight) — это **активно используемый в рантайме** код+ассеты: `player.gd` при выборе персонажа инстанцирует `.tscn`-сцену рига, та грузит `skeleton_player_rig_2d.gd` и манифест из `assets/...`. На момент заведения тикета весь этот стек жил в **незакоммиченном рабочем дереве** (untracked). Это технический долг и риск:

- Чужой коммит воркера с `git add -A` мог втянуть эти файлы вперемешку со своими изменениями или, наоборот, частично — и потерять источник истины.
- Источник геометрии костей (рестовые позы, `det==0`-точки) жил в неотслеживаемом файле — при сбросе/чистке рабочего дерева риг бы безвозвратно сломался.
- Параллельные worktree-агенты (`.claude/worktrees/`) могли наплодить осиротевшие дубли.

Цель с точки зрения продукта: гарантировать, что играбельный скелетный риг (dark_mage и knight используют его как основной визуал вместо спрайт-листа) воспроизводимо собирается из git на любой машине/в любом worktree, без зависимости от локального незакоммиченного состояния. Ожидаемый результат: весь рантайм-стек рига отслеживается git осмысленным коммитом, smoke-тесты зелёные, дублей-артефактов нет.

> ВАЖНО — состояние на момент написания спеки (2026-06-27): фактически **бо́льшая часть стека уже закоммичена** (см. ниже). Поэтому задача из «закоммитить» превращается в **«дозакрыть и верифицировать»**: убедиться, что в репозитории присутствует ПОЛНЫЙ рантайм-стек рига, ничего не осталось untracked, дубли-гард зелёный, smoke-гейт зелёный. Если найдутся остаточные untracked-куски — добрать их явным `git add`. Если всё уже в git — прогнать гейты и закрыть тикет как verified.

## Текущее состояние в коде

### Рантайм-цепочка загрузки рига
- `scripts/player.gd:17-18` — `const DARK_MAGE_SKELETON_RIG_SCENE := preload("res://scenes/characters/DarkMageSkeletonRig.tscn")` и `KNIGHT_SKELETON_RIG_SCENE := preload(".../KnightSkeletonRig.tscn")`. **preload** — значит сцены обязаны быть в репозитории, иначе проект не откроется.
- `scripts/player.gd:1784-1792` `_character_skeleton_rig_scene(class_id)` — `match` по `dark_mage`/`knight` возвращает соответствующую PackedScene-константу, иначе `null`.
- `scripts/player.gd:~251` (в применении конфига персонажа): `var skeleton_scene := _character_skeleton_rig_scene(character_id)`; `_uses_skeletal_visual = skeleton_scene != null`; затем `_configure_skeletal_player_rig(skeleton_scene)`.
- `scripts/player.gd:1760-1782` `_configure_skeletal_player_rig(skeleton_scene)` — инстанцирует сцену в `_visual_root()`, читает `rig.manifest_path`, вызывает `rig.configure(manifest, character_id, BASE_SPRITE_SCALE)` и первичный `rig.update_animation(...)`.

### Скрипт рига
- `scripts/skeleton_player_rig_2d.gd` (14 КБ) — `@export var manifest_path`; `configure()`/`_load_manifest()` читают JSON-манифест, `_spawn_part_bone(...)` строит дерево костей (root→pelvis→torso→head, конечности) из source-точек манифеста. Источник истины геометрии — манифест-JSON, не хардкод.

### Сцены
- `scenes/characters/DarkMageSkeletonRig.tscn` — `[ext_resource ... path="res://scripts/skeleton_player_rig_2d.gd"]`, `manifest_path = "res://assets/sprites/characters/skeleton_parts/dark_mage/skeleton_source_manifest.json"`.
- `scenes/characters/KnightSkeletonRig.tscn` — то же, манифест `.../knight/skeleton_source_manifest.json`.

### Что уже отслеживается git (проверено `git ls-files`)
- `scripts/skeleton_player_rig_2d.gd` + `.uid` — **TRACKED**.
- `scenes/characters/DarkMageSkeletonRig.tscn`, `scenes/characters/KnightSkeletonRig.tscn` — **TRACKED** (2 файла).
- `assets/sprites/characters/skeleton_parts/` — **82 файла** tracked, включая **рантайм-манифесты** `dark_mage/skeleton_source_manifest.json` и `knight/skeleton_source_manifest.json` (именно их грузят `.tscn` → проверены как TRACKED).
- `docs/design/references/chars_cartoon/skeleton_parts/` — **93 файла** tracked (reference-копии манифестов/частей).
- `tests/no_duplicate_artifact_files_test.gd` — **TRACKED**.

### Как это попало в git
- `git log -- scripts/skeleton_player_rig_2d.gd` → `c55610c0 chore(repo): checkpoint local WIP for GitHub migration` (массовый чекпойнт миграции) и позже `205fe13e Fix skeletal rig bone rest setup`.
- Т.е. вместо «отдельного осмысленного коммита явным add» риг уехал в **общий checkpoint-коммит** миграции. С точки зрения acceptance это технически закрывает «файлы в git», но НЕ «отдельным осмысленным коммитом». Историю переписывать **не нужно** (коммит уже в `dev`, возможно запушен) — достаточно зафиксировать факт и верифицировать целостность.

### Остаточные риски на диске
- Активный worktree `.claude/worktrees/elegant-heyrovsky-ed6f15` (ветка `claude/elegant-heyrovsky-ed6f15`, `git worktree list`). В нём `scripts/skeleton_player_rig_2d.gd` присутствует, untracked-дублей скелета в `git status` worktree не видно.
- `find` по сигнатуре Finder-дубля `« 2.<ext>»` (исключая `.git`/`.godot`) — **0 совпадений**.

## Что сделать — по шагам

1. **Снять полный инвентарь рантайм-стека рига и сверить с git.** Прогнать:
   ```
   for p in scripts/skeleton_player_rig_2d.gd scripts/skeleton_player_rig_2d.gd.uid \
            scenes/characters/DarkMageSkeletonRig.tscn scenes/characters/KnightSkeletonRig.tscn \
            assets/sprites/characters/skeleton_parts/dark_mage/skeleton_source_manifest.json \
            assets/sprites/characters/skeleton_parts/knight/skeleton_source_manifest.json; do
     git ls-files --error-unmatch "$p" >/dev/null 2>&1 && echo "TRACKED $p" || echo "MISSING $p"; done
   git ls-files --others --exclude-standard | grep -iE 'skeleton|scenes/characters|chars_cartoon'
   ```
   Цель — убедиться, что НЕТ untracked-кусков рантайм-стека.
2. **Если найдены остаточные untracked-файлы рига** (на сегодня их нет, но воркеры могли что-то догенерить) — добрать их **явным** `git add <конкретные пути>` (НЕ `git add -A`), отдельным осмысленным коммитом, например:
   `chore(SCRUM-513): track skeletal player rig <что именно> in repo`.
   Перед коммитом — `git diff --staged` глазами: только файлы рига, ничего чужого.
3. **Green-gate ДО любого коммита.** Прогнать smoke headless (Godot 4.6.3 в `~/Downloads/Godot.app` — см. память QA):
   - `runtime_smoke` (как минимум `tests/runtime_smoke_test.gd`; при возможности и остальные `runtime_smoke_*`).
   - `tests/animation_smoke_test.gd` — критично, т.к. риг участвует в анимации (`update_animation`).
   Пример запуска одного теста:
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/animation_smoke_test.gd`
4. **Прогнать дубль-гард зелёным.**
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/no_duplicate_artifact_files_test.gd`
   Ожидается строка `Duplicate-artifact guard passed (...)` и exit 0.
5. **Проверить worktree на осиротевшие дубли.** Убедиться, что `.claude/worktrees/elegant-heyrovsky-ed6f15` не содержит untracked-копий скелетных артефактов, которые могли бы «утечь» в основное дерево, и что нет файлов вида `« 2.<ext>»`:
   `find . -path ./.git -prune -o -path './.godot' -prune -o \( -name '* 2.*' -o -name '* 2' \) -print`
6. **Зафиксировать вердикт.** Если всё tracked + оба гейта зелёные + дублей нет — задача выполнена (verified). Обновить статус в этом `.md` и в Jira (К выполнению → Готово / Контроль качества по процессу). Если что-то добирали коммитом — приложить хэш коммита.

## Acceptance Criteria

- [ ] `scripts/skeleton_player_rig_2d.gd` и связанные asset/scene/manifest файлы присутствуют в git (проверено `git ls-files --error-unmatch` по полному списку рантайм-стека: скрипт+`.uid`, обе `.tscn`, оба `assets/.../skeleton_source_manifest.json`, parts-PNG, reference-копии).
- [ ] Нет ни одного untracked-файла рантайм-стека рига (`git ls-files --others --exclude-standard | grep -iE 'skeleton|scenes/characters|chars_cartoon'` пуст, кроме допустимых docs/tasks-спек).
- [ ] Если потребовался добор — он сделан **явным** `git add <пути>` (НЕ `-A`), отдельным осмысленным коммитом; `git diff --staged` проверен вручную, чужого/лишнего не попало.
- [ ] Зелёный `runtime_smoke` (`tests/runtime_smoke_test.gd` и/или набор `runtime_smoke_*`) ДО коммита — green-gate.
- [ ] Зелёный `tests/animation_smoke_test.gd` ДО коммита.
- [ ] `tests/no_duplicate_artifact_files_test.gd` зелёный (`Duplicate-artifact guard passed`, exit 0) — нет осиротевших дублей, в т.ч. в `.claude/worktrees/`.
- [ ] Рантайм-проверка целостности preload-цепочки: проект открывается без ошибок (preload обеих `.tscn` в `player.gd:17-18` резолвится), dark_mage и knight грузят скелетный риг (`_uses_skeletal_visual == true`).
- [ ] Статус синхронизирован: `.md` + Jira (по live-sync мандату).

## Files / точки входа

- `scripts/skeleton_player_rig_2d.gd` (+ `.gd.uid`) — скрипт рига; **проверить tracked**, при доборе — явный `git add`.
- `scenes/characters/DarkMageSkeletonRig.tscn`, `scenes/characters/KnightSkeletonRig.tscn` — сцены рига; `ext_resource` ссылается на скрипт, `manifest_path` — на `assets/.../skeleton_source_manifest.json`. **Проверить tracked.**
- `assets/sprites/characters/skeleton_parts/{dark_mage,knight}/skeleton_source_manifest.json` — **рантайм-источник истины** геометрии (именно их грузит `.tscn`). Обязаны быть tracked.
- `assets/sprites/characters/skeleton_parts/**` — parts-PNG + `.import` (82 файла). Проверить полноту.
- `docs/design/references/chars_cartoon/skeleton_parts/**` — reference-копии (93 файла).
- `scripts/player.gd:17-18, ~251, 1760-1792` — рантайм-потребитель; читать только для верификации цепочки, **не менять**.
- `tests/no_duplicate_artifact_files_test.gd` — дубль-гард (паттерн `« 2(\.|$)»`, скип `.godot/.git/tmp/node_modules` и `res://build/dmg`).
- `tests/runtime_smoke_test.gd`, `tests/runtime_smoke_*`, `tests/animation_smoke_test.gd` — green-gate.

## Замечания / подводные камни

- **Это tech-debt/верификационная задача, не фича.** Скорее всего код менять НЕ придётся вообще — основная работа — сверка с git + прогон гейтов. Не вносите функциональных правок в риг/анимацию под этим тикетом.
- **Состояние уже почти закрыто:** на 2026-06-27 весь стек tracked (коммит `c55610c0` checkpoint-миграции, фикс `205fe13e`). Acceptance «отдельным осмысленным коммитом» был написан ДО миграции; переписывать историю (`c55610c0` уже в `dev`/возможно запушен) **нельзя** — достаточно зафиксировать факт и верифицировать целостность. Если ревьюер требует именно отдельный коммит — это применимо только к остаточным untracked-кускам (если найдутся).
- **НЕ `git add -A`.** Это прямое требование тикета (память: «Воркеры git add -A» — чужие хунки втягиваются). Только явные пути. Перед коммитом всегда `git diff --staged`.
- **Anti-collision / locked paths:** `scripts/player.gd` — это **общий горячий файл** (player.gd часто трогают параллельные lane-агенты), но под этой задачей его трогать НЕ нужно (только читать для верификации). НЕ трогать `scripts/ui_screens.gd` и `scripts/progression_data.gd` (locked). Изменения, если будут, ограничены `git add`-операциями над файлами рига — функциональный код не редактируем.
- **Worktree-гигиена:** активен `.claude/worktrees/elegant-heyrovsky-ed6f15`. Перед коммитом убедиться, что чужой worktree не оставил untracked-копий скелета в основном дереве и что нет `« 2.<ext>»`-дублей (на сегодня — 0).
- **`.import`-сайдкары:** каждый PNG в Godot тянет `.import`. Если добираете ассеты — добавляйте PNG **вместе** с его `.import`, иначе Godot пере-импортирует и риг может «поплыть». В `.gitignore` уже лежат свежие `*.png.import` (см. git status) — проверить, что нужные рига не заигнорены.
- **Связанные тикеты:** SCRUM-496 (`docs/tasks/SCRUM-496_skeleton_rig_mage_knight_runtime.md`, сейчас untracked) — рантайм рига mage/knight; контекст происхождения стека. Тесты-гарды восходят к SCRUM-267/269/270/271/440 (волна дублей-артефактов 0.1.5).
- **Источник `det==0`/рестовые позы** живёт в JSON-манифесте — поэтому критично, что tracked именно `assets/.../skeleton_source_manifest.json` (рантайм-путь из `.tscn`), а не только reference-копия под `docs/`. Оба уже tracked — подтвердить повторно перед закрытием.
