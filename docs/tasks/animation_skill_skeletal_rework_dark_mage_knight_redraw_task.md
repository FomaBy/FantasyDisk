# ANIM: Переделать animation-скилл на СКЕЛЕТНУЮ анимацию (Skeleton2D/Bone2D) + перерисовать мага и рыцаря под неё

Статус: blocked
Приоритет: high
Роль: Animator (Codex)
Исполнитель: Codex (скилл fantasydisk-animation-director)
Версия: 0.1.6
Создано: 2026-06-17
Автор: PM (запрос пользователя)
Jira: SCRUM-474
Связано: SCRUM-456 (cartoon style-anchor), SCRUM-473 (покадровые кадры мага/рыцаря — РЕДИРЕКТ на скелет), animation-director skill

## Autonomy / Approval
Полная автономия. Пользователь одобрил направление.

## Контекст (запрос пользователя)
«Создай тикет на переделку скилла по анимации на анимацию, использующую СКЕЛЕТ
персонажа. Для этого необходимо Тёмного мага и Рыцаря перерисовать — чтобы было
удобно использовать этот тип анимации.»

Текущий рантайм анимации персонажей — это либо full-frame покадровые спрайт-листы,
либо cutout-риг (нарезка готового спрайта на части по hand-tuned боксам). Тёмный
маг/рыцарь сейчас на временном legacy-риге (bob целым спрайтом). Пользователь хочет
ПЕРЕЙТИ на настоящую СКЕЛЕТНУЮ анимацию (Skeleton2D + Bone2D + AnimationPlayer), а
для этого спрайты должны быть нарисованы в skeleton-friendly виде.

## Цель
1. **Переделать скилл `fantasydisk-animation-director`**, чтобы ОСНОВНЫМ
   (предпочтительным по умолчанию) пайплайном анимации играбельных персонажей стала
   **скелетная анимация Skeleton2D/Bone2D**: кости, иерархия, AnimationPlayer-таймлайны
   (idle/walk), и интеграция в рантайм (нативный Skeleton2D ИЛИ запекание rig→sprite-sheet
   там, где рантайм ждёт AnimatedSprite2D/SpriteFrames). Cutout-нарезка готового
   статичного спрайта перестаёт быть основным путём для персонажей.
2. **Задать контракт skeleton-friendly исходной графики** (см. ниже) в SKILL.md +
   валидатор.
3. **Перерисовать Тёмного мага и Рыцаря** под этот контракт (раздельные части под
   кости), тем же мультяшным мотивом (SCRUM-456), и собрать на них первый
   скелетный риг как эталон.

## Контракт skeleton-friendly графики (для перерисовки)
- Нейтральная A/T-поза, фронт; конечности НЕ перекрывают друг друга и торс
  неоднозначно (чистые суставы для разрезания на кости).
- Раздельные части (слои/отдельные PNG): голова, торс, таз, плечо+предплечье+кисть
  ×2, бедро+голень+стопа ×2; для мага — сегменты плаща/робы (можно как отдельные
  «кости-лоскуты» для вторичного движения). Пустые руки (оружие — сокет).
- Пивоты/суставы на стыках частей выровнены; части слегка перекрываются в суставе
  для бесшовности при повороте кости.
- Прозрачный RGBA, без шахматки/матовой подложки/тени/рамки/текста.
- Стиль/мотив сохранить (маг — капюшон/роба/фиолет; рыцарь — латы сине-золотой),
  тот же уровень мультяшности, что в cartoon2 (assets/sprites/characters/{dark_mage,knight}.png).

## Скелетный риг (эталон: маг + рыцарь)
- `Skeleton2D` + `Bone2D` иерархия (таз→позвоночник→голова, плечи→руки, бёдра→ноги),
  части-спрайты привязаны к костям.
- `AnimationPlayer`: `idle` (дыхание/осадка робы/плаща, лёгкое колыхание) loop;
  `walk`/`move` — читаемый цикл (contact/passing/lift/recovery) loop, ≥5 ключей.
- **`attack` НЕ делать** — за атаки отвечает оружие (USE_ATTACK_ANIMATION=false).
- Интеграция в рантайм `player.gd` (заменить legacy-риг для этих классов);
  оружейный сокет сохранить.

## Acceptance Criteria
- [ ] SKILL.md `fantasydisk-animation-director` описывает СКЕЛЕТНЫЙ пайплайн как
      основной + контракт skeleton-friendly графики + валидацию; cutout/full-frame —
      только для legacy/боссов где уместно.
- [ ] Тёмный маг и Рыцарь перерисованы по контракту (раздельные части), мотив сохранён.
- [ ] На них собран Skeleton2D/Bone2D риг с idle + walk (loop), без attack; в рантайме
      персонажи анимируются скелетно (заменён legacy-риг).
- [ ] `validate_animation_manifest.py` (или новый скелетный валидатор) + animation_smoke
      + runtime_smoke зелёные.
- [ ] Подход воспроизводим: задокументировано, как прогнать остальные 15 классов later.

## Files
- `~/.codex/skills/fantasydisk-animation-director/` (SKILL.md, scripts, references)
- `assets/sprites/characters/{dark_mage,knight}*` (+ части/слои/риг-сцены)
- `scripts/player.gd` (интеграция скелетного рига для cartoon-классов; CARTOON_TRIAL_CLASSES)
- `scripts/cutout_rig_2d.gd` / новые риг-сцены (`.tscn` со Skeleton2D)
- `tests/animation_smoke_test.gd`

## Примечание
Редиректит SCRUM-473 (покадровые кадры) на скелетный подход для этих классов —
кадры заменяются скелетным ригом. Остальные 15 классов перерисовываются под скелет
отдельной волной после приёмки эталона.

## Animator Intake / Blocker (2026-06-19)

Animator picked up SCRUM-474 from the heartbeat watcher and verified the current
`dev` branch plus role boundaries. The task is valid Animator work, but it
contains a required Design deliverable: final skeleton-friendly redraw/source
parts for Dark Mage and Knight. Animator must not generate final Design source
art or separated character parts directly.

Animator-owned work completed now:
- Updated `~/.codex/skills/fantasydisk-animation-director/SKILL.md` so the
  preferred playable-character path is `Skeleton2D`/`Bone2D` + `AnimationPlayer`
  when accepted separated parts exist.
- Added skeleton source-part validation script:
  `~/.codex/skills/fantasydisk-animation-director/scripts/validate_skeleton_source_manifest.py`.

Blocked until Design provides accepted source parts:
- Handoff created:
  `docs/tasks/design_skeleton_friendly_dark_mage_knight_parts_task.md`.
- Animator will resume after Design delivers transparent separated PNG parts,
  pivots, and a passing skeleton source manifest for `dark_mage` and `knight`.

No runtime files, gameplay, balance, UI, or live animation resources were changed
in this intake pass.

Jira sync note: attempted `python3 tools/jira_board_sync.py` on 2026-06-19, but
sync aborted because `/tmp/fantasydisk_jira_sync.lock` is held by an older
`tools/jira_board_sync.py --no-create` process (PID 44690). Jira mirror remains
pending until that lock clears.
