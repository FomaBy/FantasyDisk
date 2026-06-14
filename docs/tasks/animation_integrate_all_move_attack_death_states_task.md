# ANIM: Внедрить анимации всех монстров и персонажей — move/attack/death (full-frame)

Статус: blocked
Приоритет: high
Роль: Animator (Codex) → Back-end (анимации)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-370
Связано: SCRUM-351 (full-frame registry), SCRUM-352 (элитки/боссы), SCRUM-353 (призывы),
SCRUM-298 + 282-297 (перерисовка персонажей)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Progress Log
- 2026-06-14 — Animator (Codex) took SCRUM-370 after completing SCRUM-376/SCRUM-377
  batch integrations. First pass is limited to Animator-owned coverage audit,
  SpriteFrames/registry verification, and precise Design/Back-end handoffs for
  missing death rows or runtime death playback.
- 2026-06-14 — Animator coverage audit completed:
  `build/qa/animation_integrate_all_move_attack_death_states/coverage.md`.
  Existing standard enemy full-frame SpriteFrames cover `move`, `attack_primary`,
  and explicit `death`. Current allies, route elites, mini-elites, and bosses
  cover `move` + attack/skill rows but do not include explicit full-frame
  `death` rows. Runtime death lifecycle still calls `spawn_death_ghost()` and
  needs Back-end ownership to play `FullFrameBody` death before cleanup/removal.
  SCRUM-370 is blocked on the handoffs below.
- 2026-06-14 — Documentation dispatcher re-dispatched SCRUM-370 to Animator after
  the user explicitly unblocked animation work in parallel with the remaining
  death-row Design handoff. Back-end runtime death playback SCRUM-379 is done;
  Design death rows SCRUM-380 remains parallel `in_progress`, so Animator should
  proceed with available move/attack/death integration, validation, and precise
  partial blockers instead of waiting on the whole umbrella.
- 2026-06-14 — Animator partial integration completed for all currently
  available SCRUM-380 death-row inputs: `druid_beast`, `druid_pack_spirit`,
  `homunculus`, `leadership_echo`, route elites `iron_bastion`, `night_stalker`,
  `plague_prophet`, `shard_marshal`, all six mini-elites
  (`mini_scavenger_reaper`, `mini_plague_bellringer`, `mini_bone_warden`,
  `mini_spark_wight`, `mini_rot_hound`, `mini_shadow_devourer`) and bosses
  `rift_warden`, `disk_devourer`.
  Added transparent `death` frame PNGs, rebuilt the existing SpriteFrames paths,
  refreshed smoke assertions and QA artifacts:
  `build/qa/animation_integrate_all_move_attack_death_states/animation_manifest.json`,
  `scrum370_partial_death_rows_contact.png`, and per-entity GIFs.
  `fantasydisk-animation-director` manifest validator PASS and
  `tests/animation_smoke_test.gd` PASS.
- 2026-06-14 — Superseded blocker after partial integration: SCRUM-380 previously
  still needed production full-frame death rows for bosses `bone_archon`,
  `brood_mother`, and `ashen_colossus`. This art blocker is now resolved by
  SCRUM-380; runtime smoke at that moment also failed outside Animator scope in
  `runtime_smoke_test.gd` `_test_victory_flow` because the victory screen text
  did not include `Победа`.
- 2026-06-14 — Heartbeat check found SCRUM-380 now has the remaining boss death
  row inputs: `bone_archon`, `brood_mother`, and `ashen_colossus`. Animator
  resumed SCRUM-370 to integrate those rows into the existing boss SpriteFrames.
- 2026-06-14 — Animator integration completed for all 19 SCRUM-380 death-row
  inputs. Added/rebuilt 6-frame non-loop `death` coverage for all four allies,
  four route elites, all six mini-elites, and all five bosses including
  `bone_archon`, `brood_mother`, and `ashen_colossus`; rebuilt existing
  SpriteFrames paths, refreshed `tests/animation_smoke_test.gd` boss assertions,
  and regenerated QA artifacts:
  `build/qa/animation_integrate_all_move_attack_death_states/animation_manifest.json`,
  `scrum370_death_rows_contact.png`, compatibility
  `scrum370_partial_death_rows_contact.png`, and per-entity GIFs.
  Animator-owned validation is green; final SCRUM-370 status remains blocked only
  by external runtime smoke failure in victory UI text collection.

## Handoffs / Blockers
- Design handoff: `design_full_frame_death_rows_allies_elites_bosses_task.md`
  / SCRUM-380 —
  add 5+ frame transparent full-frame `death` rows/source frames for allies,
  route elites, mini-elites, and bosses that already have move/attack/skill rows.
  Design SCRUM-380 now provides all required source rows, including
  `bone_archon`, `brood_mother`, and `ashen_colossus`; Animator SCRUM-370 has
  consumed all 19 source rows into SpriteFrames.
- Back-end handoff: `backend_full_frame_death_playback_lifecycle_task.md`
  / SCRUM-379 —
  route enemy/player/ally death lifecycle through `FullFrameAnimationRegistry`
  `death` playback when explicit death frames exist, preserving death ghost as
  fallback and preserving loot/score/cleanup behavior.
  Status: done.
- Back-end bug handoff: `bug_victory_flow_runtime_smoke_text_missing_task.md` —
  runtime smoke `_test_victory_flow` currently fails outside Animator scope
  because collected victory screen text does not include `Победа`. This blocks
  final SCRUM-370 runtime verification only; manifest validation, import, and
  animation smoke are green.

## Verification
- PASS: `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_integrate_all_move_attack_death_states/animation_manifest.json`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --editor --quit`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --script res://tests/animation_smoke_test.gd`
- BLOCKED/EXTERNAL: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\\ Agent --script res://tests/runtime_smoke_test.gd`
  fails in `_test_victory_flow`: expected victory screen text to include
  `Победа`.

## Контекст (запрос пользователя)
«Надо внедрить анимацию всех монстров и персонажей, что нарисовано, в игру. Очень
красиво выглядит анимация монстров. Надо добавить анимацию смерти, атаки, движения».

Текущее состояние:
- Система: `FullFrameAnimationRegistry` (scripts/full_frame_animation_registry.gd) —
  состояния idle/move/walk/run/attack/cast/shoot/hit/**death** с fallback-цепочками
  (death:130-140). Враги (enemy.gd:972-1051 configure_entity_visual/play_state),
  allies (move/attack), элитки — full-frame листы (night_stalker/plague_prophet/
  iron_bastion и т.д.).
- ПРОБЛЕМА: смерть сейчас = `spawn_death_ghost()` (риг-призрак, enemy.gd:233/
  player.gd:483), а НЕ нарисованная анимация death. Многие обычные враги
  (enemy_melee/ranged/small_biter/suicide_runner/bone_shaman/bruiser_slow/
  venom_spitter/summoner/rift_shieldbearer) статичны (нет full-frame листов).

## ОБЯЗАТЕЛЬНО — скиллы
Анимации — `fantasydisk-animation-director` (SpriteFrames/манифест/контакт/GIF,
валидатор, animation_smoke). Исходный арт/листы — `fantasydisk-asset-generator`
(если нужны новые кадры). Full-frame, без cutout-фейка.

## Требования
1. **move/attack/death для ВСЕХ** играбельных персонажей и монстров (обычные враги,
   элитки, боссы, призывы) — каждый имеет:
   - `move`/`walk` (loop, 5+ кадров),
   - `attack`/`attack_primary` (no-loop, 5+; у элиток/боссов — по skill-паттернам),
   - **`death`** (no-loop, 5+; проигрывается при гибели ДО удаления сущности).
2. **Анимация смерти в рантайме**: при гибели врага/игрока проигрывать full-frame
   `death` (через play_state "death"), затем удалять; согласовать/заменить
   `spawn_death_ghost` там, где есть нарисованная death (ghost оставить fallback'ом
   для тех, у кого death-листа ещё нет). Не ломать лут/очки/cleanup-таймеры.
3. **Анимировать статичных обычных врагов**: сгенерировать/нарезать full-frame
   листы (move/attack/death) и подключить через configure_entity_visual; пока листа
   нет — безопасный fallback на статичный кадр (без краша).
4. Зарегистрировать все листы в registry (entity_kind/entity_id → SpriteFrames),
   единый pivot/масштаб, flip по направлению; элитки/боссы 512², обычные 256/384,
   герои 384².
5. Координация: не дублировать с 282-298 (персонажи), 352 (элитки/боссы), 353
   (призывы) — эта задача ДОВОДИТ интеграцию и добавляет **death** везде + следит,
   что всё реально проигрывается в игре.
6. Тест: animation_smoke + runtime_smoke зелёные; для каждого entity_kind/id —
   move/attack/death существуют и проигрываются (или безопасный fallback); смерть
   проигрывает анимацию перед удалением. Контакт-листы/GIF в build/qa/.
7. CHANGELOG; docs/design/systems/animation.md; content_registry; current_game_state.

## Files / Assets / IDs
- scripts/full_frame_animation_registry.gd (состояния/fallback; регистрация листов)
- scripts/enemy.gd (configure_entity_visual 974; play_state; смерть 230-234)
- scripts/player.gd (death 473-484; rig/death_ghost)
- scripts/ally_minion.gd (move/attack 85-217; + death)
- assets/sprites/{enemies,elites,characters,allies}/ (full-frame листы) + бэкап
- tests/animation_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] У всех уже подключенных full-frame стандартных врагов, призывов, route elites, mini-elites и боссов есть move + attack + death; SCRUM-370 добавил missing death rows for allies/elites/mini-elites/bosses.
- [x] Смерть проигрывает нарисованную death-анимацию перед удалением (ghost — fallback); runtime lifecycle реализован SCRUM-379.
- [x] Статичные обычные враги из current registry covered by SCRUM-363..368 or safe fallback; всё зарегистрировано и проигрывается в игре.
- [ ] animation_smoke + runtime_smoke зелёные; контакт-листы/GIF; CHANGELOG + animation.md.

## Документация
docs/design/systems/animation.md, content_registry, current_game_state.

## Разблокировано 2026-06-14 (PM)
Биллинг OpenAI восстановлен и ПРОВЕРЕН: тестовая генерация gpt-image-2 успешна. Блок `billing_hard_limit_reached` устарел — снят. Можно генерить скиллом.

## Разблокировано пользователем 2026-06-14
Пользователь: анимационные задачи персонажей готовы к выполнению — снять блок. Хэндоффы (death-арт/death-плейбек) делать параллельно, не блокировать зонтичную интеграцию.
