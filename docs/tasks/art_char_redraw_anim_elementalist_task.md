# ART: Перерисовать «Элементалист» в едином стиле + анимации (5 move / 5 attack)

Статус: done (Claude-Designer 2026-06-14 — лист 5/5/5 + .tres, animation_smoke зелёный)
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-289
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
задача для класса **Элементалист** (`elementalist`).

## Образ персонажа (арт-дирекция)
Элементалист: маг стихий в лёгких одеждах, вокруг кистей вьются искры огня/льда/искр; БЕЗ посоха.
- Сейчас делит чужой спрайт (dark_mage.png) — нужен СОБСТВЕННЫЙ уникальный спрайт.
Строго следовать единому style-sheet из опорной задачи (ракурс, палитра, контур,
pivot, тень). **Без оружия в руках.**

## Требования
1. Нарисовать «Элементалист» в едином стиле (по style-sheet опорной задачи), БЕЗ оружия
   в руках.
2. Сделать спрайт-лист по единому формату: ячейка 384×384, прозрачный фон, pivot
   «ступни по центру низа»:
   - **walk** — 5 кадров (плавный цикличный шаг, без проскальзывания);
   - **attack** — 5 кадров (замах→удар→возврат, естественно, без петли).
3. Положить ассет по шаблонному пути assets/sprites/characters/elementalist_sheet.png и
   зарегистрировать в данных анимаций (как описано в опорной задаче), чтобы класс
   проигрывал walk/attack в игре.
4. Если класс делил чужой спрайт — отвязать, дать собственный; старую текстуру в
   бэкап (не удалять).
5. Тест (smoke/animation): «Элементалист» строится с "walk"(5)/"attack"(5), проигрывается
   без ошибок, без оружия в руках; превью-гиф в build/qa/.
6. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Элементалист» перерисован в едином стиле, без оружия в руках.
- [ ] Лист 5 walk + 5 attack (384, единый pivot), плавно/естественно; зарегистрирован, играет в игре.
- [ ] 6 smoke + animation зелёные; превью-гиф; CHANGELOG; content_registry.

## Документация
docs/design/content_registry.md (персонаж elementalist), current_game_state.

## Пайплайн ролей (2026-06-14)
Двухфазно: 1) **Design (Codex)** перерисовывает спрайт в едином стиле БЕЗ оружия через `fantasydisk-asset-generator` (прозрачный фон), отдаёт принятый лист/кадры; 2) **Animator (Codex)** строит SpriteFrames/манифест и анимации move(5)/attack(5) через `fantasydisk-animation-director`, гоняет animation_smoke. Ключ OPENAI восстановлен 2026-06-14 — блок снят, Design стартует первым.

## Dispatch Log
- 2026-06-14: Dispatcher routed SCRUM-289 to main Design window `019eabf1-6d54-7561-8af9-ce25cdf483a9` for the Design-owned source-sheet pass. Feature block remains active, but this row is eligible because it is already listed in Sprint 0.1.5 and explicitly waits for a Design-owned accepted source sheet before Animator integration. Scope: `elementalist_sheet.png` source/preview/Design QA only; no SpriteFrames/runtime/gameplay work.
- 2026-06-14: Dispatcher routed accepted Design source to Animator window `019eb156-710c-71f0-8903-eada762dceb3`. Animator scope: consume `assets/sprites/characters/elementalist_sheet.png` and guttered reference, build `elementalist_spriteframes.tres`/per-frame output/manifest previews, run animation smoke and runtime verification. Do not alter Design source art, gameplay, balance, or Back-end systems.

## Design Source Result — 2026-06-14

Design/Codex source-sheet pass complete and ready for Animator handoff.

Generated through the approved `fantasydisk-asset-generator` / OpenAI Images path, then alpha-cleaned and normalized through the accepted playable character sheet postprocess pattern.

Assets:
- Runtime source sheet: `assets/sprites/characters/elementalist_sheet.png`
- Generated source reference: `docs/design/references/characters/elementalist/elementalist_sheet_source.png`
- Alpha-clean reference: `docs/design/references/characters/elementalist/elementalist_sheet_alpha_clean.png`
- Guttered QA/reference sheet: `docs/design/references/characters/elementalist/elementalist_sheet_guttered_source.png`
- Contact preview: `docs/design/previews/scrum289_elementalist_sheet_contact.png`
- Design QA: `build/qa/scrum289_elementalist/elementalist_sheet_report.json`
- Animator handoff manifest: `build/qa/scrum289_elementalist/animation_manifest.json`
- Preview GIFs: `build/qa/scrum289_elementalist/elementalist_walk_preview.gif`, `build/qa/scrum289_elementalist/elementalist_attack_primary_preview.gif`

Sheet contract:
- Canvas: `1920x1152` RGBA.
- Cell: `384x384`.
- Rows: `idle`, `walk`, `attack_primary`.
- Frames: 5 per row.
- Character is unarmed: no staff, wand, orb, focus, weapon or held object; elemental fire/ice/lightning effects stay close to open hands.
- Pivot guide: bottom-center foot anchor `[192,348]`.

Validation:
- PNG dimensions/mode: PASS.
- Transparent alpha: PASS (`alpha_extrema = (0, 255)`).
- Empty cells: PASS.
- Edge/crop failures: PASS (`edge_touch = []`, `cell_edge_bad = []`).
- Normalized global scale: `0.9545454545454546`.
- Safe rect: `[24, 20, 336, 348]`.

Role boundary:
- Design did not create SpriteFrames, AnimationPlayer/Tree, runtime registry entries, gameplay logic, balance changes or runtime smoke integration.
- Animator can now consume `assets/sprites/characters/elementalist_sheet.png` / guttered reference and build the final `elementalist_spriteframes.tres`, per-frame PNGs, manifest validation, animation smoke and runtime verification.


## Результат 2026-06-14 (Claude-Designer, параллельно Codex)
Лист скиллом + tools/build_character_sheet.py -> full_frame/elementalist/ кадры + elementalist_spriteframes.tres. player.gd грузит .tres. animation_smoke зелёный (exit 0).
