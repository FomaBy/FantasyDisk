# FAN-1883 — понятные атрибуты: UI/UX spec

Статус: `ready_for_integration`
Владелец: Design/UI (FAN-1885)
Базовый viewport: 1920×1080
Проверяемые viewport: 1280×720, 1920×1080, 2560×1440
Preview: `docs/design/previews/fan1883_attribute_clarity/attribute_clarity_1920x1080.png`
Generator provenance: `docs/design/references/fan1883_attribute_clarity/manifest.json`

## Решение

Новая карточка всегда отвечает на три вопроса: **что изменится**, **сколько было → стало** и **какой реальный прирост получен сейчас**. Она не показывает сырой модификатор, внутренний параметр или «слабую» альтернативу.

- «Добавление урона» — плоское `+N` к фактическому физическому **или** магическому каналу текущего оружия. Канал подписывается в строке результата, а не отдельной универсальной карточкой.
- «Увеличение урона» — процентный `+N%` к фактическому урону. Это отдельная ось и отдельная единица измерения.
- Один player-facing показатель «Увеличение области атаки» покрывает радиусы, ауры, ширину лучей и секторные атаки. `aura_radius`, сектор и ширина луча не образуют самостоятельных карточек.
- Неприменимый для класса, оружия, capability или текущего cap выбор **отсеивается до построения offer**. Не существует плитки с пометкой «слабый», `0`, «не для вас» или disabled-кнопки в ряду выбора.
- Все текстовые значения, заголовки, иконки и стрелки создаются runtime Controls. PNG ниже — только review/geometry evidence, не runtime asset.

## Общий контракт карточки

Каждая selectable карточка имеет один `presentation` view-model:

| Поле | Отображение | Требование |
| --- | --- | --- |
| `axis_id`, `axis_name`, `unit` | имя оси и единица | одно имя и одна единица на ось |
| `effect_sentence` | простая фраза «Что изменится» | без ключей, формул и внутренних названий |
| `before`, `after`, `delta_effective` | `было → стало`, затем `реально: +…` | вычислено после diminishing/cap |
| `channel_label` | `Физический урон` или `Магический урон` | только для плоского/процентного урона; по фактическому оружию |
| `current`, `cap` | `сейчас X · максимум Y` | для `crit_chance` и `vampiric`; cap не скрывается |
| `availability` | отсутствует из offer, если не `eligible` | `class_ineligible`, `cap_reached`, `no_capability`, `zero_effective_delta` никогда не рисуются как выбор |

Карточка не содержит длинную формулу. Длинное русское объяснение открывается тем же tooltip/focus drawer и полностью скроллится; на самой карточке допускается до двух строк `effect_sentence` и одна строка `before → after / реально`. `OVERRUN_TRIM_ELLIPSIS` для этих данных запрещён.

### Состояния, обязательные для каждого surface

| Состояние | Level Up | Attribute Shop | Pause / Codex | Hero Select |
| --- | --- | --- | --- | --- |
| normal | 3 применимых выбора | 2–3 применимых базовых характеристики | текущие реальные значения | оси и capability текущего героя |
| class-ineligible | карточка отсутствует до раскладки | характеристика с нулевым итогом отсутствует; ряд не резервируется | в «Этот герой» отсутствует; общий справочник не выдаёт её за доступную | не попадает в рекомендации и не именуется «слабой» |
| capped | ось с `delta_effective=0` заменяется альтернативой | не продаётся; не занимает слот | сохраняется как строка `достигнут максимум`, без CTA | потенциал показывает `текущий / максимум`, без ложного обещания роста |
| long Russian copy | focus drawer — scroll, карточка не обрезается | tooltip/drawer — scroll | detail scroll — scroll | dossier scroll — scroll |

## Канонические player-facing оси

| Axis ID | Игрок видит | Единица | Простое действие | Current runtime source / backend handoff |
| --- | --- | --- | --- | --- |
| `damage_flat` | Добавление урона | урон | Каждый подходящий удар сильнее на N | `run_modifiers.damage_flat`; канал через `ProgressionData.damage_parameter_for(character_id)` и `derived_parameters.damage`/`magic_damage` |
| `damage_percent` | Увеличение урона | % | Все подходящие удары сильнее на N% | `run_modifiers.damage_multiplier`; магический канал остаётся в `magic_damage_multiplier`, но не становится «Магическим фокусом» |
| `attack_speed` | Скорость атаки | атак/с | Атакуете чаще | `attack_speed_multiplier` → `derived_parameters.attack_speed` |
| `max_health` | Максимальное здоровье | HP | Можете получить больше урона | `max_health_flat`, `max_health_multiplier` → `health_point` |
| `move_speed` | Скорость движения | ед./с | Быстрее двигаетесь | `move_speed_multiplier` → `move_speed` |
| `attack_area` | Увеличение области атаки | % | Больше зона попадания, аура, луч или сектор | `aoe_radius_multiplier` → `aoe_radius`; backend объединяет представление `aura_radius`, beam/sector consumers |
| `pickup_radius` | Радиус подбора | ед. | Подбираете предметы издалека | `pickup_radius_flat` → `pickup_radius` |
| `defense` | Защита | % снижения | Каждый удар врага слабее | `defense_flat` → effective `defense`; `absorb` остаётся internal-only |
| `crit_chance` | Шанс крита | % | Чаще наносите критический удар | `crit_chance_flat`, Agility, `class_crit_profile().cap`; current and cap are required |
| `crit_power` | Сила крита | × | Критический удар сильнее | `crit_damage_flat` → `crit_damage_multiplier` |
| `dodge` | Уклонение | % | Часть ударов не попадает | `dodge_flat` → effective `dodge` |
| `dot_damage` | Периодический урон | урон/тик | Яд, горение и кровотечение сильнее | `dot_damage_flat` → `dot_damage`; `dot_speed` is internal cadence only |
| `summon_power` | Сила призыва | сила | Призывы и deploy-объекты сильнее | `summon_bonus` → `summon_amount`; emit only when current class/weapon has a real consumer |
| `regeneration` | Регенерация | HP/с | Восстанавливаете HP со временем | `regeneration_flat` → `regeneration` |
| `vampiric` | Вампиризм | HP при срабатывании | При ударе можете восстановить HP | `vampiric_amount_flat`, `vampiric_chance_flat`, `vampiric_heal_per_second_cap`; current chance and fixed `VAMPIRIC_CHANCE_CAP` shown together |
| `ultimate_power` | Сила ультимейта | % | Ультимейт сильнее | `ultimate_flat` → `ultimate_multiplier` |
| `projectile_count` | Количество снарядов | снаряд | Выпускаете ещё N снарядов | capability-gated `extra_projectile` / weapon consumer; never infer it from arbitrary multi-target/tick/trap modes |

### Запрещённые самостоятельные выборы

`attack_range`, `projectile_speed`, `buff_power`, `knockback_power`, `knockback_distance`, `dot_speed`, `aura_radius`, `sector_multiplier`, `range_multiplier`, `absorb`, `vampiric_amount` и `vampiric_chance` не получают своих карточек. Они могут существовать в runtime-derived layer и участвовать в расчёте эффективной дельты.

## Инвентарь и geometry

### 1. Level Up

| ID | Rect @1920×1080 | Anchors / safe zone | Runtime content |
| --- | --- | --- | --- |
| `LU.Backdrop` | `0,0,1920,1080` | full rect, existing `ui_backdrop_arcane_lab` | existing artwork only |
| `LU.Shade` | `0,0,1920,1080` | full rect | readable dim |
| `LU.Title` | `560,92,800,64` | top-center | `Выберите улучшение` |
| `LU.OfferRow` | `270,254,1380,490` | centered, 3 equal cells / 36 gap | only eligible offers |
| `LU.Card[n]` | `270 + n×472,254,436,490` | local card safe content `32,30,32,30` | axis, effect, factual before/after/delta, cap line when relevant |
| `LU.DetailDrawer` | `510,770,900,190` | bottom-center, scroll body `32,24,32,24` | focused long Russian copy and capability explanation |
| `LU.Continue` | `760,978,400,64` | bottom-center | only where skip/continue is allowed |

Cards have sections `icon 48×48`, title `340×36`, result `340×62`, delta badge `340×34`, cap line `340×28`; the rest is a two-line effect sentence. At 1280×720 the stage uniformly scales to 0.667 inside `1280×720`; at 2560×1440 it scales 1.333. No reflow means the three cards remain three cards and card content stays in its authored safe zone.

### 2. Attribute Shop

| ID | Rect @1920×1080 | Anchors / safe zone | Runtime content |
| --- | --- | --- | --- |
| `AS.GoldShell` | existing inner rect | existing unified Gold shell | unchanged ornament |
| `AS.Title` | `710,126,500,60` | top-center inside shell | `Докачка` |
| `AS.Money` | `140,138,380,50` | top-left inner shell | current gold |
| `AS.OfferRow` | `350,286,1220,410` | centered, `360×410` cards / `70` gap | eligible base-characteristic offers |
| `AS.Card[n]` | `350 + n×430,286,360,410` | Atlas card content `28,26,28,26` | characteristic, simple downstream result, factual delta |
| `AS.Actions` | `590,866,740,72` | bottom-center inner shell | reroll, skip |
| `AS.DetailDrawer` | `470,704,980,132` | below offers, scroll | long copy and all affected player-facing axes |

`_attribute_shop_layout_for_size()` currently supports two/three entries but reserves a three-card row. The integration must instead pass `eligible_stat_ids`; an ineligible or cap-reached base characteristic is removed before `AttributeOffers` children are built. The row is recentered after filtering and never exposes an empty/weak card.

### 3. Pause / Codex

Pause routes the user to Codex rather than a new stat skin. Existing Pause controls remain unchanged; the selected `Характеристики` Codex tab gets the comparison panel below.

| ID | Rect @1920×1080 | Anchors / safe zone | Runtime content |
| --- | --- | --- | --- |
| `CX.Stage` | `0,0,1920,1080` | uniform stage scale | existing Codex shell/backdrop |
| `CX.Nav` | `72,172,324,840` | existing panel_9slice content | category tabs |
| `CX.AxisList` | `452,278,556,690` | scroll content | current hero’s player-facing axes only |
| `CX.AxisRow` | `460,290,516,154` stride `170` | existing entry-card inner zone | name, unit, now, cap state |
| `CX.Detail` | `1064,172,784,840` | existing panel_9slice content | plain explanation, exact before/after history and full long copy |
| `CX.CapChip` | `1432,396,330,70` | existing chip_bar content `18,14,18,14` | `сейчас X · максимум Y` when chance has cap |

The existing `CodexStage` transform is preserved: uniform centered scales `0.667 / 1.0 / 1.333` for the requested matrix. A player-ineligible axis does not appear in `CX.AxisList`; a universal glossary entry may explain it separately but cannot be shown as an available reward. A capped row remains readable history with no upgrade CTA.

### 4. Hero Select

| ID | Rect @1920×1080 | Anchors / safe zone | Runtime content |
| --- | --- | --- | --- |
| `HS.Shell` | `160,120,1600,830` | existing Hero Select gold rails | unchanged shell |
| `HS.Portrait` | existing live rect | portrait frame inner zone | selected hero |
| `HS.Dossier` | `706,280,1012,286` | existing `HS4DossierContentSafe` | scrollable hero explanation |
| `HS.CurrentAxes` | `742,309,590,231` | left scroll lane, 16px scrollbar reserve | current recommended axes and capability-only axes |
| `HS.BaseStats` | `1362,309,320,231` | fixed 8-stat lane | current base stats, unchanged geometry |
| `HS.CapPotential` | within dossier after axes | scroll body | crit/vamp current and maximum; no CTA |
| `HS.CapabilityLine` | within dossier after axes | scroll body | visible only for real summon/projectile consumers |

No «Слабые атрибуты» rail is retained. The dossier lists what this hero can actually receive; exclusions are not displayed as choices. At 1280×720 the existing 2×4 stat reflow stays fixed and the dossier remains a scroll lane. Long Russian copy is therefore complete and scrollable, not shortened.

## Responsive matrix and no-overlap checks

| Viewport | Policy | Required visual result |
| --- | --- | --- |
| 1280×720 | uniform `0.667` for Level Up/Codex; current Shop/Hero compact rules | no clipped line; Shop row and actions separate; Hero dossier scrollbar remains free |
| 1920×1080 | authored rects | every content rectangle stays within declared inner safe zone |
| 2560×1440 | uniform `1.333` for Level Up/Codex; current Shop/Hero large rules | no stretched ornament; `NinePatchRect`/StyleBoxTexture margins unchanged |

Visual validation must inspect all 12 combinations (4 surfaces × 3 viewports), each in normal, filtered-ineligible, capped and longest-copy fixtures. Focus/hover/pressed/disabled must never change geometry.

## Backend handoff — FAN-1887

This design makes no runtime, formula, reward or balance change. FAN-1887 owns the data/UI implementation and must build one view-model **after** reward relevance, capability and effective calculation:

```text
AttributePresentation {
  axis_id, axis_name, unit, effect_sentence, channel_label?,
  before, after, delta_effective, current?, cap?,
  availability: eligible | class_ineligible | no_capability | cap_reached | zero_effective_delta
}
```

Required input sources are exact current keys: `ProgressionData.ATTRIBUTE_REGISTRY`, `ATTRIBUTE_RELEVANCE`, `ContentData.LEVEL_UP_REWARDS[].attr`, `LevelUpReward.mods`, `Player.run_modifiers`, `ProgressionData.derived_parameters()`, `StatFormulas.DERIVED_STAT_ORDER`, `StatFormulas.DERIVED_BASE_DEPENDENCIES`, `ProgressionData.class_crit_profile()`, `ProgressionData.VAMPIRIC_CHANCE_CAP`, and current weapon/class capability data. `extra_projectile` must be normalized to a capability-specific projectile-count consumer before it reaches this view-model.

Backend must:

1. replace current `magic_focus`, `range`, `buff_power`, `absorb` and internal-only rows with the canonical axes above; never remove internal consumers merely to remove a UI label;
2. provide actual `before`, `after`, `delta_effective` after all current diminishing and caps, and set `zero_effective_delta` when the displayed gain is zero;
3. provide `crit_chance.current/cap` from the Agility-driven profile (ordinary cap starts 55%, grows by 0.5pp over class-base Agility to 75%; Assassin 100%) and `vampiric.current/cap` with fixed 20% cap;
4. filter all non-`eligible` presentations before the Level Up and Shop rows are built; and
5. preserve the existing Gold-shell, Atlas/Codex and Hero Select assets/rects in this spec. No raster asset promotion is part of the handoff.

## Acceptance checklist

- [x] Inventory covers Level Up, Attribute Shop, Pause/Codex and Hero Select.
- [x] Each surface has normal, class-ineligible, capped and long-copy contracts.
- [x] All player-facing axes have one name, unit and result; prohibited internal axes are not separate choices.
- [x] Before/after, effective delta and current cap requirements are explicit.
- [x] Bounds, anchors, safe zones, content margins and all requested viewports are specified.
- [x] Exact current data keys and backend handoff are specified without altering runtime files.
- [x] Existing generator-routed backgrounds, frames, buttons and icons are reused; no new runtime asset or baked runtime text is requested.
