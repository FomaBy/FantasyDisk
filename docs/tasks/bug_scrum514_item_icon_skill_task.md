# BUG SCRUM-543: item-icon skill — нет local mirror + Asset Matrix не покрывает stats/

Jira: SCRUM-543 (Баг) · Эпик: SCRUM-216 · labels: qa, bug, claude, foma, skill, asset-pipeline
Статус: new
Приоритет: high (БЛОКЕР AC №1)
Роль: Design main / Codex (по зоне skill)
Найдено QA при тестировании: docs/tasks/SCRUM-514_item_icon_generator_skill.md
Родительская задача: SCRUM-514 (возвращена в «К выполнению»)

## Дефект 1 (БЛОКЕР, AC №1): нет local skill mirror
AC требует «Skill доступен в repo И в local skill mirror».
Факт: `skills/codex/fantasydisk-item-icon-generator/` есть в репо, но `~/.codex/skills/fantasydisk-item-icon-generator/` отсутствует. Все прочие repo-skill'ы зеркалированы, этот — нет.

### Воспроизведение
1. `ls ~/.codex/skills/ | grep item-icon-generator` → пусто.
2. Сравнить с `ls skills/codex/fantasydisk-item-icon-generator/` → SKILL.md + agents/openai.yaml есть.

### Ожидание / Реальность
Ожидание: зеркало существует, SKILL.md идентичен репозиторному.
Реальность: каталога нет → AC №1 формально не закрыт.

## Дефект 2 (AC «Asset Matrix = реальным путям»): матрица не покрывает stats/
Факт: SKILL.md:36 — одна строка Stat/attribute → `assets/sprites/ui/icons/derived/attr_<id>.png`.
Реальность: базовые атрибуты в `assets/sprites/ui/icons/stats/stat_<id>.png` (8 файлов, префикс `stat_`: strength/agility/intelligence/perception/energy/knowledge/endurance/leadership); производные — в `derived/attr_<id>.png` (префикс `attr_`).

### Воспроизведение
1. `ls assets/sprites/ui/icons/stats/` и `ls assets/sprites/ui/icons/derived/`.
2. `grep -n 'icons/(stats|derived)' scripts/ui_icon_registry.gd` (строки 51-70) — грузит обе папки.

### Ожидание / Реальность
Ожидание: матрица разводит Base stat (`stats/stat_<id>.png`) и Derived attribute (`derived/attr_<id>.png`) двумя строками с префиксами.
Реальность: одна строка, маршрут `stats/` отсутствует → исполнитель запишет иконку базового атрибута в неверную папку с неверным префиксом.

## Мелочь (не блокер)
workflow (SKILL.md:52) ссылается на `tools/artgen/generate_asset.py` «when it exists», но `tools/artgen/` отсутствует. Пометить опциональным с каноничным bundled-фоллбэком `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py` (существует).

## Окружение
Ветка dev, HEAD 176d67bb; skill-коммит 4b103750; macOS. Проверки read-only (skill не генерит картинки).

## Definition of done
Создать/засинкать зеркало `~/.codex/skills/fantasydisk-item-icon-generator/` (идентично репо); развести Asset Matrix на stats/ vs derived/; пометить `tools/artgen/` опциональным. После — обратно на QA.

## Codex result 2026-06-28

Status: done, ready for QA.
Owner: Codex design SCRUM-543 skill mirror fix.
Worktree: `C:\FantasyDisk_agents\scrum543_skill_icon_matrix`.
Locked paths:
- `skills/codex/fantasydisk-item-icon-generator/`
- `docs/tasks/bug_scrum514_item_icon_skill_task.md`
- local mirror `C:\Users\FomaE\.codex\skills\fantasydisk-item-icon-generator/`

Result:
- Repo skill and local mirror are present and byte-equivalent for `SKILL.md`.
- Asset Matrix separates base stats and derived attributes:
  - base stats: `assets/sprites/ui/icons/stats/stat_<canonical_id>.png`
  - derived attributes: `assets/sprites/ui/icons/derived/attr_<canonical_id>.png`
- Required inputs use `stat_basic` and `stat_derived`, matching the matrix.
- Workflow documents `tools/artgen/generate_asset.py` as optional and names the bundled `$fantasydisk-asset-generator` script as the canonical available generator in this repo.

Verification:
- `Compare-Object` between repo and local mirror `SKILL.md`: no differences.
- Repo and local mirror both contain `agents/openai.yaml`.
- `assets/sprites/ui/icons/stats/` contains the eight `stat_*.png` base stat icons.
- `assets/sprites/ui/icons/derived/` contains `attr_*.png` derived attribute icons.
- `scripts/ui_icon_registry.gd` maps base stats to `stats/stat_*.png` and derived attributes to `derived/attr_*.png`.
- `scripts/stat_formulas.gd` exposes `BASE_STAT_ORDER` and `DERIVED_STAT_ORDER` for ID validation.
- `quick_validate.py` passes for the repo skill.

No production icon pack was generated for this bug.
