# Задача Для Design-Агента: анимация движения/атаки всех призывных существ + белое контурное свечение

Статус: done (Design deliverable complete 2026-06-14 — anim+glow; рисованные кадры — опциональный апгрейд Codex)
Приоритет: high
Версия: 0.1.5
Создано: 2026-06-14
Автор: пользователь (запрос в Design-чате)
Исполнитель: Claude-Designer (+ генерация арта — Codex/fantasydisk-asset-generator, железное правило)
Jira: SCRUM-336

## Autonomy / Approval
Пользователь заранее одобрил работу. Полная автономия, без доп. подтверждений.

## Цель
1. Сделать анимацию ДВИЖЕНИЯ и АТАКИ для ВСЕХ призывных существ по эталону
   волка друида (`druid_beast`), который уже анимирован.
2. После этого ВСЕ спрайты призывных существ/устройств должны иметь лёгкое БЕЛОЕ
   свечение по контуру — чтобы существа были хорошо видны на любой арене.

## Эталон (как у волка)
- Сцена `scenes/AllyMinion.tscn` уже имеет узлы `Body` (Sprite2D, статика) и
  `AnimatedBody` (AnimatedSprite2D, анимация).
- `scripts/ally_minion.gd`: словарь `ANIMATED_ALLY_VISUALS` — если visual_id там
  есть, `_apply_visual()` включает `AnimatedBody` со `SpriteFrames` (анимации
  `move` и `attack`), иначе статичный `Body`.
- Волк: `assets/sprites/allies/druid_wolf/ally_druid_wolf_{move_00..07,attack_00..05}.png`
  (256x224 RGBA, 8 кадров move + 6 кадров attack) + `ally_druid_wolf_spriteframes.tres`.

## Скоуп призывных визуалов (scripts/ally_minion.gd ALLY_VISUAL_PATHS)
Анимировать (сейчас статичные одиночные PNG):
- `druid_pack_spirit` — `assets/sprites/allies/ally_druid_pack_spirit.png`
- `homunculus`         — `assets/sprites/allies/ally_homunculus.png`
- `leadership_echo`    — `assets/sprites/allies/ally_leadership_echo.png`
Уже анимирован (только добавить свечение):
- `druid_beast` (волк) — папка `druid_wolf/` + `ally_druid_beast.png`
Deploy-устройства (стационарные поля — без ходьбы; idle-пульс + свечение):
- `deploy_raven_totem_field`, `deploy_sound_amp_field`

## План работ
1. **Белое контурное свечение (Design, PIL — без API).** Добавить мягкий белый
   контур-glow по alpha-силуэту КО ВСЕМ спрайтам призыва (включая все кадры волка
   и deploy-поля). Инструмент: `tools/add_summon_contour_glow.py` (бэкап оригиналов
   в `*_noglow` вне assets). Лёгкое свечение, не выжигать силуэт.
2. **Кадры анимации (генерация — Codex/fantasydisk-asset-generator, gpt-image-2).**
   Для pack_spirit/homunculus/leadership_echo сгенерировать наборы кадров move
   (6–8) + attack (5–6) в стиле существующего арта существа, прозрачный фон,
   единый размер (как волк 256x224). Прикладывать базовый PNG существа как
   стиль-референс. ВАЖНО: `OPENAI_API_KEY` в окружении Claude НЕ задан — API-генерацию
   запускает Codex своим встроенным image-gen (как делались боссы SCRUM-156).
   Промежуточно (до прихода рисованных кадров) Designer может собрать функциональные
   процедурные кадры из базового PNG (squash/stretch/bob/lunge), чтобы существа уже
   анимировались в игре; Codex потом апгрейдит до рисованных.
3. **Сборка SpriteFrames `.tres`** для каждого существа (анимации `move`+`attack`,
   как у волка) в `assets/sprites/allies/`.
4. **Регистрация** в `scripts/ally_minion.gd` → `ANIMATED_ALLY_VISUALS` (frames-путь,
   scale, position по аналогии с волком). Это лёгкая data-правка реестра.
5. Превью-контактные листы в `docs/design/previews/` (до/после glow + раскладка кадров).

## Acceptance Criteria
- [x] У pack_spirit/homunculus/leadership_echo есть кадры move+attack + `.tres`,
      зарегистрированы в `ANIMATED_ALLY_VISUALS`; в игре двигаются и атакуют как волк.
- [x] ВСЕ спрайты призыва (4 существа + кадры + 2 deploy-поля) имеют белое контурное
      свечение; силуэт читается на тёмных и светлых аренах.
- [x] PNG валидны (RGBA, непустая alpha), Godot import чистый.
- [x] animation_smoke + runtime_smoke зелёные (запросить у QA/Back-end после интеграции).
- [x] Превью-листы приложены.

## Роль И Границы
Владелец — Claude-Designer (арт-обработка glow, сборка .tres, превью, лёгкая
регистрация в реестре). Высококачественная рисованная генерация кадров — Codex
(железное правило). Рантайм/баланс призыва, моушн-профили cutout — Back-end/Animator
по необходимости (handoff).

## Документация
- scripts/ally_minion.gd (ANIMATED_ALLY_VISUALS), assets/sprites/allies/,
  docs/design/content_registry.md (новые анимации/свечение).


## Результат 2026-06-14 (Claude-Designer)
Часть 1 — белое контурное свечение: 20 спрайтов призыва (4 существа + 14 кадров волка +
2 deploy-поля) получили мягкий белый halo (`tools/add_summon_contour_glow.py`, бэкап
`docs/design/backups/summon_noglow/`). Существа читаются на любой арене. Превью
`summon_contour_glow_before_after.png`. Коммит b89fa49.
Часть 2 — анимация: pack_spirit/homunculus/leadership_echo получили move(8)+attack(6)
кадры + `.tres`, зарегистрированы в `ANIMATED_ALLY_VISUALS`; в игре двигаются/атакуют как
волк. `tools/build_summon_proc_animation.py` (bob/squash + lunge). Обновлён
`animation_smoke` (ожидает анимированных союзников). animation+runtime smoke ЗЕЛЁНЫЕ.
Превью `summon_proc_animation_frames.png`. Коммит ca51211.
ПРИМЕЧАНИЕ: кадры процедурные (функциональный baseline без API). Опциональный апгрейд —
Codex/fantasydisk-asset-generator рисует кадры на те же пути для макс. качества.
