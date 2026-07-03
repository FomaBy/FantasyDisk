# BUG: SCRUM-855 Doctor still receives external regeneration/vampirism rewards

Статус: done
Приоритет: high
Роль: Back-end
Версия: 0.2.1
Контур: Codex
Исполнитель: Codex
Jira: SCRUM-862
Найдено QA при тестировании: SCRUM-855
Связано: SCRUM-855

## Воспроизведение

1. Check SCRUM-855 acceptance: Doctor should no longer see external
   regeneration/vampirism rewards in level-up/shop reward pool, while Doctor
   weapon sustain still works.
2. Inspect reward relevance and the Doctor reward pool on `origin/dev`.
3. Verify whether `regeneration_up`, `vampiric_amount_up`, and
   `vampiric_chance_up` can still appear for Doctor.

## Ожидание / Реальность

Expected:
- Doctor sustain identity comes from Doctor weapons (`restore_potion`,
  `plague_syringe`, `bone_saw`) and personal drain caps.
- External regeneration/vampirism level-up/shop rewards are excluded from
  Doctor's reward pool per SCRUM-855.

Actual:
- `ProgressionData.is_reward_relevant()` currently returns `true` for every
  reward and character.
- `ProgressionData.level_up_rewards("doctor")` only filters through
  `is_reward_relevant()`, so external sustain rewards remain eligible.
- `ATTRIBUTE_RELEVANCE` still marks Doctor as primary for `regeneration`,
  `vampiric_amount`, and `vampiric_chance`, reinforcing their availability.
- Doctor weapon sustain itself is capped and passes `doctor_drain_softcap_test.gd`,
  but the reward-pool exclusion acceptance is not met.

## Окружение

- QA source: Jira SCRUM-855 acceptance criteria.
- Verified on `origin/dev` after fast-forward to `7a74c850`.
- Positive focused test: `tests/doctor_drain_softcap_test.gd` PASS.
- Relevant paths:
  - `scripts/progression_data.gd`
  - `scripts/progression_data_content.gd`
  - `scripts/progression_data_characters.gd`
  - `tests/doctor_drain_softcap_test.gd`

## Suggested Fix

- Add a Doctor-specific reward exclusion for external sustain rewards while
  preserving weapon-owned drain sustain.
- Add a focused reward-pool regression test asserting that Doctor cannot roll
  `regeneration_up`, `vampiric_amount_up`, `vampiric_chance_up`, or matching
  shop/artifact sustain entries if those are in scope.

## Результат

- Исправлено в рамках backend land для `SCRUM-854`: Doctor external sustain
  rewards filtered from level-up/shop/artifact/start-boon paths while Doctor
  weapon-owned sustain remains allowed.
- Fix commit: `c6634fac`; verified as ancestor of tested `origin/dev`.

## QA-Вердикт 2026-07-04
Статус: PASSED
Commit tested: `1924f6e3e8c404dfbba8e0fda0af4a829aa1d15e`.

Проверки через `tools/godot_gate.py`:
- `tests/doctor_drain_softcap_test.gd` — PASS.
- `tests/attribute_relevance_test.gd` — PASS.
- `tests/start_boons_test.gd` — PASS.
- `tests/runtime_smoke_test.gd` — PASS; known non-blocking `_apply_dot_tick` CallbackTweener stderr only.

Focused check: Doctor reward pools exclude `regeneration_up`, `vampiric_amount_up`,
`vampiric_chance_up`, and external sustain shop/artifact/start-boon rewards;
Doctor weapon sustain via `restore_potion` / `plague_syringe` remains allowed.

Disk cleanup: QA removed `/private/tmp/fantasydisk-scrum862-qa-40e0a657`.
