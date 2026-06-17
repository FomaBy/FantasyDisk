# Backend: Оружие крутится вокруг персонажа и НЕ перекрывает его

Статус: done
Приоритет: high
Роль: Back-end (бой/анимации)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-455
QA: in_progress (2026-06-17)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Оружие должно КРУТИТЬСЯ вокруг персонажа и НЕ перекрывать его».

Раз атаки персонажа не анимируются (USE_ATTACK_ANIMATION=false), визуализацию боя
несёт оружие. Сейчас оружие крепится к сокету/перекрывает спрайт.

## Требования
1. Оружие **вращается по орбите вокруг персонажа** (визуально облетает его / держится
   на радиусе), отражая атаку; направление — к цели/курсору.
2. Оружие **НЕ перекрывает персонажа**: z-order/слой так, чтобы оружие не закрывало
   тело (или орбита выносит его за силуэт); при прохождении «перед» — не загораживать
   читаемость героя.
3. Согласовать с WeaponSocket/позицией оружия (player.gd), с прицелом (aim) и flip.
4. Не ломать урон/тайминги/механику оружия (только визуальное расположение/орбита).
5. Тест (smoke): оружие на орбите вокруг игрока, не перекрывает спрайт; атака
   корректна. Скрин/гиф в build/qa/.
6. CHANGELOG; current_game_state; systems/combat.

## Files / Assets / IDs
- scripts/player.gd (WeaponSocket/позиция оружия; _weapon_socket; flip/aim)
- scripts/*weapon*.gd (визуал/позиция оружия), scenes/*Weapon*.tscn
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Оружие вращается вокруг персонажа по орбите; направление к цели.
- [x] Оружие НЕ перекрывает спрайт героя (z-order/радиус); читаемость сохранена.
- [x] Урон/тайминги/механика целы; focused smoke зелёные; QA dump; CHANGELOG.

## Документация
docs/design/systems/combat.md, current_game_state.

## Result — 2026-06-17 Back-end
- `scripts/player.gd`: `VisualRoot/WeaponSocket` больше не остается в центре/hand mount. Сокет ставится на orbit radius `104px`, поворачивается по `attack_aim_direction()` / последнему направлению оружия и рендерится за телом героя (`z_index=-8`). При экипировке root оружия и `WeaponVisual` нормализуются к relative `z_index=0`, чтобы старые положительные z-index сцен не перекрывали персонажа.
- Добавлен permanent smoke `tests/weapon_orbit_smoke_test.gd`; `tests/runtime_smoke_test.gd` получил такой же SCRUM-455 guard в weapon-config блоке. QA dump: `build/qa/scrum455/weapon_orbit_runtime_dump.md`.
- Проверки PASS: `tests/weapon_orbit_smoke_test.gd`, `tests/animation_smoke_test.gd`, `tests/weapon_integrity_test.gd`, `tests/melee_weapon_targeting_test.gd`, `tests/runtime_smoke_test.gd`.

## QA-Вердикт (2026-06-17)
Статус: PASSED — оружие на орбите вокруг героя, не перекрывает спрайт

Проверено (фактически): `weapon_orbit_smoke_test` PASS; `animation_smoke` PASS; runtime_smoke
зелёный. `player.gd`: WeaponSocket на orbit radius 104px, поворот по attack_aim_direction,
`z_index=-8` (за телом) — не перекрывает героя; root/visual z нормализованы к 0. Урон/тайминги
не тронуты. Acceptance [x] все. done → Готово.
