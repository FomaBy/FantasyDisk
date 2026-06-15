# ART/ANIM: Перерисовать «Инженер» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: cancelled
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-428
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Инженер** (`engineer`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Инженер: изобретатель, тёплая медь+латунь, искры, светящиеся гаджеты; ярко, харизматично. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Инженер» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Инженер» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Инженер» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (engineer), current_game_state.

## Dispatcher Handoff To Designer 2 (2026-06-15)

Передано Designer 2 thread `019ec7a6-55a5-7bc3-a397-606ce046308d` как следующий
свободный 0.1.6 character v2 Design-source row.

Scope for this pass: produce only Engineer v2 Design/source artifacts in the
SCRUM-422 bright/epic style: transparent source PNG, strict alpha/white/neutral
cleanup validation, normalized 512-cell, source-sheet handoff, contact/dark-bg
preview, pivot/height report, task/docs/board/Jira updates. Do not build
SpriteFrames, runtime integration, AnimationPlayer/AnimationTree, animation
smoke, gameplay logic, balance, or attack frames. Animator starts only after the
Engineer source handoff is accepted. Keep reasoning High/no low.

## ОТМЕНЕНО 2026-06-15 (пользователь)
Широкий редизайн персонажей v2 отменён — пользователю не нравится подход. Работаем по одному классу заново (старт — Берсерк, отдельная задача).
