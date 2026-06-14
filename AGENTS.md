# FantasyDisk Agent Instructions

This repository is a Godot 4 project for FantasyDisk.

Before making gameplay, balance, character, enemy, UI, or progression changes, read:
- `docs/design/fantasydisk_design_brief.md`
- `docs/design/gdd_source.md` when exact GDD wording matters.
- `docs/design/mechanics_extract.md` when formulas, classes, stats, weapons, or MVP screens matter.
- `docs/design/current_game_state.md` for the implemented game state.
- `docs/design/content_registry.md` for canonical entity IDs and names.
- `docs/process/agent_role_boundaries_and_handoffs.md` for Design/Back-end/Animator ownership and cross-chat handoff rules.
- `docs/process/versioning_and_branching.md` for the active version/branch policy.

Autonomy and approval:
- The user pre-approves all in-scope project changes requested in task files or direct prompts.
- Do not stop to ask for confirmation when the requirement is clear enough to implement. Make a reasonable product/engineering decision, implement it, test it, and document it.
- Ask the user only when the task is impossible without missing information, would change the product direction outside the request, or would require a dangerous/destructive action.
- Still obey Codex/runtime safety rules: request required sandbox escalation, do not expose secrets, do not use destructive git/file commands unless explicitly requested, and do not modify files outside the project without approval.
- For every future task that changes functionality, balance, content, UI, progression, visuals, or animation, update the relevant documentation in the same task.
- After large multi-agent change batches, run the documentation split/update task in `docs/tasks/documentation_post_changes_domain_split_task.md` and keep domain docs under `docs/design/systems/` up to date.

**UI/ВИЗУАЛ — ГЛОБАЛЬНОЕ ПРАВИЛО ФРЕЙМОВ (директива пользователя 2026-06-14, ОБЯЗАТЕЛЬНО для ВСЕХ агентов).**
Ни при каких обстоятельствах нельзя накладывать элементы интерфейса — кнопки,
портреты/героев, области выбора (карусели, списки, слоты), иконки, текст — на
текстуру/окантовку/орнамент рамки (frame). Контент размещается ТОЛЬКО в пустой
зоне фрейма: в прозрачной/тёмной внутренней области или на подложке фона.
Декоративная рамка всегда остаётся видимой и не перекрытой контентом.
- Технически: у текстурных стилей (StyleBoxTexture / 9-slice) **content margins ≥
  texture margins (толщины окантовки) + запас**. Для радиальных/фигурных рамок
  content-зона = реальная внутренняя пустая область, не bounding box.
- Это hard-правило приёмки: наложение контента на орнамент рамки = QA FAILED
  (см. `docs/process/qa_protocol.md` «Контент только в пустой зоне фрейма»).

Role boundaries:
- A PM chat forms requirements and issues tasks; its workflow is `docs/process/pm_workflow.md`, task statuses are tracked in `docs/process/task_board.md`.
- Design, Back-end, and Animator agents must do only their own discipline-specific work: Design owns art/sprites/UI visuals, Back-end owns logic/code/balance/tests, Animator owns motion/rigs/animation states.
- If a task needs another discipline, create/update a `.md` handoff task in `docs/tasks/` and send it to the correct chat instead of doing that specialist's work directly.
- Use `docs/process/agent_role_boundaries_and_handoffs.md` as the source of truth for ownership and handoff format.
- When taking a task, set `Статус: in_progress` in its file; when finishing, set `done` (or `review`) and append a short result summary so the PM can sync the task board.
- Jira is mandatory for task tracking. Follow `docs/process/jira_sync.md`: every task must have a `Jira: SCRUM-*` link, current sprint membership, and Jira status/comment updates matching `.md` status changes. Never store Jira API tokens in the repository.

**ЖИВАЯ СИНХРОНИЗАЦИЯ JIRA — ОБЯЗАТЕЛЬНА (директива пользователя 2026-06-13).**
Пользователь управляет разработкой по Jira, поэтому Jira ВСЕГДА должна отражать
реальность. Каждый агент, который берёт, двигает или завершает работу, ОБЯЗАН:
1. **Взял в работу** → задача в `.md` `in_progress` + `python3 tools/jira_board_sync.py`
   (тикет уходит в «В работе»). Не работать «в тени», не отразив это в Jira.
2. **Завершил** → `.md` `done` с резюме + sync (тикет → «Контроль качества»;
   после QA-вердикта PASSED → «Готово»). Закрытая работа ОБЯЗАНА быть закрыта в Jira.
3. **Передаёшь работу другому агенту (handoff)** → создай handoff-`.md`, и его
   тикет в Jira создаётся синком автоматически с нужным эпиком/ролью; в исходном
   тикете комментарием отметь, КОМУ и ЧТО передано (Jira-ключ handoff'а). Передача
   основной задачи без отражения в Jira запрещена.
4. **Заблокировал / переименовал / дублировал** → отрази статус и причину в Jira
   (status/comment), не оставляй расхождений `.md`↔Jira.
5. В КОНЦЕ ЛЮБОГО прогона со сменой статусов — `python3 tools/jira_board_sync.py`
   (идемпотентен); если изменился `jira_sync_map.json` — закоммить.
Правило: «не закрыл/не передал в Jira — работа не считается сделанной». Держи
синхронизацию Jira с реальностью в голове на каждом шаге.

Versioning:
- `main` is the stable `0.1` line.
- `dev` is the active working branch for the current `0.1.x` line.
- All implementation tasks should be done on `dev` unless a task explicitly says otherwise.
- Check the current branch before making changes; do not do ordinary feature work directly on `main`.

Full autonomy (user directive, 2026-06-12):
- ALL agents (Claude chats, board workers, QA, Codex threads) work autonomously:
  do NOT ask the user questions, do NOT wait for user input or confirmation.
- The user pre-approved all in-scope changes. If a requirement is ambiguous,
  make the most reasonable product decision yourself, implement it, and record
  the decision + rationale in the task file report.
- If something truly cannot proceed (missing asset, broken dependency,
  conflicting requirement), do not stall: mark the task `blocked` with a precise
  reason on the board, create a handoff if another role can unblock it, and move
  to the next task. PM reviews blocked items.
- Questions for the user are allowed ONLY for destructive/irreversible actions
  outside the repo (deleting user files, external accounts, payments) — these
  are out of scope for executors anyway.

Feature block:
- LIFTED 2026-06-13 релизом v0.1.4. Активен `Спринт 0.1.5` (Jira board 1) —
  патч «Бой и баланс»; задачи 0.1.5 теперь в работе обычным порядком.
- Механизм сохраняется: перед стабилизацией следующего релиза PM снова включает
  фриз (новые не-баги → `Версия: <следующая>`, sync держит их в бэклоге).

Use Godot 4 GDScript and keep systems compatible with the source design:
- FantasyDisk is a 2D top-down loot-action survival roguelite with RPG buildcraft.
- The MVP prioritizes Berserk, Dark Mage, Guitarist, melee enemy, shooter enemy, and summoner enemy.
- Berserk should trend toward melee cone/AoE weapons, not generic permanent bullet shooting.
- Spreadsheet stat names and formulas are the long-term authority for balancing.

Project practices:
- Keep code split into focused scenes and scripts.
- Prefer data-driven character/enemy/weapon configuration where practical.
- Keep prototype visuals simple until art direction exists.
- **Генерация графики/ассетов — ТОЛЬКО скиллом `fantasydisk-asset-generator`**
  (Codex skill, `~/.codex/skills/fantasydisk-asset-generator/`, SCRUM-324):
  `scripts/generate_asset.py --prompt "<...>" --output <тема/файл> --size <WxH>
  --quality high` (OpenAI Images API, модель `gpt-image-2`, PNG). Он рисует кратно
  лучше прежнего пайплайна — старый способ не использовать. Все ассеты — на
  ПРОЗРАЧНОМ фоне; исходник сохраняется в `docs/design/references/<тема>/` (для
  единообразия на будущее), затем внедряется в `assets/`. Стиль — D&D + Dark
  Fantasy Dragon (см. UI Overhaul SCRUM-327).
- Run Godot headless smoke tests after gameplay changes:
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --script res://tests/runtime_smoke_test.gd`
- Do not commit `.godot/`.
