# Design Task: Secret Ascension Boss Source Pack

Status: done
Contour: Codex
Owner: Design / Codex
Thread: SCRUM-539 worktree delivery
Locked paths: docs/design/references/bosses/secret_ascension_boss/, assets/sprites/bosses/secret_ascension_boss*, assets/sprites/effects/secret_ascension_boss_*_telegraph.png, docs/design/previews/scrum539_secret_ascension_boss_*.png
Jira: SCRUM-539
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

## Result

SCRUM-539 source pack is delivered. The package uses D&D + Dark Fantasy Dragon
direction, transparent PNGs, no baked text, and a large readable top-down
three-quarter boss silhouette.

Delivered files:

- Source/reference pack: `docs/design/references/bosses/secret_ascension_boss/`
- Runtime boss candidate: `assets/sprites/bosses/secret_ascension_boss.png`
- Runtime telegraph candidates:
  - `assets/sprites/effects/secret_ascension_boss_ring_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_cone_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_beam_telegraph.png`
  - `assets/sprites/effects/secret_ascension_boss_rupture_telegraph.png`
- Evidence previews:
  - `docs/design/previews/scrum539_secret_ascension_boss_contact.png`
  - `docs/design/previews/scrum539_secret_ascension_boss_scale_preview.png`
- Source report: `docs/design/references/bosses/secret_ascension_boss/secret_ascension_boss_source_pack_report.json`

## Handoff

Animator: prefer a full-frame boss spritesheet path. Use `1024x1024` source,
recommended pivot `(512, 960)`, alpha bbox `[180, 42, 843, 984]`, visual radius
about `390px`, and keep the halo disk/claws within a stable frame envelope.

Back-end: static-plus-VFX is acceptable only as an interim. Use the delivered
telegraph candidates for ring, cone, beam, and rupture warning overlays; keep
hits delayed/fair and avoid fallback primitive circles where these assets fit.

## Verification

- PNG metadata verified with Pillow: runtime/source candidates are RGBA with
  transparent alpha.
- Contact and scale previews regenerated without baked text.
- No Godot smoke required: design asset/docs handoff only; no scripts, scenes,
  SpriteFrames, AnimationPlayer, combat logic, or balance changed.

## QA Verdict - 2026-06-28

Status: QA PASSED by `anim-loop-1` fallback QA.

Read-only verification on current `origin/dev`:

- Required runtime candidate exists: `assets/sprites/bosses/secret_ascension_boss.png`.
- Required telegraph candidates exist: ring, cone, beam, rupture under `assets/sprites/effects/`.
- Checked boss + 4 telegraph PNGs with Pillow: all RGBA, alpha extrema include `0` and `255`, and `edge_alpha_pixels = 0`.
- Boss candidate is `1024x1024`; alpha bbox `[180, 42, 843, 984]` matches `secret_ascension_boss_source_pack_report.json`.
- Contact preview `docs/design/previews/scrum539_secret_ascension_boss_contact.png` is readable and contains the boss plus all four VFX candidates.
- No script/scene/runtime logic changed by this QA pass.

## QA-Вердикт: PASSED

Статус: PASSED
Проверил: claude-qa (drift-repair), 2026-07-02, read-only на origin/dev 8d091d5e.
Причина правки .md: тикет с уже зафиксированным QA PASSED (см. историю комментов Jira + PM sprint audit) дрейфовал обратно в «Контроль качества». Корень — board_sync (tools/jira_board_sync.py:222-226): при «Статус: done» без секции «## QA-Вердикт» со строкой «Статус: PASSED» статус пересчитывается как done → «Контроль качества». Добавлен канонический блок, чтобы board_sync стабильно мапил тикет в «Готово».
Верификация: deliverables на origin/dev — assets/sprites/bosses/secret_ascension_boss.png + 4 telegraph PNG (ring/cone/beam/rupture) + source_pack_report.json. Design/asset-only, смоук не требуется (уже подтверждено anim-loop-1 QA PASSED 2026-06-28).
