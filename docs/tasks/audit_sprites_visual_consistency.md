# Аудит: все спрайты и визуальная консистентность

Статус: done (Design audit signed off 2026-06-13)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя: полный аудит и рефакторинг проекта)
Jira: SCRUM-177
Эпик: epic_full_project_quality_pass

Dispatcher: sent to Design thread `019eabf1-6d54-7561-8af9-ce25cdf483a9` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил ВСЁ. Работать автономно без вопросов и ожидания
инпута (директива полной автономии). Тупик = blocked с причиной + handoff.

## Роль
Design (Claude-Designer)
## Роль И Границы
Владелец — Claude-Designer (инвентаризация/ревью/спека). Перерисовки — Codex
Design с референсами (железное правило). Эта задача — READ-ONLY аудит + спека.

## Контекст
~111 спрайтов: 24 персонажа, 51 оружие, 17 врагов/элиток/боссов, 19 эффектов +
UI. После массового add-character часть может быть hue-shift placeholder; идёт
dark fantasy UI рестайл (SCRUM-147). Нужна проверка единства канона и качества.

## Что сделать
1. Инвентаризация всех спрайтов: какие финальные, какие placeholder/hue-shift
   (сверить с content_registry пометками), какие низкого качества/мыло/обрезки.
2. Консистентность канона: единый стиль/масштаб/освещение персонажей и врагов;
   читаемость на 10 аренах; соответствие dark fantasy UI-канону.
3. Контактные листы по группам в `docs/design/previews/` для визуальной сверки.
4. **Отчёт** `docs/design/reviews/sprite_visual_audit_2026_06.md` со списком
   «перерисовать/починить» по приоритету.
5. **Породить** `codex_design_<area>_redraw_task.md` (0.1.4) на перерисовки —
   Codex-генерация с референсами, Claude-Designer ревью/интеграция.

## Acceptance Criteria
- [x] Инвентаризация всех ~111 спрайтов со статусом (финал/placeholder/чинить).
- [x] Контактные листы по группам; отчёт с приоритетами.
- [x] Созданы дочерние codex_design-задачи на перерисовки.

## Документация
content_registry.md (актуализация статусов), docs/design/reviews/, previews/.

## Result

2026-06-13: Read-only Design audit completed for active sprite groups and nearby legacy/UI assets.

- Generated contact sheets in `docs/design/previews/`:
  - `audit_characters_active.png`
  - `audit_characters_legacy_placeholders.png`
  - `audit_weapons_active.png`
  - `audit_enemies_active.png`
  - `audit_enemies_legacy_root.png`
  - `audit_effects_projectiles_allies.png`
  - `audit_backgrounds.png`
  - `audit_map_cursor_hud_frames.png`
  - `audit_ui_stat_shop_icons.png`
  - `audit_artifact_icons_1.png`
  - `audit_artifact_icons_2.png`
- Wrote audit report: `docs/design/reviews/sprite_visual_audit_2026_06.md`.
- Wrote machine/markdown inventory:
  - `docs/design/reviews/sprite_visual_audit_inventory_2026_06.json`
  - `docs/design/reviews/sprite_visual_audit_inventory_2026_06.md`
- Created child 0.1.4 tasks:
  - `docs/tasks/codex_design_new_bosses_mini_elites_redraw_task.md`
  - `docs/tasks/codex_design_vfx_sprite_polish_task.md`
  - `docs/tasks/codex_design_ui_icon_style_unification_task.md`
  - `docs/tasks/codex_design_legacy_sprite_cleanup_spec_task.md`

Top findings:

- Active character/weapon/core enemy/artifact/background sets are mostly coherent and should be kept.
- New SCRUM-155 bosses/mini-elites still need canonical art instead of placeholder/tint identity.
- VFX sprites and some derived/shop UI icons are the weakest style-consistency groups.
- Legacy prototype/root placeholder sprites should be cleaned or archived after Back-end reference confirmation.

No source PNG redraws or gameplay/animation changes were performed in this audit.


## Design Sign-off / 2026-06-13 — ЗАКРЫТ (Claude-Designer)
Все критерии выполнены: инвентарь ~111 спрайтов (JSON+MD), 11 контактных листов
`docs/design/previews/audit_*.png`, отчёт с приоритетами, 4 дочерних codex_design-
задачи (new_bosses_mini_elites_redraw / vfx_sprite_polish / ui_icon_style_unification /
legacy_sprite_cleanup_spec). Перерисовки идут отдельными задачами -> Codex генерация,
Claude-Designer ревью. Read-only, исходники/анимации не трогались.
