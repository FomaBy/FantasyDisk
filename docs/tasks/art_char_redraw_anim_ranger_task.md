# ART: Перерисовать «Рейнджер» в едином стиле + анимации (5 move / 5 attack)

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-294
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
задача для класса **Рейнджер** (`ranger`).

## Образ персонажа (арт-дирекция)
Рейнджер: лесной следопыт в зелёном плаще с капюшоном, лёгкая кожа, перо; БЕЗ лука, руки свободны.
Строго следовать единому style-sheet из опорной задачи (ракурс, палитра, контур,
pivot, тень). **Без оружия в руках.**

## Требования
1. Нарисовать «Рейнджер» в едином стиле (по style-sheet опорной задачи), БЕЗ оружия
   в руках.
2. Сделать спрайт-лист по единому формату: ячейка 384×384, прозрачный фон, pivot
   «ступни по центру низа»:
   - **walk** — 5 кадров (плавный цикличный шаг, без проскальзывания);
   - **attack** — 5 кадров (замах→удар→возврат, естественно, без петли).
3. Положить ассет по шаблонному пути assets/sprites/characters/ranger_sheet.png и
   зарегистрировать в данных анимаций (как описано в опорной задаче), чтобы класс
   проигрывал walk/attack в игре.
4. Если класс делил чужой спрайт — отвязать, дать собственный; старую текстуру в
   бэкап (не удалять).
5. Тест (smoke/animation): «Рейнджер» строится с "walk"(5)/"attack"(5), проигрывается
   без ошибок, без оружия в руках; превью-гиф в build/qa/.
6. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Рейнджер» перерисован в едином стиле, без оружия в руках.
- [ ] Лист 5 walk + 5 attack (384, единый pivot), плавно/естественно; зарегистрирован, играет в игре.
- [ ] 6 smoke + animation зелёные; превью-гиф; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (персонаж ranger), current_game_state.

## Пайплайн ролей (2026-06-14)
Двухфазно: 1) **Design (Codex)** перерисовывает спрайт в едином стиле БЕЗ оружия через `fantasydisk-asset-generator` (прозрачный фон), отдаёт принятый лист/кадры; 2) **Animator (Codex)** строит SpriteFrames/манифест и анимации move(5)/attack(5) через `fantasydisk-animation-director`, гоняет animation_smoke. Ключ OPENAI восстановлен 2026-06-14 — блок снят, Design стартует первым.


## Результат 2026-06-14 (Claude-Designer, параллельно Codex)
Лист сгенерён скиллом fantasydisk-asset-generator (1920x1152, 5x3 idle/walk/attack, без оружия), обработан tools/build_character_sheet.py (flood-fill фон + центровка pivot) -> assets/sprites/characters/ranger_sheet.png. player.gd авто-подхватывает (приоритет над ригом). animation_smoke зелёный.

## Animator Result — 2026-06-14

Animator-фаза по accepted source sheet выполнена:
- runtime SpriteFrames: `assets/sprites/characters/ranger_spriteframes.tres`;
- extracted runtime frames: `assets/sprites/characters/full_frame/ranger/`;
- source sheet: `assets/sprites/characters/ranger_sheet.png`;
- animations: `idle` 5f loop at 5fps, `walk` 5f loop at 10fps,
  `attack_primary` 5f one-shot at 14fps, runtime alias `attack` 5f one-shot at
  14fps;
- QA artifacts: `build/qa/scrum294/animation_manifest.json`,
  `build/qa/scrum294/ranger_anim_contact.png`,
  `build/qa/scrum294/ranger_idle.gif`,
  `build/qa/scrum294/ranger_walk.gif`,
  `build/qa/scrum294/ranger_attack_primary.gif`.

Verification:
- animation manifest validator — PASS.
- `tests/animation_smoke_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS after Back-end blocker SCRUM-409.

Back-end handoff resolved:
- `docs/tasks/backend_assassin_crit_shadow_vfx_runtime_smoke_task.md` — done,
  unblocked full runtime verification for SCRUM-291/SCRUM-282/SCRUM-294.


## QA-Вердикт (2026-06-14)
Статус: PASSED — «Рейнджер» перерисован + анимирован, играет в игре

Проверено (фактически):
- **Манифест** `build/qa/.../animation_manifest.json` (id `ranger`): **walk 5 / attack 5**
  (+attack_primary 5, idle 5) — требование 5 move/5 attack выполнено.
- **Рантайм-привязка активна**: `player.gd:_character_resource_sprite_frames` грузит
  `assets/sprites/characters/ranger_spriteframes.tres` (приоритет над cutout-ригом) —
  новая анимация играет в игре.
- **Визуал** контакт-лист/gif: перерисован в едином D&D dark-fantasy стиле, без оружия
  в руках (по спеке), плавные walk/attack позы, прозрачный фон.
- **Тесты**: `animation_smoke_test` + `runtime_smoke_test` — passed.

Acceptance:
- [x] «Рейнджер» перерисован в едином стиле, без оружия в руках.
- [x] 5 walk + 5 attack, зарегистрирован (.tres), играет в игре.
- [x] animation + runtime smoke зелёные; превью/контакт.

Статус done. Баги: нет. Двухфазная Design→Animator закрыта.
