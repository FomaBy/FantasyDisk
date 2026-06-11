# Задача Для Back-end-Агента: Усиление Элиток — Размер И Уникальные Атаки

Статус: done 2026-06-11. Результат: (1) размер — Design уже выкатил спрайты 256x256, при прежнем scale сцен это дает ~1.33-1.35x видимого размера, поэтому scale не менялся (без двойного увеличения); collision radius всех 4 сцен увеличен в 1.35x, contact_range подгоняется автоматически; (2) уникальные атаки реализованы data-driven в `scripts/enemy.gd::ELITE_ATTACK_CONFIG`: iron_bastion slam_wave (замах 0.6с, кольцо 260, урон+отбрасывание, кд 6с), night_stalker shadow_strike (тень 0.5с, телепорт за спину, кд 7с), plague_prophet poison_volley (3 lob, лужи 3с с тиками, кд 8с), shard_marshal shard_fan (веер 5 осколков, кд 6с); (3) все атаки телеграфируются финальным ассетом elite_telegraph_circle.png (VFX Design уже готовы, placeholder не понадобился); (4) урон атак ограничен 25% max HP игрока, во время атаки элитка стоит; (5) фазы windup/strike/recover/idle доступны Animator через сигнал `elite_attack_phase_changed` и meta `elite_attack_phase`. Smoke test проверяет полный цикл фаз всех 4 элиток, проходит. Документация обновлена (current_game_state, content_registry).
Создано: 2026-06-11
Автор: PM

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений, если требование понятно.

## Роль И Границы
Ты — Back-end-агент. Делай только работу своей роли (логика, баланс, интеграция).
Арт делает Design (`design_elite_sprites_upsize_attack_vfx_task.md`),
анимации — Animator (`animation_elite_unique_attacks_task.md`).
Если ассеты/анимации еще не готовы — реализуй логику с текущими ассетами и
placeholder-VFX через `scripts/attack_vfx.gd`, подключение финальных ассетов
оформи как продолжение после их готовности.

## Контекст
Решение пользователя: элитки должны ощущаться значимо сильнее. Сейчас у них
есть пассивные способности (щит, рывки, ядовитые зоны, аура — см.
`docs/design/content_registry.md`, строки про elites), но нет уникальных
активных атак, и размер у них как у обычных мобов (спрайт 192x192).

## Требования
1. **Размер**: увеличить элиток в ~1.35 раза относительно текущего размера
   (scale узла + пропорционально collision shape и `contact_range`).
   После выхода спрайтов 256x256 от Design убедиться, что итоговый видимый
   размер соответствует этому масштабу без двойного увеличения.
2. **Уникальные атаки** — реализовать по одной телеграфированной активной атаке
   на элитку (предложение PM, разумные отклонения допустимы):
   - `iron_bastion` (Железный Оплот): **Slam** — пауза-замах ~0.6с, затем кольцевая
     ударная волна радиусом ~260: урон + отбрасывание игрока. Кулдаун ~6с.
   - `night_stalker` (Ночной Сталкер): **Теневой удар** — исчезает на ~0.5с,
     появляется за спиной игрока и наносит быстрый удар. Кулдаун ~7с.
   - `plague_prophet` (Чумной Пророк): **Ядовитый залп** — 3 снаряда по дуге
     (lob), в точках падения остаются малые ядовитые лужи на ~3с. Кулдаун ~8с.
   - `shard_marshal` (Маршал Осколков): **Залп осколков** — веер из 5 кристальных
     снарядов в сторону игрока. Кулдаун ~6с.
3. Каждая атака обязана иметь **telegraph** (предупреждение) до нанесения урона:
   зона/направление подсвечивается заранее (asset `elite_telegraph_circle.png`
   от Design; до его готовности — `AttackVfx.ring_pulse`).
4. Балансные рамки: уникальная атака при попадании снимает не более ~25% максимального
   HP игрока среднего билда на текущем route_stage; от всех атак можно увернуться.
5. Состояния атак реализовать так, чтобы Animator мог повесить на них анимационные
   состояния (явные фазы windup / strike / recover, сигналы или экспортируемые имена состояний).
6. Зафиксировать параметры атак в данных (константы/конфиг в стиле проекта,
   предпочтительно data-driven, как в `scripts/progression_data.gd`).

## Files / Assets / IDs
- Сцены: `scenes/EliteArmored.tscn`, `scenes/EliteStalker.tscn`,
  `scenes/ElitePoisoned.tscn`, `scenes/EliteCommander.tscn`.
- Скрипты: `scripts/enemy.gd` (база), `scripts/combat_director.gd` (спавн/баланс),
  `scripts/attack_vfx.gd` (временные VFX), `scripts/enemy_projectile.gd` (снаряды).
- Будущие ассеты Design: `assets/sprites/effects/elite_shockwave_ring.png`,
  `elite_shadow_trail.png`, `elite_poison_lob.png`, `elite_crystal_shard.png`,
  `elite_telegraph_circle.png`.
- ID: `iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`.

## Acceptance Criteria
- [ ] Элитки визуально и по коллизии крупнее обычных мобов (~1.35x), без мыла после интеграции 256x256 спрайтов.
- [ ] У каждой из 4 элиток работает своя уникальная атака с telegraph-фазой.
- [ ] От каждой атаки можно увернуться движением.
- [ ] Фазы атак доступны Animator-агенту (windup/strike/recover различимы извне).
- [ ] Параметры атак вынесены в данные, а не разбросаны по коду.
- [ ] `tests/runtime_smoke_test.gd` проходит; добавлены проверки на спавн элиток с атаками.

## Документация
- `docs/design/current_game_state.md`: раздел про элиток — размер и уникальные атаки.
- `docs/design/content_registry.md`: обновить описания способностей элиток.

## Самопроверка
- Запустить headless smoke test:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- Запустить бой с каждой элиткой и проверить атаку, telegraph, кулдаун, увороты.

## Handoffs
- Design: `design_elite_sprites_upsize_attack_vfx_task.md` (спрайты 256, VFX).
- Animator: `animation_elite_unique_attacks_task.md` (анимации фаз атак).
