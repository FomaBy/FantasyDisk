# Codex Design Task: Elementalist Art Kit

Статус: done (Design review approved 2026-06-12)
Версия: 0.1.4
Создано: 2026-06-13
Роль: Design
Jira: SCRUM-163
Связь: Back-end task `backend_add_character_elementalist_task.md` / Jira SCRUM-163

## Контекст

Back-end добавляет нового играбельного персонажа `elementalist` по add-character pipeline. До финального арта используются documented fallback-ассеты ближайшего магического архетипа (`dark_mage` + existing magic/alchemy weapon textures). Нужно подготовить канонический visual kit в стиле FantasyDisk.

## Требуемые Ассеты

- `assets/sprites/characters/elementalist.png` — 512x512 RGBA, прозрачный фон.
- `assets/sprites/weapons/elementalist_orb_ring.png` — 256x256 RGBA.
- `assets/sprites/weapons/elementalist_prism_focus.png` — 256x256 RGBA.
- `assets/sprites/weapons/elementalist_meteor_core.png` — 256x256 RGBA.

## Стиль И Референсы

- Стиль: текущий D&D-канон FantasyDisk, painterly/cartoon fantasy, читаемый top-down arena survival.
- Согласовать с существующими героями:
  - `assets/sprites/characters/dark_mage.png`
  - `assets/sprites/characters/chemist.png`
  - `assets/sprites/characters/druid.png`
- Персонаж: стихийный маг без grimdark-хоррора, четыре стихии в деталях костюма, мантия/броня легкого caster-типа, яркие но не neon акценты.
- Нейтральная стойка, ноги разделены для будущего cutout rig, без встроенного оружия в руках, без текста и UI-элементов.

## Оружие

- `elementalist_orb_ring`: набор/кольцо стихийных сфер, читается как орбитальная защита.
- `elementalist_prism_focus`: кристалл/призма для крестового elemental rift.
- `elementalist_meteor_core`: раскаленное ядро/метеорный фрагмент, отличимый от обычной бомбы/пороха.

## Acceptance

- Все PNG добавлены и импортированы Godot.
- Пути совпадают с каноническими ID выше.
- Визуал не flat/stock/grimdark, соответствует существующему D&D/painterly канону.
- После готовности сообщить Back-end, чтобы заменить fallback scene textures/config paths.

## Dispatch

- 2026-06-13: создано Back-end агентом как обязательный Design handoff для SCRUM-163. Пользователь заранее одобрил in-scope изменения.
- 2026-06-12: Codex Documentation dispatcher не отправил задачу: task-файл и Jira key есть, но отдельной строки `codex_design_elementalist_art_task.md` нет в `docs/process/task_board.md`. PM/owner должен синхронизировать board row перед dispatch.
- 2026-06-13: dispatched to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` after board row appeared; scope is Design-only canonical Elementalist art kit. Jira SCRUM-163 remains shared with Elementalist pipeline and should stay open until art/animation pipeline finishes.

## Result

2026-06-13 — Design/Codex visual kit completed and ready for review.

Generated final D&D-canon FantasyDisk PNG assets:

- `assets/sprites/characters/elementalist.png` — 512x512 RGBA, transparent background;
- `assets/sprites/weapons/elementalist_orb_ring.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/elementalist_prism_focus.png` — 256x256 RGBA, transparent background;
- `assets/sprites/weapons/elementalist_meteor_core.png` — 256x256 RGBA, transparent background.

Preview / QA sheet:

- `docs/design/previews/elementalist_art_contact.png`.

Visual notes:

- Elementalist is a bright D&D/painterly caster with four elements integrated into costume details, distinct from Dark Mage, Chemist, and Druid.
- Orb ring reads as orbiting elemental defense.
- Prism focus reads as a cross-rift spell focus.
- Meteor core reads as molten stone, not a bomb or grenade.

Validation:

- PNG dimensions and alpha validated by script.
- Godot import completed successfully and generated `.import` files.

Handoff:

- Back-end can replace fallback references with the canonical PNG paths above if not already auto-resolved by ID.
- Animator can now proceed with `docs/tasks/animation_elementalist_rig_motion_task.md`; Design does not perform rig/cutout/motion work.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-163)
- 4 PNG: `elementalist.png` 512×512 RGBA + 3 оружия 256×256 RGBA, preview `elementalist_art_contact.png` на месте.
- Канон D&D: маг стихий в каноне. Прозрачный фон, без watermark. Багов нет.


## Design Review / 2026-06-12 — ПРИНЯТО (Claude-Designer)
- SCRUM-163 Элементалист: 512 + orb_ring/prism_focus/meteor_core 256. 4 стихии когерентно, насыщенный фэнтези-арт.
- Тех: 512 герой / 256 предметы RGBA, bbox в рамке, alpha чистая, .import готов, заведён в progression/player.
- Без текста/watermark. Cutout-нарезка/проводка геймплея — Back-end handoff (backend_new_classes_foundation). Готово к QA.
