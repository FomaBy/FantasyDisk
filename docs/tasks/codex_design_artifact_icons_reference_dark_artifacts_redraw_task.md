# Задача Для Codex (Design): Полная Перерисовка Иконок Артефактов В Dark Artifacts Стиле

Статус: done 2026-06-11
Создано: 2026-06-11
Автор: пользователь
Исполнитель: Codex

Superseded note 2026-06-11: этот deterministic reference redraw был заменен прямым пользовательским запросом на более эпичные AI concept-sheet item tiles. Активные файлы по-прежнему лежат на тех же путях `assets/sprites/ui/icons/artifacts/artifact_<id>.png`; актуальный preview — `assets/sprites/ui/icons/artifact_generated_concept_40px_preview.png`.

## Autonomy / Approval
Пользователь напрямую попросил удалить/заменить все иконки артефактов и нарисовать каждую заново в стиле dark fantasy по приложенному референсу `Dark Artifacts`. Изменения в рамках задачи одобрены.

## Требование
Полностью заменить текущий набор `assets/sprites/ui/icons/artifacts/artifact_*.png`:
- стиль: dark fantasy / dark artifacts как в референсе пользователя;
- предметы должны выглядеть как отдельные мрачные артефакты, а не как яркие RPG-медальоны;
- материалы: черненый металл, кость, камень, темная кожа, проклятая бумага, кристаллы, руны;
- акценты: фиолетовое, зеленое, кроваво-красное, циановое и оранжевое магическое свечение по смыслу предмета;
- без текста, watermark и встроенных UI-рамок;
- прозрачный фон, `256x256`, имена файлов сохраняются.

## Результат
Сгенерирован новый детерминированный генератор `tools/generate_reference_dark_artifact_icons.py` и перерисованы все 52 текущие иконки артефактов из `ProgressionData.ARTIFACTS` на месте. `.import` sidecars не изменялись.

Проверки:
- 52 файла `artifact_*.png`;
- все `256x256`;
- прозрачные углы;
- 40px preview: `assets/sprites/ui/icons/artifact_dark_artifacts_40px_preview.png`;
- `runtime_smoke_test.gd` пройден.

## Acceptance Criteria
- [x] Все artifact PNG заменены на месте.
- [x] Стиль соответствует dark fantasy reference direction.
- [x] Предметы остаются читаемыми при 40px.
- [x] Документация и task board обновлены.
