# Аудит и обновление документации (код/ассеты ↔ доки)

Статус: done
Приоритет: normal
Роль: Back-end
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя — полный рефакторинг/чистка)
Jira: SCRUM-268
Эпик: CLEANUP — рефакторинг и чистка v2 (SCRUM-266)

## Dispatcher Dispatch (2026-06-14)

Sent to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`. Keep reasoning
High/no low. Scope is documentation audit/report and documentation updates only:
do not change gameplay, balance, runtime code, assets, releases, commits or tags.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## ВАЖНО: это READ-ONLY аудит (Фаза 1)
Только читать код/ассеты/доки и писать ОТЧЁТ + порождать точечные execution-задачи.
НЕ удалять и не рефакторить в этой задаче. Исполнение (Фаза 2) — отдельными
задачами, СЕРИАЛИЗОВАНО ПОСЛЕ балансового патча 0.1.5 (общие файлы:
progression_data/stat_formulas/class_weapon/player/ui_screens), чтобы не ловить
коллизии и сломанный HEAD. Порождённые execution-задачи помечать
`blocked (после балансового патча 0.1.5)` либо new, если файл-изолированы.

## Контекст
Запрос пользователя: «обновить документацию». После 0.1.4-релиза, сплитов и
активного патча доки могли разойтись с реальностью.

## Требования (READ-ONLY аудит → точечные обновления доков)
1. Сверить docs/design/current_game_state.md, content_registry.md,
   mechanics_extract.md и docs/design/systems/* с фактическим кодом/ассетами
   (17 классов, новые боссы/мини-элитки, dark fantasy UI, мета-древо, локализация,
   патч-ноуты). Найти устаревшие/противоречивые/отсутствующие разделы.
2. Сверить ID/имена/пути в реестре со фактом (после сплитов progression_data).
3. ОТЧЁТ docs/design/reviews/cleanup_docs_audit_2026_06.md: расхождения.
4. Обновить доки по факту (это правки ДОКОВ, не кода — безопасно, файл-изолированно):
   привести в соответствие; пометить, что ещё в разработке (патч 0.1.5).
5. Если нужно крупное разбиение — сослаться на documentation_post_changes_domain_split.

## Acceptance Criteria
- [x] Расхождения доки↔реальность перечислены; ключевые доки обновлены по факту.
- [x] Реестр ID/имён/путей сверен; отчёт готов.

## Документация
docs/design/reviews/, current_game_state.md, content_registry.md, mechanics_extract.md.

## Result (2026-06-14)

Docs-only audit/update completed. Added report
`docs/design/reviews/cleanup_docs_audit_2026_06.md`; updated the main factual docs
and system docs to match current 0.1.5 reality:
`docs/design/current_game_state.md`, `docs/design/content_registry.md`,
`docs/design/mechanics_extract.md`, `docs/design/fantasydisk_design_brief.md`,
`docs/design/systems/menus_ui.md`, `docs/design/systems/progression_balance.md`,
`docs/design/systems/technical_architecture.md`, `docs/design/systems/combat.md`,
and `docs/design/systems/audio.md`.

No gameplay/runtime code, balance constants, assets, releases, commits, merges,
tags or generated media were changed. Key fixes: 17-class stat table, real Berserk
weapon IDs (`sword`/`axe`/`hammer`), 5-boss/6-mini-elite documentation, 0.1.5
sprint labels, cursor hotspot `(2, 2)`, final SCRUM-262 balance audit references
and 512px elite/boss/mini-elite source sprite status. Remaining non-doc follow-up:
`scripts/codex_data.gd` still uses placeholder boss sprites for some new bosses;
this is Back-end content integration scope and was recorded in the audit report,
not changed here.

## QA-Вердикт (2026-06-14)
Статус: PASSED
Коммит: 2981acf8 (ветка dev)

Проверено (фактически):
- **Отчёт** `docs/design/reviews/cleanup_docs_audit_2026_06.md` (7.2KB) — на месте.
- **Docs-only**: обновлены 9 доков (current_game_state, content_registry,
  mechanics_extract, design_brief + 5 systems-доков) под 0.1.5-реальность;
  gameplay/код/баланс/ассеты/коммиты НЕ менялись.
- **Ключевые сверки**: 17-class stat table, реальные Berserk weapon IDs
  (sword/axe/hammer), 5 боссов/6 мини-элиток, 0.1.5-лейблы, cursor hotspot (2,2),
  SCRUM-262 references, статус 512px source-спрайтов.
- **Кросс-подтверждение**: аудит зафиксировал «`codex_data.gd` ещё использует
  placeholder-боссов для части новых» — ровно находка QA SCRUM-156 (арт не в
  игре до Back-end вайринга); корректно отнесено к follow-up, не правлено здесь.

Acceptance:
- [x] Расхождения доки↔реальность перечислены; ключевые доки обновлены.
- [x] Реестр ID/имён/путей сверен; отчёт готов.

Баги: нет.
