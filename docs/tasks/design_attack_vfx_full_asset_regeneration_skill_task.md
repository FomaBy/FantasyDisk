# Задача Для Design/Codex: Полная Перегенерация Attack VFX Через Skill

Статус: done
Создано: 2026-06-14
Автор: Codex handoff из SCRUM-335
Исполнитель: Design / Codex
Версия: 0.1.5
Jira: SCRUM-337
QA: in_progress (2026-06-14)

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Blocker History — 2026-06-14
В текущем окружении отсутствует `OPENAI_API_KEY`, поэтому skill `fantasydisk-asset-generator` не может вызвать OpenAI Images API (`gpt-image-2`). Старые локальные генераторы `tools/generate_*vfx*.py` не использовать: пользовательская директива требует генерацию графики/ассетов только через skill.

## Blocker Resolved — 2026-06-14
Documentation dispatcher verified that local `OPENAI_API_KEY` can now be loaded
from the secure Codex env file outside the repository and Python `openai` imports
successfully. Previous asset-generator environment blocker is resolved; task is
eligible for Design/Codex execution after the currently active Design task.

## Контекст
Пользователь попросил переработать все эффекты атак персонажей и монстров реалистично и в стиле игры. SCRUM-335 закрыл runtime-покрытие существующими ассетами: `BerserkWeapon` теперь использует `vfx_weapon_*` signature layer, а enemy projectile получил textured trail/impact. Эта задача остается для полноценного нового art pass через Images API skill.

## Scope
- Сгенерировать новый cohesive reference/source pack через:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py \
  --prompt "<attack VFX pack prompt>" \
  --output "attack_vfx_realistic_dark_fantasy/<file>.png" \
  --size <WxH> \
  --quality high
```

- Покрыть минимум:
  - generic player VFX: slash, impact ring/flash, beam strip, sound wave, void orb, music note, dust puffs;
  - 51 `vfx_weapon_<weapon_id>.png` signature plates;
  - enemy projectile magic orb/trail/impact;
  - elite/boss hazard textures and helper VFX currently routed through `HazardVfx`;
  - persistent pools: poison/spark/briar.
- Все source/reference PNG сохранять в `docs/design/references/attack_vfx_realistic_dark_fantasy/`.
- Финальные runtime PNG переносить в `assets/sprites/effects/` и `assets/sprites/projectiles/` только после visual QA/crop/alpha cleanup.
- Сохранить прозрачный фон, читаемый combat-scale silhouette, no text/watermark, D&D + Dark Fantasy Dragon style.

## Acceptance Criteria
- [x] `OPENAI_API_KEY` доступен в окружении и generation script успешно создает reference PNG.
- [x] Новый pack просмотрен, очищен под alpha и нарезан/экспортирован в runtime paths.
- [x] Gameplay timing/damage/targeting не изменены.
- [x] `attack_vfx_smoke_test`, `hazard_vfx_smoke_test`, `enemy_projectile_smoke_test`, `runtime_smoke_test` проходят.
- [x] `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/visual_style_assets.md` и `CHANGELOG.md` обновлены.


## Ключ настроен — блокер снят (2026-06-14)
`OPENAI_API_KEY` фактически сохранён в `~/.codex/.env` (права 600, вне git) +
автозагрузка в `~/.zshrc` — доступен в окружении автоматически в каждом новом
shell (включая shell Codex-воркеров). Скилл `fantasydisk-asset-generator`
(gpt-image-2) готов к вызову. Блокер по отсутствию `OPENAI_API_KEY` снят
окончательно; задача готова к исполнению через скилл.

## Blocked Again — 2026-06-14
Design queue audit after SCRUM-352 confirmed this task still requires full
attack VFX regeneration through `fantasydisk-asset-generator` / OpenAI Images
(`gpt-image-2`) and disallows old/local/random generators. The current approved
env source is available, but OpenAI Images returns:

```text
billing_hard_limit_reached
```

Task is blocked until OpenAI image generation billing is available again or PM
provides an approved alternative generation source.

## Разблокировано 2026-06-14 (PM)
Биллинг OpenAI восстановлен и ПРОВЕРЕН: тестовая генерация gpt-image-2 успешна. Блок `billing_hard_limit_reached` устарел — снят. Можно генерить скиллом.

## Progress Log

- 2026-06-14 — Started Design/Codex execution after SCRUM-338 closure. Current
  live inventory is 83 `assets/sprites/effects/*.png` plus 2 projectile PNGs.
  Scope is asset/reference generation, alpha cleanup, previews, docs and smoke
  checks only; gameplay timings, damage, targeting and runtime scripts remain
  Back-end-owned.
- 2026-06-14 — Generated six `gpt-image-2` source sheets via
  `fantasydisk-asset-generator` under
  `docs/design/references/attack_vfx_realistic_dark_fantasy/`; cut and
  alpha-cleaned 85 runtime PNGs (83 effects + 2 projectiles) with stable names
  and sizes using `tools/build_scrum337_attack_vfx_from_sources.py`.
- 2026-06-14 — Visual QA/contact sheets ready:
  `docs/design/previews/scrum337_attack_vfx_core_contact.png`,
  `docs/design/previews/scrum337_attack_vfx_weapon_contact.png`, plus field
  readability previews in `build/qa/scrum337/`. PNG validation: 85/85 RGBA,
  transparent pixels present, no fully transparent files, 51/51 weapon plates.

## Result Summary — 2026-06-14

Design/Codex scope complete and ready for QA. SCRUM-337 replaced the full live
attack VFX/projectile art pack in place:

- `assets/sprites/effects/*.png` — 83 files regenerated/alpha-cleaned.
- `assets/sprites/projectiles/*.png` — 2 projectile sprites regenerated.
- Runtime paths, filenames and canvas sizes are preserved.
- Source sheets/manifest:
  `docs/design/references/attack_vfx_realistic_dark_fantasy/`.
- Previews:
  `docs/design/previews/scrum337_attack_vfx_core_contact.png`,
  `docs/design/previews/scrum337_attack_vfx_weapon_contact.png`.
- QA manifests/readability previews:
  `build/qa/scrum337/vfx_manifest_before.json`,
  `build/qa/scrum337/vfx_manifest_after.json`,
  `build/qa/scrum337/field_meadow_readability.png`,
  `build/qa/scrum337/field_marsh_readability.png`.

Verification:

- Godot import: PASS (existing tracked SCRUM-337 backup folder still produces
  duplicate UID warnings during import; no runtime test failure).
- `tests/attack_vfx_smoke_test.gd`: PASS.
- `tests/hazard_vfx_smoke_test.gd`: PASS.
- `tests/enemy_projectile_smoke_test.gd`: PASS.
- `tests/unique_weapon_vfx_assets_test.gd`: PASS (51 plates).
- `tests/runtime_smoke_test.gd`: PASS.

No gameplay timing, damage, targeting, formulas, mechanics, node names or
Back-end runtime logic were changed.

## QA-Вердикт (2026-06-14)
Статус: PASSED — полная перегенерация attack VFX скиллом, in-place, gameplay не тронут

Проверено (фактически):
- **Счётчики**: `assets/sprites/effects/*.png` = **83**, `assets/sprites/projectiles/*.png`
  = **2** (итого 85), из них `vfx_weapon_*` signature-плашек = **51**. Пути/имена/
  размеры сохранены (in-place замена).
- **PNG-валидация 85/85**: все RGBA, у всех есть прозрачные пиксели И непустой
  предмет — `fully_transparent=0`, `no_transparent_pixel=0`.
- **Визуал** `scrum337_attack_vfx_core_contact.png`: generic-VFX (slash/impact-ring/
  beam/sound-wave/void-orb/note/dust/poison/spark/briar/projectile-orb+trail) —
  единый realistic D&D Dark Fantasy стиль, прозрачный фон, читаемый combat-силуэт.
  `scrum337_attack_vfx_weapon_contact.png`: 51 уникальная weapon-плашка, тот же стиль.
- **Тесты**: `attack_vfx_smoke_test`, `hazard_vfx_smoke_test`,
  `enemy_projectile_smoke_test`, `unique_weapon_vfx_assets_test` (51 plates),
  `animation_smoke_test`, `runtime_smoke_test` — **все passed**.
- **Gameplay не тронут**: Design-scope asset-only, runtime-скрипты/тайминги/урон/
  таргетинг без изменений.

Acceptance:
- [x] Reference PNG созданы скиллом (6 source-листов), pack нарезан/alpha-clean в runtime paths.
- [x] Gameplay timing/damage/targeting не изменены.
- [x] attack_vfx + hazard_vfx + enemy_projectile + runtime smoke (+unique_weapon 51, +animation) PASS.
- [x] content_registry/current_game_state/visual_style_assets/CHANGELOG обновлены.

⚠️ **Не блокер (housekeeping)**: импорт даёт 85 `UID duplicate` WARNING — tracked
backup-папки `docs/design/backups/{attack_vfx_pre_scrum337,artifact_icons_pre_scrum340,
hero_select_frames_pre_dragon,summon_noglow}` содержат `.import` sidecars с теми же
UID, что у живых ассетов. Тесты зелёные, на deliverable не влияет, но латентный риск
mis-resolve UID. Заведён отдельный bug-таск на чистку backup `.import`.

Статус done. Баги по самой задаче: нет (UID-warning — общая backup-гигиена, отдельным таском).
