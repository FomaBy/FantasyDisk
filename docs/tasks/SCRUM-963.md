# Artifact System: интеграция иконок, локализация и артефактный UI (0.2.1)

Статус: done
Приоритет: p1
Роль: UI/Backend Developer (Claude)
Версия: 0.2.1
Создано: 2026-07-09
Jira: SCRUM-963
Контур: Claude
Owner: claude-fable-orchestrator
Thread/Worker: claude-ui-scrum963-artifact-integration-20260709
Locked paths: `scripts/ui_screens.gd` (артефактные поверхности: TIER_LABELS/CLASS_RU/пометка/карточки/кодекс), `scripts/pause_stats_menu.gd` (экипировка), `scripts/route_map_screen.gd` (тир-хинт), `scripts/glossary.gd` (affinity), `scripts/meta_progression_tree_data.gd` (FLAG_DESC guaranteed_rare_shop), `scripts/progression_data_content.gd` (5 RU-титулов), `tests/runtime_smoke_test.gd` (анкер пометки), `tests/codex_data_smoke_test.gd`, `docs/design/systems/menus_ui.md`, `docs/design/content_registry.md`, `docs/design/artifact_shop_cursor_visual_kit.md`.

## Context / Problem

После редизайна пула (SCRUM-960/961) и пака иконок 154/154 (SCRUM-962) рантайм-UI
обязан единообразно показывать русские имена, редкость, классовые ограничения и
уникальные иконки на всех артефактных поверхностях. Гэпы разведки: reward-карточки
не использовали `artifact_<id>.png`, `TIER_LABELS` говорил «Тир 3 — легендарный»,
кодекс светил сырой id-chip, `CLASS_RU` покрывал 9/17, пометка «Интерпретация/
Тематика» осталась в старой семантике до-гейтовых affinity_mods.

## Required Change (по artifact_system_matrix §7.4)

- `TIER_LABELS` → «Обычный/Редкий/Эпический» (цвета прежние), номера тиров изъяты
  из player-facing строк; полученные артефакты показывают роллнутый
  `player.artifacts[].tier` с фоллбеком на корневой тир определения.
- Reward-карточки (элитка/босс/сундук + пост-бой) → уникальная `artifact_<id>.png`.
- Локализация: последние англ. титулы данных → RU; codex id-chip скрыт; CLASS_RU 17/17.
- Классовая пометка «Класс: <RU> · Возвышение 5» на карточках/кодексе/тултипах,
  синхронно с анкером runtime_smoke.
- Кодекс: запертые классовые (мета-Возвышение < 5) — силуэт/дим + условие разблокировки.
- Fallback-иконка не задействуется ни для одного финального id (гейт в тестах),
  ветка кода сохранена как dev-страховка.

## Result / Evidence

- **Данные:** `red_whetstone`→«Красный оселок», `star_compass`→«Звёздный компас»,
  `living_root`→«Живой корень», `captains_coin`→«Монета капитана»,
  `heavy_totem`→«Тяжёлый тотем» (id стабильны); латинских титулов в
  ARTIFACTS+SHOP_ITEMS не осталось (гейт в codex_data_smoke_test).
- **Редкость:** `TIER_LABELS {1:Обычный, 2:Редкий, 3:Эпический}`; хинт сундука
  маршрута без номеров («шанс эпического» и т.д.); сабтайтл босса «1 из 3
  эпических»; текст капстоуна «Связи в гильдии» приведён к факту (tier 3 =
  эпический). Роллнутый тир: HUD-тултип и чипы «Экипировки» паузы (имя цветом
  редкости + тултип «Название (Редкий) + описание»).
- **Иконки:** `_make_reward_card_icon` — артефакты на карточках элитки/босса/
  сундука (52px) и пост-боевого выбора (40px) грузят `artifact_<id>.png`;
  стат/атрибут-награды не тронуты. Событие random_artifact карточек не имеет
  (прямое применение в `_apply_event_outcome_to_player`) — артефакт виден в
  HUD-ряду/кодексе. Пауза: `_equipment_artifact_icon`.
- **Классовая пометка:** `_artifact_affinity_note` → «Класс: <RU[, RU]> ·
  Возвышение N» (у любого класс-артефакта; cross-class выпадение «Украденного
  герба» честно называет чужой класс). Генерик-«Интерпретация» осталась только
  у универсалов. Шоп-бейдж «!» — только на чужеклассовом товаре. Глоссарий
  `affinity` переписан («Классовый артефакт», семантика гейта + исключение герба).
- **Кодекс:** чипы = редкость + класс (+«Заперто»), сырой id изъят, shop-товары
  с чипом «Магазин»; запертые классовые — дим-ряд + тёмный силуэт иконки (приём
  скрытой звезды Атласа), эффект скрыт, секция «Как открыть» с условием
  «Откроется на Возвышении 5 — <Класс>»; силуэт удерживается и в досье
  (`texture_tint`). Разблокированные — обычные записи с иконкой и пометкой.
- **Run summary:** имена без тиров (лаконичность; редкость — в тултипах HUD/паузы).
- **Совместимость сейвов:** записи `{id,title}` без тира и голые title-строки
  живы (нормализация `_player_artifacts`, фоллбеки тултипов, null-гард теста).
- **Доки:** `menus_ui.md` §SCRUM-963 (канон поверхностей), таблицы
  `content_registry.md` (5 строк) и `artifact_shop_cursor_visual_kit.md`
  (17 строк) синхронизированы с RU-титулами данных.

Validation (godot_gate, полный список):
- `codex_data_smoke_test` PASS (161 записей, гейт иконок 154/154 + запрет латиницы)
- `null_artifacts_snapshot_test` PASS, `route_chest_artifact_test` PASS
- `rewards_data_integrity_test` PASS (154+7), `ui_icon_registry_smoke_test` PASS
- `class_artifacts_test` PASS (85/17), `artifact_family_roll_test` PASS (32 семьи)
- `ui_no_overlap_matrix_test` PASS, `runtime_smoke_test` PASS (полный)
- `python3 tools/validate_artifact_icons.py` exit 0 (info-замечания по 3 легаси
  иконкам SCRUM-690 — вне зоны 963)

## QA-Вердикт

Статус: —（ожидает SCRUM-964）
