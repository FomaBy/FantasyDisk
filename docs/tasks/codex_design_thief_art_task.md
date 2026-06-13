# Codex Design Task: Thief Art Kit

Статус: done (Design review approved 2026-06-12)
Версия: 0.1.4
Создано: 2026-06-12
Роль: Design
Jira: SCRUM-169
Связь: Back-end task `backend_add_character_thief_task.md` / Jira SCRUM-169

## Контекст

Back-end добавляет нового играбельного персонажа `thief` по add-character pipeline. До финального арта используются documented fallback-ассеты ближайшего архетипа (`assassin`/existing rogue weapons). Нужно подготовить канонический visual kit в стиле FantasyDisk.

## Требуемые Ассеты

- `assets/sprites/characters/thief.png` — 512x512 RGBA, прозрачный фон.
- `assets/sprites/weapons/thief_coin_pouch.png` — 256x256 RGBA.
- `assets/sprites/weapons/thief_shadow_cloak.png` — 256x256 RGBA.
- `assets/sprites/weapons/thief_smoke_bomb.png` — 256x256 RGBA.

## Стиль И Референсы

- Стиль: текущий D&D-канон FantasyDisk, painterly/cartoon fantasy, читаемый top-down arena survival.
- Согласовать с существующими героями:
  - `assets/sprites/characters/assassin.png`
  - `assets/sprites/characters/ranger.png`
  - `assets/sprites/characters/soldier.png`
- Персонаж: fantasy thief/rogue, легкая кожаная экипировка, капюшон или полумаска, золотые акценты, не modern burglar и не grimdark horror.
- Нейтральная стойка, ноги разделены для будущего cutout rig, без встроенного оружия в руках, без текста и UI-элементов.

## Оружие

- `thief_coin_pouch`: магический кошель/мешочек с монетами, читается как ricochet/steal weapon.
- `thief_shadow_cloak`: плащ/короткий клинок-тень для backstab-паттерна, читаемый rogue silhouette.
- `thief_smoke_bomb`: компактная дымовая бомба/шарик с фитилем, визуально отличается от химических колб и Soldier grenade.

## Acceptance

- Все PNG добавлены и импортированы Godot.
- Пути совпадают с каноническими ID выше.
- Визуал не flat/stock/grimdark, соответствует существующему D&D/painterly канону.
- После готовности сообщить Back-end, чтобы заменить fallback scene textures/config paths.

## Dispatch

- 2026-06-12: создано Back-end агентом как обязательный Design handoff для SCRUM-169. Пользователь заранее одобрил in-scope изменения.
- 2026-06-13: Design/Codex взял задачу в работу; scope только PNG/import/preview/docs, без Back-end logic и без rig/motion.

## Result

2026-06-13 — Design/Codex visual kit completed and ready for review.

Generated final D&D-canon FantasyDisk PNG assets:

- `assets/sprites/characters/thief.png` — 512x512 RGBA, transparent background;
- `assets/sprites/weapons/thief_coin_pouch.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/thief_shadow_cloak.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/thief_smoke_bomb.png` — 256x256 RGBA, transparent background.

Preview / QA sheet:

- `docs/design/previews/thief_art_contact.png`.

Visual notes:

- Thief is a light fantasy rogue with hood, mask, gold accents, pouches, separated legs, and no embedded weapon.
- Coin pouch reads as a magical ricochet/steal item.
- Shadow cloak reads as stealth/backstab equipment, distinct from a character sprite.
- Smoke bomb is smaller and sleeker than the Soldier grenade and visually distinct from alchemy flasks.

Validation:

- PNG dimensions and alpha validated by script.
- Godot import completed successfully and generated `.import` files.

Handoff:

- Back-end can replace fallback references with the canonical PNG paths above if not already auto-resolved by ID.
- Animator can now proceed with `docs/tasks/animation_thief_rig_motion_task.md`; Design does not perform rig/cutout/motion work.
- 2026-06-12: Codex Documentation dispatcher отправил задачу в Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9`; Jira `SCRUM-169` остается `В работе`, пока Thief pipeline не пройдет art/animation/QA.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-169)
- 4 PNG: `thief.png` 512×512 RGBA + 3 оружия 256×256 RGBA, preview `thief_art_contact.png` на месте.
- Канон D&D: плут в каноне. Прозрачный фон, без watermark. Багов нет.


## Design Review / 2026-06-12 — ПРИНЯТО (Claude-Designer)
- SCRUM-169 Вор: thief 512 + coin_pouch/shadow_cloak/smoke_bomb 256. Тёмно-зелёный плутовской канон, читаемые силуэты.
- Тех: 512 герой / 256 предметы RGBA, bbox в рамке, alpha чистая, .import готов, заведён в progression/player.
- Без текста/watermark. Cutout-нарезка/проводка геймплея — Back-end handoff (backend_new_classes_foundation). Готово к QA.
