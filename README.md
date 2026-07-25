# FantasyDisk

2D top-down loot-action рогалик на **Godot 4 (GDScript)**: играбельные классы,
процедурные забеги, события, прокачка, кодекс.

## 🚀 Онбординг (1 строка)
Любой агент/человек после клонирования выполняет одну команду — она подключает все
скиллы проекта и печатает стартовый протокол:
```bash
bash scripts/onboard.sh
```
Для release skill это не обычная ссылка на текущий checkout: onboarding сначала
собирает и полностью проверяет managed mirror в
`~/.codex/skill-mirrors/FantasyDisk/fantasydisk-release-director`, затем
сохраняет проверенное дерево в immutable version store и одной atomic selection
commit point переключает `~/.codex/skills/fantasydisk-release-director` на
полностью готовую версию. Непосредственно перед каждой atomic activation
onboarding заново проверяет физическую identity managed parent, stage, marker
и destination через descriptor-relative no-follow операции; подмена прерывает
run без success signal. Canonical mirror pointer обновляется после этого
commit point; старые version trees не удаляются во время обновления, поэтому
читатель, уже разрешивший старую версию, может дочитать её целиком. Обновления
сериализуются managed lock; после обычного сбоя или SIGTERM временный residue
убирается только в том же live-процессе после проверки физической идентичности.
После SIGKILL residue и ownership marker намеренно сохраняются: следующий
onboarding останавливается до изменения selection/mirror и просит оператора
удалить или проверить эти пути вручную. Persistent marker, PID, режим, имя или
содержимое никогда не считаются доказательством авторства для cross-run cleanup.
Завершённый Multica task/worktree не остаётся persistent source. Неизвестная
реальная локальная папка сохраняется и останавливает
onboarding; private version store создаётся только как реальная директория внутри
managed mirror parent, а symlink, файл, FIFO, socket или другой неожиданный тип
останавливает onboarding до любого чтения или удаления под этим путём. Внешняя
или dangling ссылка никогда не используется как source.
Дальше: AI-агенты автоматически видят мастер-скилл **`fantasydisk-onboarding`**
(в `.claude/skills/`), люди читают [`docs/process/ai_agent_memorandum.md`](docs/process/ai_agent_memorandum.md).
**Правило №1:** все задачи создаются в и берутся из **Multica** (проект
`FantasyDisk`, issues `FAN-*`) через `multica` CLI — `docs/tasks/*.md` и
`docs/process/task_board.md` лишь зеркала/кэш. Legacy Jira (`SCRUM-*`) — read-only
исторический архив, не источник новой работы (см.
[`docs/process/jira_to_multica_cutover.md`](docs/process/jira_to_multica_cutover.md)).
Ветки: `main`=релиз, `dev`=работа (default), immutable теги `v<version>`=версии.

Текущий опубликованный stable release: `0.2.4`. Обычный продуктовый релиз
использует `X.Y.Z`; технический релиз с изменёнными байтами и без новых игровых
функций использует `X.Y.Z.R`. Для обоих форм tag `v<version>` и опубликованные
байты immutable; повторная доставка не меняет их.

## Требования
- **Godot 4.7** (стандартная сборка, ветка 4.x). Скачать: https://godotengine.org/download
- **Git** — для клонирования и работы с GitHub.

## Запуск
1. Клонировать репозиторий (см. GitHub-инструкцию).
2. Открыть `project.godot` в Godot 4.7.
3. Нажать ▶ (F5) — откроется главное меню.

## Ветки
- `main` — стабильная версия.
- `dev` — активная разработка; мержится в `main` на релизе.

Работай в `dev`: правки → коммит → push в `dev`. На другой машине — `git pull`.

## Quality gate и headless smoke-тесты

Кроссплатформенный changed-profile (static checks + тесты затронутых доменов):
```bash
python3 tools/quality_gate.py --profile changed
```
Полный набор direct + inherited suites:
```bash
python3 tools/quality_gate.py --profile full
```
GitHub Actions на pull request и merge queue выполняет `--profile changed` на
закреплённом Godot `4.7.stable.official.5b4e0cb0f`: static checks плюс
Godot-suites, отобранные по diff. Push в `dev` перепроверяет уже прошедший гейт
кандидат и остаётся на `--static-only`, который Godot не запускает. Полный
`--profile full` остаётся локальным/release-гейтом.
Нативный Windows-profile (PowerShell; предварительно задать путь к Godot):
```powershell
$env:GODOT_BIN = "C:\Godot\Godot_v4.7-stable_win64.exe"
python tools/quality_gate.py --profile windows
```
Все автоматические вызовы Godot проходят через `tools/godot_gate.py`; runner
изолирует `user://` и видит также suites, наследующие другой тестовый скрипт.
Основные наборы: `runtime_smoke_test.gd`, `animation_smoke_test.gd`,
`attack_vfx_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`.
`ui_no_overlap_matrix_test.gd` является UI render gate: открывает экраны headless
на 1080p/2K/4K, ловит overflow текста, overlap контролов и некорректный stretch
точноразмерных UI frame TextureRect.

## Локальные секреты (НЕ в git — создать на каждой машине)
Эти файлы в `.gitignore`; нужны только для фидбека/релиза, на саму игру не влияют:
- `feedback_webhook.cfg` — Discord-webhook внутриигрового фидбека (шаблон: `feedback_webhook.cfg.example`).
- `release_webhook.cfg` — Discord-webhook публикации релизов.
- `fantasydisk_release.session` — текущая локальная Telethon-сессия (секрет) для
  обязательной Telegram-доставки файлов каждого stable release.

## Сборка релиза (macOS)

Текущий одобренный канал — явный `unsigned`:

```bash
FANTASYDISK_MACOS_CHANNEL=unsigned tools/build_release.sh <version>
```

Строгий подписанный канал включается отдельно, когда доступны Apple credentials:

```bash
export MACOS_SIGN_IDENTITY="Developer ID Application: <owner> (<TEAMID>)"
export MACOS_NOTARY_PROFILE="fantasydisk-notary" # credentials stored in Keychain
FANTASYDISK_MACOS_CHANNEL=signed tools/build_release.sh <version>
```

Оба канала fail-closed и не переключаются молча. `signed` требует Developer ID,
Apple notarization/stapling и успешный `spctl`; `unsigned` отказывается работать
при заданных Apple credentials, ставит только локальную ad-hoc подпись для
проверки целостности bundle и пропускает Apple trust-проверки. Она не является
подписью Developer ID: игрок по-прежнему получает честную инструкцию Gatekeeper
«Всё равно открыть».
Проверенный пакет публикуется только в public binary-only repository
`FomaBy/FantasyDisk-Releases` через bundled `github_release_publish.py`; клиент
0.2.2+ читает `update-manifest.json` из `releases/latest` этого repository.
Каждый stable release дополнительно доставляется в Telegram (poster, DMG, Windows
Setup и SHA256SUMS), а Discord сообщает Telegram download link.

## Структура
- `scripts/` — игровая логика (GDScript)
- `scenes/` — сцены Godot (`.tscn`)
- `assets/` — спрайты, фоны, аудио, шрифты, UI
- `tests/` — headless smoke-тесты
- `tools/` — утилиты (сборка, фидбек; legacy Jira-хелперы — archive-only)
- `docs/` — дизайн-доки, процессы, задачи

## AI-автоматизация (только macOS)
Агентная оркестрация (Codex-скиллы в `~/.codex/`, scheduled-task рутины,
локальный Multica daemon, запускающий Codex/Claude) специфична для Mac-машины и
**не переносится в репозиторий**. Задачи ведутся в Multica (`multica` CLI); legacy
`tools/jira_*.py` — archive-only. На Windows работает сама игра — Godot
кросс-платформенный; AI-оркестрация остаётся на Mac.
