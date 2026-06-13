# Аудит: риги и анимации всех персонажей/врагов

Статус: done
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя: полный аудит и рефакторинг проекта)
Jira: SCRUM-173
Эпик: epic_full_project_quality_pass

Dispatcher: sent to Animator thread `019eb156-710c-71f0-8903-eada762dceb3` on 2026-06-13.

## Autonomy / Approval
Пользователь заранее одобрил ВСЁ. Работать автономно без вопросов и ожидания
инпута (директива полной автономии). Тупик = blocked с причиной + handoff.

## Роль
Design (Claude-Designer ведёт READ-ONLY аудит-фазу; порождённые правки ригов — Animator/Codex)
## Роль И Границы
Animator-аудит (READ-ONLY + спека). Перерисовки частей — handoff Design (Codex).

## Контекст
Cutout-риги через `scripts/cutout_rig_2d.gd` (1485 стр) и
`scripts/sliced_rig_manifest.gd`. 17 классов + враги/элитки/боссы. Анимационный
smoke есть. Нужна проверка покрытия и качества движения.

## Что сделать
1. Покрытие по каждому играбельному классу и типу врага: наличие idle/walk/
   attack(под каждый паттерн оружия)/cast/hit/death, корректные pivot/тени.
2. Качество: рывки, неестественный темп, копипаст одного motion-профиля,
   рассинхрон позы атаки с таймингами оружия (код — источник истины).
3. **Отчёт** `docs/design/reviews/animation_rig_audit_2026_06.md`: матрица
   покрытия (класс/враг × состояние) с пробелами и дефектами по приоритету.
4. **Породить** `animation_<area>_task.md` (0.1.5) на доводку; нехватка частей
   спрайтов — handoff Design.

## Acceptance Criteria
- [x] Матрица покрытия анимаций со всеми пробелами/дефектами.
- [x] Созданы дочерние animation-задачи; smoke не запускался, потому что задача read-only/spec-only и не меняла код/сцены/ассеты.

## Результат
Done 2026-06-13 (Animator/Codex): read-only аудит завершен, отчет создан в
`docs/design/reviews/animation_rig_audit_2026_06.md`.

Порожденные follow-up задачи на 0.1.5:
- `docs/tasks/animation_legacy_player_weapon_pose_hooks_task.md`
- `docs/tasks/animation_enemy_archetype_motion_coverage_task.md`
- `docs/tasks/animation_hit_death_state_coverage_task.md`
- `docs/tasks/animation_weapon_timing_vfx_sync_task.md`
- `docs/tasks/design_animation_ready_boss_mini_elite_parts_handoff_task.md`

Smoke не запускался в этой read-only/spec-only задаче: код, сцены, manifest и
ассеты не менялись. Runtime blocker по UI уже закрыт отдельной Back-end задачей
`docs/tasks/backend_ui_screens_shop_style_parse_errors_task.md`; SCRUM-173 не
вносил runtime-изменений.

## Документация
docs/design/systems/animation.md, docs/design/reviews/.
