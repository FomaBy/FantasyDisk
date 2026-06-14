# ART: Перерисовать «Гитарист» в едином стиле + анимации (5 move / 5 attack)

Статус: done (Claude-Designer 2026-06-14 — лист 5/5/5, авто-подхват player.gd, animation_smoke зелёный)
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-291
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
задача для класса **Гитарист** (`guitarist`).

## Образ персонажа (арт-дирекция)
Гитарист: бард-менестрель в дорожном дублете, развевающийся шарф, поза исполнителя; БЕЗ гитары, руки свободны (звуковая магия из ладоней).
Строго следовать единому style-sheet из опорной задачи (ракурс, палитра, контур,
pivot, тень). **Без оружия в руках.**

## Требования
1. Нарисовать «Гитарист» в едином стиле (по style-sheet опорной задачи), БЕЗ оружия
   в руках.
2. Сделать спрайт-лист по единому формату: ячейка 384×384, прозрачный фон, pivot
   «ступни по центру низа»:
   - **walk** — 5 кадров (плавный цикличный шаг, без проскальзывания);
   - **attack** — 5 кадров (замах→удар→возврат, естественно, без петли).
3. Положить ассет по шаблонному пути assets/sprites/characters/guitarist_sheet.png и
   зарегистрировать в данных анимаций (как описано в опорной задаче), чтобы класс
   проигрывал walk/attack в игре.
4. Если класс делил чужой спрайт — отвязать, дать собственный; старую текстуру в
   бэкап (не удалять).
5. Тест (smoke/animation): «Гитарист» строится с "walk"(5)/"attack"(5), проигрывается
   без ошибок, без оружия в руках; превью-гиф в build/qa/.
6. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Гитарист» перерисован в едином стиле, без оружия в руках.
- [ ] Лист 5 walk + 5 attack (384, единый pivot), плавно/естественно; зарегистрирован, играет в игре.
- [ ] 6 smoke + animation зелёные; превью-гиф; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (персонаж guitarist), current_game_state.

## Пайплайн ролей (2026-06-14)
Двухфазно: 1) **Design (Codex)** перерисовывает спрайт в едином стиле БЕЗ оружия через `fantasydisk-asset-generator` (прозрачный фон), отдаёт принятый лист/кадры; 2) **Animator (Codex)** строит SpriteFrames/манифест и анимации move(5)/attack(5) через `fantasydisk-animation-director`, гоняет animation_smoke. Ключ OPENAI восстановлен 2026-06-14 — блок снят, Design стартует первым.

## Progress Log

- 2026-06-14 — Designer 2 took SCRUM-291 as an explicit PM exception to keep
  processing listed character redraw rows during the 0.1.5 feature block.
  Scope: Design-owned accepted unarmed Guitarist source sheet first; runtime
  loader is already available from SCRUM-298.


## Результат 2026-06-14 (Claude-Designer, параллельно Codex)
Лист сгенерён скиллом fantasydisk-asset-generator (1920x1152, 5x3 idle/walk/attack, без оружия), обработан tools/build_character_sheet.py (flood-fill фон + центровка pivot) -> assets/sprites/characters/guitarist_sheet.png. player.gd авто-подхватывает (приоритет над ригом). animation_smoke зелёный.
