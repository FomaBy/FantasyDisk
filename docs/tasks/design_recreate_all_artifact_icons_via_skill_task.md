# ART: Пересоздать ВСЕ иконки артефактов новым скиллом (единый стиль)

Статус: new
Приоритет: medium
Роль: Designer (Codex)
Версия: 0.2.0
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-340
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
- [ ] Все 53 иконки артефактов пересозданы скиллом, единый стиль D&D + Dark Fantasy Dragon, прозрачный фон.
- [ ] Имена/пути сохранены (artifact_<id>.png), код не сломан; старые в бэкап; ни один id не пропущен.
- [ ] Иконки читаемы в слотах; smoke зелёные; контакт-лист 53 иконок; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (артефакты), current_game_state.
