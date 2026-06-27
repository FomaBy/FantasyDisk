# FantasyDisk

2D top-down loot-action рогалик на **Godot 4 (GDScript)**: играбельные классы,
процедурные забеги, события, прокачка, кодекс.

## 🚀 Онбординг (1 строка)
Любой агент/человек после клонирования выполняет одну команду — она подключает все
скиллы проекта и печатает стартовый протокол:
```bash
bash scripts/onboard.sh
```
Дальше: AI-агенты автоматически видят мастер-скилл **`fantasydisk-onboarding`**
(в `.claude/skills/`), люди читают [`docs/process/ai_agent_memorandum.md`](docs/process/ai_agent_memorandum.md).
**Правило №1:** все задачи создаются в и берутся из **Jira** (проект SCRUM) —
`docs/tasks/*.md` и `docs/process/task_board.md` лишь зеркала/кэш. Ветки: `main`=релиз,
`dev`=работа (default), теги `vX.Y.Z`=версии.

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

## Headless smoke-тесты
macOS:
```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_smoke_test.gd
```
Windows (путь под свою установку Godot):
```powershell
& "C:\Godot\Godot_v4.7-stable_win64.exe" --headless --path . --script res://tests/runtime_smoke_test.gd
```
Другие наборы: `animation_smoke_test.gd`, `attack_vfx_smoke_test.gd`, `meta_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`.
`ui_no_overlap_matrix_test.gd` является UI render gate: открывает экраны headless
на 1080p/2K/4K, ловит overflow текста, overlap контролов и некорректный stretch
точноразмерных UI frame TextureRect.

## Локальные секреты (НЕ в git — создать на каждой машине)
Эти файлы в `.gitignore`; нужны только для фидбека/релиза, на саму игру не влияют:
- `feedback_webhook.cfg` — Discord-webhook внутриигрового фидбека (шаблон: `feedback_webhook.cfg.example`).
- `release_webhook.cfg` — Discord-webhook публикации релизов.
- `fantasydisk_release.session` — Telethon-сессия (создаётся при первом логине).

## Сборка релиза (macOS)
```bash
tools/build_release.sh <версия>    # напр. 0.1.6 — собирает из git-тега
```

## Структура
- `scripts/` — игровая логика (GDScript)
- `scenes/` — сцены Godot (`.tscn`)
- `assets/` — спрайты, фоны, аудио, шрифты, UI
- `tests/` — headless smoke-тесты
- `tools/` — утилиты (сборка, Jira-синк, фидбек)
- `docs/` — дизайн-доки, процессы, задачи

## AI-автоматизация (только macOS)
Агентная оркестрация (Codex-скиллы в `~/.codex/`, scheduled-task рутины,
`tools/jira_board_sync.py` через macOS Keychain) специфична для Mac-машины и **не
переносится в репозиторий**. На Windows работает сама игра — Godot кросс-платформенный;
AI-оркестрация остаётся на Mac.
