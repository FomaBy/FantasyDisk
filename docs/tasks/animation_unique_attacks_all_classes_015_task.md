# Анимации уникальных атак всех классов (патч 0.1.4)

Статус: done
Приоритет: normal
Роль: Animator (rig motion в cutout_rig_2d.gd)
Версия: 0.1.4
Создано: 2026-06-13
Автор: PM (запрос пользователя — патч баланса/механик 0.1.5)
Jira: SCRUM-239
Эпик-патч: 0.1.4 Бой и баланс (overhaul)
QA: in_progress (2026-06-13)


## Dispatcher Redispatch (2026-06-13)

Отправлено в существующий Animator thread `019eb156-710c-71f0-8903-eada762dceb3`
как 0.1.4 board-completion task. Keep reasoning High/no low. Если нужны новые
или перерисованные части спрайтов/VFX, создать/update Design handoff; если нужен
code/API/lifecycle support, создать/update Back-end handoff.

## PM Override (2026-06-13)
PM override: текущую board доделать в `0.1.4`; SCRUM-239 исполняется в
текущем sprint/version `0.1.4`, несмотря на исходное имя файла с `015`.

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
- [x] Анимации новых уникальных атак для затронутых классов/оружий; тайминги из конфигов.
- [x] Final animation+runtime smoke green after Back-end `ProgressionData` facade parse blocker is fixed.
- [x] CHANGELOG/animation.md обновлены; handoff не понадобился.

## Result
Done 2026-06-13 (Animator/Codex): `Player.play_action_animation()` теперь
передает phase-события оружия в cutout rig как animation-only action variant
`weapon_id:attack_mode:phase`, не меняя gameplay damage/targeting/VFX spawn.
Это связывает Back-end timing surface SCRUM-208 с уже существующими rig poses
для уникальных атак: windup/release/pulse/burst/deploy/channel читаются на
текущих cutout rigs.

`tests/animation_smoke_test.gd` расширен матрицей phase-pose coverage по всем
текущим playable class weapon variants: legacy classes, Soldier/Thief/
Elementalist/Sniper/Priest/Biologist/Robot/Engineer, плюс existing Berserk
weapon action coverage. Smoke проверяет, что variant сохраняет weapon ID,
attack mode и phase, а rig silhouette реально меняется относительно idle.

Verification:
- `tests/animation_smoke_test.gd` passed once immediately after the Animator
  implementation.
- Final verification is blocked by an external Back-end parse blocker introduced
  by the active `ProgressionData` domain split: Godot now reports missing
  `res://scripts/progression_data_meta.gd`, `ProgressionData.SHOP_ITEMS`
  compatibility errors, and dependent `player.gd` compile failure before the
  animation smoke/runtime smoke can make a valid pass. This is outside Animator
  ownership and must be fixed by Back-end under SCRUM-198 or equivalent
  release-blocker follow-up.

Jira sync 2026-06-13: `tools/jira_board_sync.py` was run; direct Jira comments
were added to SCRUM-239 and SCRUM-198. Live Jira status check: SCRUM-239 =
`К выполнению`, Fix Version `0.1.4`; SCRUM-198 = `В работе`, Fix Version
`0.1.4`.

## Back-end Unblock Verification (2026-06-13)

Back-end SCRUM-198 restored the `ProgressionData` compatibility facade and fixed
the missing `progression_data_meta.gd` / `ProgressionData.SHOP_ITEMS` parse
blocker. Final verification is no longer blocked.

Verification now passed:

- `tests/animation_smoke_test.gd`
- `tests/runtime_smoke_test.gd`

No Animator-owned motion, rig, pose, or timing polish was changed in this
Back-end unblock pass.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 168c3fad (ветка dev)

Проверено (фактически):
- **Механизм**: `Player.play_action_animation(...)` (player.gd:316) строит
  animation-only variant `weapon_id:attack_mode:phase` (строка 338) — передаёт
  фазу оружия в cutout rig, НЕ меняя damage/targeting/VFX (gameplay-preserving).
- **Тест не пустышка** (`animation_smoke_test.gd`): матрица phase-pose по классам
  — ассертит, что rig получает variant равный equipped weapon id и силуэт
  отличается от idle: Berserk (sword/axe/hammer + overhead slam силуэт),
  Soldier (rifle/grenade/bayonet), Thief (coin/shadow/smoke), Elementalist
  (orb/prism/meteor), Sniper (deadeye/spotter/shatter), + elite attack phase.
- **Прогон ×2 — оба зелёные**: `animation_smoke_test` + `runtime_smoke_test`.
  Блокер SCRUM-198 (ProgressionData facade / `progression_data_meta.gd` /
  `SHOP_ITEMS`) снят — финальная верификация прошла стабильно.

Acceptance:
- [x] Анимации уникальных атак для затронутых классов/оружий, тайминги фаз из
  конфигов оружия (источник истины — код).
- [x] animation + runtime smoke зелёные (×2) после снятия Back-end parse-блокера.
- [x] Риги не сломаны (silhouette-сдвиг проверяется, idle-сборка цела).

Краевые случаи:
- Gameplay-инвариант: variant — чисто анимационный, не трогает урон/таргетинг/VFX.
- Стабильность: 2 прохода после стабилизации дерева SCRUM-198.

Баги: нет.

## Dispatcher QA Status Correction (2026-06-13)

SCRUM-239 remains an active `0.1.4` QA row because Animator implementation and
Back-end unblock verification are already recorded above. It must not be
redispatched during the feature freeze unless QA/PM requests fixes, but it also
must not be returned to `0.1.5` backlog while awaiting QA. Dispatcher restored
task metadata to `Статус: done`, `Версия: 0.1.4` for Jira/board sync.
