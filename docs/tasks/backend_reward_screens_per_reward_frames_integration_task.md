# Задача Для Back-end-Агента: Подключить Отдельные Фреймы Наград

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Jira: SCRUM-404
Создано: 2026-06-14
Автор: Design handoff SCRUM-338
QA: in_progress (2026-06-14)

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

- [x] Battle reward screen uses 3 separate `reward_card` frames.
- [x] Elite artifact reward screen uses 3 separate `reward_elite_artifact_card`
  frames.
- [x] Runtime asserts content safe-zone / no ornament overlap where practical.
- [x] Reward choice logic, autosave and route flow unchanged.
- [x] `tests/runtime_smoke_test.gd` and `tests/ui_no_overlap_matrix_test.gd`
  pass; QA rect/screenshots written under `build/qa/scrum338/`.

## Result

2026-06-14 Back-end SCRUM-404 done:

- `_show_reward_screen` now renders 3 `BattleRewardButton*` cards using
  `ui_frame_reward_card.png` / hover frame, with icon/title/preview/description
  and visible `Получить` label inside the metadata-scaled SCRUM-338 content
  margins. Whole-card click, focus neighbors, autosave and route return are
  preserved.
- `_make_elite_artifact_card` now uses
  `ui_frame_reward_elite_artifact_card.png` / hover frame and a strict
  `EliteArtifactRewardContent` safe-zone container for icon, title, tier,
  description and interpretation. Reward generation and `_apply_reward_to_run`
  logic were not changed.
- Runtime smoke asserts texture paths and safe-zone containment for battle and
  elite reward cards, and writes dumps to `build/qa/scrum338/`.

Verification:

- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd`

## QA-Вердикт (2026-06-14)
Статус: PASSED — закрывает видимый редизайн экранов наград (Design 338 + Back-end 404)

Проверено (фактически):
- **Рантайм подключает reward-фреймы** (ui_screens.gd:151-159): `REWARD_CARD_PATH`/
  `REWARD_ELITE_CARD_PATH` (+hover) + texture/content margins из SCRUM-338 metadata
  (96,112,96,112 / content 132,170,132,164). Билдер `_reward_card_style` (5672)
  масштабирует content margins из 768×1024 в display, StyleBoxTexture + fallback;
  meta `reward_frame_kind`=battle(3234)/elite_artifact(3308).
- **Runtime-дамп `battle_reward_reward_frames.md`**: 3 карточки `BattleRewardButton0/1/2`
  @ x=332/650/968 size 300×430 — **НЕ накладываются** (632<650, 950<968), все на
  `ui_frame_reward_card.png`, content-rect внутри safe-zone карточки.
- **Runtime-дамп `elite_reward_reward_frames.md`**: 3 карточки `EliteArtifactRewardButton0/1/2`
  @ x=268/630/992 size 340×502 — **НЕ накладываются** (608<630, 970<992), все на
  `ui_frame_reward_elite_artifact_card.png` (более эпичный фрейм), content внутри safe.
- **Тесты**: runtime-assert `_assert_reward_cards_use_scrum338_frames` (проверяет
  текстуры + safe-zone containment) — passed; `ui_no_overlap_matrix_test`,
  `runtime_smoke_ui_test`, `runtime_smoke_test` — все passed. Логика наград
  (`_random_rewards`/`_apply_reward_to_run`/autosave/route) — без изменений
  (smoke прогнал elite-reward сценарий).

Acceptance:
- [x] «Награда за бой»: 3 отдельные карточки на reward_card фрейме (runtime-дамп подтверждает).
- [x] Награда за элитку: 3 артефакта на elite_artifact фрейме.
- [x] Content в safe-zone, карточки не накладываются (точные rect из дампов).
- [x] Reward logic/autosave/route не тронуты; runtime+no-overlap+ui smoke зелёные; QA-дампы в build/qa/scrum338/.

Петля наград закрыта: SCRUM-338 (frame kit) + 404 (рантайм-интеграция). Баги: нет.
(Примечание: визуал — runtime rect-дампы вместо скрина, т.к. экран наград требует
игрового стейта в headless; rect-дампы точнее скрина для no-overlap проверки.)
