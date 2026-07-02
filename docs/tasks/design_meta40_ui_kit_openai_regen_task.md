# ART Мета 4.0: перегенерация UI-кита через OpenAI под целевые размеры слотов

Статус: done
Приоритет: high
Роль: Design (PM/Claude chat)
Версия: 0.2.0
Создано: 2026-07-02
Jira: SCRUM-832
Контур: Claude
Owner: PM-чат (Fable 5)
Thread/Worker: pm-chat-meta40-openai-regen
Locked paths: `assets/sprites/ui/meta40/`, `tools/generate_meta40_ui_openai.py`, `docs/design/previews/meta40_asset_contact.png`

## Мандат продукта (2026-07-02, дословно по смыслу)

Переделать ВСЕ элементы интерфейса (UI-кит Меты 4.0) через OpenAI image
generation. Ключевое правило: элементы ГЕНЕРИРУЮТСЯ ПОД НУЖНЫЙ РАЗМЕР/аспект
слота на экране (окно проекта 2560×1440), а не «сгенерили как вышло и
впихиваем данные в готовую картинку».

供 замены: PixelLab-кит SCRUM-826 (принят QA e3a15412 до этого мандата).

## Что меняется структурно

- Было: `atlas_bg.png` 688×384 — рама с запечённым небом (контент вписывался
  в фикс-зону). Стало: `bg_sky.png` 2560×1440 (фулскрин-небо, точный размер
  окна) + `frame_border.png` (полая орнаментная рама под 9-slice — родной
  механизм произвольного размера) — модульно, каждый слой под свой слот.
- Сокеты/звезда/кольцо/валюты/17 гербов — целевые размеры слотов из §7
  дизайн-дока для 1440p: minor 96, notable 128, keystone 168, hidden 112,
  star 80, ring 200, валюты 64, гербы 160.
- Пайплайн: gpt-image-2, канва с аспектом слота (1024²/1536×1024), маджента
  #FF00FF key-фон (transparent у модели не поддержан) → border-connected
  flood-fill → erode 1px (анти-ореол) → точный LANCZOS в целевой размер.
  Скрипт: `tools/generate_meta40_ui_openai.py` (воспроизводимо, --only/--dry-run).

## Acceptance

1. 27 ассетов в `assets/sprites/ui/meta40/` (структура выше) с прозрачным
   фоном (кроме bg_sky), пары png↔png.import в git-tree.
2. Контакт-лист `docs/design/previews/meta40_asset_contact.png`; мокап
   пересобран на новых ассетах (`meta40_atlas_mockup.png`).
3. Дизайн-док §7 обновлён (структура кита + пайплайн OpenAI).
4. CHANGELOG + Jira evidence; сдача `Статус: done`, Jira → «Контроль качества».

## Result / Evidence (PM-чат, 2026-07-02)

Кит полностью перегенерирован OpenAI gpt-image-2 под целевые размеры слотов
окна 2560×1440 (мандат продукта). 27 ассетов в `assets/sprites/ui/meta40/`:

- `bg_sky.png` 2560×1440 (фулскрин, quality high); `frame_border.png`
  1536×1024 полая рама под 9-slice (hollow-center очистка);
- сокеты 96/128/168/112, `star_alloc` 80, `keystone_ring` 200 (полый центр),
  валюты 64/64; 17 гербов `crest_*` 160 — единый медальон-шаблон.
- Пайплайн: маджента #FF00FF key-фон (transparent у gpt-image-2 не поддержан)
  → глобальная key-очистка (закрытые полости колец/межлучевые зоны) → erode
  1px анти-ореол → точный LANCZOS в слот. Скрипт:
  `tools/generate_meta40_ui_openai.py` (--only/--dry-run/--sheet-only).
- Перегенерации по ревью: keystone_ring (маджента в полости), currency_stardust
  (цвет→ледяной серебристо-синий), crest_doctor (стиль выбивался); финальная
  сигнатурная зачистка мадженты keystone_ring (172px, остаток 0).
- Контакт-лист: `docs/design/previews/meta40_asset_contact.png`; мокап экрана
  пересобран на новых ассетах в нативном 1440p:
  `docs/design/previews/meta40_atlas_mockup.png` (контент в safe-area рамы).
- Старый PixelLab-кит SCRUM-826 заменён; `atlas_bg.png` (688×384, запечённая
  рама+небо) удалён в пользу модульных bg_sky + frame_border.

Статус меняю на done — тикет уходит в «Контроль качества».

## QA-Вердикт
Статус: PASSED
Проверил: claude-qa | Дата: 2026-07-02

- Мерж подтверждён: 033c9226 (27 ассетов + tools/generate_meta40_ui_openai.py) и follow-up 0cf1b513 (CHANGELOG + sync-map пин + санитария crest_doctor) — оба ancestor origin/dev, не strand.
- Состав: 27 png ↔ 27 .import пар в git-tree (1:1), uid-дублей 0; atlas_bg удалён чисто с сайдкаром, битых ссылок в коде/сценах нет.
- Размеры — все 27 точно по спеке/§7: bg_sky 2560×1440 (фулскрин), frame_border 1536×1024 (полая, центр alpha=0, 9-slice), сокеты 96/128/168/112, star_alloc 80, keystone_ring 200 (полое), валюты 64, 17 гербов crest_* 160.
- Прозрачность: RGBA везде, bg_sky opaque по спеке; 0 px маджента-остатков на всех 27 (строгий скан, включая дочищенный crest_doctor); полости frame_border/keystone_ring реально прозрачны.
- Перегенерация native-size: sha всех 25 переживших имён отличаются от 826-версий (+2 новых), апскейлов нет (канва аспекта слота → LANCZOS в целевой размер).
- Визуал: единый D&D dark fantasy кит (бронза/золото/сапфир), рама полая с чистой safe-area, гербы канон-символов «no text», мокап 2560×1440 — контент в safe-area; контакт-лист полный (27).
- Acceptance 1–4 закрыты: пары в git-tree, контакт-лист+мокап, дизайн-док §7 (пайплайн OpenAI + supersede 826), CHANGELOG (Unreleased/Changed, 0cf1b513) + Jira evidence + sync-map пин КК.
- Гейты: чистый worktree от origin/dev, cold --import exit 0 (0 ERROR/WARNING) + runtime_smoke_ui_test.gd PASS ×2 (fdengine, slots=1).
