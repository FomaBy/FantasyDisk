# ANIM: Настоящая анимация cartoon Тёмного мага и Рыцаря (idle + walk) через скилл

Статус: done
Приоритет: high
Роль: Animator (Codex)
Исполнитель: Codex (скилл fantasydisk-animation-director)
Версия: 0.1.6
Создано: 2026-06-17
Автор: PM (запрос пользователя)
Jira: SCRUM-473
Связано: SCRUM-456 (cartoon style), SCRUM-472 (интеграция-проба, legacy-риг)

## Autonomy / Approval
Полная автономия. Пользователь одобрил направление.

## Контекст (запрос пользователя)
«Полностью перерисуй спрайты тёмного мага и рыцаря и сделай анимацию используя
скилы. Главный мотив старый, но чуть более мультяшно.»
PM перерисовал спрайты (заметно мультяшнее, тот же мотив) и поставил их в игру.
Сейчас они анимируются ВРЕМЕННЫМ legacy-ригом (целый спрайт bob/lean) — нужна
НАСТОЯЩАЯ покадровая анимация через animation-director скилл.

## Источники (новые cartoon2-спрайты)
- В игре: `assets/sprites/characters/dark_mage.png`, `assets/sprites/characters/knight.png` (512, прозрачные).
- Чистые исходники 1024: `docs/design/references/chars_cartoon/trial_v2/{dark_mage,knight}_cartoon2.png`.
- Style-anchor: `docs/design/references/chars_cartoon/character_cartoon_anime_style_sheet.md` (SCRUM-456).

## Dispatch

- 2026-06-17 17:36 UTC — Documentation dispatcher routed SCRUM-473 to Animator
  thread `019eb156-710c-71f0-8903-eada762dceb3`. Source gate verified:
  runtime `dark_mage.png`/`knight.png`, clean cartoon2 source PNGs, and accepted
  SCRUM-456 style anchor exist. Keep reasoning High/no low.

## Требования (Output Contract скилла)
- `idle`: анимирован, looping (дыхание/покачивание робы/плаща, секундари-моушн).
- `move`/`walk`: ≥5 кадров, looping — читаемый цикл с движением ног и рук
  (contact/passing/lift/recovery). Маг — может быть лёгкая левитация с робой, но
  ноги/движение должны читаться.
- **`attack` НЕ делать** — за атаки отвечает оружие (USE_ATTACK_ANIMATION=false).
- Прозрачный RGBA, безопасные гуттеры/паддинг при sprite-sheet нарезке.
- Пайплайн на выбор скилла: rig→sprite-sheet (Skeleton2D/Bone2D) ИЛИ
  пере-тюненный sliced-cutout-rig + манифест под cartoon-пропорции (НЕ старые v2-боксы).

## Интеграция
- Подключить как `<class>_spriteframes.tres` (idle/walk/move) ИЛИ корректный
  sliced-rig в `sliced_rig_manifest.gd` под новые спрайты.
- Убрать dark_mage/knight из `CARTOON_TRIAL_CLASSES` (player.gd) ПОСЛЕ подключения
  настоящих кадров (или оставить, если выбран sliced-rig — согласовать с Back-end).
- Прогнать `validate_animation_manifest.py` + animation smoke; обновить тесты.

## Acceptance Criteria
- [x] idle + walk/move анимированы настоящими кадрами (≥5), looping, прозрачные.
- [x] attack нет. Масштаб/позиция в бою корректны.
- [x] animation_smoke зелёный; runtime_smoke заблокирован unrelated UI-дефектом; bundled manifest validator ожидаемо требует `attack_primary`, хотя SCRUM-473 явно запрещает attack.
- [x] Тот же мотив, мультяшный стиль сохранён.

## Files
- `assets/sprites/characters/{dark_mage,knight}.png` (+ sheets/cutout/spriteframes)
- `scripts/sliced_rig_manifest.gd` ИЛИ `assets/sprites/characters/full_frame/...`
- `scripts/player.gd` (CARTOON_TRIAL_CLASSES — снять после интеграции реальных кадров)
- `tests/animation_smoke_test.gd`

## Result / Animator report

Done 2026-06-17 (Codex Animator, `fantasydisk-animation-director`):
- Built real full-frame cartoon2 motion frames from accepted runtime transparent
  sprites: `assets/sprites/characters/full_frame/dark_mage/` and
  `assets/sprites/characters/full_frame/knight/`.
- Live SpriteFrames now use `idle` (5f loop), `walk` (5f loop) and `move`
  (5f walk alias loop) only:
  `assets/sprites/characters/dark_mage_spriteframes.tres`,
  `assets/sprites/characters/knight_spriteframes.tres`.
- Attack/body attack rows are intentionally absent; weapons keep owning attacks
  through `USE_ATTACK_ANIMATION=false`.
- Safe-gutter cartoon2 sheets:
  `assets/sprites/characters/cartoon2/dark_mage/dark_mage_cartoon2_anim_sheet.png`,
  `assets/sprites/characters/cartoon2/knight/knight_cartoon2_anim_sheet.png`
  (`512x512` cells, `48 px` gutters/padding metadata, transparent RGBA).
- QA artifacts:
  `build/qa/scrum473_cartoon2_dark_mage_knight_anim/animation_manifest.json`,
  `frame_alpha_stats.json`, contact sheets and idle/walk GIFs.
- Runtime integration: `scripts/player.gd` removed Dark Mage/Knight from
  `CARTOON_TRIAL_CLASSES`, so both now use real full-frame SpriteFrames and hide
  the temporary legacy cartoon rig. `tests/animation_smoke_test.gd` now asserts
  both classes expose 5f `idle`/`walk`/`move` loops and no `attack` /
  `attack_primary` animation.

Validation:
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd`.
- EXPECTED LIMITATION: `validate_animation_manifest.py
  build/qa/scrum473_cartoon2_dark_mage_knight_anim/animation_manifest.json`
  reports missing `attack_primary` for both entities. This is a validator
  contract mismatch: SCRUM-473 explicitly sets `attack_required=false` and
  forbids body attack animation because weapons own attacks.
- BLOCKED UNRELATED: runtime smoke currently fails at
  `tests/runtime_smoke_test.gd::_assert_hero_select_v3_back_button_safe` with
  `Expected hero select v3 back button to exist`, from active UI work outside
  Animator scope. No UI/gameplay/balance changes were made here.
