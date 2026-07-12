# SCRUM-1064 — Hero Select: структурированное досье всех 17 героев

Статус: done
Контур: Codex
Owner: Back-end/UI `/root/scrum1064_hero_dossier`
Thread/Worker: `/root/scrum1064_hero_dossier`
Jira: SCRUM-1064
Ветка: `codex/scrum1064-hero-dossier`
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1064-hero-dossier`
Locked paths: Hero Select dossier/data hunks in `scripts/progression_data_characters.gd`, `scripts/progression_data.gd`, `scripts/ui_screens.gd`; Doctor-only constellation entry in `scripts/meta_progression_tree_data.gd`; focused SCRUM-1064 and narrowly related Hero Select/Codex/gamepad/runtime/skill-tree tests; `docs/design/mockups/scrum1064_hero_dossier/`, `docs/design/previews/scrum1064_hero_dossier/`, character/Hero Select docs, this mirror and scoped Jira sync map.

## Цель

Заменить свободное описание, прозу «Плюсы/Минусы» и частично дублирующие
подсказки Hero Select единым data-driven досье для всех 17 канонических героев:

1. опциональная каноническая особенность с точным механическим эффектом;
2. имя;
3. три selectable weapon name из канонических конфигов;
4. детерминированные лидирующие `BASE_STATS` с числами;
5. основные атрибуты;
6. второстепенные атрибуты;
7. слабые атрибуты.

Правые восемь stat bars сохраняются. Списки релевантности обязаны быть
непересекающимися и вместе покрывать `ATTRIBUTE_REGISTRY`; термин `optional` в
Hero Select показывается игроку как «Слабые атрибуты».

## UI Director gate

- До runtime-правок используется принятый PixelLab Hero Select shell и уже
  принятый PixelLab SCRUM-951 stat-row art layer; новый артовый пиксель не
  создаётся.
- Content-zone plan/spec:
  `docs/design/mockups/scrum1064_hero_dossier/`.
- Самые длинные русские строки проверяются с обязательным вертикальным scroll и
  отдельной scrollbar lane на 1152×648, 1280×720, 1920×1080 и 2560×1440.
- Декоративная внешняя рама, dossier border, portrait, stat bars, Ascension и
  carousel остаются неперекрытыми.

## Acceptance

- Для каждого `ProgressionData.character_ids()` порядок блоков одинаков.
- Trait-строка имеет формат `Особенность: <название> — <точный эффект>` и
  отсутствует целиком, если trait отсутствует.
- Видимые `CHARACTER_CONFIGS.description/strengths/weaknesses` удалены.
- Три оружия берутся из `WEAPONS_BY_CLASS`, без ручной копии.
- Лидирующие характеристики выбираются одним документированным алгоритмом:
  top 3 по значению убыванию, при равенстве — порядок `STAT_NAMES`/`BASE_STATS`.
- Категории relevance disjoint, полны и предметно сверены с trait + тремя
  фактическими weapon mechanics каждого класса; balance numbers не меняются.
- Compact scroll/focus работает мышью, клавиатурой и геймпадом, hero switch
  сбрасывает scroll вверх.
- Focused schema/UI matrix, Hero no-overlap, Codex, gamepad и full runtime PASS;
  Metal-матрица визуально frame-safe.
- Plague Oath Доктора не оставляет в его личном созвездии отключённых generic
  sustain-звёзд или techniques.

## Результат

- Реализован единый `ProgressionData.hero_select_dossier()` для всех 17 героев:
  точная optional trait-строка, имя, три канонических оружия, детерминированный
  top-3 `BASE_STATS`, полные disjoint primary/secondary/weak группы.
- Hero Select удаляет видимые prose description/strengths/weaknesses, не режет
  строки и сохраняет восемь stat bars; dossier scroll frame-safe на
  1152×648/1280×720/1920×1080/2560×1440 и перестраивается при live resize без
  сброса run/route state.
- Предметная ревизия 17 kits исправила устаревшие relevance-категории. Связанный
  dead-progression дефект Доктора устранён: его Plague Oath больше не конфликтует
  с личными meta stars; это закреплено отдельным skill-tree assertion.
- PixelLab shell/stat layer переиспользованы без нового raster art. UI-plan оба
  `ready_for_image`, четыре Metal runtime preview сохранены в
  `docs/design/previews/scrum1064_hero_dossier/` и визуально frame-safe.
- PASS: focused all-17 dossier/schema/UI/live-resize, attribute relevance 24×17
  (2/8/7), per-hero/meta skill tree, Hero Select 1063/979, no-overlap, Codex,
  gamepad focus/full-flow, balance harness (51/51), global damage,
  survivability, Metal и full runtime smoke — до и после rebase на свежий
  `origin/dev`.
- Implementation commit: текущий `feat(SCRUM-1064): structure hero select
  dossiers`; Jira направляется в `Контроль качества` после push в `origin/dev`.
- Disk cleanup: generated untracked `.uid` удалены; `.godot`, balance reports и
  `/tmp/fsd-scrum1064-*` очищаются после финального QA handoff.
