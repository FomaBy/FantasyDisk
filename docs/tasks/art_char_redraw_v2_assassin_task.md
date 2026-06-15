# ART/ANIM: Перерисовать «Ассасин» v2 — ярко/эпично, move+idle, прозрачный фон

Статус: in_progress
Приоритет: medium
Роль: Designer (Codex) → Animator (Codex)
Версия: 0.1.6
Создано: 2026-06-15
Автор: PM (запрос пользователя)
Jira: SCRUM-419
Координация (НЕ блок, скилл задаёт критерии): SCRUM-422 (опорная: стиль/формат/размер v2)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Dispatcher Design Dispatch (2026-06-15)

Передано Design main (`019eabf1-6d54-7561-8af9-ce25cdf483a9`) как свободная
per-class v2 Design-source строка после SCRUM-422 source anchor. Designer 2
сейчас активен на SCRUM-429 Guitarist, Animator получает SCRUM-424 Dark Mage, так
что этот ряд не конфликтует с активными владельцами.

Scope for this pass: prepare the accepted bright+epic Assassin v2 Design-source
pack only: transparent source PNG, normalized `512x512` cell/source handoff,
alpha/halo/pocket validation, visible body height/pivot report, contact/dark-bg
preview and handoff notes. Use `fantasydisk-asset-generator` and the accepted
SCRUM-422 style/format anchor. Do not build SpriteFrames, AnimationPlayer,
runtime player wiring, animation smoke, combat scale/collision, or Back-end
logic in this Design pass. Animator starts only after source acceptance. Keep
reasoning High/no low.

## Контекст
Пер-персонажная задача инициативы «Перерисовка персонажей v2» (0.1.6) — класс **Ассасин** (`assassin`).
По style-sheet опорной задачи: ЯРКО и ЭПИЧНО, прозрачный фон, move+idle (без attack),
2× размер монстра.

## Образ (арт-дирекция)
Ассасин: ловкий убийца в стильном тёмно-бирюзовом, острые силуэты, лёгкое свечение клинков; ярко-контрастно. Без оружия в руках (оружие — отдельно). Прозрачный фон обязателен.

## СКИЛЛЫ (использовать обязательно)
- Арт модельки — скилл `fantasydisk-asset-generator` (`scripts/generate_asset.py
  --prompt "<...>" --output characters_v2/<id> --size 1024x1024 --quality high`,
  OpenAI Images gpt-image-2, PNG, **ПРОЗРАЧНЫЙ фон** — `background=transparent`).
- Анимация (move/idle) — скилл `fantasydisk-animation-director` (SpriteFrames/
  манифест/контакт/GIF, валидатор, animation_smoke).
Биллинг OpenAI оплачен. Прозрачность ПРОВЕРЯТЬ (нет белого фона/каймы/карманов —
есть инструмент `tools/strip_white_background.py` для дочистки).

## Требования
1. Нарисовать «Ассасин» v2 в ярком эпичном стиле класса (по опорной), на ПРОЗРАЧНОМ
   фоне (нет белого фона/каймы/карманов между рук — проверить и дочистить).
2. Анимации: **idle** (loop, лёгкое дыхание) + **move/walk** (loop, 5+ кадров,
   плавный логичный цикл). **attack НЕ делать.**
3. Размер по правилу опорной (2× средний монстр); единый pivot «ступни по центру».
4. Собрать SpriteFrames (idle/move) скиллом animation-director; путь по шаблону;
   подключить в рантайм (player.gd full-frame), герой ВИДЕН и анимирован.
5. Старые ассеты класса — в бэкап (docs/, вне сборки).
6. Тест: animation+runtime smoke зелёные; на экране «Ассасин» яркий, прозрачный,
   вдвое крупнее монстра, move/idle плавные. Превью-гиф в build/qa/.
7. CHANGELOG; content_registry.

## Acceptance Criteria
- [ ] «Ассасин» перерисован v2: ярко/эпично по классу, прозрачный фон (нет белого/каймы/карманов).
- [ ] idle + move/walk (плавные, loop), attack отсутствует; 2× размер монстра; виден и анимирован в игре.
- [ ] Старое в бэкап; animation+runtime smoke зелёные; превью-гиф; CHANGELOG.

## Документация
docs/design/content_registry.md (assassin), current_game_state.
