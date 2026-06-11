# Задача Для Design-Агента: Укрупненные Спрайты Элиток И VFX Их Уникальных Атак

Статус: done
Создано: 2026-06-11
Автор: PM

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений, если требование понятно.

## Роль И Границы
Ты — Design-агент. Делай только работу своей роли (спрайты, VFX-ассеты).
Логику атак делает Back-end (задача `backend_elite_overhaul_size_unique_attacks_task.md`),
анимации — Animator (задача `animation_elite_unique_attacks_task.md`).
Если нужна чужая работа — handoff по docs/process/agent_role_boundaries_and_handoffs.md.

## Контекст
По решению пользователя элитки усиливаются: они становятся крупнее и получают
уникальные атаки. Сейчас спрайты элиток 192x192 — при программном увеличении
масштаба они будут мылиться. Нужны перерисованные более крупные спрайты и
VFX-ассеты для новых атак.

## Требования
1. Перерисовать спрайты 4 элиток в разрешении **256x256** (замена на месте,
   те же пути), сохранив их дизайн и читаемость силуэта:
   - `iron_bastion` (Железный Оплот) — `assets/sprites/elites/iron_bastion.png`
   - `night_stalker` (Ночной Сталкер) — `assets/sprites/elites/night_stalker.png`
   - `plague_prophet` (Чумной Пророк) — `assets/sprites/elites/plague_prophet.png`
   - `shard_marshal` (Маршал Осколков) — `assets/sprites/elites/shard_marshal.png`
2. Элитки должны выглядеть заметно «дороже» обычных монстров: больше деталей,
   аксессуары статуса (броня, трофеи, свечение).
3. Нарисовать VFX-ассеты уникальных атак (PNG, прозрачный фон, в `assets/sprites/effects/`):
   - `elite_shockwave_ring.png` — кольцевая ударная волна для slam-атаки Железного Оплота (~512x512);
   - `elite_shadow_trail.png` — шлейф тени для рывка-исчезновения Ночного Сталкера (~256x128);
   - `elite_poison_lob.png` — летящий ядовитый снаряд Чумного Пророка (~96x96);
   - `elite_crystal_shard.png` — кристальный осколок-снаряд Маршала Осколков (~96x96);
   - `elite_telegraph_circle.png` — универсальный круг-предупреждение зоны атаки (~512x512, мягкий край).
4. Стилистика VFX — в общем стиле игры, читаемость угрозы важнее красоты:
   игрок должен мгновенно понимать, куда не надо вставать.

## Files / Assets / IDs
- Спрайты: `assets/sprites/elites/*.png` (192x192 → 256x256).
- Новые VFX: `assets/sprites/effects/elite_*.png` (точные имена выше — их будет
  использовать Back-end, не менять без handoff).
- ID элиток в `docs/design/content_registry.md`: `iron_bastion`, `night_stalker`,
  `plague_prophet`, `shard_marshal`.

## Acceptance Criteria
- [ ] 4 спрайта элиток имеют размер 256x256, силуэты читаемы, без артефактов.
- [ ] 5 VFX-файлов созданы по указанным путям и именам, прозрачный фон.
- [ ] Telegraph-круг хорошо виден на всех 4 боевых фонах.
- [ ] Все новые ассеты внесены в `docs/design/content_registry.md`.

## Документация
- `docs/design/content_registry.md`: обновить разрешение спрайтов элиток, добавить VFX-ассеты.

## Самопроверка
- `sips -g pixelWidth -g pixelHeight` для всех новых файлов.
- Наложить telegraph и shockwave поверх каждого боевого фона и проверить читаемость.


## Результат (2026-06-11, Design)
- 4 спрайта элиток укрупнены до 256x256 (Lanczos + unsharp, альфа без артефактов) с добавленной аурой статуса в палитре каждой элитки (`tools/upsize_elite_sprites.py`). Проверено `sips`: все 256x256.
- Cutout-части элиток пересобраны из новых 256px спрайтов (`tools/slice_rig_cutouts.py`, `coord_scale` 256/192); манифест перегенерирован, сборка в покое пиксель-в-пиксель совпадает с новым артом.
- Созданы 5 VFX-ассетов в `assets/sprites/effects/` с точными именами: `elite_shockwave_ring.png` (512), `elite_shadow_trail.png` (256x128), `elite_poison_lob.png` (96), `elite_crystal_shard.png` (96, острие +X), `elite_telegraph_circle.png` (512, мягкий край + тики по ободу). Генератор: `tools/generate_elite_vfx.py`.
- Telegraph и shockwave проверены наложением на все 4 боевых фона — читаются на каждом (превью `build/rig_debug/telegraph_check.png`).
- `docs/design/content_registry.md`: обновлены разрешения спрайтов, актуализирован блок cutout-частей, добавлен раздел VFX-ассетов.
- Headless-тесты (animation, runtime, attack_vfx) зеленые.
