# BUG/UX: Кнопка «Назад» обрезана — использовать необрезанную (чуть большую) рамку

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-343
Связано: SCRUM-273 (button kit), SCRUM-318 (hover)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Кнопка назад в меню справа обрезана — надо использовать кнопку, которая не
обрезана (можно чуть большую)».

Кнопка «Назад» на экране выбора героя (header справа): `HeroSelectBackButton`
`_set_action_button_size(back_button, 170.0)` (ui_screens.gd:409-413). Узкая
рамка кнопки (170px, тип «back S» Red&Gold) обрезает текст/орнамент.

## Требования
1. Подобрать для «Назад» рамку/размер, при котором ни текст, ни орнамент НЕ
   обрезаются: увеличить ширину/высоту до non-cropped варианта (можно чуть больше),
   либо использовать другой button asset_type, который не режется на этом размере.
2. Проверить все back-кнопки одного класса (HeroSelectBackButton 409; и при том же
   симптоме — SkillTree/PatchNotes/Codex back 260px) — чтобы текст «Назад»/«Назад в
   меню» не обрезался; единый аккуратный вид.
3. Контент кнопки в content-зоне рамки (глобальное правило фреймов), не наезжает
   на окантовку; кнопка не выходит за экран справа (safe-area, как фикс SCRUM-257).
4. Тест (smoke): целевые экраны строятся; back-кнопки не обрезаны, в пределах
   экрана. Скрин в build/qa/. CHANGELOG; menus_ui.

## Files / Assets / IDs
- scripts/ui_screens.gd (HeroSelectBackButton 409-413; _set_action_button_size;
  _button_asset_type / RED_GOLD_BUTTON_* ; прочие back 1175/1284/1351)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [ ] «Назад» не обрезана (ни текст, ни орнамент), при необходимости чуть крупнее.
- [ ] В пределах экрана справа; контент в content-зоне; smoke зелёные; скрин; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md

## Result 2026-06-14

Implemented Back-end UI fix:
- `HeroSelectBackButton` increased from 170x104 to 240x104 so it uses the
  medium Red&Gold `back_m` frame instead of the cropped narrow `back_s` frame.
- Added runtime smoke coverage for `HeroSelectBackButton`,
  `SkillTreeBackButton`, `PatchNotesBackButton` and `CodexBackButton`: checks
  viewport bounds, minimum size, button height and content-zone width/height.
- QA dump written to `build/qa/scrum343/back_button_frames.md`.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.

Docs updated: `CHANGELOG.md`, `docs/design/systems/menus_ui.md`.
