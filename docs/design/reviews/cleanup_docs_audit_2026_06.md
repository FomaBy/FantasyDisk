# Cleanup Docs Audit 2026-06

Дата: 2026-06-14  
Задача: SCRUM-268 / `docs/tasks/cleanup_audit_docs_full_update_task.md`  
Область: read-only сверка кода/ассетов и точечные правки документации. Runtime code, gameplay, balance, assets, releases и git history не менялись.

## Метод

Проверены:
- `scripts/progression_data_characters.gd` — 17 классов, базовые характеристики, character sprite paths, ultimate/class identity data.
- `scripts/progression_data_weapons.gd` — 51 стартовое оружие, Berserk IDs `sword`/`axe`/`hammer`, class weapon modes.
- `scripts/progression_data_enemies.gd`, `scripts/boss.gd`, `scripts/combat_director.gd`, `scripts/codex_data.gd` — mini-elite roster, boss roster, encounter pattern data.
- `scripts/main.gd`, `scripts/ui_screens.gd` — cursor hotspot and UI backdrop/runtime mappings.
- Asset folders: `assets/sprites/characters/`, `assets/sprites/weapons/`, `assets/sprites/bosses/`, `assets/sprites/elites/`, `assets/sprites/ui/icons/artifacts/`, `assets/backgrounds/ui/`.
- Core docs: `current_game_state.md`, `content_registry.md`, `mechanics_extract.md`, `fantasydisk_design_brief.md`, `docs/design/systems/*.md`.

## Исправлено В Документации

| Файл | Что было | Что обновлено |
| --- | --- | --- |
| `docs/design/mechanics_extract.md` | Таблица «Текущие статы» показывала только 3 старых класса; Berserk weapon IDs были `berserk_sword`/`berserk_axe`/`berserk_hammer`. | Таблица обновлена до всех 17 классов из `BASE_STATS`; Berserk IDs приведены к runtime IDs `sword`/`axe`/`hammer`; старый 0.2 class-sheet блок помечен как историческая выдержка. |
| `docs/design/current_game_state.md` | Старый SCRUM-190 survivability result читался как текущий; кодекс указывал только 2 босса; Berserk IDs и параметры меча были устаревшими. | Snapshot обновлен на 2026-06-14; survivability описывает SCRUM-255 как актуальный слой; кодекс описывает 11 обычных + 4 элитки + 6 мини-элиток + 5 боссов; Berserk IDs/параметры синхронизированы. |
| `docs/design/content_registry.md` | Source sprite resolution для элиток/боссов оставался 256x256; mini-elite text говорил, что runtime/codex wiring еще Back-end scope. | Registry обновлен под 512x512 active elite/boss/mini-elite source sprites и фактический mini-elite runtime через meta/scale/drop profile. |
| `docs/design/fantasydisk_design_brief.md` | Brief говорил про `dev` как 0.2, 9 классов, новые классы 0.2 и старый cursor hotspot `(5, 4)`. | Brief обновлен под active sprint target 0.1.5, 17 классов, 51 стартовое оружие и cursor hotspot `(2, 2)`. |
| `docs/design/systems/menus_ui.md` | Cursor hotspot был `(5, 4)`. | Hotspot синхронизирован с `main.gd::GAME_CURSOR_HOTSPOT` и visual kit: `(2, 2)`. |
| `docs/design/systems/progression_balance.md` | Заголовок был 0.1.4; не упоминался финальный crowd-clear audit. | Обновлено до 0.1.5; добавлен SCRUM-262 final balance audit gate/report. |
| `docs/design/systems/technical_architecture.md` | Branching section называл текущую стабилизацию 0.1.4. | Обновлено до current sprint target 0.1.5. |
| `docs/design/systems/combat.md` | Boss roster перечислял 4 boss IDs и пропускал `disk_devourer`. | Boss roster обновлен до 5 IDs: `rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`. |
| `docs/design/systems/audio.md` | Описание называло stabilization target 0.1.4. | Обновлено до sprint target 0.1.5. |

## Подтверждено Сверкой

- Runtime character roster: 17 классов, все имеют `CHARACTER_CONFIGS`, `BASE_STATS`, `ULTIMATE_CONFIGS` и class identity data.
- Weapon roster: 51 стартовое оружие через `ProgressionData.WEAPONS_BY_CLASS`; системный doc `characters_weapons.md` уже содержит полную матрицу.
- Artifact icon naming в активном registry: canonical `artifact_<artifact_id>.png`; duplicate ` N.` cleanup SCRUM-270 уже отражен как done в task board и не был откатан.
- UI backdrop mapping в `main.gd::SCREEN_BACKGROUND_PATHS` совпадает с `docs/design/systems/menus_ui.md`.
- Cursor runtime hotspot в `main.gd::GAME_CURSOR_HOTSPOT` — `(2, 2)`; `content_registry.md`, `artifact_shop_cursor_visual_kit.md`, `visual_style_assets.md` и `ui_technical_requirements.md` уже согласованы.
- Enemy size profiles в `progression_data_enemies.gd` совпадают с `docs/design/systems/enemies_bosses.md`: ordinary 1.00, mini_elite 1.05, elite 1.68, boss 1.90.
- Final balance audit SCRUM-262 уже описан в `current_game_state.md` и теперь дополнительно в `progression_balance.md`.

## Оставшиеся Расхождения / Follow-Up

1. `scripts/codex_data.gd` у новых boss entries частично использует placeholder sprites: `bone_archon` ссылается на `boss_rift_warden.png`, а `brood_mother`/`ashen_colossus` — на `boss_disk_devourer.png`. Source PNG для всех трех есть в `assets/sprites/bosses/`. Это Back-end content integration follow-up, не документационная правка.
2. Read-only scan все еще находит duplicate sidecar/import artifacts с суффиксом ` 2` вне canonical registry, например `.import`/`.uid` в `assets/`, `docs/design/previews/`, `docs/design/references/`, `scripts/`. Их нельзя удалять в SCRUM-268; они относятся к уже завершенной/соседней cleanup линии SCRUM-270/SCRUM-269/SCRUM-193.
3. `docs/design/systems/ui_technical_requirements.md` существует в рабочем дереве как новый системный doc и уже имеет дату 2026-06-14. В рамках SCRUM-268 он учитывался как часть `docs/design/systems/*`, но его tracked/untracked статус оставлен без вмешательства.

## Решение По Handoff

Новый Design/Animator handoff не создавался: выявленные расхождения не требуют нового арта или motion polish. Единственный runtime/content follow-up — корректная привязка boss sprites в `scripts/codex_data.gd` — относится к Back-end content integration и должен идти отдельной задачей, если PM решит включить его в спринт.
