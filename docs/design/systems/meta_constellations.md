# Мета 4.0 «Созвездия героев» — дерево умений и метапрогрессия (редизайн с нуля)

> **Целевой контракт SCRUM-1067 (schema 6, реализация — SCRUM-1068).**
> Исторические разделы Меты 4.0/4.1 ниже продолжают описывать schema-5 runtime
> до внедрения. Новый источник истины для следующей схемы:
> `docs/design/reports/scrum1067_constellation_3x6_balance_spec.md` и
> `docs/design/data/scrum1067_weapon_finals_manifest.json`.
>
> На класс: одно бесплатное ядро, три canonical weapon-owned ветви по шесть
> cost-1 узлов и две revealed-then-purchased hidden side stars cost 1. Итого
> 21 узел, полный spend 20. Шестой узел каждой ветви — уникальный mechanic-first
> weapon final; все три финала действуют одновременно только на своё оружие.
> Machine manifest явно инстанцирует все 306 branch nodes и 34 hidden effect
> profiles с axis/effect/cap/consumer/fixture; reveal не активирует hidden без
> отдельной покупки.
> Старые class-wide mutually-exclusive keystone и auto-active hidden в schema 6
> не переносятся.

Обновлено: 2026-07-03. Автор: PM/game-design (Fable 5), по прямому мандату
продукта. Заменяет как целевую архитектуру: `skill_tree.md` (v3, SCRUM-807 —
остаётся описанием ТЕКУЩЕГО кода до внедрения), части `progression_balance.md`
(мета-слой) и распределённые описания CLASS_PROGRESSION / CLASS_CHALLENGES.

Мандат продукта: игрок должен играть дольше, постоянно открывать новые
возможности и усиливать персонажа; каждый класс — уникальный геймплей; всё в
балансе; интерфейс дерева — удобный и красивый, чтобы его было интересно
изучать.

---

## 1. Диагноз: почему один общий граф не решает задачу

v2/v3 честно улучшали контент узлов, но архитектура «один граф на всех» имеет
потолок:

1. **UX-масштаб.** 192 узла на одном полотне — это карта, а не игрушка. Чтобы
   найти «свои» 9 узлов, игрок листает 17 чужих ветвей. Изучать неудобно, а
   значит неинтересно — прямое противоречие мандату.
2. **Обезличенные очки.** Общий пул `skill_points`: играя берсерком, качаешь
   «аккаунт». Психологическая связь «играю героем → расту героем» не работает,
   хотя начисление и так уже per-class (`meta_point_awards`).
3. **Нет discovery.** Всё дерево видно с первой секунды. Открывать нечего —
   только докупать. Мандат «открывал для себя новые возможности» не закрыт.
4. **Мета распылена.** Дерево, награды возвышений (`ASCENSION_LEVELS`),
   `CLASS_PROGRESSION` (за победы), `CLASS_CHALLENGES`, кодекс и секретный босс —
   шесть несвязанных систем. Игрок не видит их как одну прогрессию.

Вывод: не «ещё больше узлов в общем графе», а смена рамки.

## 2. Архитектура: два слоя

```
МЕТА 4.0
├── СОЗВЕЗДИЕ КЛАССА (×17)  — личное дерево героя, ~22 узла,
│   валюта: ЭМБЛЕМЫ КЛАССА (sigils), зарабатываются только этим классом.
│   Форма созвездия = силуэт классового символа. Уникальные механики.
└── АТЛАС ГИЛЬДИИ (×1)      — общий слой QoL/экономики, ~24 узла,
    валюта: ЗВЁЗДНАЯ ПЫЛЬ (stardust), за аккаунт-вехи всеми классами.
    Боевой силы почти не несёт (4 наследных keystone v2 — отдельный бюджет).
```

Почему так:
- Личное созвездие на экран целиком (~22 узла) — компактно, без пан/зума,
  красиво читается как ОБРАЗ (секира берсерка, прицел снайпера). Изучение
  дерева = разглядывание символа своего героя. Это «интересно изучать».
- Две валюты чинят мотивацию: эмблемы героя тратятся только на героя;
  пыль — редкая аккаунт-валюта для общих удобств. Играть РАЗНЫМИ классами
  всё ещё выгодно (пыль дают вехи «первая победа классом», «A5 классом»).
- Разрозненные системы стягиваются в одну картину: челленджи класса открывают
  СКРЫТЫЕ ЗВЁЗДЫ его созвездия; кодекс и секретный босс сыплют пыль в Атлас;
  награды возвышений остаются пассивным фоном (не трогаем, SCRUM-516).

## 3. Созвездие класса — анатомия (на класс: 21–23 узла)

| Тип узла | Кол-во | Цена | Что даёт |
| --- | --- | --- | --- |
| Ядро-эмблема | 1 | 0 (открыт) | Центр созвездия, герб класса, +1 primary-атрибут — «первый вкус» без гринда |
| Звезда-атрибут (minor) | 12 | 1 | `+1`/`+2` ТОЛЬКО primary/secondary атрибутов класса (матрица `ATTRIBUTE_RELEVANCE` — жёсткий гейт) |
| Звезда-техника (notable) | 4 | 2 | Механика оружия/ульты класса, не голый процент: «спора перепрыгивает на +1 цель», «вихрь шире на +20%», «мина взводится на 0.4с быстрее» |
| Ключевая звезда (keystone) | 2–3 | 4 | Взаимоисключающие СТИЛИ ИГРЫ (активен максимум один; переключение купленных — бесплатно, в любой момент между забегами) |
| Скрытая звезда (hidden) | 2 | — | Не покупается: ОТКРЫВАЕТСЯ подвигом класса (см. §5). До открытия — туманное «?» с текстом условия |

Стоимость полного созвездия: 12×1 + 4×2 + (2–3)×4 = **28–32 эмблемы**
(+2 скрытые звезды вне денег).

**Keystone-пары — сердце уникального геймплея.** У каждого класса 2–3
взаимоисключающих капстоуна с осмысленным трейд-оффом (downside обязателен,
ориентир ≥25% ценности апсайда). Эталонные примеры (полная таблица 17 классов —
приложение A, заполняется в реализационном тикете по этим правилам):

- **Берсерк**: «Кровавый танец» — вампиризм ×2 при HP<50%, но лечение лавки
  −50% || «Несущий бурю» — +2% урона за врага в ближнем радиусе (cap +30%),
  но −10% max HP.
- **Снайпер**: «Один выстрел» — +75% урона по целям с полным HP, но −15%
  скорострельности || «Свинцовый ветер» — крит поджигает рикошет на соседа,
  но −20% крит-урона.
- **Биолог**: «Пандемия» — DoT-смерть взрывается споровым облаком, но прямой
  урон −15% || «Симбиоз» — призывы наследуют 40% DoT-силы, но −1 к лимиту
  призывов.
- **Рыцарь**: «Бастион» — стоя на месте >1с, +25% защиты и провокация, но
  −15% скорости || «Марш легиона» — +15% урона за каждые 2с движения без
  урона (cap +45%), сбрасывается при попадании.

Механики реализуются ТОЛЬКО через ключи, разведённые в `player.gd`
(`META_SKILL_*_MAP`) — новые ключи добавляются вместе с реализацией узла,
реестр новых ключей ведётся в приложении B дизайн-дока.

## 4. Экономика

**Эмблемы класса** (per-class, заменяют вклад класса в общий пул):

| Источник | Эмблем |
| --- | --- |
| Первый клир возвышения A0..A5 этим классом | 2/2/3/4/5/6 = **22** |
| Классовые челленджи (3 шт, существующие `CLASS_CHALLENGES`) | 3×2 = **6** |
| **Итого на класс** | **28** |

Полное созвездие стоит 28–32 → на максимуме прогресса выкуплено **~85–90%**
СВОЕГО созвездия. Осознанный отход от «купишь треть» v3: внутри ОДНОГО героя
дефицит мягкий (приятно почти-максимизировать любимого героя — retention), а
выбор билда обеспечивают взаимоисключающие keystone и порядок покупок в
середине прогресса, не искусственная нехватка.

**Звёздная пыль** (аккаунт):

| Источник | Пыли |
| --- | --- |
| Первая победа каждым классом (17) | 17 |
| Первый A5-клир каждым классом (17) | 17 |
| Секретный босс (первый раз) | 3 |
| Вехи кодекса (монстры/боссы/артефакты, 8 вех) | 8 |
| Вехи достижений (5) | 5 |
| **Потолок** | **50** |

Атлас гильдии стоит 59 (потолок 50) → на общем слое «всё не купить» сохраняется
как принцип. Ранний крючок §4: первый QoL-узел `atlas_m0` стоит 1 пыль, поэтому
первая же победа (1 пыль) сразу открывает и даёт купить его.

**Миграция сейвов (schema 4 → 5).** `meta_point_awards` уже хранит начисления
per-class → конвертация честная: очки класса → эмблемы класса по новой
формуле (пересчёт от `ascension_levels`), выполненные челленджи → +2 эмблемы
каждый; аккаунт-вехи (победы, кодекс, секретный босс) пересчитываются из
существующих полей (`class_boss_wins`, `discovered_*`, `secret_boss_defeated`).
Все купленные узлы сбрасываются (полный респек, паттерн миграций 1→3→4).
Игрок ничего не теряет — только перераскладывает.

## 5. Discovery: скрытые звёзды и туман

- В каждом созвездии 2 скрытые звезды. До открытия: туманный узел «?» с
  читаемым условием («Победи финального босса Act 2 берсерком, ни разу не упав ниже
  30% HP»). Условия строятся на инфраструктуре `class_challenge_progress`.
- Открытие — momентальная церемония на экране: туман рассеивается, звезда
  вспыхивает, показывается лор-строка класса (1 предложение) + эффект-твист
  (не голый стат: «после смертельного удара оставляет 1 HP раз в 3 боя» и т.п.).
- Кодекс-вехи и секретный босс аналогично «зажигают» узлы Атласа — механика
  та же, переживание «я открыл» размазано по всей мете.
- Новичку Атлас показывает только ближний круг узлов (+1 кольцо тумана
  вперёд) — экран не пугает объёмом; созвездие класса видно целиком сразу
  (оно компактное и это витрина героя).

## 6. Баланс

Дерево — аддитивный слой поверх базы; балансовые гейты строят билды без меты,
поэтому мета не входит в их коридоры (унаследовано от v3 — рабочая схема).
Собственные инварианты Меты 4.0, каждый — тестом:

1. **Бюджет силы созвездия**: полный реалистичный билд класса (все атрибутные +
   все техники + 1 keystone) даёт **+18–25% комбинированной эффективной силы**
   (взвешенная сумма DPS/EHP/utility по формуле бюджет-теста v3). Коридор
   damage_mult-эквивалента: [0.10 .. 0.40] — совместим с фактическим v3.
2. **Кросс-классовый спред**: max/min бюджета силы по 17 созвездиям ≤ **1.25**
   (иначе «сильные созвездия» ломают комфорт-балансировку классов).
3. **Матрица релевантности**: атрибутные звезды класса ⊆ его
   primary/secondary из `ATTRIBUTE_RELEVANCE`; запрет чужих атрибутов —
   существующий гейт v3 сохраняется как есть.
4. **Keystone-трейдофф**: у каждого keystone есть числовой downside (правило
   дизайна, проверка на ревью; в тесте — наличие негативного эффекта в данных).
5. **Атлас без боевой силы**: узлы Атласа — только QoL/экономика/удобство,
   кроме 4 «наследных» keystone v2 (`death_save`, `guaranteed_rare_shop`,
   `first_levelup_rare`, `ult_start_charge`) — их суммарный боевой вклад уже
   учтён историческим балансом и заперт тестом аккаунт-множителя (<1.30).
6. **Экономика**: гейт очков-за-возвышения переписывается под формулу
   2/2/3/4/5/6 per-class (тест `meta_points_per_ascension_test` → новая
   редакция «sigils per ascension»); анти-фарм (повторные победы не дают
   валюту) сохраняется 1:1.
7. **Прогресс к возвышениям**: целевая кривая — к A3 куплены ~50% созвездия и
   первый keystone; полный билд компенсирует ~⅔ давления A5 (−20% HP игрока,
   +hp/+dmg врагов); остальное — скилл и in-run билд. Проверяется
   survivability-harness сценарием A5.

## 7. Интерфейс: экран «Атлас героев»

Один экран, две вкладки: **Созвездие** (по умолчанию) и **Гильдия**.

```
┌─ кожаная рама, золотой кант ─────────────────────────────────────────┐
│ [◈ Эмблемы Берсерка: 7]                [✦ Звёздная пыль: 12]  [Гильдия]│
│ ┌────┐                                                                │
│ │лента│        НОЧНОЕ НЕБО — СОЗВЕЗДИЕ КЛАССА                 ┌──────┐│
│ │класс│      (силуэт секиры из звёзд, ~22 узла,               │панель││
│ │-ов  │       линии созвездия слабо светятся;                 │узла: ││
│ │17   │       купленные — золотые звёзды,                     │иконка││
│ │порт-│       доступные — пульсируют,                         │титул ││
│ │ретов│       скрытые — туман «?»)                            │число ││
│ │скролл│                                                      │цена  ││
│ └────┘                                                        │[Вло- ││
│                                                               │жить] ││
│ [Респек — бесплатно]        [Легенда: ◉ куплено ◎ доступно ? скрыто] │
└──────────────────────────────────────────────────────────────────────┘
```

Ключевые решения UX:
- **Всё созвездие видно целиком** — без пан/зума и мини-карты (22 узла).
  Скорость входа: 3 клика от главного меню до покупки узла: открыть Атлас,
  выбрать звезду для предпросмотра, подтвердить вложение кнопкой панели.
- **Лента классов слева** (портреты из hero select): переключение героя —
  1 клик, шёлковый скролл; на медальоне — прогресс созвездия (x/22) и
  непотраченные эмблемы (бейдж) — «есть что вложить» видно сразу.
- **Имя выбранного класса над холстом** (SCRUM-971): компактный нативный
  заголовок берётся из того же `ProgressionData.character_config().title`, что
  и tooltip медальона, обновляется в том же input dispatch при выборе героя и
  остаётся видимым во вкладке Гильдии. Строка занимает собственный ряд
  центральной колонки, поэтому не накладывается на сокеты, линии, табы,
  валюты, досье или орнамент рамы; отдельная тяжёлая панель не добавляется.
- **Панель узла справа**: русский титул, описание С ЧИСЛАМИ (генератор
  описаний v3 переиспользуется), цена, кнопка «Вложить эмблему»;
  для keystone — переключатель «Активен» и напоминание про взаимоисключение;
  для скрытой — текст условия и прогресс к нему.
- **Клик по ячейке = только предпросмотр** (SCRUM-838): выбор любой звезды, включая
  доступную, недоступную из-за цены/связи, скрытую и keystone, только обновляет
  правую панель (описание, цена, требования, состояние action-кнопки). Покупка
  обычных/гильдейских узлов происходит только через «Вложить эмблему/пыль»,
  а активация/погашение купленного keystone — только через отдельную кнопку
  панели. SCRUM-970 закрепляет responsive input-контракт: видимый сокет является
  явной `STOP`-целью и выбирается на pointer-down; отложенные layout-проходы
  могут перенастраивать focus-neighbours, но не имеют права возвращать фокус и
  выбор на медальон/ядро. Action-кнопки заполняют доступную ширину досье без
  фиксированного минимума, поэтому их появление не расширяет панель и не отменяет
  активный клик на 720p/1080p.
- **Состояния узла**: куплен = горящая золотая звезда; доступен = пустой
  сокет с мягкой пульсацией; недоступен = тусклый сокет; скрыт = туман «?»;
  keystone активный = сапфировое сияние, купленный-неактивный = тлеющий.
- **Геометрия сокетов**: runtime чуть компактнее масштабирует сокеты на 720p/1080p,
  разводит плотные вертикальные лучи змейкой, затем делает collision-relax и
  финальный no-overlap placement; круги улучшений не должны наслаиваться при
  1280×720, 1920×1080, 2048×1152 и 2560×1440. Реальный pointer regression
  проходит полный путь: class selector → preview → explicit buy → Guild →
  preview → explicit buy → respec/cancel → back.
- **Церемонии**: покупка — короткая вспышка + линия к соседям загорается;
  открытие скрытой — рассеивание тумана (0.6с, скипается кликом).
- Стиль — существующий кит leather/gold/parchment + новый слой «звёздная
  карта» (тёмно-синее небо, латунные сокеты, золотые звёзды). Контент
  строго в safe-area рам (правило проекта).
- Геймпад/клавиатура: фокус ходит по граф-соседям (adj), Tab — вкладки.

**Ассет-кит экрана (мандат продукта 2026-07-02, SCRUM-832): OpenAI image
generation, каждый элемент — ПОД ЦЕЛЕВОЙ размер/аспект слота в окне
2560×1440, а не вписывание контента в готовую картинку.** Структура
`assets/sprites/ui/meta40/` (27 файлов):
- `bg_sky.png` 2560×1440 — фулскрин-небо точно под окно (без рамы);
- `frame_border.png` — полая орнаментная рама под 9-slice (родной механизм
  произвольного размера, фикс-margin углы);
- сокеты под слоты 1440p: `socket_minor` 96, `socket_notable` 128,
  `socket_keystone` 168, `socket_hidden` 112; `star_alloc` 80,
  `keystone_ring` 200; валюты `currency_emblem`/`currency_stardust` 64;
- 17 гербов `crest_<class_id>` 160 (медальон-плита, классовый символ).
Пайплайн: `tools/generate_meta40_ui_openai.py` — gpt-image-2, канва с
аспектом слота, маджента #FF00FF key-фон → border-connected flood-fill →
erode 1px → точный LANCZOS в целевой размер; в промпте целевой px
(«designed to read at N pixels») и «ISOLATED sprite».

Мокап и превью-ассеты: `docs/design/previews/meta40_*` (генерируются вместе с
этим доком). Формы созвездий 17 классов — приложение C (силуэт-референсы:
берсерк секира, снайпер прицел, биолог спираль ДНК, рыцарь щит, вор кинжал и
монета, друид коготь/ветвь, инженер шестерня, гитарист гриф, священник печать,
доктор крест-ампула, химик колба, тёмный маг серп луны, элементалист триада
стихий, робот ядро-реактор, солдат шеврон, ассасин клинок-полумесяц, рейнджер
стрела-лук).

## 8. Что происходит со старыми системами

| Система | Судьба |
| --- | --- |
| Дерево v3 (общий граф 192) | Данные заменяются созвездиями; код-ядро (граф-аллокация, class_affinity, генератор описаний, data-модуль) переиспользуется |
| `CLASS_PROGRESSION` (за победы) | Вливается в созвездие: пороги побед → часть атрибутных звёзд открываются «победами» вместо эмблем? НЕТ — оставляем как пассивный фон (не трогаем в этой волне), помечаем кандидатом на слияние в 4.1 |
| `CLASS_CHALLENGES` | Становятся источником эмблем (+2 каждый) и условиями скрытых звёзд |
| Награды возвышений (`ASCENSION_LEVELS`) | Без изменений (пассивный фон, SCRUM-516) |
| Кодекс/секретный босс | Дают звёздную пыль в Атлас |
| Экономика metapoints | Формула → 2/2/3/4/5/6 эмблем per-class; cap 100 общего пула умирает вместе с общим пулом |

## 9. Реализация — волна тикетов (порядок обязателен)

1. **T1 core (backend, claude-lane)**: валюты + per-class графы (данные
   созвездий всех 17 классов по правилам §3, keystone-пары по эталонам,
   скрытые звёзды на challenge-инфре) + миграция schema 5 + адаптация гейтов
   (§6) + новые ключи эффектов в player.gd. UI не трогает (экран v3 живёт на
   старом API до T3; API совместим).
2. **T2 art (design-lane)**: 17 гербов классов + недостающие UI-ассеты по
   списку §7. Выполнено дважды: SCRUM-826 (PixelLab, принят QA) →
   заменён SCRUM-832 (OpenAI под целевые размеры слотов — актуальный кит).
3. **T3 UI (backend/claude-lane)**: экран «Атлас героев» по §7 и мокапу
   (лента классов, созвездие, панель узла, вкладка Гильдии, церемонии),
   замена старого экрана дерева, UI-смоки.
4. **T4 QA**: сквозная приёмка по этому доку (чек-лист = §6 инварианты + §7
   UX-решения + миграция на реальном старом сейве).

Каждый тикет обязан ссылаться на этот док как единственный источник истины
дизайна; отступления — только через комментарий PM в Jira.

## Приложение A — keystone-тройки 17 классов

Заполнено в T1 (SCRUM-828), затем частично переведено в условные и семантические
боевые механики в линейке 4.1 (SCRUM-834a/835/836/837): у каждого класса РОВНО 3 взаимоисключающих keystone (cost 4, exclusive-группа
`<class>_keystones`, активен ≤1, переключение купленных бесплатно). Числовой
downside обязателен и ≥25% ценности апсайда в весах силы (`POWER_WEIGHTS`
дата-модуля); «чистый вклад» (последний столбец) — вклад keystone в
damage-mult-эквивалент бюджета §6, удержан в узкой полосе 0.035–0.060 ради
кросс-классового спреда ≤1.25.

**4.1 — условные и семантические keystone (SCRUM-834a/835).** SCRUM-834a
закрывает real-node путь `soldier_k1` «Шквал» (стойка → скорострельность) и
`thief_k0` «Из тени» (окно после уклонения → крит-шанс). SCRUM-835 переводит
PM-пары на новые боевые подсистемы: on-hit suppression, gold-scaling, elemental
resonance, ward/heal conversion, reactor heat, devices/mines, DoT death-spread,
beam duration, sound/riff, execute/invisibility, charged pierce/traps, drain/
surgery, cloud/homunculus, pets/briars и bastion taunt. Оставшиеся generic
conditional rows в таблице ниже — только переходные старые узлы, которые не
входили в 835 scope (например Berserk/Sniper/Biologist/Knight-k1).
Четыре базовых типа условий разведены в `player.gd` (гейты
`*_active`/`swarm_fraction`, консумит `progression_data.derived_parameters`):

- **HP-порог** (`hurt_damage_bonus`) — пока здоровье героя ниже половины
  (`_update_conditional_keystones`, порог 50%). «Кровавый танец», «Хор
  искупления», «Из тени», «Триаж», «Подавляющий огонь».
- **Стойка** (`stance_damage_bonus`) — пока герой неподвижен ≥0.8с
  (`STANCE_ACTIVATION_TIME`). «Один выстрел», «Бастион», «Овердрайв» и др.
- **Окно после уклонения** (`rush_damage_bonus`) — 2с после успешного уворота
  (`_trigger_rush_window`, эталон `_trigger_dodge_rush`). «Большой куш»,
  «Свинцовый ветер», «Тысяча порезов», «Марш легиона», «Полевая хирургия».
- **Счёт-в-радиусе** (`swarm_damage_bonus`) — доля врагов рядом от кэпа
  (`SWARM_CAP`=8, радиус `SWARM_RADIUS`). «Несущий бурю», «Пандемия»,
  «Крещендо» и др.

Вес каждого условного ключа в `POWER_WEIGHTS` = средняя доля времени активности
(аптайм) × вес урона, поэтому крупный заголовочный процент (напр. +34% «в
рывке») держит тот же budget-вклад, что старый статический трейд. Для 834a
та же бюджетная логика применена к не-урон стат-целям `stance_attack_speed_bonus`
и `rush_crit_bonus`; для 835 semantic-ключей вес = ожидаемый аптайм/полезность
подсистемы, а положительные штрафы (`reactor_heat_incoming_damage`,
`charge_time_mult`) имеют отрицательный вес. Экономический `shop_price_mult`
остаётся weight-0 для Атласа, а downside «Джекпота» проверяется per-hero gate.
Третий keystone (`k2`) сохраняет статический трейд T1.

| Класс | Keystone | Апсайд | Downside | Целевая механика 4.1 | Чистый вклад |
| --- | --- | --- | --- | --- | --- |
| **Берсерк** | «Кровавый танец» (`berserk_k0`) | +32% к урону, пока здоровье ниже половины | −30% к получаемому лечению | HP-порог | 0.051 |
|  | «Несущий бурю» (`berserk_k1`) | +18% к урону в гуще боя (на пике — врагов рядом) | −4% к макс. здоровью | счёт-в-радиусе | 0.050 |
|  | «Последний рубеж» (`berserk_k2`) | +29% к урону при низком здоровье, +0.4 к регенерации при низком здоровье | −2.2% к защите | — | 0.049 |
| **Солдат** | «Подавление» (`soldier_k0`) | поражённые за последние 2с враги наносят −15% урона | −10% к скорости движения | on-hit suppression | 0.040 |
|  | «Шквал» (`soldier_k1`) | +19.1% к скорострельности в неподвижной боевой стойке (реализовано 834a) | −4% к урону | стойка | 0.046 |
|  | «Гранатный подсумок» (`soldier_k2`) | +7% к радиусу области, +9% шанс взрыва при убийстве | −6% к дальности атаки | — | 0.039 |
| **Вор** | «Из тени» (`thief_k0`) | +17.2% к шансу крита в рывке (окно после уклонения) (реализовано 834a) | −4% к макс. здоровью | окно после уклонения | 0.046 |
|  | «Джекпот» (`thief_k1`) | +1% к урону за каждые 50 золота, cap +25% | +20% к ценам лавки | gold-scaling | 0.050 |
|  | «Азарт канатоходца» (`thief_k2`) | +17% к урону крита, +9% к скорости движения после уклонения (рывок) | −2.2% к защите | — | 0.047 |
| **Элементалист** | «Резонанс» (`elementalist_k0`) | +35% к урону другой стихией по отмеченной цели | −12% к прямому урону | elemental mark/resonance | 0.045 |
|  | «Монолит» (`elementalist_k1`) | +2 стихийные орбы | −20% к радиусу prism/rift зон | elemental orbit + rift radius | 0.050 |
|  | «Огонь по площади» (`elementalist_k2`) | +11% шанс взрыва при убийстве, +1 периодического урона | −6% к скорости движения | — | 0.044 |
| **Снайпер** | «Один выстрел» (`sniper_k0`) | +20% к урону в неподвижной боевой стойке | −4% к скорости атаки | стойка | 0.050 |
|  | «Свинцовый ветер» (`sniper_k1`) | +34.5% к урону в рывке (окно после уклонения) | −12% к урону крита | окно после уклонения | 0.041 |
|  | «Гнездо ястреба» (`sniper_k2`) | +6% к дальности атаки, +2% к шансу крита | −6% к скорости движения | — | 0.040 |
| **Священник** | «Мученик» (`priest_k0`) | 50% исходящего лечения превращается в святую цепь урона | −30% к получаемому лечению | heal→holy chain | 0.045 |
|  | «Заступник» (`priest_k1`) | +40% к поглощению ward-волн | −17% к скорости заряда ультимейта | ward absorb | 0.043 |
|  | «Глас гнева» (`priest_k2`) | +5% к урону, +2.9% к силе поддержки | −2.2% к защите | — | 0.042 |
| **Биолог** | «Пандемия» (`biologist_k0`) | +17.7% к урону в гуще боя (на пике — врагов рядом) | −4% к урону | счёт-в-радиусе | 0.048 |
|  | «Симбионт» (`biologist_k1`) | +20.4% к урону в неподвижной боевой стойке | −0.07 к скорости тиков | стойка | 0.050 |
|  | «Регенеративный цикл» (`biologist_k2`) | +0.15 к регенерации, +4% к макс. здоровью | −6% к скорости движения | — | 0.044 |
| **Робот** | «Перегрев» (`robot_k0`) | при жаре реактора >70% +30% к урону | +15% входящего урона при перегреве | reactor heat | 0.044 |
|  | «Сверхпроводник» (`robot_k1`) | +50% к радиусу магнитного якоря | −12% к макс. здоровью | magnet radius | 0.045 |
|  | «Протокол мести» (`robot_k2`) | +11% шанс ответной волны при получении удара, +18% полученного урона отражается шипами | −4% к скорости атаки | — | 0.051 |
| **Инженер** | «Автоматизация» (`engineer_k0`) | устройства стреляют на 25% быстрее | −15% к личному урону вне устройств | devices | 0.060 |
|  | «Минёр» (`engineer_k1`) | +2 мины, мгновенный взвод | −30% к радиусу ремонтной сети | mines + repair radius | 0.045 |
|  | «Перегретые стволы» (`engineer_k2`) | +33 к скорости снарядов, +5% к скорости атаки | −2.2% к защите | — | 0.042 |
| **Тёмный маг** | «Пожинатель» (`dark_mage_k0`) | смерть cursed/DoT цели распространяет/продлевает DoT вокруг на +2с | −15% к прямому урону | DoT death-spread | 0.043 |
|  | «Ненасытный луч» (`dark_mage_k1`) | +30% к длительности лучей | −20% к радиусу взрывов луча | beam duration | 0.040 |
|  | «Договор пустоты» (`dark_mage_k2`) | +0.9 к силе призыва, +14% к урону при низком здоровье | −30% к получаемому лечению | — | 0.044 |
| **Гитарист** | «Хедлайнер» (`guitarist_k0`) | +30% к ширине звуковых аур | −50% к отталкиванию | sound aura width | 0.040 |
|  | «Рифф» (`guitarist_k1`) | непрерывная серия без паузы >1с даёт +25% к урону | −10% к базовой скорости атаки | riff streak | 0.045 |
|  | «Фронтмен» (`guitarist_k2`) | +7% к силе ультимейта, +7% к скорости заряда ультимейта | −4% к макс. здоровью | — | 0.048 |
| **Ассасин** | «Экзекутор» (`assassin_k0`) | крит добивает не-элитную цель ниже 35% HP | −10% к шансу крита | crit execute | 0.045 |
|  | «Теневой шаг» (`assassin_k1`) | 2с невидимости после shadow_burst | −15% к макс. здоровью | shadow invisibility | 0.040 |
|  | «Призрачный шаг» (`assassin_k2`) | +1.8% к уклонению, +12% к скорости движения после уклонения (рывок) | −4% к урону | — | 0.050 |
| **Рейнджер** | «Штурмовая стойка» (`ranger_k0`) | заряженный выстрел получает +2 пробития | +20% к времени зарядки | charged pierce | 0.046 |
|  | «Капканщик» (`ranger_k1`) | +2 капкана, мгновенный взвод | −12% к урону вне капканов | traps | 0.048 |
|  | «Хозяин тропы» (`ranger_k2`) | +6% к скорости движения, +2.2% к шансу крита | −4% к макс. здоровью | — | 0.052 |
| **Доктор** | «Вампирический контур» (`doctor_k0`) | drain-link цепляет +1 цель | −40% к лечению меднабора | drain link | 0.045 |
|  | «Хирург» (`doctor_k1`) | +60% к хирургическому удару в упор | −20% к дальнему урону | close surgery | 0.038 |
|  | «Доза адреналина» (`doctor_k2`) | +5% к скорости атаки, +2.9% к силе поддержки | −30% к получаемому лечению | — | 0.041 |
| **Химик** | «Катализатор» (`chemist_k0`) | +40% к площади детонации облаков | −30% к длительности луж/облаков | cloud detonation | 0.040 |
|  | «Гомункул-прайм» (`chemist_k1`) | гомункул получает +50% к HP и урону | −10% к макс. здоровью | homunculus | 0.050 |
|  | «Пары эфира» (`chemist_k2`) | +6% к скорости движения, +1.5% к уклонению | −4% к макс. здоровью | — | 0.053 |
| **Рыцарь** | «Бастион» (`knight_k0`) | после 1с стойки +25% защиты и провокация врагов | −15% к скорости движения | bastion taunt | 0.045 |
|  | «Марш легиона» (`knight_k1`) | +32.8% к урону в рывке (окно после уклонения) | −2.2% к защите | окно после уклонения | 0.038 |
|  | «Шипастый панцирь» (`knight_k2`) | +27% полученного урона отражается шипами, +7% шанс ответной волны при получении удара | −4% к скорости атаки | — | 0.049 |
| **Друид** | «Вожак стаи» (`druid_k0`) | питомцы наносят +25% урона | −15% к личному урону без питомцев и терний | pets | 0.035 |
|  | «Терновый круг» (`druid_k1`) | +35% к ширине терновых зон | −10% к скорости движения | briar zones | 0.046 |
|  | «Гнев леса» (`druid_k2`) | +1.4 периодического урона, +18% полученного урона отражается шипами | −0.13 к регенерации | — | 0.043 |

Примечание к эталонам §3 (реализация 4.1): строки таблицы фиксируют текущий
runtime data state. SCRUM-835 закрыл semantic combat-пары на новых подсистемах;
оставшиеся generic conditional строки — отдельный будущий scope, а не статус
835.

## Приложение B — реестр новых ключей эффектов

Заполнено в T1 (SCRUM-828), дополнено условными ключами 4.1 (SCRUM-834a и
продолжения). Все
ключи — через `apply_meta_skill_modifiers` в `player.gd`; потребители — либо
существующие артефакт-триггеры (SCRUM-500), либо `derived_parameters` (условные
бонусы урона 4.1 и 834a не-урон стат-цели, гейты ставит player):

| Ключ | Узлы | Разводка в player.gd | Тест |
| --- | --- | --- | --- |
| `healing_mult` | `berserk_k0`, `dark_mage_k2`, `doctor_k2`, `atlas_m13`, `atlas_n3` | `META_SKILL_MULT_MAP` → `run_modifiers.healing_multiplier` (потребление: `_apply_regeneration`, heal-потоки) | wired-гейт smoke + downside-гейт per-hero |
| `kill_explosion_chance` | `soldier_k2`, `elementalist_t3/k2/h0`, `biologist_h0`, `engineer_t3`, `dark_mage_h0`, `chemist_t3/h0` | `META_SKILL_FLAT_MAP` → триггер «взрыв при убийстве» | wired-гейт smoke |
| `take_hit_pulse_chance` | `berserk_t2/h0`, `soldier_h0`, `robot_k2`, `engineer_h0`, `guitarist_h1`, `knight_k2/h0` | `META_SKILL_FLAT_MAP` → `_trigger_take_hit_pulse` | wired-гейт smoke |
| `thorn_reflect_multiplier` | `biologist_t3/h1`, `robot_k2`, `knight_t2/k2`, `druid_t2/k2/h0` | `META_SKILL_FLAT_MAP` → `_trigger_thorn_reflect` | wired-гейт smoke |
| `crit_speed_burst` | `thief_h1`, `sniper_h0`, `guitarist_h0`, `assassin_h0`, `ranger_h0` | `META_SKILL_FLAT_MAP` → `_trigger_crit_speed_burst` | wired-гейт smoke |
| `dodge_rush_bonus` | `thief_t3/k2/h0`, `assassin_t3/k2/h1`, `ranger_h1` | `META_SKILL_FLAT_MAP` → `_trigger_dodge_rush` | wired-гейт smoke |
| `lowhp_guard` | скрытые звезды: `berserk_h1`, `elementalist_h1`, `priest_h0`, `robot_h1`, `doctor_h0`, `knight_h1` | флаг (max-merge) → `_trigger_lowhp_guard` («Рубеж Стража») | per-hero hidden-гейт + wired-гейт |
| `hurt_damage_bonus` | k0 (HP-порог): `berserk_k0` | `META_SKILL_FLAT_MAP`; гейт `hurt_active` (HP<50%) → `derived_parameters.damage_multiplier` | conditional-гейт smoke (`_test_conditional_keystones`) |
| `stance_damage_bonus` | k0/k1 (стойка): `sniper_k0`, `biologist_k1` | `META_SKILL_FLAT_MAP`; гейт `stance_active` (неподвижность ≥0.8с) → `damage_multiplier` | conditional-гейт smoke |
| `rush_damage_bonus` | k1 (окно после уклонения): `sniper_k1`, `knight_k1` | `META_SKILL_FLAT_MAP`; гейт `rush_window_active` (2с после уворота, `_trigger_rush_window`) → `damage_multiplier` | conditional-гейт smoke |
| `swarm_damage_bonus` | k0/k1 (счёт-в-радиусе): `berserk_k1`, `biologist_k0` | `META_SKILL_FLAT_MAP`; гейт `swarm_fraction` (0..1 от `SWARM_CAP`) → `damage_multiplier` | conditional-гейт smoke |
| `stance_attack_speed_bonus` | k1 (стойка → не-урон): `soldier_k1` («Шквал», 834a) | `META_SKILL_FLAT_MAP`; гейт `stance_active` → `attack_speed_multiplier` | real-node conditional smoke (`soldier_k1` → active keystone → player/progression) |
| `rush_crit_bonus` | k0 (окно после уклонения → не-урон): `thief_k0` («Из тени», 834a) | `META_SKILL_FLAT_MAP`; гейт `rush_window_active` → `crit_chance` | real-node conditional smoke (`thief_k0` → active keystone → player/progression) |
| `enemy_hit_damage_down` | `soldier_k0` «Подавление» | `META_SKILL_FLAT_MAP`; `on_weapon_hit` → `_apply_meta_keystone_hit_effects` → `StatusEffects.damage_multiplier(enemy)` на 2с | SCRUM-835 semantic smoke + `global_survivability_balance_smoke` |
| `gold_damage_per_50`, `gold_damage_bonus_cap` | `thief_k1` «Джекпот» | `meta_damage_multiplier`: floor(current gold/50) × step, capped; `shop_price_mult` downside consumed in `ui_screens.gd` | SCRUM-835 semantic smoke (floor/cap) + shop smoke |
| `elemental_resonance_bonus` | `elementalist_k0` «Резонанс» | elemental mark metadata on enemy; different next element gets resonance multiplier | SCRUM-835 semantic smoke |
| `elemental_orb_extra_count`, `prism_rift_radius_mult` | `elementalist_k1` «Монолит» | `meta_extra_projectiles` for `elemental_orbit`; `meta_radius_multiplier` for `prism_rift` | SCRUM-835 semantic smoke |
| `heal_to_holy_damage_ratio` | `priest_k0` «Мученик» | heal flows call `_apply_heal_to_holy_damage`, nearest enemies receive holy/magic chain damage | SCRUM-835 semantic smoke + runtime smoke |
| `ward_absorb_bonus` | `priest_k1` «Заступник» | `meta_apply_priest_ward` temporarily increases `absorb_flat` during ward wave | SCRUM-835 semantic smoke + survivability smoke |
| `reactor_heat_damage_bonus`, `reactor_heat_incoming_damage` | `robot_k0` «Перегрев» | robot hits build `_reactor_heat`; >70% toggles damage bonus and incoming-damage penalty | SCRUM-835 semantic smoke + survivability smoke |
| `magnet_radius_mult` | `robot_k1` «Сверхпроводник» | `meta_radius_multiplier` for `robot_magnetic_anchor` | SCRUM-835 semantic smoke |
| `device_attack_speed_bonus`, `non_device_damage_mult` | `engineer_k0` «Автоматизация» | `meta_interval_multiplier` speeds devices; `meta_damage_multiplier` penalizes non-device damage | SCRUM-835 semantic smoke + global damage smoke |
| `mine_extra_count`, `repair_radius_mult` | `engineer_k1` «Минёр» | `meta_extra_projectiles`/`meta_trap_instant_arm` for pressure mines; repair-drone radius multiplier | SCRUM-835 semantic smoke |
| `dot_death_spread_duration`, `direct_damage_mult` | `dark_mage_k0` «Пожинатель» | `on_enemy_killed` snapshots DoT statuses and spreads/extends them around the corpse; direct-damage penalty in `meta_damage_multiplier` | SCRUM-835 semantic smoke + runtime smoke |
| `beam_duration_mult`, `explosion_radius_mult` | `dark_mage_k1` «Ненасытный луч» | `meta_duration_multiplier` for beams; beam/explosion radius multiplier | SCRUM-835 semantic smoke |
| `guitar_aura_radius_mult` | `guitarist_k0` «Хедлайнер» | `meta_radius_multiplier` for sound/aura modes; `knockback_mult` remains derived weapon scaling downside | SCRUM-835 semantic smoke |
| `riff_streak_damage_bonus` | `guitarist_k1` «Рифф» | sound hits build `_riff_streak_time`; >1с toggles damage multiplier, with `attack_speed_mult` downside | SCRUM-835 semantic smoke |
| `crit_execute_threshold` | `assassin_k0` «Экзекутор» | critical hit executes non-elite targets below threshold; elite/boss groups are excluded | SCRUM-835 semantic smoke |
| `shadow_burst_invisibility_time` | `assassin_k1` «Теневой шаг» | `trigger_assassin_crit_shadow` grants timed invisible state after shadow burst and ignores incoming damage during the window | SCRUM-835 semantic smoke + runtime smoke |
| `charged_shot_extra_pierce`, `charge_time_mult` | `ranger_k0` «Штурмовая стойка» | `meta_extra_pierce` for charged shots; charge-time multiplier downside | SCRUM-835 semantic smoke |
| `trap_extra_count`, `non_trap_damage_mult` | `ranger_k1` «Капканщик» | `meta_extra_projectiles`/`meta_trap_instant_arm` for traps; non-trap damage penalty | SCRUM-835 semantic smoke |
| `drain_extra_targets`, `medkit_healing_mult` | `doctor_k0` «Вампирический контур» | `meta_extra_projectiles` extends drain-link target count; medkit/healing downside stored as run modifier | SCRUM-835 semantic smoke + survivability smoke |
| `surgical_close_damage_bonus`, `ranged_damage_mult` | `doctor_k1` «Хирург» | close `stab_flurry` hits receive surgical bonus; non-stab/ranged attacks get damage penalty | SCRUM-835 semantic smoke + global damage smoke |
| `cloud_detonation_radius_mult`, `pool_duration_mult` | `chemist_k0` «Катализатор» | cloud radius multiplier and pool/cloud duration downside | SCRUM-835 semantic smoke |
| `homunculus_power_mult` | `chemist_k1` «Гомункул-прайм» | `summoner_weapon.gd` boosts real homunculus summon HP/damage profiles from owner run modifiers | SCRUM-835 semantic smoke + runtime smoke |
| `pet_damage_mult`, `pet_personal_damage_mult` | `druid_k0` «Вожак стаи» | real summon/pet profiles get damage bonus; non-pet/non-briar personal damage is penalized | SCRUM-835 semantic smoke + global damage smoke |
| `briar_radius_mult` | `druid_k1` «Терновый круг» | `meta_radius_multiplier` for briar pool/zones; move-speed downside via derived parameters | SCRUM-835 semantic smoke |
| `bastion_defense_bonus`, `bastion_taunt` | `knight_k0` «Бастион» | stance active adds defense in `take_damage`; `_apply_bastion_taunt` applies taunt metadata and `Enemy._combat_target()` redirects movement/shooting/contact/elite targeting to the valid taunt owner until expiry, then falls back to `_player()` | SCRUM-835 semantic smoke + survivability smoke |

Метрика скрытых звёзд `class_wins` добавлена к
`weapon_diversity`/`best_ascension`/`no_shop_wins` и читается из
`class_boss_wins` (`meta_progression.hidden_star_unlocked/hidden_star_progress`,
`condition_text`); строгий аудит 17/17 уникальных hidden-star условий и лора
вынесен в SCRUM-836.

Гейт: `tests/meta_skill_tree_smoke_test.gd::_test_effect_keys_are_wired` — любой
ключ эффекта графа, не разведённый в `player.gd` (`META_SKILL_*_MAP`, флаги) или
в main/ui (экономика: `shop_price_mult`, `attr_cost_mult`, `start_gold_flat`,
`attr_extra_options`, `guaranteed_rare_shop`, `first_levelup_rare`), роняет тест.
Наследные v3-ключи (атрибутные `*_flat`/`*_mult`, `elite_boss_damage_mult`,
`low_hp_damage_bonus`, `lowhp_regen_bonus` и т.д.) остаются разведёнными как были.

**Детерминированный гейт скидки лавки (SCRUM-1027).**
`tests/meta_skill_tree_smoke_test.gd::_test_shop_discount` сравнивает base и
`atlas_m4 + atlas_m5` только как парные корзины. Для каждой пары тест одинаково
инициализирует `Main.rng`, управляющий выборкой, и глобальный RNG, через который
`ProgressionData.shop_items()` материализует tier семейства артефактов. Затем он
доказывает равенство `id`/`kind`/`tier` каждого слота и проверяет точную цену
`max(1, round(base_cost * 0.96))`. Гарантированный tier-3 от `atlas_k0`
проверяется отдельно в `_test_guaranteed_rare_shop_capstone`; смешивать эти две
механики в одном oracle нельзя.

**Behavioral gate 4.1d (SCRUM-837).** Для semantic keystone-ключей после
SCRUM-835 одного wired-гейта недостаточно: `tests/meta_keystone_behavioral_smoke_test.gd`
проверяет реальные исходы в headless mini-arena (`Player`/`Enemy`/`ClassWeapon`/
`SummonerWeapon`) и падает, если k0/k1 снова сведены к generic
`hurt/stance/rush/swarm`-подписям без класс-специфичных combat effects. QA
прогоняет его через `python3 tools/godot_gate.py` вместе с `meta_skill_tree`,
`skill_tree_per_hero` и `runtime_smoke`.

**Live behavioral fixture contract (SCRUM-1029).**
`tests/meta_keystone_behavioral_smoke_test.gd` по-прежнему проверяет реальные
`Player`/`Enemy`/`ClassWeapon` outcomes, но ручные Reactor и pierce mini-arena
отключают автоматические `_process`/`_physics_process` callbacks до первого
ожидаемого кадра. Reactor oracle обязан начинать с heat `0`, получить холодный
удар, зарядиться реальными weapon hits выше `0.70`, активироваться только через
runtime update и после этого показать больший исходящий и входящий урон.
Временные swarm-счётчики удаляются и flush-ятся сразу после своего сценария,
чтобы не расходовать hit limit последующих beam/pierce проверок. Ручные вызовы
production API, target query и live health outcomes сохраняются; проверки
словарей вместо боя, ослабление порогов и production balance overrides не
допускаются.

**Изоляция semantic mini-arena (SCRUM-1028).** Ручные сценарии
`_test_semantic_keystone_runtime_835` проверяют production API прямыми вызовами,
поэтому до первого ожидаемого кадра отключают `_process`/`_physics_process`
callbacks тестового игрока, его дочернего оружия и ручных целей. Узлы остаются в
scene/physics space, так что явные production-вызовы и `move_and_slide` oracle
сохраняют реальную семантику. Это не заменяет отдельный live behavioral gate,
зато не позволяет автоматической атаке потратить Assassin cooldown или
уничтожить fixture во время `await process_frame`. Shadow oracle сначала доказывает
немедленное двухсекундное invisible-window, затем гарантированно проверяет
отказ `take_damage`. В парном Bastion oracle случайный dodge обеих сторон
обнуляется только в fixture после stance-recalculation, нулевой итоговый шанс и
активная стойка доказываются явно, затем сравнивается чистое снижение входящего
урона. Production dodge, оружие и combat runtime при этом не изменяются.

## Приложение C — силуэты созвездий

Список силуэтов — §7. Нормированные координаты узлов (npos 0..1) зафиксированы
в T1: `CONSTELLATION_LAYOUT` в `scripts/meta_progression_tree_data.gd` — по 22
точки на класс в порядке [ядро, 4 луча × (звезда,звезда,звезда,техника),
3 keystone, 2 скрытые]. Единая топология «ядро + 4 луча» изгибается кривыми
лучей под форму символа класса (секира берсерка = рукоять вниз + два лезвия +
шип; прицел снайпера = 4 кардинальных луча; ДНК биолога = две скрещенные нити;
щит рыцаря = кромки и остриё; и т.д.). Runtime сохраняет эти `npos` как якоря,
но для плотных колонок добавляет небольшой horizontal stagger, collision-relax
и финальный поиск ближайшей свободной точки, чтобы круги сокетов не
наслаивались на 720p/1080p/1440p. Арт-референсы силуэтов и кит экрана — T2
(SCRUM-832).
