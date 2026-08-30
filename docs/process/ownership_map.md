# Карта владения: непересекающиеся write-set для параллельных задач

Источник решения: `docs/process/adr/ADR-parallel-agent-ownership.md` (FAN-3638).
Назначение: PM выдаёт каждой игровой задаче `planned_write_set` по этой карте;
диспетчер ставит `locked_paths` по тем же глобам. Две задачи параллельны,
если их домены различаются и ни одна не превышает бюджет общих файлов.

Колонка «сейчас» действует до соответствующей фазы миграции ADR; «после
миграции» — целевые глобы, включаются по мере влития фаз (помечено фазой).

## Домены

### actor/<actor_id> — анимация и ассеты одного актёра

Сейчас (Фаза 1 — FAN-3660, Фаза 2 — FAN-3814: данные и smoke-тесты пошардированы):
- `data/animation/<kind>/<actor_id>.json`
- `tests/actors/<actor_id>_smoke_test.gd`
- `assets/sprites/**/<actor_id>*`
- свой блок в `docs/design/systems/animation.md` (общий файл!)

После оставшейся миграции:
- `changelog.d/<FAN-id>.md` (Фаза 1, шардирование CHANGELOG — отдельная работа)

Эталонный planned_write_set, пример actor/void_mage:
`data/animation/enemy/void_mage.json`, `assets/sprites/enemies/full_frame/void_mage_8dir/**`,
`tests/actors/void_mage_smoke_test.gd`.

### class/<class_id> — оружие, ультимейты, баланс, VFX одного из 17 классов

(balance/<class> и vfx/<class> — под-срезы этого же домена; отдельные задачи
одного класса НЕ параллелятся между собой, только между классами.)

Сейчас:
- `scripts/ultimates/classes/<class_id>/**`
- `data/ultimates/classes/<class_id>/**`
- `tests/balance/<class_id>/**` (Фаза 2 — FAN-3814), `tests/ultimates/**/<class_id>_*`
- строки своего класса в `build/ultimate_effectiveness_baseline.json` (общий файл!)
- строки своего класса в `scripts/class_weapon.gd` (общий файл!)
- `assets/**/ultimates/<class_id>/**`, `scenes/ultimates/<class_id>*`
- `docs/design/ultimates/<class_id>.md`

После миграции:
- `build/effectiveness/<class_id>.json` (Фаза 1)
- `scripts/classes/<class_id>_weapon.gd` (Фаза 3)
- остальное как сейчас

Эталонный planned_write_set (после Фаз 1–3), пример class/druid:
`scripts/ultimates/classes/druid/**`, `data/ultimates/classes/druid/**`,
`scripts/classes/druid_weapon.gd`, `build/effectiveness/druid.json`,
`tests/balance/druid/**`, `tests/ultimates/**/druid_*`,
`docs/design/ultimates/druid.md`, `changelog.d/FAN-XXXX.md`.

### ui/<screen> — один экран/оверлей UI

Сейчас:
- свой участок `scripts/ui_screens.gd` (общий файл!)
- `scripts/ui/<свои файлы>.gd`, `scenes/ui/**<screen>*`
- `tests/*<screen>*_test.gd`

После миграции (Фаза 3):
- `scripts/ui/screens/<screen>.gd` (+ сцена), `tests/ui/<screen>_*_test.gd`

### core — общие ядра, один агент за раз (не параллелится ни с кем, кто их пишет)

- `scripts/player.gd`, `scripts/enemy.gd`, `scripts/main.gd`,
  `scripts/combat_director.gd`, `scripts/progression_data*.gd`
- фасады реестров: `scripts/full_frame_animation_registry.gd` (после Фазы 1 —
  только логика, не данные), `scripts/ultimates/{registry,schema,controller,
  executors,presentation}/**`
- `tools/**`, `.github/workflows/**`, `project.godot`, `export_presets.cfg`

### process/docs — процессные и дизайн-документы

- `docs/process/**`, `docs/design/**` (кроме пер-классовых
  `docs/design/ultimates/<class_id>.md`, принадлежащих class/<class_id>)

## Общие файлы: бюджет

Файлы вне доменов, которые задача МОЖЕТ трогать — не более ОДНОГО на PR
(после Фазы 4 это проверяет гард в `tools/quality_static_guard.py`; до неё —
дисциплина PM/QA):

- `CHANGELOG.md` — до Фазы 1; после — только `changelog.d/<FAN-id>.md` (свой файл, вне бюджета)
- `docs/design/content_registry.md` — до Фазы 1; после — свой доменный файл `docs/design/content/*.md`
- `docs/design/systems/animation.md`
- `scripts/progression_data_*.gd` (данные классов/врагов — до выноса)

Кросс-доменная задача (меняет ядро + несколько доменов) — это отдельная
пометка `cross-domain` в описании карточки; она не параллелится с задачами
затронутых доменов. Рефакторинги ядра и релизные карты — всегда cross-domain.

## Правила для PM

1. Каждой игровой задаче — ровно один домен из карты; planned_write_set
   собирается из глобов домена + максимум один общий файл из бюджета.
2. Параллельный набор (3–4 задачи) валиден, когда домены попарно различны
   (актёры/классы/экраны разные) и пересечение write-set пусто.
3. Задача, которой нужен чужой домен или второй общий файл, дробится или
   помечается cross-domain и идёт последовательно.
4. QA-карта наследует write-set проверяемой задачи только на чтение; её
   собственные артефакты (скриншоты, отчёты) живут в комментариях Multica,
   не в репозитории.
