# ART: Перерисовать «Биолог» в едином стиле + анимации (5 move / 5 attack)

Статус: review (Design-source ready; Animator integration pending)
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-284
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
задача для класса **Биолог** (`biologist`).

## Образ персонажа (арт-дирекция)
Биолог: учёный-натуралист в защитном костюме с биолюминесцентными вставками; БЕЗ инструментов в руках.
- Сейчас делит чужой спрайт (chemist.png) — нужен СОБСТВЕННЫЙ уникальный спрайт.
Строго следовать единому style-sheet из опорной задачи (ракурс, палитра, контур,
pivot, тень). **Без оружия в руках.**

## Требования
1. Нарисовать «Биолог» в едином стиле (по style-sheet опорной задачи), БЕЗ оружия
   в руках.
2. Сделать спрайт-лист по единому формату: ячейка 384×384, прозрачный фон, pivot
   «ступни по центру низа»:
   - **walk** — 5 кадров (плавный цикличный шаг, без проскальзывания);
   - **attack** — 5 кадров (замах→удар→возврат, естественно, без петли).
3. Положить ассет по шаблонному пути assets/sprites/characters/biologist_sheet.png и
   зарегистрировать в данных анимаций (как описано в опорной задаче), чтобы класс
   проигрывал walk/attack в игре.
4. Если класс делил чужой спрайт — отвязать, дать собственный; старую текстуру в
   бэкап (не удалять).
5. Тест (smoke/animation): «Биолог» строится с "walk"(5)/"attack"(5), проигрывается
   без ошибок, без оружия в руках; превью-гиф в build/qa/.
6. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Биолог» перерисован в едином стиле, без оружия в руках.
- [ ] Лист 5 walk + 5 attack (384, единый pivot), плавно/естественно; зарегистрирован, играет в игре.
- [ ] 6 smoke + animation зелёные; превью-гиф; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (персонаж biologist), current_game_state.

## Пайплайн ролей (2026-06-14)
Двухфазно: 1) **Design (Codex)** перерисовывает спрайт в едином стиле БЕЗ оружия через `fantasydisk-asset-generator` (прозрачный фон), отдаёт принятый лист/кадры; 2) **Animator (Codex)** строит SpriteFrames/манифест и анимации move(5)/attack(5) через `fantasydisk-animation-director`, гоняет animation_smoke. Ключ OPENAI восстановлен 2026-06-14 — блок снят, Design стартует первым.

## Dispatch Log
- 2026-06-14: Dispatcher routed SCRUM-284 to Designer 2 window `019ec7a6-55a5-7bc3-a397-606ce046308d` for the Design-owned source-sheet pass. Feature block remains active, but this row is eligible because it is already listed in Sprint 0.1.5 and explicitly waits for a Design-owned accepted source sheet before Animator integration. Scope: `biologist_sheet.png` source/preview/Design QA only; no SpriteFrames/runtime/gameplay work.

## Результат 2026-06-14 (Designer 2 / Codex)
Design-owned source pass completed through `fantasydisk-asset-generator` using the approved OpenAI pipeline. Rejected the earlier source variant because it included bag/flask/spore props; accepted source uses a fitted protective scientist-naturalist suit with subtle green/blue bioluminescent inserts and visibly empty hands in every frame.

Generated and validated Design handoff artifacts:
- accepted runtime/source sheet: `assets/sprites/characters/biologist_sheet.png` (`1920x1152`, 3 rows x 5 columns, `384x384` cells);
- source reference: `docs/design/references/characters/biologist/biologist_sheet_source.png`;
- alpha-clean reference: `docs/design/references/characters/biologist/biologist_sheet_alpha_clean.png`;
- 32px-gutter source: `docs/design/references/characters/biologist/biologist_sheet_guttered_source.png`;
- contact preview: `docs/design/previews/scrum284_biologist_sheet_contact.png`;
- QA manifest/report/GIFs: `build/qa/scrum284_biologist/`.

Validation: animation manifest validator PASS; PIL source cleanliness PASS (`15/15` non-empty cells, alpha extrema `(0,255)`, no safe-padding/edge-touch failures, global scale `1.0`). No weapons, tools, syringes, flasks, bags, or held objects remain in the accepted sheet. SpriteFrames, runtime registry, gameplay logic and smoke-test integration were intentionally not touched; Animator owns the next phase.
