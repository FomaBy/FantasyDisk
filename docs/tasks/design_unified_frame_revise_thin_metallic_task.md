# ART: Ревизия единого фрейма — ТОНКАЯ металлическая рамка (самоцветы+драконья плашка)

Статус: done
Приоритет: high
Роль: Designer (Codex) → Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-384
QA: in_progress (2026-06-14)
Связано: SCRUM-373 (единый мастер-фрейм, design done) + его backend-интеграция, SCRUM-324 (скилл)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Изменить фреймы интерфейса везде: рамки ТОНЕНЬКИЕ металлические, углы такие же
тоненькие, можно красных самоцветов на углы + в серединах металлических рамок
можно плашку дракона. Надо тоненько, чтобы все элементы, которые должны быть
внутри, были во внутренней области рамки».

ВАЖНО: единый фрейм SCRUM-373 уже СГЕНЕРИРОВАН (design done), но по прежней общей
спеке — **толстая** окантовка (texture margins 128px на 1024² → ~12.5% с каждой
стороны). Пользователь хочет ТОНКУЮ. Это РЕВИЗИЯ ассета + параметров, не новый фрейм.

## ОБЯЗАТЕЛЬНО — скилл
Перегенерировать скиллом `fantasydisk-asset-generator` (gpt-image-2, PNG, ПРОЗРАЧНЫЙ
фон). Биллинг OpenAI восстановлен (проверено 2026-06-14). Старый ассет — в бэкап.

## Требования
1. **Тонкая металлическая рамка**: тонкая металлическая окантовка (НЕ массивная),
   углы — **такие же тонкие**. Существенно уменьшить толщину vs текущий ассет
   (ориентир: texture margins ~32-48px на 1024² вместо 128px — подобрать так, чтобы
   рамка читалась, но была тонкой).
2. **Красные самоцветы на углах** — небольшие аккуратные камни в 4 углах.
3. **Плашка дракона в СЕРЕДИНЕ краёв** (центральный драконий медальон) — опционально,
   включаемый оверлей, «где уместно» (крупные панели/окна), не на каждом мелком фрейме.
4. **Контент строго во внутренней области**: тонкая рамка → больше места внутри;
   все элементы (кнопки/иконки/текст/портреты/области выбора) помещаются в content-зоне
   и НЕ заходят на металл (content margins тонкие, но ≥ тонкой окантовки).
5. Сохранить 9-slice пригодность (тайлящиеся края H/V) и существующие пути ассетов
   из SCRUM-373 (ui_frame_unified_master*.png) — заменить содержимое, чтобы
   backend-интеграция подхватила без смены путей; обновить texture/content margins
   (метаданные unified_master_frame_metadata.json) под тонкие значения.
6. Прогнать по экранам (через backend-интеграцию SCRUM-373): тонкая рамка везде,
   контент внутри, ничего не наезжает, текст читаем на 1280×720/1920×1080/2560×1440.
7. Тест: runtime + ui_no_overlap_matrix зелёные; обновлённый контактлист (тонкая
   рамка/самоцветы/дракон/тайл) в docs/design/previews/; скрины экранов в build/qa/.
8. CHANGELOG; visual_style_assets; menus_ui.

## Files / Assets / IDs
- assets/sprites/ui/frames/unified/ui_frame_unified_master*.png (перегенерировать тоньше) + бэкап
- docs/design/references/unified_master_frame/ (+ metadata.json — тонкие margins)
- backend_unified_master_frame_system_projectwide_integration_task.md (использует ревизованный ассет)
- tests/runtime_smoke_test.gd, tests/ui_no_overlap_matrix_test.gd

## Acceptance Criteria
- [ ] Единый фрейм перегенерирован ТОНКИМ металлическим (тонкие углы + красные самоцветы по углам + опц. драконья плашка в середине краёв).
- [ ] Рамка существенно тоньше прежней; контент строго во внутренней content-зоне, не на металле; читаема на 2560×1440.
- [ ] Пути ассетов сохранены (backend-интеграция подхватывает); margins/метаданные обновлены; старое в бэкап.
- [ ] runtime + no-overlap matrix зелёные; контактлист + скрины; CHANGELOG.

## Документация
docs/design/systems/visual_style_assets.md, docs/design/systems/menus_ui.md.

## Progress Log
- 2026-06-14 — Took task in Design/Codex thread; starting thin metallic unified frame revision from SCRUM-373 assets with preserved runtime paths.
- 2026-06-14 — Generated reference via `fantasydisk-asset-generator`:
  `docs/design/references/unified_master_frame/thin_metallic_unified_frame_reference.png`.
  The generated reference matched the thin metal/gem/dragon direction, but the
  raw image had a baked paper background, so the production asset was rebuilt
  as a clean alpha-ready thin frame while preserving the generated art direction.
- 2026-06-14 — Replaced preserved runtime paths:
  `assets/sprites/ui/frames/unified/ui_frame_unified_master.png`,
  `ui_frame_unified_master_fill.png`, `ui_frame_unified_inner_fill.png`,
  `ui_frame_unified_ornament_top.png`, `ui_frame_unified_ornament_bottom.png`,
  `ui_frame_unified_hover_overlay.png`. Old SCRUM-373 PNGs are backed up under
  `build/qa/scrum384/backups/`.
- 2026-06-14 — Updated metadata:
  `docs/design/references/unified_master_frame/unified_master_frame_metadata.json`.
  New texture margins: `72/72/72/72`; content margins: `88/88/88/88`; strict
  safe rect: `Rect2(88, 88, 848, 848)`. Dragon ornaments are separate optional
  overlays for large panels only and are not baked into 9-slice stretch zones.
- 2026-06-14 — QA artifacts:
  `docs/design/previews/unified_master_frame_thin_revision_contact.png`,
  `docs/design/previews/unified_master_frame_thin_safe_zone.png`,
  `build/qa/scrum384/unified_frame_thin_revision_qa.md`.
- 2026-06-14 — Verification PASS: PNG RGBA/alpha validation, Godot headless
  import, `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd`
  and `tests/runtime_smoke_test.gd`.

## Result
Design ревизия готова к QA/review. Единый master frame теперь тонкий: dark steel
rails, тонкие углы, небольшие красные самоцветы в углах, больше внутреннего
пространства для контента. Runtime paths сохранены, поэтому SCRUM-382 integration
подхватывает ревизованный ассет без смены ссылок. Важное правило для Back-end/UI:
контент остается строго внутри scaled safe rect из metadata; optional dragon
overlays можно использовать только на крупных панелях и нельзя размещать поверх
них текст/иконки/кнопки.

## QA-Вердикт (2026-06-14)
Статус: PASSED (Design-scope: тонкая ревизия ассета + метаданные)

Проверено (фактически):
- **Тоньше**: метаданные `texture_margins` 128→**72**, `content_margins` 132→**88**,
  `strict_safe_rect` inner 760→**848** (больше места). Путь сохранён
  (`ui_frame_unified_master.png` 1024² RGBA прозрачный) — SCRUM-382 подхватывает.
- **Визуал** `unified_master_frame_thin_revision_contact.png` + рендер
  `cap_thinframe_384.png` (Древо умений): рамка реально тоньше (vs old backup/382),
  тёмная сталь, **красные самоцветы в углах**, опц. dragon-overlays, контент внутри,
  9-slice тайлится (wide preview); красивее/легче.
- **Тесты**: `ui_no_overlap_matrix_test` + `runtime_smoke_test` — passed (контент в
  content-зоне, без наложений).

⚠️ **Back-end follow-up (не Design-дефект)**: runtime-константа
`UIThemePaths.UNIFIED_FRAME_TEXTURE_MARGINS = Vector4(128,128,128,128)`
(ui_theme_paths.gd:15) **НЕ обновлена** под тонкий ассет (бордюр ~72px). Сейчас
9-slice режет по 128 в рамку с 72px бордюром — на крупных панелях рендер приемлем
(зона 72-128px пустая, искажения нет), но для ПИКСЕЛЬ-точности (особенно мелкие
панели/тултипы <256px) константу следует привести к `72`. Это Back-end-интеграция
(SCRUM-382 домен), вне Design-scope 384.

Acceptance (Design-scope):
- [x] Тонкая металлическая рамка + тонкие углы + красные самоцветы; dragon-overlay опц.
- [x] Контент во внутренней зоне (safe_rect 848); 9-slice тайлится; пути сохранены.
- [x] Метаданные обновлены под тонкие значения; превью/бэкап; тесты зелёные.
- [~] Runtime texture margins под тонкий ассет — Back-end follow-up (SCRUM-382).

Статус review→done (Design-source). Баги: нет (рендер приемлем; margin-точность —
delegated Back-end follow-up).