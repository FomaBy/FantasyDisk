# Backend Task: SCRUM-676 — Дерево умений, переделка раскладки (бэкенд)

Статус: done
Контур: Claude (backend)
Owner: backend
Jira: SCRUM-676 (blocked by SCRUM-675)
Спринт: 0.1.7 (133)
Locked paths: scripts/ui_screens.gd (`_show_skill_tree_screen` и связанные стили)

## Что и зачем

Переделать раскладку экрана «Древо умений» под новый дизайн (SCRUM-675):
компактно, читаемо, с классовым dropdown и отдельной кнопкой очков.

## Текущий код

`scripts/ui_screens.gd:1733` `_show_skill_tree_screen`:
- `SkillTreeClassPanel` → заголовок «Классы» + `SkillTreeClassProgress` +
  `SkillTreeClassBonusList` (Label-список применённых классовых бонусов, строки
  из `META_PROGRESSION.class_unlocked_tiers`);
- 4 ветки `SkillTreeBranchPanel_{wealth,lore,might,endure}`, узлы
  `SkillNode_<id>` (кнопки 74×74, font_size 20);
- `SkillTreePointsBadge`/`SkillTreePointsLabel` (Очки умений), `SkillTreeBackButton`.
- Данные/логика — `META_PROGRESSION` (data-driven), не трогать.

## Шаги

1. **Классы → dropdown**: вместо постоянного Label-списка сделать селектор класса
   (OptionButton/кастомная кнопка) + красивый попап (PanelContainer/PopupPanel)
   с применёнными бонусами класса (брать из `class_unlocked_tiers`). Источник
   данных тот же.
2. **4 пути компактнее**: уменьшить футпринт `SkillTreeBranchPanel_*`, но шрифт
   заголовков/описаний узлов чуть КРУПНЕЕ для читаемости; каждый путь в своём
   фрейме (ассеты из SCRUM-675).
3. **Очки умений — отдельная кнопка**: оставить показ счётчика + добавить
   отдельную кнопку (открывает попап/объяснение очков). Бейдж сохранить.
4. **Общий фрейм** заменить на новый из SCRUM-675.
5. Интегрировать ассеты `assets/sprites/ui/skill_tree/**`.

## Ограничения / тесты

- Сохранить имена узлов, на которые завязаны тесты: `SkillTreeBackButton`,
  `SkillTreePointsBadge`, `SkillTreeBranchPanel_*`, `SkillNode_*` (см.
  `tests/ui_no_overlap_matrix_test.gd`, `runtime_smoke_ui_test.gd`).
- `ui_no_overlap_matrix_test.gd` и `runtime_smoke_ui_test.gd` зелёные @2K.
- Логику покупки узлов / сохранение не менять.

## Acceptance

- Классы открываются dropdown'ом с попапом применённых бонусов.
- 4 пути компактны, в своих фреймах, читаемый шрифт.
- Очки умений видны + отдельная кнопка.
- Новый общий фрейм; тесты зелёные; визуальная QA-проверка скриншотом.

## Files

- scripts/ui_screens.gd

## QA-Вердикт (2026-06-29)

Статус: PASSED

Проверено на чистом `origin/dev @ 7d085c2e` + независимый subagent:
- `SkillTreeClassSelector`, `SkillTreeClassBonusButton` и `SkillTreeClassBonusPopup`
  есть; постоянный `SkillTreeClassBonusList` убран.
- `SkillTreePointsBadge`/`SkillTreePointsLabel` сохранены; добавлена отдельная
  `SkillTreePointsInfoButton` с popup.
- `SkillTreeBranchPanel_wealth/lore/might/endure` и `SkillNode_*` сохранены.
- Ассеты `assets/sprites/ui/skill_tree/**` используются в layout.
- Покупка/сохранение узлов остаются через `META_PROGRESSION`.

Гейты:
- `tests/meta_skill_tree_smoke_test.gd` PASS.
- `tests/runtime_smoke_ui_test.gd` PASS.
- `tests/ui_no_overlap_matrix_test.gd` FAIL только на внешнем Codex/SCRUM-684
  (`CodexBackButton` vs `CodexDetailPanel`, frame mismatch); skill-tree ошибок нет.

Blockers for SCRUM-676: none. Disk cleanup: temp worktrees/logs removed, `git worktree prune` run.
