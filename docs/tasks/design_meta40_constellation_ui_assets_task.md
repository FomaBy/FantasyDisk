# ART Мета 4.0: UI-кит экрана «Атлас героев» + 17 гербов классов

Статус: done
Приоритет: high
Роль: Design (Claude)
Версия: 0.1.8
Создано: 2026-07-02
Jira: SCRUM-826
Контур: Claude
Owner: claude-designer
Thread/Worker: n/a
Locked paths: `assets/sprites/ui/meta40/`, `docs/design/previews/meta40_*`

## Источник истины

`docs/design/systems/meta_constellations.md` §7 (UI) и приложение C (силуэты).
Референсы стиля (уже сгенерены PM, лежат в `docs/design/previews/`):
`meta40_atlas_bg.png` (рама-небо), `meta40_socket_minor/notable/keystone.png`
(сокеты), `meta40_star_gold.png` (звезда аллокации), `meta40_crest_berserk.png`
(эталон герба), `meta40_atlas_mockup.png` (полный мокап экрана). Задача
полностью автономна.

## Scope (продакшн-ассеты в `assets/sprites/ui/meta40/`)

1. **Фон экрана**: звёздное небо в кожаной раме с золотым кантом — финальная
   версия в разрешении под экран (базовое окно проекта), full-bleed;
   PixelLab (create_ui_asset, омит elements, «no text») по референсу
   `meta40_atlas_bg.png`. Прозрачность краёв вычистить (border-connected
   flood-fill по протоколу, размер не менять).
2. **Сокеты узлов**: minor / notable / keystone / скрытый («туманный») —
   4 состояния читаемы тонировкой в рантайме (куплен/доступен/недоступен) —
   рисуем ОДИН нейтральный вариант каждого + отдельную золотую звезду
   аллокации и сапфировое «активное» кольцо keystone.
3. **17 гербов классов** (ядра созвездий, ~46–96px, круглый медальон-плита как
   у эталона берсерка): секира берсерка (эталон готов — перерисовать в
   продакшн-размер), прицел снайпера, спираль ДНК биолога, щит рыцаря, кинжал
   и монета вора, коготь/ветвь друида, шестерня инженера, гриф гитариста,
   печать священника, крест-ампула доктора, колба химика, серп луны тёмного
   мага, триада стихий элементалиста, ядро-реактор робота, шеврон солдата,
   клинок-полумесяц ассасина, стрела-лук рейнджера (список §7/прил. C).
   PixelLab create_map_object, единая палитра (бронза/золото + классовый
   акцент), «no text».
4. **Валютные иконки**: эмблема класса (ромб-сигил) и звёздная пыль
   (4-конечная звёздочка), 24–32px.
5. Контакт-лист всех ассетов в `docs/design/previews/meta40_asset_contact.png`.

## Acceptance

1. Все ассеты в `assets/sprites/ui/meta40/` с прозрачным фоном (проверка
   alpha-cleanup), с .import сайдкарами в коммите (пары png↔png.import в
   git-tree — гейт QA).
2. Гербы различимы на 46px, стилистически едины (палитра/обводка), безымянны
   («no text»).
3. Контакт-лист приложен; CHANGELOG + Jira evidence (id PixelLab-источников);
   сдача `Статус: done`, Jira → «Контроль качества».

## Процесс

PixelLab MCP (квоту проверить get_balance до батча); OpenAI images НЕ
использовать (billing hard limit). Git: pull перед стартом, явный add, push
сразу; полная автономия.

## Выполнено (claude-designer, 2026-07-02)

**26 продакшн-ассетов** в `assets/sprites/ui/meta40/` (все с прозрачным фоном +
.import-пары в git-tree):

- **17 гербов** `crest_<class>.png` (96×96, канон class_id): berserk, sniper,
  biologist, knight, thief, druid, engineer, guitarist, priest, doctor, chemist,
  dark_mage, elementalist, robot, soldier, assassin, ranger. Единый шаблон —
  круглый бронзово-золотой медальон, тёмно-синий центр, классовый символ,
  «no text», high detail. Читаемость на 46px проверена (LANCZOS-даунскейл).
- **Фон-рама** `atlas_bg.png` (688×384) — звёздное небо в кожаной раме с золотым
  кантом; edge-халоу вычищен border-connected flood-fill (0 полупрозрачных px,
  размер не менялся).
- **Сокеты** `socket_minor/notable/keystone/hidden.png` (нейтральные варианты,
  тонировка состояний — в рантайме T3).
- **Звезда аллокации** `star_alloc.png`; **активное кольцо keystone**
  `keystone_ring.png` (сапфировое сияние).
- **Валюты** `currency_emblem.png` (ромб-сигил) и `currency_stardust.png`
  (4-конечная звёздочка, 48px).
- **Контакт-лист**: `docs/design/previews/meta40_asset_contact.png`.

**Решения (автономия):** фон/сокеты/звезда взяты из утверждённых PM-превью
`meta40_*` (это и есть канон-стиль кита) и промоутнуты в продакшн с alpha-cleanup
+ свежими .import; регенерация 688px рамы дала бы худший/несогласованный результат.
Новая арт-работа (17 гербов, hidden-сокет, keystone-кольцо, валюты) —
свежая генерация PixelLab под единый шаблон. engineer/robot/ranger
перегенерены v2 (первые версии теряли символ/рамку).

**Evidence (PixelLab create_map_object id):** berserk `5a72b6a0`, sniper
`a5cfe5a5`, biologist `314a7b34`, knight `e2230fff`, thief `98196109`, druid
`4842554c`, engineer(v2) `45256985`, guitarist `8991392f`, priest `a549a610`,
doctor `5a6912e1`, chemist `7b06e812`, dark_mage `a7c5fd9d`, elementalist
`9e14a3b6`, robot(v2) `2f003aa7`, soldier `9dcc8db2`, assassin `c4235530`,
ranger(v2) `43de0124`; socket_hidden `c1257da2`, keystone_ring `e84c15e2`,
currency_emblem `20e8d0df`.

**Гейт:** `godot_gate.py --import` (26/26 png↔import пар, uid-уникальность OK) +
`tests/runtime_smoke_test.gd` → PASS (16311 файлов, duplicate-artifact guard OK).
