# DESIGN: Релизный постер FantasyDisk 0.2.1

Статус: done
Приоритет: high
Роль: Design
Контур: Codex
Owner: codex-root
Thread: /root
Locked paths: docs/design/mockups/release_0_2_1/, docs/design/references/release_0_2_1/, docs/design/previews/release_0_2_1/
Версия: 0.2.1
Создано: 2026-07-12
Автор: прямой запрос пользователя
Jira: SCRUM-1098

## Цель

Сгенерировать готовый релизный постер FantasyDisk 0.2.1 в формате 1920×1080 для публикации. Показать главные release highlights — артефакты, билды, 17 героев / 51 оружие и новую горизонтальную карту — в PixelLab dark-fantasy key art. Текст и логотип размещать только внутри заранее утверждённых пустых зон, не поверх орнамента.

## Acceptance Criteria

- [x] `ui_plan.json` проходит planning gate с `decision: ready_for_image`.
- [x] PixelLab MCP использован для нового 16:9 release key-art/frame layer; ID и prompt сохранены в manifest.
- [x] Финальный PNG содержит версию, краткие highlights, платформы и год релиза.
- [x] Render report имеет `ok: true`; debug overlay доказывает safe-zone fit.
- [x] Итог визуально проверен в 1920×1080; текст не перекрывает орнамент или героев.
- [x] Jira, GitHub и disk cleanup отражают фактический результат.

## Claim / heartbeat

Owner: codex-root. Thread/Worker: `/root`. Lane: Codex. Locked paths: только `docs/design/{mockups,references,previews}/release_0_2_1/` и этот task mirror. Branch/worktree: shared checkout, `dev`. Следующая проверка: planning gate → PixelLab generation → compositor fit report → visual QA.

## Result — 2026-07-12

- Во время pre-push sync обнаружен уже залендившийся параллельный canonical результат `FAN-1027` в `origin/dev` (`b25241059`, cleanup `eb3af8ce4`) с теми же locked paths. Во избежание перезаписи чужого принятого результата локальный дубль удалён до merge; канонический постер сохранён без изменений.
- Готовый release asset: `assets/marketing/fantasydisk_021_announcement_telegram_discord.png`, 1920×1080 RGB PNG, SHA-256 `9dda5196b8a4751e72c9ab0cc059c0035329fc7784d0478909de81a5913f9b6c`.
- Preview/evidence: `docs/design/previews/release_0_2_1/release_0_2_1_final.png`, debug overlay и `release_0_2_1_report.json` (`ok: true`).
- PixelLab MCP accepted source: `faaec6cf-de1f-4ffb-9a15-2326923918e5` (`release_0_2_1_announcement_variant_b`); config smoke PASS, no secrets recorded. Полный prompt/spec и rejected variants сохранены в `docs/design/references/release_0_2_1/manifest.json` и `docs/design/mockups/release_0_2_1/spec.md`.
- Planning gate: `ready_for_image`, `ok: true`, zero errors/warnings. Visual QA и debug-overlay QA: PASS; контент не перекрывает орнамент фрейма.
- Godot smoke: не запускался — runtime logic/code не менялись; canonical marketing PNG уже залендился отдельным зелёным asset-task commit.
- Disk cleanup: удалены локальный duplicate source/base/final package и временные QA previews; disposable worktree/cache не создавались.
- Thread cleanup: not a disposable worker thread.

## QA-Вердикт

Статус: PASSED

Canonical `FAN-1027` evidence проверено по `origin/dev`: planning gate и content-zone report `ok: true`, визуальный QA `PASS`, SHA-256 runtime PNG совпадает с manifest. Отдельный локальный дубль не лендился и не перезаписывал принятый asset.
