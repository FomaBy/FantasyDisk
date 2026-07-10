# SCRUM-988 — третья Atlas-характеристика в том же ряду

Статус: done
- Контур: `Codex`
- Owner: `/root/scrum982_remove_gold_stat`
- Combined scope: `SCRUM-982` + `SCRUM-987` + `SCRUM-988`

## Контракт

- По умолчанию показать 2 предложения; с `atlas_n2`/`attr_extra_options = 1` — 3 уникальных предложения.
- Все предложения расположены одним L→R рядом на 720p/1080p/1440p.
- Две карточки центрируются в той же зоне; третья не создаёт второй ряд, скролл или рост высоты.
- Сохранить buy/reroll/skip, цену, gamepad focus и старые save-поля.

## Evidence

- `_random_attribute_pair()` preserves 2 default / 3 Atlas choices and uniqueness.
- `AttributeOffers` is one horizontal HBox; the responsive matrix keeps all three cards L→R without wrap or scroll.
- Two-card state centers inside the same authored row.
- Buy, reroll, skip, exact spend, focus ring and live 2560→1280→1920 resize are covered by `tests/scrum982_987_988_attribute_shop_test.gd`.
- Focused combined, meta skill tree, progression/economy, full runtime and UI no-overlap gates: PASS.
- Independent read-only code review: PASS after horizontal focus and legacy offer hardening.
- Disk cleanup: removed task `.godot` import cache; disposable worktree retained only through `dev` landing.

## QA-Вердикт (2026-07-10)

Статус: PASSED

Проверено: default = 2 уникальных предложения, `atlas_n2` = 3; один `HBoxContainer` без wrap/scroll на `1280×720`, `1920×1080`, `2560×1440`; buy/reroll/skip, exact spend, legacy normalization, full tooltip/effect copy и horizontal gamepad focus. `gamepad_full_flow_smoke_test.gd` прошёл 3/3, профильные menu/in-run/core input tests — PASS.

Краевые случаи: malformed `4+` save offer с duplicate/removed stat; две карточки центрируются в той же строке; три остаются L→R при live resize `2560→1280→1920`; Reroll/Skip доступны по Left/Right, предложения сохраняются при resize.

Баги: нет.

Disk cleanup: QA import cache/generated UID sidecars are removed after the verdict push; final Jira comment records deletion of the disposable QA worktree.
