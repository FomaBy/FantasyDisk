# ART: Пересоздать ВСЕ иконки артефактов новым скиллом (единый стиль)

Статус: done
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-340
QA: in_progress (2026-06-14)
Связано: SCRUM-327 (опорная стиля UI Overhaul), SCRUM-324 (asset-skill)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Используя новый скилл по созданию картинок, надо полностью пересоздать иконки
ВСЕХ существующих артефактов, и все будущие надо делать через этот скилл».

Артефактов: 53 (ARTIFACTS, scripts/progression_data_content.gd:58). Иконки сейчас:
`assets/sprites/ui/icons/artifacts/artifact_<id>.png`, 256×256, 53 файла.
Используются в магазине, наградах, досье паузы (pause_stats_menu.gd:353; ui_screens
1547/5132/5161 _artifact_icon_texture).

## ОБЯЗАТЕЛЬНО — скилл генерации (директива пользователя)
ВСЕ иконки СОЗДАВАТЬ скиллом `fantasydisk-asset-generator`
(`scripts/generate_asset.py --prompt "<...>" --output icons/artifacts/<id>
--size 1024x1024 --quality high`, OpenAI Images, `gpt-image-2`, PNG, ПРОЗРАЧНЫЙ
фон), стиль D&D + Dark Fantasy Dragon. Старый способ не использовать.
Будущие иконки артефактов — тоже только этим скиллом (закреплено в AGENTS.md).

## Требования
1. Пересоздать иконки ВСЕХ 53 артефактов (по списку ARTIFACTS, по их id и
   title/description — иконка отражает суть артефакта) единым набором в новом
   стиле D&D + Dark Fantasy Dragon: одинаковая рамка-подложка/освещение/масштаб
   предмета, прозрачный фон, центрированный предмет.
2. Генерация скиллом в высоком разрешении (напр. 1024×1024), затем привести к
   игровому формату 256×256 (или выше, если апскейл иконок планируется) —
   сохранить совместимость с текущим путём `artifact_<id>.png`.
3. Сохранять: исходники в docs/design/references/icons/artifacts/, игровые — в
   assets/sprites/ui/icons/artifacts/ (тем же именем artifact_<id>.png, чтобы код
   не менять). Старые иконки — в бэкап (docs/design/backups/...), не удалять.
4. Полный охват: ни один из 53 id не пропущен; сверить список сгенерированных с
   ARTIFACTS (нет лишних/недостающих). Привести таблицу id → готово.
5. Единый стиль с опорной SCRUM-327 и общим UI Overhaul; читаемость иконки на
   мелком размере (в слотах магазина/досье).
6. Тест (smoke): магазин/награды/досье паузы строятся; для каждого артефакта
   иконка грузится (нет «дыр»/fallback); прозрачный фон. Контакт-лист всех 53
   иконок в docs/design/previews/ + скрин слотов в build/qa/.
7. CHANGELOG; content_registry.

## Files / Assets / IDs
- scripts/progression_data_content.gd (ARTIFACTS 58 — список из 53 id/title/desc)
- assets/sprites/ui/icons/artifacts/artifact_<id>.png (53 файла, заменить)
- docs/design/references/icons/artifacts/ (исходники), docs/design/backups/ (старые)
- scripts/ui_screens.gd (_artifact_icon_texture 5161), scripts/pause_stats_menu.gd (353)
- tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] Все 53 иконки артефактов пересозданы скиллом, единый стиль D&D + Dark Fantasy Dragon, прозрачный фон.
- [x] Имена/пути сохранены (artifact_<id>.png), код не сломан; старые в бэкап; ни один id не пропущен.
- [x] Иконки читаемы в слотах; smoke зелёные; контакт-лист 53 иконок; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (артефакты), current_game_state.

## Blocker History — 2026-06-14
Design/Codex проверил mandatory skill path. Все 53 artifact icons должны быть
пересозданы через `fantasydisk-asset-generator` (`gpt-image-2`), но текущая среда
не содержит `OPENAI_API_KEY`, а Python `openai` import падает с
`ModuleNotFoundError`. Старый/ручной генератор запрещён директивой задачи.
Задача заблокирована до восстановления API-доступа к skill.

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
Design queue audit after SCRUM-352 confirmed this task still requires all
artifact icons to be recreated through `fantasydisk-asset-generator` / OpenAI
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

- 2026-06-14 — Взято в работу Design/Codex после heartbeat audit. Branch:
  `dev`. Повторная проверка очереди показала SCRUM-340 первым доступным Design
  item; OpenAI Images уже был проверен как available в предыдущем work block.
  Scope: asset generation/postprocess/backup/previews/docs only; runtime code
  remains unchanged because artifact paths stay stable.
- 2026-06-14 — Completed. Generated 53/53 source PNGs through
  `fantasydisk-asset-generator` / OpenAI Images (`gpt-image-2`, `1024x1024`,
  `quality=high`, `--no-task`), postprocessed chroma background to alpha,
  downscaled/cropped into final `256x256` RGBA runtime icons at the existing
  stable paths, and imported them in Godot. Runtime code was not changed.

## Result Summary

- Final runtime icons: `assets/sprites/ui/icons/artifacts/artifact_<id>.png`
  (`53` files, `256x256`, RGBA, transparent background).
- Source references:
  `docs/design/references/icons/artifacts/artifact_<id>_source.png` (`53`
  files, generated by `fantasydisk-asset-generator`).
- Backup of previous icons:
  `docs/design/backups/artifact_icons_pre_scrum340_2026_06_14/` (`53` files).
- Coverage/QA manifests:
  `docs/design/references/icons/artifacts/artifact_icons_scrum340_manifest.json`
  and `build/qa/scrum340/artifact_icons_scrum340_manifest.json`.
- Previews:
  `docs/design/previews/artifact_icons_scrum340_contact.png` and
  `docs/design/previews/artifact_icons_scrum340_40px_readability.png`.

Verification:

- Coverage PASS: `ProgressionData.ARTIFACTS = 53`, final icon files = 53,
  missing = `[]`, extra = `[]`.
- PNG validation PASS: 53/53 final icons are `256x256` RGBA with transparent
  outer alpha and non-empty item alpha.
- Godot import PASS.
- `tests/runtime_smoke_ui_test.gd` PASS.
- `tests/ui_no_overlap_matrix_test.gd` PASS.
- `tests/runtime_smoke_test.gd` PASS.

## QA-Вердикт (2026-06-14)
Статус: PASSED — все 53 иконки артефактов пересозданы скиллом, единый стиль, полный охват

Проверено (фактически):
- **Полный охват 53/53**: id из `ARTIFACTS` (progression_data_content.gd) точно
  совпадают с файлами `assets/sprites/ui/icons/artifacts/artifact_<id>.png` —
  `missing=[]`, `extra=[]`. Манифест `build/qa/scrum340/...manifest.json`:
  `count=53`, `failed=0`.
- **PNG-валидация 53/53**: все `256×256`, color-type RGBA(6); прозрачная окантовка
  (border alpha ≤ 40 на всех 53) + непустой предмет (opaque-пикселей много на всех 53).
- **Бэкап/исходники**: 53 старых в `docs/design/backups/artifact_icons_pre_scrum340_2026_06_14/`,
  53 source в `docs/design/references/icons/artifacts/artifact_<id>_source.png`.
- **Визуал** `artifact_icons_scrum340_contact.png`: все 53 в едином D&D Dark Fantasy
  Dragon стиле — единое освещение/масштаб, центрированный предмет, прозрачный фон
  (checkerboard). `..._40px_readability.png`: каждая узнаваема в slot-размере
  (сапоги/орб/линза/кодекс/амулеты/оружие/кольца/кристаллы — различимы).
- **Тесты**: `runtime_smoke_ui_test` («Runtime UI smoke suite passed» — строит
  магазин/награды/досье паузы, грузит иконки без fallback-дыр),
  `ui_no_overlap_matrix_test`, `runtime_smoke_test` — все passed. Код путей иконок
  не менялся (стабильные пути artifact_<id>.png).

Acceptance:
- [x] Все 53 иконки пересозданы скиллом (gpt-image-2), единый стиль, прозрачный фон.
- [x] Имена/пути сохранены (код не сломан); старые в бэкап; ни один id не пропущен.
- [x] Читаемы в слотах (40px-превью); smoke зелёные; контакт-лист 53; CHANGELOG/content_registry.

Статус done. Баги: нет. (Примечание: live shop-capture в headless зависает из-за
требований игрового стейта — функциональную загрузку иконок покрывает зелёный
runtime_smoke_ui; визуал покрыт контакт-листом + 40px readability.)
