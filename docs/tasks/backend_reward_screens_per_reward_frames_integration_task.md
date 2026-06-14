# Задача Для Back-end-Агента: Подключить Отдельные Фреймы Наград

Статус: in_progress
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design handoff SCRUM-338

## Контекст

Design SCRUM-338 подготовил production PNG для отдельных карточек наград боя и
награды за элитку. Runtime сейчас частично использует общий `_add_text_action_block`
для `_show_reward_screen`, а `_make_elite_artifact_card` все еще оформляется через
generic reward button theme. Нужно подключить новые reward-frame assets без
изменения логики выдачи наград, формул, пула наград, выбора или маршрутизации.

## Design Assets

Metadata/source:

- `docs/design/references/rewards/reward_frames_scrum338_metadata.json`
- `docs/design/previews/reward_frames_scrum338_contact_safe_zones.png`

Runtime PNG:

- `assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`
- `assets/sprites/ui/frames/rewards/ui_frame_reward_card_hover.png`
- `assets/sprites/ui/frames/rewards/ui_frame_reward_elite_artifact_card.png`
- `assets/sprites/ui/frames/rewards/ui_frame_reward_elite_artifact_card_hover.png`

Suggested StyleBoxTexture metrics:

| Frame | Texture Margins | Content Margins |
| --- | --- | --- |
| `reward_card` | `Vector4(96, 112, 96, 112)` | `Vector4(132, 170, 132, 164)` |
| `reward_elite_artifact_card` | `Vector4(108, 130, 108, 130)` | `Vector4(150, 202, 150, 190)` |

Source size for both frames: `768x1024`.

## Требования

1. `_show_reward_screen` должен показывать 3 награды как отдельные карточки с
   frame asset `ui_frame_reward_card*.png`: иконка, заголовок, описание и кнопка
   `Получить` должны сидеть только внутри content margins.
2. `_show_elite_artifact_reward` / `_make_elite_artifact_card` должны использовать
   `ui_frame_reward_elite_artifact_card*.png` для 3 artifact choices.
3. Не менять reward logic: `_random_rewards`, `elite_artifact_choices`,
   `_apply_reward_to_run`, autosave и route transitions должны остаться
   функционально прежними.
4. Сохранить mouse, keyboard and gamepad focus: вся карточка может оставаться
   кликабельной, но визуально content/button/hit-area не должен заходить на
   металл, самоцветы, шипы или гребни.
5. Проверить 1280x720, 1920x1080, 2560x1440: карточки не накладываются, текст не
   обрезается, content находится в safe-zone.

## Files

- `scripts/ui_screens.gd`
- `tests/runtime_smoke_test.gd`
- `tests/ui_no_overlap_matrix_test.gd`
- `docs/design/references/rewards/reward_frames_scrum338_metadata.json`

## Acceptance Criteria

- [ ] Battle reward screen uses 3 separate `reward_card` frames.
- [ ] Elite artifact reward screen uses 3 separate `reward_elite_artifact_card`
  frames.
- [ ] Runtime asserts content safe-zone / no ornament overlap where practical.
- [ ] Reward choice logic, autosave and route flow unchanged.
- [ ] `tests/runtime_smoke_test.gd` and `tests/ui_no_overlap_matrix_test.gd`
  pass; QA rect/screenshots written under `build/qa/scrum338/`.
