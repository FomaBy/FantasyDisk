# Задача Для Codex Design: Рестайл Всех Спрайтов Эффектов/Скиллов В D&D — Красиво И Лаконично

Статус: done 2026-06-12 (интегрировано Claude-Designer, QA PASSED)
Создано: 2026-06-12
Автор: PM
Dispatch: отправлено в существующий Design чат `019eabf1-6d54-7561-8af9-ce25cdf483a9` 2026-06-12.
Исполнитель: Codex Design (генерация, железное правило арта). Ревью/интеграция/коммит: Claude-Designer.

## Autonomy / Approval
Пользователь заранее одобрил. Работать автономно, поштучно с самопроверкой.

## Цель (решение пользователя)
Перерисовать ВСЕ спрайты анимаций скиллов и эффектов в стилистике D&D, но
**БЕЗ вырвиглазных и суперярких эффектов** — красиво и лаконично.

## Стилевая Рамка (главное в этой задаче)
1. **D&D-канон проекта**: живописная tabletop-подача, как актуальные артефакты
   и UI (референсы: `assets/sprites/ui/icons/artifacts/` — несколько штук,
   `assets/sprites/ui/frames/global/ui_panel_frame.png`).
2. **Сдержанность — обязательное требование**: приглушенная благородная палитра,
   НИКАКОГО кислотного неона, никакой 100%-насыщенности и чисто-белых пересветов;
   свечение мягкое и полупрозрачное; максимум один цветовой акцент на эффект.
3. **Лаконичность**: простая читаемая форма, минимум деталей — эффект живет
   доли секунды и должен читаться мгновенно, а не разглядываться;
   никакой мелкой мишуры/искр по всему кадру.
4. Эффекты обязаны оставаться ЧИТАЕМЫМИ на плоских боевых фонах (приглушенных) —
   проверять наложением на `assets/backgrounds/field_meadow.png` и `field_marsh.png`.

## Что Перерисовать (замена на месте, те же имена/размеры/прозрачность)
Все 19 файлов `assets/sprites/effects/`:
`beam_strip, briar_pool, dust_puff_0..2, elite_crystal_shard, elite_poison_lob,
elite_shadow_trail, elite_shockwave_ring, elite_telegraph_circle, hazard_zone,
impact_flash, impact_ring, music_note, poison_pool, slash_arc, sound_wave,
spark_pool, void_orb` — у каждого сверить текущий размер файла и сохранить его
(sips), RGBA, прозрачный фон.

Назначение каждого смотри в `docs/design/content_registry.md` (раздел VFX) и
`scripts/attack_vfx.gd` — форма должна соответствовать применению (slash_arc —
дуга замаха, beam_strip — тянущийся луч, telegraph — предупреждение зоны,
pools — лужи с настроением стихии, и т.д.). Тинтуемые кодом текстуры
(hazard_zone, telegraph) рисовать в нейтрально-светлой гамме под модуляцию.

## Порядок (поштучно)
1. Один файл за раз: сгенерировать → самопроверка (размер как был, alpha,
   читаемость поверх двух фонов, сдержанность палитры) → следующий.
2. Прогресс-лог в этом файле каждые 5 файлов.
3. По завершении: контрольный лист `assets/sprites/effects/effects_dnd_preview.png`
   (все эффекты на фрагменте боевого фона), smoke-тест runtime + attack_vfx.
4. Коммит НЕ делать. Статус: review + резюме. Ревью и коммит — Claude-Designer.

## Acceptance Criteria (Claude-Designer)
- [x] Все 19 заменены, размеры/имена/alpha сохранены.
- [x] Палитра сдержанная: ни одного кислотного/неонового эффекта, свечения мягкие.
- [x] Формы лаконичны и читаются мгновенно поверх плоских фонов.
- [x] Тинтуемые текстуры корректно модулируются кодом (проверить в бою).
- [x] Контрольный лист собран; smoke зеленые после интеграции.

## Документация
- content_registry (VFX-раздел), CHANGELOG (Unreleased) — при коммите Designer-ом.

## Progress Log

2026-06-12 — Started by Codex Design on `dev`; confirmed 19 PNG in `assets/sprites/effects/` and recorded original sizes/alpha.

2026-06-12 — Files 1-5 replaced and self-checked: `beam_strip.png`, `briar_pool.png`, `dust_puff_0.png`, `dust_puff_1.png`, `dust_puff_2.png`. Sizes preserved; RGBA alpha preserved; palette muted D&D/tabletop.

2026-06-12 — Files 6-10 replaced and self-checked: `elite_crystal_shard.png`, `elite_poison_lob.png`, `elite_shadow_trail.png`, `elite_shockwave_ring.png`, `elite_telegraph_circle.png`. Sizes preserved; `elite_telegraph_circle` kept neutral/tintable.

2026-06-12 — Files 11-15 replaced and self-checked: `hazard_zone.png`, `impact_flash.png`, `impact_ring.png`, `music_note.png`, `poison_pool.png`. Sizes preserved; `hazard_zone` kept warm-neutral for code modulation.

2026-06-12 — Files 16-19 replaced and self-checked: `slash_arc.png`, `sound_wave.png`, `spark_pool.png`, `void_orb.png`. Sizes preserved; forms simplified and softened to avoid neon/overbright reads.

## Result Summary

Статус переведен в `review` для Claude-Designer/QA.

- Все 19 PNG в `assets/sprites/effects/` заменены на месте.
- Имена, размеры и прозрачный RGBA сохранены.
- Добавлен контрольный лист `assets/sprites/effects/effects_dnd_preview.png` с проверкой поверх `field_meadow.png` и `field_marsh.png`.
- Godot import выполнен.
- Валидация размеров/alpha/hot-pixel sanity: OK, no overbright hot visible pixels.
- `tests/attack_vfx_smoke_test.gd` — passed.
- `tests/runtime_smoke_test.gd` — passed.
- Коммит не делался, как требовалось.

## QA-Вердикт (2026-06-12)
Статус: PASSED

Проверено (фактически):
- Состав/имена: ровно 19 PNG в `assets/sprites/effects/`, имена из спецификации
  на месте. OK.
- Размеры сохранены: сверка рабочего дерева с версией в HEAD — все 19 совпадают
  попиксельно (beam_strip 256x64, pools 256x256, shockwave/telegraph 512x512,
  dust 128x128, и т.д.). Ни один размер не изменён. OK.
- Alpha: все 19 — RGBA с прозрачным фоном (sips hasAlpha=yes). OK.
- Палитра (объективный анализ пикселей с alpha≥40 по всем 19 файлам):
  0.00% пересвеченных пикселей (нет чисто-белых ≥248,248,248) ни в одном файле;
  0.00% «кислотных» пикселей (нет s≥0.85 и v≥0.85); макс. насыщенность по набору —
  spark_pool 0.79, poison_pool 0.59, остальные ≤0.54. Требование «без неона/
  100%-насыщенности/чисто-белых пересветов» выполнено. OK.
- Тинтуемые текстуры: `hazard_zone` и `elite_telegraph_circle` — низкая насыщенность
  (0.23), нейтрально-светлые → корректно модулируются кодом. В бою HazardVfx их
  тинтует (подтверждено в QA VFX-задачи). OK.
- Читаемость: контрольный лист effects_dnd_preview наложением на field_meadow/
  field_marsh — формы лаконичны и читаются, фоны не «съедают» эффект. OK.
- Preview: `effects_dnd_preview.png` в `assets/` отсутствует, но НАМЕРЕННО вынесен
  чисткой проекта в `build/cleanup_backup_2026_06_12/assets/sprites/effects/`
  (задокументировано в content_registry:159 — preview не должен лежать в runtime
  assets). Артефакт жив и пригоден для review. Не дефект.
- Доки: content_registry (VFX-раздел, строки ~153-159) и CHANGELOG:33 описывают
  рестайл. OK.

Тесты: attack_vfx ✅, runtime ✅; регрессия — все 6 smoke зелёные.
Краевые случаи: тинтуемые текстуры (нейтраль под модуляцию), читаемость на 2 фонах,
сверка размеров до/после.

Баги: нет.

Примечание (не дефект): правки лежат в рабочем дереве (не закоммичены) — финальная
интеграция/коммит за Claude-Designer, как и предусмотрено задачей.


## Integrated / 2026-06-12 (Claude-Designer)
19 D&D-рестайл VFX PNG приняты и закоммичены. Дизайн-ревью: приглушённый палитра пергамент/бронза/земля, без неона/пересветов. Интеграция: размеры сохранены, внутренняя геометрия совместима с хардкод-константами HazardVfx/AttackVfx (RING_RADIUS/ZONE_RADIUS/SLASH_REACH) — проверено каптюрами (телеграф/детонация/слэш/level-up корректно масштабируются). attack_vfx/hazard/animation smoke зелёные.
