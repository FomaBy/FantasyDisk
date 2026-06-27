# SCRUM-514: Codex skill — генератор артефактов, иконок характеристик/атрибутов и оружия

Jira: SCRUM-514 · Роль: Design main / Codex · Контур: design-main · Приоритет: P1 · foma · Эпик: SCRUM-216
Статус: К выполнению (Задача) — QA: failed (2 бага, см. SCRUM-543)

## Что и зачем

Нужен отдельный, узкоспециализированный Codex-skill для **стабильной** генерации FantasyDisk-картинок трёх категорий: **артефакты**, **иконки характеристик/атрибутов** и **оружие**. Общий `$fantasydisk-asset-generator` слишком широкий: он не фиксирует жёстких правил под эти конкретные категории (точные пути, naming, размеры, alpha-readiness, читаемость силуэта на малых размерах), из-за чего разные агенты генерят несогласованные паки и каждый раз переспрашивают детали у пользователя.

Цель с точки зрения продукта: любой агент-исполнитель (Codex/Claude) может позже сгенерировать целый пак иконок артефактов/атрибутов/оружия **без уточнений у пользователя** — взять skill, заполнить required inputs, прогнать workflow и сдать с QA-доказательствами. Стиль — D&D + Dark Fantasy Dragon, прозрачный PNG, читаемый силуэт в мелком масштабе, единая палитра/материалы.

Важное ограничение задачи: skill **не должен** генерировать production-пак прямо здесь. Поставка — только reusable workflow/tooling (SKILL.md + правила + чеклист + пример промпта), а не сами картинки.

**Это QA-задача (колонка «Контроль качества»).** Сам skill уже создан в репо коммитом `4b103750 Add FantasyDisk item icon generator skill` — `skills/codex/fantasydisk-item-icon-generator/SKILL.md` + `agents/openai.yaml`. Поэтому работа исполнителя здесь = **верифицировать существующий skill против всех Acceptance Criteria, закрыть найденные дыры (см. ниже) и подтвердить вердикт**, а не писать skill с нуля.

## Текущее состояние в коде

Skill уже существует и в целом покрывает требования тикета:

- `skills/codex/fantasydisk-item-icon-generator/SKILL.md` — основной файл (90 строк):
  - frontmatter `name` + `description` с trigger-словами под artifacts / stat-attribute icons / weapons (строки 1-4) — корректно для роутинга.
  - `## Scope` (строки 10-14): in/out scope, явный запрет старых ручных генераторов, переиспользование `$fantasydisk-asset-generator`.
  - `## Required Inputs` (строки 16-27): `asset_category` (artifact|stat_attribute|weapon), `canonical_id`, `display_name`, `target_size` (по умолчанию 256x256), `final_path`, `source_dir`, `style_notes`, `qa_evidence`.
  - `## Asset Matrix` (строки 29-39) — таблица путей runtime PNG / source / preview по категориям.
  - `## Generation Workflow` (строки 41-62): 8 шагов, ссылка на `tools/artgen/generate_asset.py` с фоллбэком на bundled `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py`, размер генерации 1024x1024 → даунскейл, постпроцесс alpha.
  - `## Prompt Template` (строки 64-75) — готовый текстовый шаблон промпта + правило символьных силуэтов для stat-иконок.
  - `## QA Checklist` (строки 77-89) — 7 проверок: RGBA/прозрачность, no-crop + 10-18% padding, читаемость 32/40/64, no baked text/frame/panel, единая палитра, точный runtime-нейминг с префиксами, полнота артефактов в task mirror + Jira.
- `skills/codex/fantasydisk-item-icon-generator/agents/openai.yaml` — interface-манифест (display_name, short_description, default_prompt `Use $fantasydisk-item-icon-generator ...`).

Родительский skill, который этот переиспользует:

- `skills/codex/fantasydisk-asset-generator/SKILL.md` (102 строки) — общий арт-директор: workflow генерации, output paths, quality/size правила для `gpt-image-2`, явная оговорка что `gpt-image-2` **не** умеет прозрачный фон напрямую → генерим reference, потом постпроцессим alpha (строки 91, 43-50). Окружение: `OPENAI_API_KEY` + python `openai` (строки 93-95). Есть скрипт-фоллбэк `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py` (подтверждён, существует и реально вызывает OpenAI Images `model="gpt-image-2"`, `output_format="png"`).

Реальные пути в репо (для сверки Asset Matrix):

- `assets/sprites/ui/icons/artifacts/` — существует (runtime артефакты, ~108 файлов).
- `assets/sprites/ui/icons/derived/` — существует.
- `assets/sprites/ui/icons/stats/` — **существует** (отдельная от `derived`!).
- `assets/sprites/ui/icons/shop/`, `assets/sprites/ui/icons/system/` — существуют.
- `assets/sprites/weapons/` — существует (директория, runtime оружие).
- `docs/design/references/icons/artifacts/` — существует (source-референсы артефактов).
- `docs/design/content_registry.md` — существует (165 КБ), реальный источник canonical id.
- `tools/artgen/` — **НЕ существует** → primary-команда workflow указывает на отсутствующий скрипт, реально работает только bundled-фоллбэк.

## Что сделать — по шагам

Это валидация + добивка существующего skill. По порядку:

1. **Проверить наличие skill в local skill mirror (БЛОКЕР AC №1).** В репо skill есть, но в зеркале `~/.codex/skills/` лежат другие repo-skill'ы (`fantasydisk-asset-generator`, `fantasydisk-animation-director`, `fantasydisk-ui-director`, `jira-create-ticket` и т.д.), а `fantasydisk-item-icon-generator` **отсутствует**. AC требует «Skill доступен в repo/local skill mirror». Засинкать/смиррорить `skills/codex/fantasydisk-item-icon-generator/` (SKILL.md + agents/openai.yaml) в `~/.codex/skills/fantasydisk-item-icon-generator/` тем же механизмом, что и остальные (проверить, есть ли скрипт/таргет синка зеркала; если синк ручной — выполнить и зафиксировать в notes). Убедиться, что зеркальный SKILL.md идентичен репозиторному.

2. **Сверить Asset Matrix с реальными runtime-путями.** В таблице stat/attribute указан `assets/sprites/ui/icons/derived/attr_<canonical_id>.png`, но в репо есть отдельная папка `assets/sprites/ui/icons/stats/`. Определить, куда реально кладутся иконки атрибутов/характеристик (сверить с тем, как их грузит UI-код и как названы существующие файлы в `stats/` и `derived/`), и привести таблицу в SKILL.md к фактической раскладке. Если обе папки валидны (stats = базовые атрибуты, derived = производные характеристики) — развести их в матрице двумя строками с явными префиксами, чтобы исполнитель не ошибся целевой папкой.

3. **Починить ссылку на primary-генератор.** Workflow (строка 52) предлагает `tools/artgen/generate_asset.py` «when it exists», но в репо такого нет. Это не ошибка (есть корректный фоллбэк на bundled-скрипт), но формулировку оставить однозначной: явно пометить, что project-local `tools/artgen/` сейчас отсутствует и каноничен bundled-путь `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py`. Никаких новых скриптов плодить не нужно.

4. **Подтвердить корректность примера команды.** Bundled-команда в SKILL.md генерит `--size 1024x1024` (валидно: `gpt-image-2` имеет нижний порог ~1 МП — генерить большой reference, потом даунскейл до target 256x256). Убедиться, что в SKILL.md явно прописан шаг даунскейла reference → 256x256 final (шаг 5 workflow это покрывает; проверить непротиворечивость размеров) и что alpha-постпроцесс упомянут (родительский skill: `gpt-image-2` прозрачный фон напрямую не умеет).

5. **Прогнать QA Checklist как ревью-критерий самого skill** (не генерируя картинки): проверить, что чеклист (строки 77-89) реально покрывает все три «Acceptance criteria» из тикета про качество — transparent PNG, no cropped subject, readable silhouette at small sizes, consistent palette/materials, no baked text. Сопоставление 1:1 (см. секцию AC ниже). Если какой-то пункт тикета не отражён в чеклисте — дописать.

6. **Подтвердить, что есть валидный example/checklist для self-serve генерации later** (AC №5). Сейчас есть `## Prompt Template` + `## QA Checklist` + правило символьных силуэтов для stat-иконок. Проверить, что этого достаточно для генерации пака без вопросов к пользователю; при необходимости добавить 1 короткий end-to-end example (например, заполненный набор Required Inputs + готовый промпт для одной конкретной иконки каждой из трёх категорий).

7. **Документ-роутинг (если потребуется).** Тикет в Suggested locked paths упоминает «AGENTS.md/process docs if routing text changes». Менять их ТОЛЬКО если skill-роутинг реально требует упоминания нового skill в `AGENTS.md`. Если общего упоминания asset-пайплайна достаточно — не трогать, зафиксировать решение в notes.

8. **Финал: вердикт QA.** Прогнать `python3 tools/jira_board_sync.py`, выставить статус по результату (PASSED → Готово), оставить Jira-комментарий с перечнем проверенных AC и закрытых дыр.

## Acceptance Criteria

Из тикета (дословно) + добитые проверками по коду:

- [ ] Skill доступен в **repo И в local skill mirror** (`~/.codex/skills/fantasydisk-item-icon-generator/`), SKILL.md валиден, frontmatter `description` содержит trigger-слова под artifacts, stat/attribute icons и weapons. **(сейчас зеркало отсутствует — закрыть)**
- [ ] Workflow описывает обязательные входы: `asset_category`, canonical id/name, target size, transparency, style notes, output dirs, QA evidence (секция `## Required Inputs`).
- [ ] Правила качества присутствуют и проверяемы: transparent RGBA PNG, no cropped subject (10-18% padding), readable silhouette at small sizes (32/40/64), consistent palette/materials (D&D + Dark Fantasy Dragon), **no text baked into icons** unless explicitly requested (секция `## QA Checklist`).
- [ ] Skill переиспользует текущий OpenAI Images / `gpt-image-2` asset pipeline (`$fantasydisk-asset-generator` + bundled `generate_asset.py`) и **не** возвращается к старым ручным генераторам (явный запрет в `## Scope`).
- [ ] Есть короткий validation/example prompt или checklist (`## Prompt Template` + `## QA Checklist`), достаточный, чтобы другой агент сгенерировал пак later **без уточнений у пользователя**.
- [ ] **(добитое)** Asset Matrix в SKILL.md соответствует реальным runtime-путям репо (`artifacts/`, `derived/` vs `stats/`, `assets/sprites/weapons/`) — никаких выдуманных путей.
- [ ] **(добитое)** Ссылка на генератор корректна: отсутствующий `tools/artgen/` помечен как опциональный, каноничен bundled-фоллбэк.
- [ ] **(добитое)** Skill ничего не генерит в этой задаче (никаких новых production PNG в `assets/`); поставка — только workflow/tooling.

## Files / точки входа

- `skills/codex/fantasydisk-item-icon-generator/SKILL.md` — основной файл skill; править Asset Matrix (шаг 2), формулировку генератора (шаг 3), при необходимости добить QA Checklist/example (шаги 5-6).
- `skills/codex/fantasydisk-item-icon-generator/agents/openai.yaml` — interface-манифест; проверить актуальность, обычно править не нужно.
- `~/.codex/skills/fantasydisk-item-icon-generator/` — **создать/засинкать зеркало** (шаг 1, БЛОКЕР).
- `skills/codex/fantasydisk-asset-generator/SKILL.md` — read-only референс родительского пайплайна (правила `gpt-image-2`, alpha, окружение). НЕ менять без отдельной причины.
- `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py` — bundled-генератор (фоллбэк, существует) — read-only.
- `docs/design/content_registry.md` — источник canonical id для сверки наименований — read-only.
- `assets/sprites/ui/icons/{artifacts,derived,stats}/`, `assets/sprites/weapons/`, `docs/design/references/icons/` — реальные целевые/source-папки для сверки матрицы — read-only.
- `tools/jira_board_sync.py` — финальный синк статуса/вердикта (шаг 8).

## Замечания / подводные камни

- **Это QA-валидация, не green-field.** Skill уже в репо. Главная реальная дыра — отсутствие зеркала в `~/.codex/skills/` (все прочие repo-skill'ы там есть, а этот — нет). Без зеркала AC №1 формально не закрыт.
- **`derived` vs `stats`.** Не считать за факт, что stat/attribute иконки идут в `derived/`. В репо есть отдельная `assets/sprites/ui/icons/stats/`. Перед правкой матрицы реально посмотреть, как UI грузит эти иконки и как названы существующие файлы — заземлиться, не угадывать.
- **`gpt-image-2` без прозрачности напрямую.** Любая «transparent PNG» проходит через постпроцесс alpha (см. `fantasydisk-asset-generator/SKILL.md:91`). Skill это уже учитывает; при правках не сломать этот инвариант.
- **Размерный конвейер.** Генерация ≥1 МП (нижний порог `gpt-image-2`, см. `generate_asset.py:24` `MIN_PIXELS = 1024*1024`) → даунскейл до target 256x256. Не предлагать генерить сразу 256x256 — отклонится API.
- **Anti-collision / locked paths.** Тикет фиксирует locked paths: `skills/codex/fantasydisk-asset-generator/`, `skills/codex/fantasydisk-item-icon-generator/`, AGENTS.md/process docs. **НЕ трогать** `scripts/ui_screens.gd` и `scripts/progression_data.gd` (глобально залоченные за параллельными контурами) — эта задача их не касается. Любые правки runtime GDScript вне scope.
- **Никакой генерации картинок в этой задаче.** Не коммитить новые PNG в `assets/` — поставка только текст skill/workflow. Если для примера нужно показать картинку — это нарушение scope; ограничиться текстовым промптом/чеклистом.
- **Foma / автоматизация.** Метка `foma` → задача в user-approved automation queue; держать Jira синхронной на каждом шаге (live-sync mandate). После вердикта самому прогнать `jira_board_sync.py`.
- **Связанные сущности.** Эпик SCRUM-216 (asset-pipeline). Родительский skill SCRUM-уровня — `fantasydisk-asset-generator` (используется как база, переиспользовать, не дублировать его правила внутрь item-icon-skill сверх необходимого).

## QA-Вердикт (2026-06-27)
Статус: FAILED
Проверено фактически (коммит skill 4b103750, ветка dev, HEAD 176d67bb; skill ничего не генерит):
- frontmatter trigger-слова (artifacts/stat-attribute/weapons) — PASS
- Required Inputs (category/id/name/size/transparency/style/output dirs/qa evidence) — PASS
- QA Checklist (transparent RGBA, no-crop 10-18%, readable 32/40/64, palette, no baked text) — PASS
- reuse $fantasydisk-asset-generator + bundled generate_asset.py (существует), запрет легаси — PASS
- никаких новых production PNG в assets/ — PASS (scope соблюдён)

Баги (2 невыполненных AC):
1. **БЛОКЕР AC №1** — нет local skill mirror `~/.codex/skills/fantasydisk-item-icon-generator/` (все прочие repo-skill'ы зеркалированы, этот нет). `ls ~/.codex/skills/ | grep item-icon-generator` → пусто.
2. **AC «Asset Matrix = реальным путям»** — матрица (SKILL.md:36) имеет одну строку Stat/attribute → `derived/attr_<id>.png`, но базовые атрибуты реально в `assets/sprites/ui/icons/stats/stat_<id>.png` (8 файлов, префикс `stat_`); `scripts/ui_icon_registry.gd:51-70` грузит обе папки. Маршрут `stats/` в матрице отсутствует.

Мелочь (не блокер): workflow:52 `tools/artgen/generate_asset.py` «when it exists» — каталога нет; пометить опциональным с каноничным bundled-фоллбэком.

Bug-issue: SCRUM-543. Задача возвращена в «К выполнению».
