# Back-end: обновить runtime texture margins под тонкий единый фрейм (SCRUM-384)

Статус: done
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: QA (follow-up из SCRUM-384)
Jira: SCRUM-392
Связано: SCRUM-384 (тонкая ревизия ассета), SCRUM-373/382 (единый мастер-фрейм)

## Контекст
SCRUM-384 заменил единый мастер-фрейм на ТОНКИЙ металлический по тем же путям
(`ui_frame_unified_master.png`), обновив метаданные:
`texture_margins 128→72`, `content_margins 132→88`, `safe_rect inner 760→848`.

НО runtime-константа в коде НЕ обновлена:
- `scripts/ui/ui_theme_paths.gd:15` — `UNIFIED_FRAME_TEXTURE_MARGINS := Vector4(128,128,128,128)`.

Сейчас 9-slice режет тонкую рамку (бордюр ~72px) по 128px → на крупных панелях
рендер приемлем (зона 72-128px пустая/тёмная, искажения нет — проверено
`build/qa/cap_thinframe_384.png`), но НЕ пиксель-точно. На мелких панелях/тултипах
(<256px ширины) два 128px-угла могут превысить размер → сжатие/искажение 9-slice.

## Scope
Back-end/UI runtime margin alignment only. Не менять ассеты/геймплей/баланс.

## Требования
1. Привести `UNIFIED_FRAME_TEXTURE_MARGINS` (и связанные content-margins, если
   захардкожены) к значениям из `unified_master_frame_metadata.json` (texture 72,
   content 88) — лучше читать из метаданных, чтобы будущие ревизии не рассинхронились.
2. Проверить рендер на крупных И мелких unified-панелях (тултипы/HUD-карточки/
   кнопки): рамка тонкая, не искажена, контент в content-зоне.
3. Прогнать `runtime_smoke_test`, `runtime_smoke_ui_test`, `ui_no_overlap_matrix_test`,
   `dark_fantasy_ui_theme_test` (последний ассертит 128 — обновить ожидание на 72).

## Acceptance Criteria
- [x] Runtime texture/content margins = метаданные тонкого фрейма (72/88), без рассинхрона.
- [x] 9-slice тонкой рамки не искажён на крупных и мелких панелях (визуал в build/qa/).
- [x] dark_fantasy_ui_theme_test обновлён под 72 и зелёный; runtime+ui+no-overlap зелёные.
- [x] CHANGELOG при изменении.

## Files / IDs
- `scripts/ui/ui_theme_paths.gd:15` (UNIFIED_FRAME_TEXTURE_MARGINS)
- `scripts/ui_screens.gd` (`_unified_frame_style`, импорт константы :34)
- `tests/dark_fantasy_ui_theme_test.gd` (ассерт margins)
- `docs/design/references/unified_master_frame/unified_master_frame_metadata.json` (источник истины)

## Result
2026-06-14 Back-end:
- `scripts/ui/ui_theme_paths.gd` приведен к SCRUM-384 metadata: unified master
  frame texture margins `72/72/72/72`, strict safe rect `Rect2(88,88,848,848)`.
- `tests/dark_fantasy_ui_theme_test.gd` больше не держит stale `128px`
  expectation: тест читает `unified_master_frame_metadata.json`, сверяет runtime
  constants и проверяет StyleBoxTexture margins по metadata.
- QA artifacts:
  - `build/qa/scrum392/unified_frame_margins.md`
  - `build/qa/scrum392/unified_frame_margin_preview.png`
- `CHANGELOG.md` обновлен.

Verification:
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/dark_fantasy_ui_theme_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed.

## QA-Вердикт (2026-06-14)
Статус: PASSED — закрывает margin-mismatch из SCRUM-384

Проверено (фактически):
- **Константа обновлена**: `ui_theme_paths.gd:15` `UNIFIED_FRAME_TEXTURE_MARGINS =
  Vector4(72,72,72,72)` (было 128), `:16` `UNIFIED_FRAME_SAFE_RECT = Rect2(88,88,848,848)`
  — совпадают с метаданными тонкого ассета (SCRUM-384).
- **Анти-рассинхрон**: `dark_fantasy_ui_theme_test` теперь читает
  `unified_master_frame_metadata.json` (стр.9/121-122) и динамически сверяет runtime-
  константы со StyleBoxTexture margins — stale-128 ожидание убрано (будущие ревизии
  не рассинхронятся).
- **Визуал** `cap_thinmargin_392.png` (Древо умений): тонкая металлическая рамка +
  красные самоцветы в углах, 9-slice режет по 72 в 72px-бордюр → **без искажений**
  (mismatch 128-vs-72, который я флагнул в SCRUM-384, устранён), контент внутри,
  текст читаем.
- **Тесты**: `dark_fantasy_ui_theme_test`, `runtime_smoke_test`, `ui_no_overlap_matrix_test`,
  `runtime_smoke_ui_test` — все passed.

Acceptance:
- [x] Runtime margins = метаданные (72/88), без рассинхрона (тест читает метаданные).
- [x] 9-slice тонкой рамки не искажён (визуал чист).
- [x] dark_fantasy зелёный + читает метаданные; runtime+ui+no-overlap зелёные; CHANGELOG.

Баги: нет. Петля тонкого единого фрейма закрыта: SCRUM-384 (ассет) + 392 (runtime margins).