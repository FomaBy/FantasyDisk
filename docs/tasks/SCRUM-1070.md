# SCRUM-1070 — Atlas reset footer 420 px

Статус: done
Версия: 0.2.1  
Jira: SCRUM-1070  
Контур: Codex  
Owner: Back-end UI / Codex  
Thread: `/root/audit_new_sprint_tail/review_scrum1067_spec`  
Branch: `codex/scrum1070-atlas-respec-420`  
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1070-atlas-respec-420`

## Locked scope

- Atlas reset/footer-only hunk in `scripts/ui_screens.gd`;
- focused `tests/atlas_scrum1070_respec_button_test.gd`;
- `docs/design/mockups/scrum1070_atlas_respec_420/`;
- `docs/design/systems/meta_constellations.md` and
  `docs/design/current_game_state.md`;
- this mirror and scoped Jira sync metadata.

Excluded: constellation/Guild topology, schema, balance and currencies
(SCRUM-1068/1069), reset business logic, other screens and new art/assets.

## UI Director source decision

The accepted existing SCRUM-832 OpenAI
`docs/design/previews/meta40_atlas_mockup.png` already shows the wide left
footer reset plate. Runtime reuses the accepted OpenAI per-size
`text/standard_420x104` five-state asset package and its 9-slice/content-margin
contract. PixelLab redraw exception: `existing source reuse`; no new art or
fallback generation is part of this geometry-only task.

## Acceptance

- exact 420×72/88/104 visible/hit geometry on seven target sizes through 4K
  plus same-instance compact→large→compact live resize;
- both Russian labels fit one line inside content margins;
- explicit `text/standard_420x104` family in all states;
- footer/button/legend stay inside the empty Atlas frame content zone;
- tooltip, mouse/gamepad focus, popup cancel/confirm and per-scope full refund
  stay unchanged;
- focused Atlas, Metal/family, semantic, gamepad, no-overlap and runtime gates
  pass before landing.

## Result

- `AtlasRespecButton` uses the exact accepted `standard_420x104` family at
  420×72/88/104, with 21px compact and 23px medium/large action typography.
- Same-instance live resize refreshes the button, `AtlasSafeArea` margins and
  outer `AtlasFrame` 9-slice margins across both tier thresholds.
- Both labels, tooltip/focus, confirmation and scope-specific full refunds are
  preserved; constellation/Guild data and reset business logic are unchanged.
- Independent subagent re-review: PASS, no remaining findings.

## Verification

Post-integration base: `origin/dev` `e5c8d32a8`.

- `tests/atlas_scrum1070_respec_button_test.gd` — PASS (seven tiers through
  3840×2160, same-instance 648→900→2160→720, both reset scopes);
- `tests/meta40_atlas_screen_smoke_test.gd` — PASS;
- `tests/atlas_scrum970_clickability_test.gd` — PASS;
- `tests/semantic_typography_scrum1061_test.gd` — PASS;
- `tests/scrum1051_ui_button_family_test.gd` — PASS;
- `tests/dark_fantasy_ui_theme_test.gd` — PASS;
- `tests/gamepad_menu_focus_test.gd` — PASS;
- `tests/ui_no_overlap_matrix_test.gd` — PASS;
- `tests/runtime_smoke_ui_test.gd` — PASS;
- `tests/runtime_smoke_test.gd` — PASS (known non-fatal dummy-renderer texture
  capture warning only).

Disk cleanup: `.godot`, isolated `/tmp/fsd-scrum1070-*` user-data roots and
generated unrelated UID sidecars removed; task worktree removed after push.

## QA-Вердикт: FAILED

Independent QA на свежем `origin/dev` `0b17c754a` подтвердила всю продуктовую
часть: focused exact `420×72/88/104` на семи размерах и same-instance live
resize, обе reset scope, semantic inventory, Meta40, pointer clickability,
button family/theme, gamepad focus, no-overlap, runtime UI и полный runtime —
PASS. Existing-source provenance, five-state `standard_420x104`, margins,
`21/23 px` typography и отсутствие schema/balance/currency drift также PASS.

Блокирует только обязательный windowed QA lifecycle gate. Два запуска focused
теста на macOS Metal функционально прошли, но оба оставили `4 ObjectDB`
instances и `2` Ogg resources. `--verbose` указал
`music_menu_tavern_warm.ogg`: `OggPacketSequence`, `AudioStreamOggVorbis` и
playback-объекты. Новый fixture освобождает viewport одним `queue_free()` и
одним кадром, не применяя child-first/WeakRef/`AudioManager.stop_music()`
контракт из SCRUM-1031 и `docs/process/qa_protocol.md`.

Bug/handoff: SCRUM-1074. До его исправления и чистой Metal-серии SCRUM-1070
остаётся в Jira «Контроль качества», а не «Готово».

## QA-Повторный вердикт: FAILED

На свежем `origin/dev` `d7548ba8d` продуктовая часть повторно подтверждена:
focused headless, exact `420x72/88/104`, live resize, обе области сброса,
Meta40, pointer clickability, button family/theme, gamepad focus, no-overlap,
runtime UI и full runtime — PASS. Static diff/provenance audit также PASS:
единственный production-файл коммита `c0c0a6d82` — `scripts/ui_screens.gd`,
existing-source reuse правдив, art/schema/balance drift отсутствует.

Связанный обязательный SCRUM-1074 Metal-gate остаётся красным: независимая
серия дала `4/5`, один запуск завершился `exit 1` на нестабильном сравнении
глобального `Performance.OBJECT_COUNT 1905 -> 1906`, хотя owned `WeakRef` и
внешние exit-leak/resources/Ogg diagnostics были чистыми. Поэтому SCRUM-1070
остаётся в Jira `Контроль качества`, а SCRUM-1074 возвращён в `К выполнению`.

Integration note: semantic typography inventory на текущем общем tip устарел
только по двум line-number полям после шестистрочной вставки SCRUM-1069 в
`scripts/player.gd`; fingerprint/counts/content не изменились и это не drift
продуктового diff SCRUM-1070.

Disk cleanup: disposable combined QA worktree/cache and isolated
`/tmp/fsd-qa-1074-1070-*` roots are removed after evidence push.

## Independent corrective re-QA: BLOCKED

Fresh `origin/dev` `6819a2a8c` preserves the previously accepted SCRUM-1070
product diff/provenance. The linked corrective oracle in SCRUM-1074 passes its
pure contract, focused headless gate and five isolated Metal lifecycle runs.
However, the focused test itself can write `user://fantasydisk_meta.cfg` because
it executes both reset confirmations without a fail-closed scratch user-data
guard; the task's reproduction command also omits the isolation it claims.

This is a test-safety blocker, not a new product UI finding. SCRUM-1070 remains
in Jira `Контроль качества` until SCRUM-1074 adds the guard, proves refusal on
default `user://`, and receives a clean independent rerun. No SCRUM-1070
product code, assets, schema, balance or runtime behavior changed during QA.
