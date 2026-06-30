# Refactor Wave: Meta Progression, Codex, Achievements And Glossary Data

Jira: SCRUM-719
Статус: done
Приоритет: P2
Роль: Back-end / meta quality
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p2, area-meta, area-codex
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task covers meta/game data modules that are not part of core combat or progression facade work.

## Scope / Locked Paths

- `scripts/meta_progression.gd`
- `scripts/codex_data.gd`
- `scripts/achievements_data.gd`
- `scripts/glossary.gd`
- `scripts/patch_notes_data.gd`
- Related tests
- `docs/design/systems/progression_balance.md` if meta contracts change

## Required Change

Audit and safely refactor meta/data modules: unlock tracking, achievements, glossary entries, patch notes, Codex data contracts, save compatibility and stale hardcoded IDs. Preserve player-facing Russian text unless fixing a typo/bug with evidence.

## Acceptance Criteria

- Meta/Codex/data audit is recorded.
- Save compatibility and unlock tracking are preserved.
- Stale or missing IDs are fixed or filed with evidence.
- Player-facing text changes are intentional and documented.
- Focused tests cover changed contracts.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/meta_skill_tree_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/codex_data_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/achievements_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## QA-Вердикт
Статус: PASSED

Проверял claude-qa (2026-06-30) на чистом изолир. worktree от origin/dev HEAD, fdengine slots=1. Коммиты `03e2c36c` (фикс+тест+аудит) + `3bb4a765` (mirror) — ancestor origin/dev подтверждён.

Реальный баг подтверждён исправленным: 4 мини-элитки Возвышения (SCRUM-607: mini_siege_rammer/swarm_sniper/plague_berserker/void_phantom) были в геймплее (MINI_ELITE_KINDS), но отсутствовали в `codex_data.gd` → их убийство молча не открывало codex-запись. Добавлены canonical-записи (player-facing RU title/desc), кодекс монстров 26→30. Save-compat/unlock не трогались.

Code review: новый `codex_discovery_contract_test.gd` валиден — гоняет реальный контракт `record_codex_discovery → is_codex_discovered` в обе стороны (каждый рантайм-источник id записывается; нет мёртвых codex-монстров) и **закрепляет** известный задокументированный разрыв секретного босса (ассерт «покраснеет», если разрыв молча закроют). Секретный босс намеренно НЕ правился (player-facing дизайн-решение, зафиксирован как finding + тест).

Гейты (fdengine slots=1, все pass):
- `codex_discovery_contract_test` → passed (20 enemy-name, 10 mini-elite, 5 act-boss; reverse OK).
- `codex_data_smoke_test` → passed (**30 монстров** — подтверждает 26→30).
- `mini_elite_roster_spawn_test` → passed (10 видов, **+4 новых**, tint виден).
- `content_registry_consistency_test` → passed (0 allowlisted).
- `meta_progression_smoke_test` / `meta_skill_tree_smoke_test` → passed (save-compat/unlock чисто).
- `achievements_smoke_test` → passed (8 ачивок, unlock/reward/save-load).
- `runtime_smoke_test` (умбрелла): все функциональные ассерты проходят (прогон доходит до финального dup-guard, codex-счётчик привязан к mini_elite_kinds().size()=30). Трейлинг dup-guard-скан периодически ловит OOM-kill (RC 137/247) — это **пре-существующий** environment-flake скана ~9800 файлов (dup-guard байт-идентичен версии в worktree SCRUM-722, где прямой прогон прошёл RC=0 @1.24 GB; зависит от окна памяти), НЕ дефект SCRUM-719 (719 dup-guard не трогает). Краша/_fail-крошки нет.

Прим. для PM (вне scope 719): умбрелла-dup-guard склонна к OOM при нехватке памяти — кандидат на потоковую (stream) проверку вместо удержания всех файлов в памяти.

→ PASSED.
