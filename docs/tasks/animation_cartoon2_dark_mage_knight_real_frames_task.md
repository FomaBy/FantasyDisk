# ANIM: Настоящая анимация cartoon Тёмного мага и Рыцаря (idle + walk) через скилл

Статус: new
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
- [ ] idle + walk/move анимированы настоящими кадрами (≥5), looping, прозрачные.
- [ ] attack нет. Масштаб/позиция в бою корректны.
- [ ] animation_smoke + runtime_smoke зелёные; манифест валиден.
- [ ] Тот же мотив, мультяшный стиль сохранён.

## Files
- `assets/sprites/characters/{dark_mage,knight}.png` (+ sheets/cutout/spriteframes)
- `scripts/sliced_rig_manifest.gd` ИЛИ `assets/sprites/characters/full_frame/...`
- `scripts/player.gd` (CARTOON_TRIAL_CLASSES — снять после интеграции реальных кадров)
- `tests/animation_smoke_test.gd`
