# ART/UX: Уменьшить интенсивность анимаций атак оружия (не вырвиглазно)

Статус: done
Приоритет: medium
Роль: Back-end (VFX) → Designer
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-457
QA: in_progress (2026-06-17)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Чуток уменьшить анимации атак оружия, чтобы не выглядело вырвиглазно».

## Требования
1. Снизить интенсивность VFX атак оружия: меньше яркости/насыщенности/размера/
   частоты вспышек; убавить «кислотность» цветов и перекрытие экрана. Атака должна
   читаться, но НЕ слепить/перегружать.
2. Применить ко ВСЕМ классам/оружиям (beam/sweep/strip/projectile/aoe vfx).
3. Сохранить читаемость зоны урона (VFX совпадает с зоной поражения).
4. Тест (smoke): attack VFX строятся, спокойнее; зоны урона целы. Скрин/гиф.
5. CHANGELOG; current_game_state; systems/combat.

## Files / Assets / IDs
- scripts/attack_vfx.gd / class_weapon.gd / berserk_weapon.gd (параметры VFX: alpha/радиус/яркость)
- assets/sprites/effects/ (если ассеты слишком яркие — приглушить)
- tests/attack_vfx_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Интенсивность attack-VFX заметно снижена (яркость/размер/частота), не вырвиглазно, но читаемо; все классы.
- [x] Зоны урона совпадают; smoke зелёные; QA dump; CHANGELOG.

## Документация
docs/design/systems/combat.md, current_game_state.

## Result — 2026-06-17 Back-end
- `scripts/attack_vfx.gd`: добавлен общий calmness layer для attack VFX: additive-цвета десатурируются/приглушаются (`_calmed_color`), alpha capped, beam visual width уменьшен, trail intervals реже, dust/note clutter снижен. Damage radii, hit queries, cooldowns, weapon timings и targeting не менялись.
- `tests/attack_vfx_smoke_test.gd`: smoke теперь проверяет SCRUM-457 calmness contract (slash additive alpha cap, narrowed beam visual, ограничение нот sound/ring VFX) и пишет QA dump `build/qa/scrum457/attack_vfx_calmness_dump.md`.
- Проверки PASS: `tests/attack_vfx_smoke_test.gd`, `tests/weapon_orbit_smoke_test.gd`, `tests/weapon_integrity_test.gd`, `tests/animation_smoke_test.gd`, `tests/runtime_smoke_test.gd`.

## QA-Вердикт (2026-06-17)
Статус: PASSED — attack-VFX приглушены (calmness layer), читаемо, зоны урона целы

Проверено (фактически): `attack_vfx_smoke_test` PASS (проверяет SCRUM-457 calmness contract:
slash additive alpha cap, narrowed beam, ограничение note/ring VFX); runtime_smoke зелёный.
`attack_vfx.gd`: additive-цвета десатурированы/приглушены, alpha capped, beam уже, trail реже,
clutter снижен. Damage radii/hit queries/cooldowns/timings не менялись. Acceptance [x] все. done → Готово.
