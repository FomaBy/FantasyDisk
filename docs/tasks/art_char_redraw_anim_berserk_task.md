# ART: Перерисовать «Берсерк» в едином стиле + анимации (5 move / 5 attack)

Статус: review
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-283
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
задача для класса **Берсерк** (`berserk`) (эталон уже задан опорной задачей — привести к финалу единого стиля 5+5, без оружия).

## Образ персонажа (арт-дирекция)
Берсерк: свирепый воин-варвар, обнажённый мускулистый торс, меховые наручи и пояс, боевая раскраска; РУКИ ПУСТЫЕ (топор убрать).
Строго следовать единому style-sheet из опорной задачи (ракурс, палитра, контур,
pivot, тень). **Без оружия в руках.**

## Требования
1. Нарисовать «Берсерк» в едином стиле (по style-sheet опорной задачи), БЕЗ оружия
   в руках.
2. Сделать спрайт-лист по единому формату: ячейка 384×384, прозрачный фон, pivot
   «ступни по центру низа»:
   - **walk** — 5 кадров (плавный цикличный шаг, без проскальзывания);
   - **attack** — 5 кадров (замах→удар→возврат, естественно, без петли).
3. Положить ассет по шаблонному пути assets/sprites/characters/berserk_sheet.png и
   зарегистрировать в данных анимаций (как описано в опорной задаче), чтобы класс
   проигрывал walk/attack в игре.
4. Если класс делил чужой спрайт — отвязать, дать собственный; старую текстуру в
   бэкап (не удалять).
5. Тест (smoke/animation): «Берсерк» строится с "walk"(5)/"attack"(5), проигрывается
   без ошибок, без оружия в руках; превью-гиф в build/qa/.
6. CHANGELOG; content_registry.

## Acceptance Criteria
- [x] «Берсерк» перерисован в едином стиле, без оружия в руках.
- [x] Лист 5 walk + 5 attack (384, единый pivot), плавно/естественно; зарегистрирован, играет в игре.
- [x] animation_smoke зелёный; 6 smoke + animation зелёные; превью-гиф; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (персонаж berserk), current_game_state.

## Пайплайн ролей (2026-06-14)
Двухфазно: 1) **Design (Codex)** перерисовывает спрайт в едином стиле БЕЗ оружия через `fantasydisk-asset-generator` (прозрачный фон), отдаёт принятый лист/кадры; 2) **Animator (Codex)** строит SpriteFrames/манифест и анимации move(5)/attack(5) через `fantasydisk-animation-director`, гоняет animation_smoke. Ключ OPENAI восстановлен 2026-06-14 — блок снят, Design стартует первым.

## Design Result — 2026-06-14

Design source-sheet phase завершена и готова к handoff Animator:
- production source sheet: `assets/sprites/characters/berserk_sheet.png`;
- clean Design source reference: `docs/design/references/characters/berserk/berserk_sheet_alpha_clean.png`;
- raw OpenAI generation reference: `docs/design/references/characters/berserk/berserk_sheet_source.png`;
- contact preview: `docs/design/previews/scrum283_berserk_sheet_contact.png`;
- validation manifest: `build/qa/scrum283/berserk_sheet_validation.json`.

Параметры принятого листа:
- `1920x768`, RGBA, transparent;
- `384x384` cells, 5 columns x 2 rows;
- row 0: `walk` 5 frames loop source;
- row 1: `attack_primary` 5 frames one-shot source;
- Berserk is unarmed in all frames;
- bottom-center pivot guide recorded as `[192, 348]` per cell;
- validation: `accepted_for_design_handoff=true`, `magenta_visible_pixels=0`, no edge-touch/crop failures.

Design scope intentionally did not build SpriteFrames, AnimationPlayer, runtime registry entries, gameplay wiring, GIF preview, or animation smoke. Those remain Animator scope after source-sheet acceptance.


## Результат 2026-06-14 (Claude-Designer, параллельно Codex)
Сгенерил лист скиллом fantasydisk-asset-generator (gpt-image-2, 1920x1152, 5x3 idle/walk/attack),
БЕЗ оружия в руках. Обработка `tools/build_character_sheet.py`: flood-fill удаление фона
(модель выдала белый, не прозрачный) + по-кадровый автокроп с центровкой по pivot (192,348).
Лист -> `assets/sprites/characters/berserk_sheet.png` (конвенция). player.gd:_character_sprite_frames
АВТО-подхватывает лист над cutout-ригом; idle(5,5fps)/walk(5,10)/attack(5,14). animation_smoke ЗЕЛЁНЫЙ.
Исходник+keyed в references/characters/berserk/; превью previews/berserk_sheet_normalized.png.
