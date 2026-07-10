# Задача Для Back-end-Агента: Settings / Game — four-tab runtime integration

Статус: blocked
Контур: Codex
Owner: unassigned
Thread: n/a
Locked paths: Settings-only hunks in `scripts/ui_screens.gd`; new focused Settings/Game UI tests; Settings paragraphs in `docs/design/systems/menus_ui.md` and `docs/design/current_game_state.md`; optional promoted `assets/sprites/ui/frames/settings_v6/ui_settings_v6_icon_game.png`
Jira: SCRUM-1025
Sprint / fixVersion: `Спринт 0.2.1` / `0.2.1`
Blocked by: SCRUM-976 (sandbox persistence/run-modifier API) and SCRUM-975 (design QA-ready package)
Source design: `docs/design/references/scrum975_settings_game_tab/spec.md`

## Autonomy / Approval

The user pre-approved all in-scope repository work. After the Jira `blocked`
label is removed and the issue is officially claimed, Back-end may pull/rebase,
edit only the listed runtime paths, run tests, update docs, commit and push
without routine confirmation. Do not start while SCRUM-976 or the SCRUM-975
design gate remains unresolved.

## Контекст

SCRUM-975 delivers a PixelLab/UI Director design package for a fourth Settings
tab, `Игра`. Live Settings v6 uses a fullscreen Atlas-family shell with three
independent global-kit plates. Do not stretch the historical three-slot bitmap
or place a fourth hit area on its ornament.

## Что Уже Сделано

- PixelLab source and provenance manifest for one-row 1080p/2K and 2×2 720p
  layouts.
- Exact safe zones, responsive rules, content inventory, node names and
  interaction states in `spec.md`, `ui_plan*.json` and `layout*.json`.
- Render/fit/debug evidence at 1280×720, 1920×1080 and 2560×1440.
- Design candidate Game icon:
  `docs/design/references/scrum975_settings_game_tab/ui_settings_game_tab_icon_44.png`.

## Что Нужно От Back-end

Integrate the visual/control contract after SCRUM-976 exposes a single
authoritative sandbox settings API. UI code must consume that layer rather than
duplicate values or combat rules in `ui_screens.gd`.

Expected API surface (exact names may follow SCRUM-976, semantics may not):

- snapshot/get all five clamped multipliers;
- set one multiplier and persist it;
- atomically reset all five to neutral;
- query neutral/custom state;
- preserve next-run snapshot semantics so editing Settings does not mutate the
  already-running run.

## Data/control contract

| UI key | Range | Step | Neutral | Runtime node suffix |
| --- | ---: | ---: | ---: | --- |
| `sandbox_monster_hp_multiplier` | 0.5–3.0 | 0.1 | 1.0 | `monster_hp` |
| `sandbox_monster_damage_multiplier` | 0.5–3.0 | 0.1 | 1.0 | `monster_damage` |
| `sandbox_player_damage_multiplier` | 0.5–2.0 | 0.1 | 1.0 | `player_damage` |
| `sandbox_player_attack_speed_multiplier` | 0.5–2.0 | 0.1 | 1.0 | `player_attack_speed` |
| `sandbox_monster_attack_speed_multiplier` | 0.5–3.0 | 0.1 | 1.0 | `monster_attack_speed` |

Backend remains authoritative for clamping. If the implementation must narrow a
range, update the source spec/docs with a reason before changing UI geometry.

Required nodes:

- `SettingsTabButton_3` / `Игра` and the fourth `SettingsTabs` child;
- `SettingsGameScroll`, `SettingsGameStatus`, `SettingsSandboxWarning`;
- `SettingsSandboxSlider_<suffix>` and `SettingsSandboxValue_<suffix>` ×5;
- `SettingsResetGameButton`, disabled when all values are neutral.

Display values as `%.1f×`. Neutral status: `Обычный режим · 1.0×`; custom
status: `Песочница активна`. Changes persist immediately and apply to the next
run. Non-neutral state must clearly warn that normal progression, achievements
and release-balance evidence are disabled, matching SCRUM-976 policy.

## Responsive contract

- 2560×1440: four 260×104 plates, one row, 24px gaps; all five rows + reset.
- 1920×1080: four 260×88 plates, one row, 24px gaps; all five rows + reset.
- 1280×720: centered 2×2 grid of 260×72 plates, 24×12 gaps; internal Game
  `ScrollContainer` with 14px lane and `follow_focus=true`.

Hitboxes equal plate rects. Runtime labels/icons/focus rings stay inside plate
interiors. No content may touch frame borders, dragon heads, gems, bevels or
separators.

## Acceptance Criteria

- [ ] Existing Screen/Sound/Controls behavior does not regress.
- [ ] Mouse/keyboard/gamepad navigation reaches all four tabs; LB/RB order
      includes Game.
- [ ] Five values load, change, persist, reset and update neutral/custom status
      through the SCRUM-976 service.
- [ ] Editing Settings never changes an already-running run snapshot.
- [ ] 1280×720, 1920×1080, 2560×1440 pass no-overlap/frame-safe checks.
- [ ] Focused Settings/Game tests plus `runtime_smoke_ui_test.gd`,
      `ui_no_overlap_matrix_test.gd`, `gamepad_menu_focus_test.gd`,
      `gamepad_full_flow_smoke_test.gd` and full runtime smoke pass.
- [ ] SCRUM-977 remains blocked until this issue and SCRUM-976 both reach
      `Контроль качества` with commits/tests.

## Документация

Update the live runtime state in `docs/design/systems/menus_ui.md` and
`docs/design/current_game_state.md`. Do not rewrite the PixelLab design package;
record only implementation deviations and exact runtime paths/tests.
