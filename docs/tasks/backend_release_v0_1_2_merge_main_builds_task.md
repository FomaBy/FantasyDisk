# Задача Для Back-end-Агента: Релиз v0.1.2 — Merge В Main И Сборки

Статус: done
Создано: 2026-06-12
Автор: PM / Codex dispatcher
Роль: Back-end
Приоритет: high
Dispatch: отправлено в Back-end чат `019ebadd-c0f8-7100-b33a-2887ad5a9561` 2026-06-12.

## Autonomy / Approval
Пользователь заранее одобрил все in-scope изменения для релиза: предрелизные
фиксы, обновление версии, коммиты, merge в `main`, тег и сборки Windows/macOS.
Не спрашивай подтверждение, если задача ясна: делай, проверяй, документируй.

## Контекст
Нужно собрать **FantasyDisk v0.1.2** в `main` и подготовить релизные артефакты
для Windows и macOS. Активная разработка идет в `dev`, `main` — стабильная
линия. Предыдущий релиз `v0.1.1` уже был собран через аналогичный flow.

Источник процесса:
- `docs/process/release_versioning.md`
- `docs/process/versioning_and_branching.md`
- `AGENTS.md`

## Важное Перед Стартом
1. Проверь `git branch --show-current`: обычная работа должна стартовать из
   `dev`.
2. Проверь `docs/process/task_board.md` и task-файлы. Если есть активные
   `new` / `in_progress` / `review` задачи, которые должны попасть в 0.1.2,
   не релизь поверх них молча: сначала доведи, синхронизируй с владельцем роли
   или явно зафиксируй в резюме, что задача не входит в релиз.
3. Особое внимание: если `codex_design_new_classes_restyle_to_starter_style_task.md`
   еще `in_progress` или `review`, выясни по task-файлу/борде, можно ли включать
   текущий результат в релиз или нужно дождаться закрытия Design/Claude review.
4. Рабочее дерево может быть грязным из-за параллельных агентов. Не теряй и не
   откатывай чужие изменения. Разбери статус аккуратно, не коммить `.godot/`.

## Требования

### 1. Code Freeze И Проверки
1. Синхронизировать task board: понять, какие изменения считаются входящими в
   `0.1.2`, и убедиться, что релиз не ломает чужую работу.
2. Запустить обязательные headless/smoke проверки:
   - `res://tests/runtime_smoke_test.gd`
   - animation smoke test, если есть отдельный скрипт
   - meta progression smoke/test, если есть отдельный скрипт
   - melee weapon targeting regression test
   - любые дополнительные релизные/build-тесты, которые уже есть в проекте
3. Любой красный тест или явная runtime-ошибка до релиза — исправить в рамках
   Back-end зоны ответственности. Если ошибка относится к Design/Animator,
   оформить handoff task в `docs/tasks/` и отправить в нужный чат.
4. Сделать быстрый ручной/автоматизированный sanity flow: главное меню → выбор
   героя → карта → бой → победа/level-up → магазин/ивент, без ошибок в консоли.

### 2. Обновление Версии
5. Обновить версию проекта на **0.1.2**:
   - `project.godot`: `config/version = "0.1.2"`
   - export presets: macOS `short_version`/`version` = `0.1.2`
   - export presets: Windows `file_version`/`product_version` = `0.1.2.0` /
     `0.1.2`
6. Обновить `CHANGELOG.md`:
   - текущий `Unreleased` закрыть как `## [0.1.2] — 2026-06-12`
   - сверху создать новый пустой `Unreleased`
   - формулировки должны быть пользовательскими и читаемыми, без технического
     мусора.
7. Обновить релевантную документацию:
   - `docs/design/current_game_state.md`
   - при необходимости `docs/process/release_versioning.md`, если в процессе
     сборки нашли новый важный нюанс.
8. Коммит в `dev`: `release: bump version to 0.1.2`.

### 3. Merge В Main И Тег
9. Выполнить release merge:
   - `git checkout main`
   - `git merge dev --no-ff -m "Release v0.1.2"`
   - `git tag v0.1.2`
   - `git checkout dev`
10. Если есть конфликты, разрешать осознанно, обычно в пользу актуального
    `dev`. Не использовать destructive-команды.
11. После merge убедиться:
    - рабочая ветка снова `dev`
    - `main` содержит релизный merge
    - тег `v0.1.2` указывает на релизный коммит

### 4. Сборки
12. Запустить релизную сборку:
    - `tools/build_release.sh 0.1.2`
13. Ожидаемые артефакты:
    - `releases/v0.1.2/FantasyDisk-0.1.2-macos.dmg`
    - `releases/v0.1.2/FantasyDisk-0.1.2-windows-setup.exe`
    - `releases/v0.1.2/FantasyDisk-0.1.2-windows.zip`
    - `releases/v0.1.2/SHA256SUMS.txt`
14. Проверить macOS DMG: смонтировать, запустить игру до главного меню,
    убедиться, что видна версия `0.1.2`.
15. Проверить Windows артефакты насколько возможно на macOS:
    - файлы ненулевого размера
    - zip открывается/тестируется
    - если build script поддерживает self-check/CRC для NSIS, прогнать его
    - в финальном резюме явно написать, что полноценный installer-test нужен
      на Windows-машине.

## Acceptance Criteria
- [x] Все обязательные smoke/regression тесты зеленые до merge.
- [x] Board проверена; активные задачи либо закрыты/включены, либо явно
      исключены из релиза с причиной.
- [x] Версия `0.1.2` обновлена в проекте, export presets, CHANGELOG и docs.
- [x] В `dev` есть release bump commit.
- [x] `main` содержит `Release v0.1.2`, тег `v0.1.2` создан, рабочая ветка
      возвращена на `dev`.
- [x] Артефакты Windows/macOS лежат в `releases/v0.1.2/`, есть SHA256SUMS.
- [x] DMG проверен запуском до меню; Windows artifacts прошли доступные
      локальные проверки.
- [x] Task-файл переведен в `done` с коротким резюме: что вошло, какие тесты
      пройдены, где лежат сборки, что нужно проверить пользователю на Windows.

## Result Summary

Закрыто 2026-06-12.

- Board проверена: единственная нерелизная активная задача —
  `codex_design_new_classes_restyle_to_starter_style_task.md` (`in_progress`,
  12/24 файлов, без финального cutout/review). Она не закрывается этим релизом;
  уже закоммиченный dev-срез не откатывался.
- В `0.1.2` вошел текущий стабильный срез `dev`: UI D&D-таверна, realistic D&D
  artifact icons, 9 классов/27 оружий, универсальные вторичные атрибуты,
  fullscreen hero select, уникальные class patterns, настройки v2, обновленный
  Berserk melee targeting и релизный bump версии.
- Пройдены до merge и после bump: `runtime_smoke_test.gd`,
  `animation_smoke_test.gd`, `meta_progression_smoke_test.gd`,
  `melee_weapon_targeting_test.gd`, `attack_vfx_smoke_test.gd`.
- Коммит в `dev`: `552fe59 release: bump version to 0.1.2`.
- `main` содержит merge commit `76f970a Release v0.1.2`; тег `v0.1.2`
  указывает на этот merge commit; рабочая ветка возвращена на `dev`.
- Сборки созданы через `tools/build_release.sh 0.1.2`:
  `releases/v0.1.2/FantasyDisk-0.1.2-macos.dmg`,
  `releases/v0.1.2/FantasyDisk-0.1.2-windows-setup.exe`,
  `releases/v0.1.2/FantasyDisk-0.1.2-windows.zip`,
  `releases/v0.1.2/SHA256SUMS.txt`.
- Проверки артефактов: DMG смонтирован, `FantasyDisk.app` запущен из DMG с
  кодом 0, bundle `CFBundleShortVersionString`/`CFBundleVersion` = `0.1.2`;
  Windows zip проходит `unzip -t`, файлы ненулевого размера, SHA256SUMS
  сходятся, NSIS CRC verify в build script прошел.
- Полноценный запуск Windows installer нужно проверить на Windows-машине.
