# ART/BACKEND: Cartoon-проба — Тёмный маг + Рыцарь в игру с анимацией движения

Статус: done
Приоритет: high
Роль: Back-end (интеграция) + Design (cartoon-спрайты)
Версия: 0.1.6
Создано: 2026-06-17
Автор: PM (запрос пользователя — «1-2 на пробу», затем «добавь с анимацией движения»)
Jira: SCRUM-472
Связано: SCRUM-456 (cartoon style-anchor), SCRUM-461 (Берсерк cartoon)
QA: PASSED (2026-06-17)

## Контекст
Пользователь одобрил 2 пробных cartoon-персонажа (Тёмный маг, Рыцарь) по style-sheet
SCRUM-456 и попросил добавить их в игру с анимацией движения. Цель — оценить стиль
в деле до перерисовки остальных 15.

## Что сделано
- **Спрайты:** cartoon-версии (gpt-image, прозрачный фон, alpha вырезан) заменяют
  v2 `assets/sprites/characters/{dark_mage,knight}.png` (512², фигура вписана, ноги
  к низу). Обновляет и портрет (sprite_path), и риг-источник.
- **Анимация движения:** `CARTOON_TRIAL_CLASSES` в `player.gd` форсит legacy-cutout-риг
  (целый спрайт через `Pelvis/HeroFull`: bob/lean/breath при ходьбе), минуя v2
  full-frame и sliced-нарезку (её hand-tuned боксы под v2-пропорции не подходят
  cartoon). Атаки не анимируются — оружие (USE_ATTACK_ANIMATION=false).
- **Тесты:** `animation_smoke` обновлён — cartoon-классы на legacy-риге (вместо
  sliced/full-frame); per-arm pose-silhouette проверки к ним неприменимы.

## Проверка (QA — PM)
- Headless-рендер боя: оба показывают cartoon-спрайт, верный масштаб/позиция на
  земле, оружие/VFX работают (`/tmp/qa_shots/combat_{dark_mage,knight}.png`).
- `animation_smoke_test` + `runtime_smoke_test` — зелёные.

## QA-Вердикт
Статус: PASSED
Дата: 2026-06-17
Тёмный маг и Рыцарь интегрированы в cartoon-стиле, анимируются движением (legacy-риг
bob/lean), смоуки зелёные. Ждёт визуальной приёмки пользователем в preview-билде;
после «ок» — перерисовка остальных 15 классов (отдельные задачи).

## Файлы
- `assets/sprites/characters/dark_mage.png`, `knight.png`
- `scripts/player.gd` (CARTOON_TRIAL_CLASSES, configure_character, _configure_player_rig)
- `tests/animation_smoke_test.gd`
- `docs/design/references/chars_cartoon/trial/` (исходники)
