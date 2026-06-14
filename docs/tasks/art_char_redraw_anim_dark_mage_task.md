# ART: Перерисовать «Тёмный маг» в едином стиле + анимации (5 move / 5 attack)

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-286
Координация (НЕ блок, скилл задаёт критерии): SCRUM-298 (единый стиль + формат листа + система анимаций)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## АНИМАЦИЯ — СКИЛЛОМ (директива пользователя 2026-06-14)
Анимацию (move/walk 5+ кадров loop, attack_primary 5+ кадров non-loop; элитки/боссы
— full-frame sprite-sheet без cutout-разрезания) делать скиллом
`fantasydisk-animation-director`
(`~/.codex/skills/fantasydisk-animation-director/`): он строит SpriteFrames/
AnimationPlayer, манифест, контакт-лист/GIF, валидирует
`scripts/validate_animation_manifest.py` и гоняет animation_smoke. Источник арта —
через `fantasydisk-asset-generator`. См. AGENTS.md (раздел анимаций).

## Контекст (запрос пользователя)
«Перерисовать всех персонажей в едином стиле; каждому — 5 кадров движения и 5
кадров атаки, плавно и естественно; все БЕЗ оружия в руках». Это пер-персонажная
задача для класса **Тёмный маг** (`dark_mage`).

## Образ персонажа (арт-дирекция)
Тёмный маг: тёмный чародей в рваном капюшоне и мантии, теневая дымка вокруг кистей; БЕЗ посоха, руки свободны.
Строго следовать единому style-sheet из опорной задачи (ракурс, палитра, контур,
pivot, тень). **Без оружия в руках.**

## Требования
1. Нарисовать «Тёмный маг» в едином стиле (по style-sheet опорной задачи), БЕЗ оружия
   в руках.
2. Сделать спрайт-лист по единому формату: ячейка 384×384, прозрачный фон, pivot
   «ступни по центру низа»:
   - **walk** — 5 кадров (плавный цикличный шаг, без проскальзывания);
   - **attack** — 5 кадров (замах→удар→возврат, естественно, без петли).
3. Положить ассет по шаблонному пути assets/sprites/characters/dark_mage_sheet.png и
   зарегистрировать в данных анимаций (как описано в опорной задаче), чтобы класс
   проигрывал walk/attack в игре.
4. Если класс делил чужой спрайт — отвязать, дать собственный; старую текстуру в
   бэкап (не удалять).
5. Тест (smoke/animation): «Тёмный маг» строится с "walk"(5)/"attack"(5), проигрывается
   без ошибок, без оружия в руках; превью-гиф в build/qa/.
6. CHANGELOG; content_registry.

## Acceptance Criteria
- [x] «Тёмный маг» перерисован в едином стиле, без оружия в руках.
- [x] Лист 5 walk + 5 attack (384, единый pivot), плавно/естественно; зарегистрирован, играет в игре.
- [x] 6 smoke + animation зелёные; превью-гиф; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (персонаж dark_mage), current_game_state.

## Пайплайн ролей (2026-06-14)
Двухфазно: 1) **Design (Codex)** перерисовывает спрайт в едином стиле БЕЗ оружия через `fantasydisk-asset-generator` (прозрачный фон), отдаёт принятый лист/кадры; 2) **Animator (Codex)** строит SpriteFrames/манифест и анимации move(5)/attack(5) через `fantasydisk-animation-director`, гоняет animation_smoke. Ключ OPENAI восстановлен 2026-06-14 — блок снят, Design стартует первым.

## Progress Log

- 2026-06-14 — Designer 2 took SCRUM-286 after user directive to start
  character animations. Scope for this pass: Design-owned accepted unarmed
  Dark Mage source sheet first; Animator integration/manifest/smokes remain
  follow-up ownership unless a dispatcher hands off runtime animation work.

## Result Summary — 2026-06-14

Design-source pass complete and ready for QA / Animator review.

Deliverables:
- Runtime sheet: `assets/sprites/characters/dark_mage_sheet.png`
  (`1920x1152`, 5 columns x 3 rows, `384x384` cells, RGBA transparent).
- Source/reference:
  - `docs/design/references/characters/dark_mage/dark_mage_sheet_source.png`
  - `docs/design/references/characters/dark_mage/dark_mage_sheet_alpha_clean.png`
  - `docs/design/references/characters/dark_mage/dark_mage_sheet_guttered_source.png`
- QA preview/contact:
  - `docs/design/previews/scrum286_dark_mage_sheet_contact.png`
  - `build/qa/scrum286_dark_mage/dark_mage_walk_preview.gif`
  - `build/qa/scrum286_dark_mage/dark_mage_attack_primary_preview.gif`
- Manifest/report:
  - `build/qa/scrum286_dark_mage/animation_manifest.json`
  - `build/qa/scrum286_dark_mage/dark_mage_sheet_report.json`
- Builder: `tools/build_scrum286_dark_mage_sheet.py`.

Design decisions:
- Kept the character unarmed: no staff, wand, book, skull, or held object.
- Preserved small hand/robe shadow mist as Dark Mage identity, but trimmed long
  detached attack VFX so the sheet remains character animation, not weapon VFX.
- Runtime integration now uses `assets/sprites/characters/dark_mage_spriteframes.tres`
  via `Player._character_resource_sprite_frames()`, with the Design sheet kept
  as source/reference.

Validation:
- `validate_animation_manifest.py build/qa/scrum286_dark_mage/animation_manifest.json`
  PASS.
- PIL safe-cell check PASS: all 15 frames non-empty, RGBA alpha, inside
  documented padding, no edge-touch.
- Godot headless import PASS; `dark_mage_sheet.png.import` present.
- `animation_smoke_test.gd` PASS.
- `runtime_smoke_test.gd` PASS.

## Animator Result — 2026-06-14

Animator-фаза SCRUM-286 завершена:
- runtime SpriteFrames: `assets/sprites/characters/dark_mage_spriteframes.tres`;
- extracted runtime frames: `assets/sprites/characters/full_frame/dark_mage/`;
- source sheet remains `assets/sprites/characters/dark_mage_sheet.png`;
- animations: `idle` 5f loop at 5fps, `walk` 5f loop at 10fps, `attack_primary` 5f one-shot at 14fps, runtime alias `attack` 5f one-shot at 14fps;
- pivot/canvas: `384x384`, bottom-center feet guide `[192,348]`;
- safe slicing: runtime SpriteFrames use separate per-frame PNGs; guttered source reference remains `docs/design/references/characters/dark_mage/dark_mage_sheet_guttered_source.png`.

Verification:
- `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/scrum286_dark_mage/animation_manifest.json` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.


## Результат 2026-06-14 (Claude-Designer, параллельно Codex)
Лист сгенерён скиллом fantasydisk-asset-generator (1920x1152, 5x3 idle/walk/attack, без оружия), обработан tools/build_character_sheet.py (flood-fill фон + центровка pivot) -> assets/sprites/characters/dark_mage_sheet.png. player.gd авто-подхватывает (приоритет над ригом). animation_smoke зелёный.
