# ART/UX: Редизайн наград за уровень (обычный/элитка) — каждая награда в своём фрейме

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-338
QA: in_progress (2026-06-14)
Связано: SCRUM-328 (UI Overhaul: повышение/награды), SCRUM-327 (опорная стиля),
SCRUM-324 (asset-skill)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Пересмотреть дизайн наград по прохождению уровня (обычного или с элиткой).
Награда должна быть в отдельных фреймах в новом стиле (использовать скилл для
создания фреймов)».

Экраны наград (scripts/ui_screens.gd):
- `_show_reward_screen` (2432) «Награда за бой» — 3 варианта усилений, сейчас
  текстовыми блоками `_add_text_action_block` (без отдельных декоративных фреймов).
- `_show_elite_artifact_reward` (2526) — награда за элитку, одна центральная панель
  (_level_up_panel_style), артефакт(ы).
Это детальная спека «наградной» части кластера SCRUM-328.

## ОБЯЗАТЕЛЬНО — фреймы скиллом (директива пользователя)
Фреймы наград СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`scripts/generate_asset.py --prompt "<...>" --output rewards/<файл> --size <WxH>
--quality high`, OpenAI Images, `gpt-image-2`, PNG, ПРОЗРАЧНЫЙ фон), стиль
D&D + Dark Fantasy Dragon. Исходники — в docs/design/references/rewards/, внедрить
в assets/. Старые стили — в бэкап.

## Требования
1. **Каждая награда — в своём отдельном красивом фрейме** (карточка награды) в
   новом стиле, а не общий текстовый блок. Для экрана «Награда за бой»: 3 карточки
   наград, каждая в своём фрейме (иконка/заголовок/описание/кнопка «Получить»).
2. Для награды за **элитку**: артефакт(ы) в отдельных фреймах того же стиля
   (более «эпичный»/редкий вариант рамки допустим — отличать ценность).
3. Согласованность: единый стиль с кластером SCRUM-328 и опорной SCRUM-327;
   рамки/иконки/типографика в духе D&D + Dark Fantasy Dragon.
4. Глобальное правило фреймов: контент (иконка/текст/кнопка) — только в content-зоне
   фрейма, не на орнаменте; content margins ≥ окантовки. Карточки не накладываются
   друг на друга; весь текст читаем (без обрезки) на 1280×720 / 1920×1080 / 2560×1440.
5. Не ломать логику выбора/применения награды (_apply_reward_to_run /
   _apply_reward_to_active_run, переходы на карту/бой); клавиатура+геймпад-фокус.
6. Тест (smoke + no-overlap): оба экрана наград строятся; каждая награда в своём
   фрейме; no-overlap; текст в content-зоне. Скрины обоих экранов в build/qa/.
7. CHANGELOG; menus_ui; content_registry.

## Files / Assets / IDs
- scripts/ui_screens.gd (_show_reward_screen 2432; _show_elite_artifact_reward 2526;
  _add_text_action_block; _level_up_panel_style; _create_menu_box)
- assets/sprites/ui/frames/rewards/ (фреймы наград, скиллом) + бэкап старого
- docs/design/references/rewards/ (исходники скилла)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] «Награда за бой»: 3 награды, каждая в своём фрейме нового стиля (скиллом).
- [ ] Награда за элитку: артефакт(ы) в отдельных фреймах того же стиля.
- [ ] Контент только в content-зоне; карточки/текст не накладываются; текст читаем на 3 разрешениях.
- [ ] Логика наград цела; smoke + no-overlap зелёные; скрины; CHANGELOG.

## Документация
docs/design/systems/menus_ui.md, docs/design/content_registry.md, current_game_state.

## Blocker History — 2026-06-14
Новые reward frame PNG по требованиям должны быть созданы через
`fantasydisk-asset-generator`. В текущем окружении отсутствует `OPENAI_API_KEY`,
и Python-пакет `openai` недоступен, поэтому выполнить mandatory skill generation
невозможно. Runtime/layout переработка наград должна идти после готовности
ассетов или отдельным Back-end handoff; текущая Design-задача заблокирована до
восстановления skill-доступа.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved; task is
eligible for Design/Codex execution after the currently active Design task.


## Ключ настроен — блокер снят (2026-06-14)
`OPENAI_API_KEY` фактически сохранён в `~/.codex/.env` (права 600, вне git) +
автозагрузка в `~/.zshrc` — доступен в окружении автоматически в каждом новом
shell (включая shell Codex-воркеров). Скилл `fantasydisk-asset-generator`
(gpt-image-2) готов к вызову. Блокер по отсутствию `OPENAI_API_KEY` снят
окончательно; задача готова к исполнению через скилл.

## Blocked Again — 2026-06-14
Design queue audit after SCRUM-352 confirmed this task still requires reward
screen frames to be produced through `fantasydisk-asset-generator` / OpenAI
Images (`gpt-image-2`) and disallows old/local/random generators. The current
approved env source is available, but OpenAI Images returns:

```text
billing_hard_limit_reached
```

Task is blocked until OpenAI image generation billing is available again or PM
provides an approved alternative generation source.

## Разблокировано 2026-06-14 (PM)
Биллинг OpenAI восстановлен и ПРОВЕРЕН: тестовая генерация gpt-image-2 успешна. Блок `billing_hard_limit_reached` устарел — снят. Можно генерить скиллом.

## Progress Log
- 2026-06-14 — Started Design execution. Previous billing blocker is obsolete after SCRUM-340 successful `fantasydisk-asset-generator` run. Scope kept to Design assets, safe-zone metadata, previews and Back-end handoff for runtime layout integration.
- 2026-06-14 — Design assets completed. Generated two source frames through
  `fantasydisk-asset-generator` / OpenAI Images and built four production RGBA
  PNGs for battle reward and elite artifact reward card states. Runtime code was
  not changed; integration is handed off to Back-end.

## Result Summary

Design-ready reward frame kit:

- `assets/sprites/ui/frames/rewards/ui_frame_reward_card.png`
- `assets/sprites/ui/frames/rewards/ui_frame_reward_card_hover.png`
- `assets/sprites/ui/frames/rewards/ui_frame_reward_elite_artifact_card.png`
- `assets/sprites/ui/frames/rewards/ui_frame_reward_elite_artifact_card_hover.png`

Source references:

- `docs/design/references/rewards/reward_card_common_source.png`
- `docs/design/references/rewards/reward_card_elite_artifact_source.png`
- `docs/design/references/rewards/reward_frames_scrum338_metadata.json`

Preview / QA:

- `docs/design/previews/reward_frames_scrum338_sources_contact.png`
- `docs/design/previews/reward_frames_scrum338_contact_safe_zones.png`

Safe-zone contract:

- `reward_card`: source `768x1024`, texture margins `Vector4(96, 112, 96, 112)`,
  content margins `Vector4(132, 170, 132, 164)`.
- `reward_elite_artifact_card`: source `768x1024`, texture margins
  `Vector4(108, 130, 108, 130)`, content margins
  `Vector4(150, 202, 150, 190)`.

Verification:

- PNG validation PASS: 4/4 production reward frames are `768x1024` RGBA with
  transparent corners and non-empty alpha.
- Godot import PASS.
- Visual safe-zone preview PASS: content rectangles stay inside dark center
  fields and away from border gems, crests, metal, spikes and bottom ornaments.
- `tests/ui_no_overlap_matrix_test.gd` PASS on current runtime.
- `tests/runtime_smoke_test.gd` PASS on current runtime.
- Design QA report: `build/qa/scrum338/reward_frame_design_qa.md`.

Back-end handoff:

- `docs/tasks/backend_reward_screens_per_reward_frames_integration_task.md`
  created for runtime StyleBoxTexture constants, `_show_reward_screen` /
  `_show_elite_artifact_reward` integration and actual no-overlap/smoke checks.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: reward frame kit + safe-zone metadata + Back-end handoff)

Проверено (фактически):
- **4 reward-фрейма** (`assets/sprites/ui/frames/rewards/`): `reward_card` +
  hover, `reward_elite_artifact_card` + hover — все `768×1024` RGBA, прозрачные
  углы (corner_alpha=0), непустая alpha (≈571k–619k opaque px). 4 `.import`
  sidecars, Godot import без ошибок.
- **Safe-zone metadata** `reward_frames_scrum338_metadata.json`: content margins
  ≥ texture margins на обоих ассетах (reward content [132,170,132,164] ≥ tex
  [96,112,96,112]; elite content [150,202,150,190] ≥ tex [108,130,108,130]) —
  глобальное правило фреймов соблюдено.
- **Визуал** `reward_frames_scrum338_contact_safe_zones.png`: 4 фрейма в D&D Dark
  Fantasy Dragon стиле (elite — фиолетовый «эпичный»/редкий вариант, отличает
  ценность); content-rect внутри тёмного поля, не на орнаменте/самоцветах/гребнях;
  3-up раскладки (битва/элитка) — карточки не накладываются. Source-контакт +
  2 source PNG + metadata.
- **Тесты** (текущий рантайм): `ui_no_overlap_matrix_test` +
  `runtime_smoke_ui_test` + `runtime_smoke_test` — все passed. Рантайм
  `scripts/ui_screens.gd` не тронут (Design-only).
- **Back-end handoff** `backend_reward_screens_per_reward_frames_integration_task.md`
  создан (статус **«new»**).

⚠️ **Видимый редизайн экранов наград (3 карточки в фреймах + элитка) ещё НЕ в
рантайме**: требует интеграции `_show_reward_screen` / `_show_elite_artifact_reward`
со StyleBoxTexture-константами — Back-end задача («new»), вне Design-scope.
Проверю live-no-overlap на 3 разрешениях при готовности интеграции.

Acceptance (Design-scope):
- [x] Reward-фреймы созданы скиллом в едином D&D dragon-стиле (4 PNG: common+elite, normal+hover).
- [x] Elite — отдельный более эпичный фрейм (фиолетовый), отличает ценность.
- [x] Content margins ≥ окантовки; safe-zone превью (контент в зоне, карточки не накладываются).
- [x] Текущие no-overlap/runtime/ui smoke зелёные; Back-end handoff с metadata.
- [~] Live 3-карточная раскладка + no-overlap на 1280/1920/2560 — Back-end integration.

Статус review→done (Design-source). Баги: нет (видимая интеграция — delegated Back-end).
