# Mockup-спека — Бой / HUD (SCRUM-564, эпик SCRUM-481 UI Overhaul 2K)

База **2560×1440**, `stretch=canvas_items`, `aspect=keep`. Редизайн боевого HUD:
per-слот @2K-рамки вместо общих `minimal_metal`-фреймов, которые ужимались под слот
и мылили орнамент. Стиль — единый D&D + Dark Fantasy Dragon (тот же bright-минимал
amber-кит, что в остальных @2K-рамках блока Меню/Навигация SCRUM-486).

## ЭТАП 1 — раскладка / метрики @2560×1440

Координаты уже зафиксированы код-константами `CHUD_*_2K` в `scripts/ui_screens.gd`
(блок SCRUM-487) и сверены рантайм-верификатором. Этот редизайн их НЕ меняет —
только подменяет рамки на нарисованные 1:1 под слот.

| Слот | const | x | y | w | h |
|---|---|---:|---:|---:|---:|
| Ресурс-панель (HP/XP/Gold/ULT) | `CHUD_RESOURCE_PANEL_2K` | 18 | 18 | 820 | 84 |
| Панель таймера (нет на боссе) | `CHUD_TIMER_2K` | 1136 | 14 | 288 | 96 |
| Бейдж возвышения (asc>0) | `CHUD_ASCENSION_BADGE_2K` | 1432 | 18 | 64 | 64 |
| Ряд артефактов | `CHUD_ARTIFACT_ROW_2K` | 2140 | 16 | 402 | 104 |
| Кнопка повышения (bottom-right) | `CHUD_LEVELUP_BUTTON_2K` | 2436 | 1316 | 96 | 117 |
| Дамаг-флэш (overlay) | `CHUD_DAMAGE_FLASH_2K` | 0 | 0 | 2560 | 1440 |

**Инварианты (проверены `ui_no_overlap_matrix_test`):** ничего не вылазит за экран;
слоты не наслаиваются на 1080p/2K/4K; текст в рамке; HUD не перекрывает игровое поле
(только верх-бар + нижний правый угол). Подписи компактные (HP/XP/ULT, таймер — моно).

## ЭТАП 2 — генерация рамок (рисующий скилл)

Рамки сгенерированы детерминированным пайплайном `tools/build_ui_2k_frame_kit.py`
(SCRUM-485) — рисует 9-slice-safe frame-ассет РОВНО в пиксельный размер слота @2K
с нативными бордюрами; орнамент держится в margin-band, центр — ровный вертикальный
градиент (тянется только он). Рендер-верификатор (`--verify`) зелёный: размер ==
ожидаемый, 9-slice валиден, углы попиксельно стабильны на 1080p/2K/4K, центр чистый,
нет stray-островов.

Тонкие HUD-стрипы получили **узкие вертикальные бордюры**, чтобы рамка не вырастала
за свой слот и не наезжала на соседние плашки (`CharacterStatsHud` под ресурс-панелью,
`ArtifactHudRow` справа от таймера):

| slug | размер | tex-margins (l,t,r,b) | content (l,t,r,b) | margin-key |
|---|---|---|---|---|
| `chud_resource_panel` | 820×84 | 60,16,60,16 | 72,18,72,18 | `hud_resource` |
| `chud_timer` | 288×96 | 56,22,56,22 | 64,26,64,24 | `hud_timer` |
| `chud_artifact_row` | 402×104 | 60,24,60,24 | 70,28,70,28 | `hud_artifact` |

Ассеты: `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_chud_*.png`.
Контактный лист: `docs/design/previews/ui_2k_frame_kit_contact.png`.

## Подключение в рантайм

- `scripts/ui/ui_theme_paths.gd`: HUD-слоты добавлены в `OVERHAUL_2K_FRAME_PATHS` /
  `_SOURCE_SIZE` / `_TEXTURE_MARGINS` / `_CONTENT`; новые margin-профили
  `hud_resource`/`hud_timer`/`hud_artifact` в `MINIMAL_METAL_FRAME_TEXTURE_MARGINS`
  (единый источник для генератора и рантайма, anti-drift сверяется в `--verify`).
- `scripts/ui_screens.gd`: `_hud_panel_style()` и `_timer_panel_style()` переведены
  на `_overhaul_2k_frame_style("chud_resource_panel"/"chud_timer", …)`.
- `chud_artifact_row` сгенерирован и зарегистрирован (ArtifactHudRow — прозрачный
  HFlowContainer; оборачивание в панель оставлено отдельной задачей, чтобы не менять
  раскладку ряда в этом редизайне).

## Тесты (green-gate)

- `tests/runtime_smoke_test.gd` — PASS (текстур-ассерты HUD обновлены на @2K-пути,
  пометка supersession SCRUM-448→SCRUM-564 в двух местах).
- `tests/ui_no_overlap_matrix_test.gd` — PASS (combat_hud без overflow/overlap @1080p/2K/4K).
