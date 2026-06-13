# Анимации уникальных атак всех классов (патч 0.1.5)

Статус: new (возвращён в бэклог 0.1.5 PM 2026-06-13 по команде пользователя — фриз: патч 0.1.5 не делается в спринте 0.1.4)
Приоритет: normal
Роль: Animator (rig motion в cutout_rig_2d.gd)
Версия: 0.1.5
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-239
Эпик-патч: 0.1.5 Бой и баланс (overhaul)


## Dispatcher Redispatch (2026-06-13)

Отправлено в существующий Animator thread `019eb156-710c-71f0-8903-eada762dceb3`
как 0.1.4 board-completion task. Keep reasoning High/no low. Если нужны новые
или перерисованные части спрайтов/VFX, создать/update Design handoff; если нужен
code/API/lifecycle support, создать/update Back-end handoff.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Тема патча 0.1.5
Патч посвящён БАЛАНСНЫМ правкам и МЕХАНИКАМ (формулы урона и выживаемости),
уникальному геймплею на каждом персонаже и каждом оружии. Общий критерий приёмки
любой задачи патча: глобальные balance smoke по урону и выживаемости остаются
в целевых коридорах (см. backend_global_balance_smoke_damage_survivability_task).

## Контекст (запрос пользователя)
«Переделать поведение, оружие и АНИМАЦИИ» под новые уникальные механики.

## Требования
1. По итогам framework-задачи (уникальные механики per класс) и melee/summoner/
   auras — обновить/добавить анимации атак/каста/призыва/ауры для затронутых
   классов и оружий: читаемый windup→release→recover, тайминги из конфигов
   оружия (код — источник истины).
2. Не ломать существующие риги; cutout_rig_2d профили согласованы.
3. animation + runtime smoke зелёные.
4. Нехватка частей спрайтов — handoff Design.
5. CHANGELOG; animation.md.

## Files / Assets / IDs
- scripts/cutout_rig_2d.gd, scripts/sliced_rig_manifest.gd, tests/animation_smoke_test.gd

## Acceptance Criteria
- [ ] Анимации новых уникальных атак для затронутых классов/оружий; тайминги из конфигов.
- [ ] animation+runtime smoke зелёные; CHANGELOG/animation.md; handoff при нехватке частей.
