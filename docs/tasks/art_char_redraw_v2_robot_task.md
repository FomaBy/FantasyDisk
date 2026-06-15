# ART/ANIM: Перерисовать «Робот» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: done
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-432
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Робот** (`robot`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Робот: блестящий механический страж, яркие неоновые сенсоры (циан/синий), полированный металл; эпично. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Робот» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Робот» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [x] «Робот» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов) — Design-source handoff ready.
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (robot), current_game_state.

## Dispatcher Handoff To Design Main (2026-06-15)

Передано Design main thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` как следующий
свободный 0.1.6 character v2 Design-source row.

Scope for this pass: produce only Robot v2 Design/source artifacts in the
SCRUM-422 bright/epic style: transparent source PNG, strict alpha/white/neutral
cleanup validation, normalized 512-cell, source-sheet handoff, contact/dark-bg
preview, pivot/height report, task/docs/board/Jira updates. Do not build
SpriteFrames, runtime integration, AnimationPlayer/AnimationTree, animation
smoke, gameplay logic, balance, or attack frames. Animator starts only after the
Robot source handoff is accepted. Keep reasoning High/no low.

## ОТМЕНЕНО 2026-06-15 (пользователь)
Широкий редизайн персонажей v2 отменён — пользователю не нравится подход. Работаем по одному классу заново (старт — Берсерк, отдельная задача).

## REOPENED FOR DESIGN SOURCE PASS 2026-06-15

Dispatcher explicitly reopened SCRUM-432 for the Robot v2 Design-source pass
after the broad-row cancellation note. Scope remains narrowed to source art,
alpha cleanup, normalized cell/sheet handoff, preview and docs only; Animator
and runtime integration remain gated until source acceptance.

## Design Source Result 2026-06-15

Status: ready for QA / Animator-source acceptance.

Generated a Robot v2 bright+epic source package in the SCRUM-422 style:
polished fantasy mechanical guardian, cyan/blue sensors and rune core, clean
heavy silhouette, empty hands, no weapon/tool/gun/cannon/shield/orb/focus.

Artifacts:
- Raw source: `docs/design/references/characters_v2/robot/robot_v2_source_raw.png`
- Alpha-clean source: `docs/design/references/characters_v2/robot/robot_v2_source_clean.png`
- Normalized `512x512` cell: `docs/design/references/characters_v2/robot/robot_v2_idle_cell_512.png`
- Source-sheet handoff: `docs/design/references/characters_v2/robot/robot_v2_sheet_source_handoff.png`
- Asset-side idle source: `assets/sprites/characters/v2/robot/robot_v2_idle_source.png`
- Asset-side source-sheet handoff: `assets/sprites/characters/v2/robot/robot_v2_sheet_source_handoff.png`
- Handoff spec: `docs/design/references/characters_v2/robot/robot_v2_design_handoff.md`
- Contact preview: `docs/design/previews/scrum432_robot_v2_contact.png`
- QA report: `build/qa/scrum432_robot_v2/scrum432_robot_v2_alpha_size_report.json`

Validation:
- Alpha min/max after cleanup: `[0, 255]`.
- Edge-visible pixels after cleanup: `0`.
- Edge floodable neutral/checker pixels after cleanup: `0`.
- Normalized visible bbox: `[121, 94, 391, 470]`.
- Visible height: `376 px`; pivot `[256,470]`; bottom y `470`.

Not done in this Design pass: real idle/move motion frames, SpriteFrames,
AnimationPlayer/AnimationTree, runtime wiring, runtime smoke, combat scale or
attack frames. These remain Animator/Back-end scope after source acceptance.

## QA-Вердикт (2026-06-15)
Статус: PASSED (Design-source: технически валидный Robot v2 source-пакет) — НО см. ⚠️ отмену v2

Проверено (фактически, на артефактах):
- **Чистая прозрачность**: `robot_v2_idle_cell_512.png` (512×512), `robot_v2_source_clean.png`
  (1024×1024), asset-side `robot_v2_idle_source.png` (512×512) — все RGBA, **edge_alpha_max=0**,
  все 4 угла alpha=0, есть transparent(0)+opaque(255). Нет белого фона/каймы/карманов;
  отчёт: edge-visible=0, edge floodable=0, alpha [0,255] ✓.
- **Формат по опорной SCRUM-422**: нормализованная 512-ячейка, pivot [256,470], visible
  bbox [121,94,391,470], visible height 376px (цель 360-380, ≈2× монстра) ✓.
- **Визуал** `scrum432_robot_v2_contact.png`: яркий эпичный механический страж, полированный
  бронза/золото металл, циан/синие неоновые сенсоры + рун-ядро; **руки пустые** (без оружия/
  щита/орба); source-handoff strip = 5 idle + 5 move placeholder-слотов (движение — Animator),
  attack вне scope ✓.

Acceptance (Design-source scope):
- [x] Robot v2 перерисован ярко/эпично, прозрачный фон (нет белого/каймы/карманов) — source handoff ready.
- [~] idle+move motion / SpriteFrames / runtime / 2×-scale / превью-гиф — Animator/Back-end scope, НЕ в этом проходе.

Статус review→done (**только Design-source технический приём**). Баги: нет.

⚠️ **ОТМЕНА ИНИЦИАТИВЫ v2 (пользователь, 2026-06-15):** широкий редизайн персонажей v2
отменён («не нравится подход»), активное направление — **«по одному классу» v3** (старт —
Берсерк, SCRUM-442 PASSED). Поэтому этот Robot v2 source — **архивный/handoff-only**: НЕ
продвигать в Animator/runtime/SpriteFrames и НЕ тиражировать на остальные классы без явного
PM-переподтверждения. PASSED здесь = только техническая валидность сгенерированного
Design-source (прозрачность/формат/спека), НЕ возобновление инициативы v2.
