# Задача Для Animator-Агента: Анимации Уникальных Атак Элиток

Статус: done 2026-06-11. Результат: `enemy.gd` подключает backend-фазы `windup/strike/recover` к `cutout_rig_2d.gd` через animation variant `<elite_behavior>:<elite_attack_id>:<phase>` и длительность фазы; rig получил отдельные phase-aware body poses для Iron Bastion slam, Night Stalker shadow strike, Plague Prophet poison volley и Shard Marshal shard fan. `tests/animation_smoke_test.gd` покрывает phase variants/poses; `tests/animation_smoke_test.gd` и `tests/runtime_smoke_test.gd` проходят.
Создано: 2026-06-11
Автор: PM

Назначено: Animator
Разблокировано: `backend_elite_overhaul_size_unique_attacks_task.md` завершена, stable phase API получен.

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений, если требование понятно.

## Роль И Границы
Ты — Animator-агент. Делай только анимационную работу.
Логика атак — Back-end (`backend_elite_overhaul_size_unique_attacks_task.md`),
спрайты и VFX-ассеты — Design (`design_elite_sprites_upsize_attack_vfx_task.md`).
Если фазы атак в коде не готовы или ассетов не хватает — handoff соответствующему
агенту по docs/process/agent_role_boundaries_and_handoffs.md.

## Контекст
Элитки получают уникальные активные атаки (см. backend-задачу). Back-end дает
фазы windup / strike / recover для каждой атаки. Нужно, чтобы каждая атака
читалась телом персонажа, а не только VFX.

## Требования
1. Для каждой элитки сделать анимацию ее уникальной атаки по фазам windup → strike → recover:
   - `iron_bastion` — Slam: подъем корпуса/оружия вверх (windup), резкий удар вниз
     с приседанием (strike), медленное выпрямление (recover).
   - `night_stalker` — Теневой удар: сжатие в присед (windup), исчезновение
     с шлейфом `elite_shadow_trail.png`, резкий выпад при появлении (strike), отскок (recover).
   - `plague_prophet` — Ядовитый залп: ритуальный замах посоха/рук (windup),
     бросок по дуге (strike), покачивание (recover).
   - `shard_marshal` — Залп осколков: раскинутые руки, кристаллы поднимаются (windup),
     резкий жест вперед (strike), опускание рук (recover).
2. Длительности анимаций синхронизировать с таймингами фаз из backend-кода
   (не наоборот: тайминги боя — источник истины).
3. Анимации совместимы с pause/game state и с существующей animation scheme
   (`scripts/cutout_rig_2d.gd`, см. `docs/design/content_registry.md` про rig_parts).
4. Сохранить рабочими базовые состояния idle/walk/hit/death элиток.
5. Обновить/дополнить `tests/animation_smoke_test.gd` проверками новых состояний.

## Files / Assets / IDs
- Сцены: `scenes/EliteArmored.tscn`, `scenes/EliteStalker.tscn`,
  `scenes/ElitePoisoned.tscn`, `scenes/EliteCommander.tscn`.
- Rig: `assets/sprites/elites/rig_parts/`, `scripts/cutout_rig_2d.gd`.
- ID: `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`.

## Acceptance Criteria
- [x] У каждой элитки атака читается по позе тела даже без VFX.
- [x] Фазы анимации совпадают по времени с фазами урона из backend-логики.
- [x] Пауза игры корректно замораживает анимации атак.
- [x] `tests/animation_smoke_test.gd` проходит и покрывает новые состояния.

## Документация
- Обновить animation-разделы в `docs/design/` (animation doc / current_game_state.md).

## Самопроверка
- Запустить animation smoke test headless.
- Визуально проверить каждую атаку в бою и на паузе.

## Зависимости
- Старт после готовности фаз атак в backend-задаче (или параллельно по согласованным именам состояний).

## QA-Вердикт
Статус: PASSED

Легаси-задача (старт 2026-06-11), работа выполнена и в игре: enemy.gd подключает backend-фазы windup/strike/recover к cutout_rig_2d.gd через animation variant, phase-aware body poses для Iron Bastion/Night Stalker/Plague Prophet/Shard Marshal. Повторно всплыла в QA из-за board-sync revert (в .md «Статус: done» без блока ## QA-Вердикт/Статус: PASSED). QA-проверка 2026-06-30: tests/animation_smoke_test.gd PASS на origin/dev. Блок дописан, чтобы остановить дрейф.
