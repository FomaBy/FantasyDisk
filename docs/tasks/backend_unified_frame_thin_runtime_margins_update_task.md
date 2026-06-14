# Back-end: обновить runtime texture margins под тонкий единый фрейм (SCRUM-384)

Статус: new
Приоритет: medium
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: QA (follow-up из SCRUM-384)
Jira: pending sync
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
- [ ] Runtime texture/content margins = метаданные тонкого фрейма (72/88), без рассинхрона.
- [ ] 9-slice тонкой рамки не искажён на крупных и мелких панелях (визуал в build/qa/).
- [ ] dark_fantasy_ui_theme_test обновлён под 72 и зелёный; runtime+ui+no-overlap зелёные.
- [ ] CHANGELOG при изменении.

## Files / IDs
- `scripts/ui/ui_theme_paths.gd:15` (UNIFIED_FRAME_TEXTURE_MARGINS)
- `scripts/ui_screens.gd` (`_unified_frame_style`, импорт константы :34)
- `tests/dark_fantasy_ui_theme_test.gd` (ассерт margins)
- `docs/design/references/unified_master_frame/unified_master_frame_metadata.json` (источник истины)
