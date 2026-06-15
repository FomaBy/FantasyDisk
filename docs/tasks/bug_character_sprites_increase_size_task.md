# UX: Увеличить размер всех персонажей на 20-30%

Статус: done
Приоритет: medium
Роль: Back-end (UI/бой)
Версия: 0.1.5
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-417
Связано: SCRUM-416 (портреты), SCRUM-412 (прозрачность), SCRUM-411 (видимость анимспрайта)

Dispatcher: routed to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`
on 2026-06-15 as an eligible active-sprint bug/UX stabilization row under
the 0.1.5 feature block. Keep reasoning High/no low.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Увеличить размер ВСЕХ персонажей на 20-30%».

В бою размер задаёт `BASE_SPRITE_SCALE := Vector2(0.28, 0.28)` (player.gd:32),
применяется к AnimatedSprite2D (player.gd:201) и ригу (1570). Персонажи мелковаты.
Портрет в выборе героя/кодексе — STRETCH_KEEP_ASPECT_CENTERED в фикс-панели (мелкий
из-за пустого поля вокруг арта).

## СТАТУС/УТОЧНЕНИЕ (2026-06-15)
- Боевой scale приведён к acceptance-диапазону SCRUM-417:
  **0.36** (`PLAYER_COMBAT_VISUAL_SCALE` / smoke expectations), не `0.5`.
- Preview персонажа в Hero Select и Codex увеличены через более плотное
  кадрирование/размер внутри content-zone, без наезда на орнамент.

## Требования
1. **Увеличить боевой размер персонажа на 20-30%**: поднять `BASE_SPRITE_SCALE`
   (~0.28 → 0.34-0.36) — применяется ко всем 17 классам (анимспрайт + риг).
2. **Согласовать хитбокс/коллайдер**: если размер персонажа влияет на восприятие,
   проверить, что коллизия/прицел/баланс не ломаются (по необходимости подогнать
   collision radius пропорционально, но НЕ менять геймплейные дистанции без нужды —
   согласовать с балансом).
3. **Портрет крупнее**: в выборе героя (HeroSelectLargePortrait) и кодексе персонаж
   должен занимать рамку плотнее (не теряться в пустом поле) — за счёт более тугого
   кадрирования арта ИЛИ увеличения scale портрета в content-зоне (не наезжая на рамку).
4. Не ломать центрирование/pivot (персонаж не «тонет» в землю), flip, позицию оружия.
5. Тест (smoke): персонажи крупнее в бою (scale выше) и в портрете; коллизия
   консистентна; no-overlap; на 1280×720/1920×1080/2560×1440. Скрин боя + выбора героя.
6. CHANGELOG; current_game_state; systems/combat|menus_ui.

## Files / Assets / IDs
- scripts/player.gd (BASE_SPRITE_SCALE 32; применение 201/1570; collision radius при наличии)
- scripts/ui_screens.gd (HeroSelectLargePortrait 752-758; _codex_portrait 1241)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Боевой размер персонажей увеличен на 20-30% (BASE_SPRITE_SCALE), все 17 классов.
- [x] Портрет в выборе героя/кодексе крупнее (персонаж заполняет рамку), без наезда на орнамент.
- [x] Хитбокс/прицел/баланс не сломаны; pivot/flip/оружие целы; smoke зелёные; скрины; CHANGELOG.

## Документация
docs/design/systems/combat.md, docs/design/systems/menus_ui.md, current_game_state.

## Результат
- `BASE_SPRITE_SCALE` нормализован в целевой SCRUM-417 диапазон:
  `Vector2(0.36, 0.36)` (+28.6% от исходных `0.28`) и применяется к
  full-frame `AnimatedSprite2D` и legacy cutout-rig fallback.
- Player collision radius оставлен `10.5`: gameplay ranges/balance не менялись,
  а smoke фиксирует визуальный рост отдельно от hurtbox.
- `HeroSelectLargePortrait` и Codex character portrait используют tighter
  `STRETCH_KEEP_ASPECT_COVERED`; Codex character portrait size увеличен до
  `216x216`, при этом no-overlap/safe-zone matrix зелёный.
- QA dumps: `build/qa/scrum417/combat_character_size_runtime_dump.md`,
  `build/qa/scrum417/character_size_runtime_dump.md`,
  `build/qa/scrum417/codex_character_portrait_runtime_dump.md`.
- Проверки PASS: `animation_smoke_test.gd`, `runtime_smoke_ui_test.gd`,
  `ui_no_overlap_matrix_test.gd`, `character_sprite_registry_alignment_test.gd`,
  `runtime_smoke_test.gd`.

## QA-Вердикт (2026-06-15)
Статус: PASSED — персонажи крупнее в бою (+29%) и в портретах

Проверено (фактически):
- **Боевой размер +29%**: `PLAYER_COMBAT_VISUAL_SCALE 0.36` → `BASE_SPRITE_SCALE=Vector2(0.36,0.36)`
  (было 0.28) — применяется к `body.scale` (player.gd:204) + ригу (1573) +
  `scenes/Player.tscn` scale 0.28→0.36. +29% = в диапазоне +20-30% (0.5 в промежуточном
  коммите был overshoot, скорректирован до 0.36).
- **Портреты крупнее**: hero-select large + codex портреты `STRETCH_KEEP_ASPECT_COVERED`
  (заполняют рамку), codex-портрет 176→216px — заметно крупнее, в content-зоне.
- **Тесты**: `runtime_smoke` + `runtime_smoke_ui` + `ui_no_overlap_matrix` +
  `animation_smoke` — все зелёные (коллизия/no-overlap консистентны при новом scale).

Acceptance:
- [x] Боевой размер персонажа +20-30% (0.28→0.36); коллайдер/scene согласованы.
- [x] Портреты (hero-select/codex) заметно крупнее, в content-зоне (no-overlap).
- [x] runtime + ui + no-overlap + animation smoke зелёные.

Статус done. Баги: нет.
