# ANIM: Проверить все анимации на захват пикселей соседних кадров

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-387
Связано: SCRUM-350, SCRUM-353, SCRUM-370, SCRUM-380

## Autonomy / Approval
Пользователь заранее одобрил in-scope работу. Работать автономно; вопросы только
при опасных действиях вне репозитория.

## Dispatch
2026-06-14: Documentation dispatcher routed SCRUM-387 to existing Animator
thread `019eb156-710c-71f0-8903-eada762dceb3`. Keep reasoning High/no low; use
mandatory `fantasydisk-animation-director`; work on existing `dev`; no branch
switch, commits, pushes, merges, tags, new worktrees or new threads.

## Контекст
После обновления `fantasydisk-animation-director` введено обязательное правило
safe slicing: generated/source sprite sheets должны иметь discard-only gutters
между кадрами и внешний padding. Сейчас есть риск, что при нарезке некоторых
анимаций crop прямоугольник захватывает несколько пикселей соседнего кадра, из-за
чего по краям runtime-анимации появляется визуальный мусор.

Эта задача не дублирует SCRUM-350: тот аудит проверял покрытие full-frame/5+
кадров, а здесь нужен отдельный pixel-bleed/safe-slicing проход по уже
существующим анимациям и новым death/full-frame рядам.

## Scope / Ownership
Animator-owned QA/fix task. Не менять gameplay, balance, targeting, UI layout,
spawn rules, reward flow или художественный стиль. Если требуется перегенерация
source art/full-frame row, создать Design handoff. Если нужна runtime API/registry
правка вне SpriteFrames/AnimationPlayer ownership, создать Back-end handoff.

## Требования
1. Провести duplicate audit против активных и завершённых animation/design задач,
   особенно SCRUM-350, SCRUM-353, SCRUM-370, SCRUM-380 и связанных batch
   integrations.
2. Собрать список всех runtime-анимаций и source sheets, которые сейчас
   используются для персонажей, монстров, призывов, элиток, mini-elites и
   боссов:
   - `assets/sprites/allies/**/*spriteframes.tres`
   - `assets/sprites/enemies/**/*spriteframes.tres`
   - `assets/sprites/elites/**/*spriteframes.tres`
   - `assets/sprites/bosses/**/*spriteframes.tres`
   - hero/cutout/full-frame animation assets where applicable.
3. Проверить каждый SpriteFrames/source row на:
   - захват пикселей соседнего кадра на левой/правой/верхней/нижней границе;
   - alpha bleed, chroma remnants, случайные островки/ореолы у crop edge;
   - weapon/VFX/shadow/tail/cloth touching crop edge without documented intent;
   - отсутствие обязательных safe gutters/outer padding для source sheets.
4. Для безопасных случаев исправить Animator-owned артефакты:
   - пересобрать SpriteFrames из чистых кадров;
   - обновить frame rects/offsets/pivots без изменения визуального масштаба;
   - пересобрать padded full-frame PNG rows/frames с safe gutters, если это не
     требует нового арта;
   - сохранить runtime пути и имена ресурсов.
5. Для случаев, где нужен новый source art или перегенерация кадров, создать
   отдельный Design handoff с точным списком entity/animation/path и требуемым
   gutter/padding.
6. Обновить animation manifest/QA artifacts по стандарту скилла:
   `frame_gutter_px`, `outer_padding_px`, `safe_slicing_checked`.
7. Обновить документацию только там, где меняются активные asset paths,
   SpriteFrames, manifests или известное состояние.

## Технический стандарт проверки
Использовать `fantasydisk-animation-director`.

Минимальные значения safe slicing:
- `256x256`: gutter `24 px`, outer padding `24 px`
- `384x384`: gutter `32 px`, outer padding `32 px`
- `512x512`: gutter `48 px`, outer padding `48 px`
- больше `512`: минимум `8%` от большей стороны, округление вверх до `8 px`

Runtime frame rectangles не должны включать gutter pixels. Gutter — только
discard-only область source sheet.

## Acceptance Criteria
- [x] Есть отчёт `docs/design/reviews/animation_safe_slicing_audit_2026_06.md`
  со списком проверенных assets, найденных bleed-дефектов, исправлений и handoff.
- [x] Все runtime SpriteFrames/source sheets текущего активного набора проверены
  на соседний-frame bleed и edge artifacts.
- [x] Все безопасные Animator-owned дефекты исправлены без изменения gameplay и
  без регрессии масштаба/пивота.
- [x] Для не-Animator-owned дефектов созданы Design/Back-end handoff tasks.
- [x] Манифесты/QA artifacts включают `frame_gutter_px`, `outer_padding_px`,
  `safe_slicing_checked`; skill validator проходит.
- [x] `animation_smoke_test.gd` проходит; `runtime_smoke_test.gd` запущен, если
  менялись runtime ресурсы, registry, scenes или shared scripts.

## Verification
Минимально:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/<task>/animation_manifest.json
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
```

Если затронуты runtime paths/registry:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

## Результат

2026-06-14 Animator SCRUM-387 завершён.

Проверено:
- 30 active runtime `SpriteFrames` under `assets/sprites/allies`,
  `assets/sprites/enemies`, `assets/sprites/elites`, `assets/sprites/bosses`;
- 794 unique runtime PNG frames;
- 45 source/reference sheets from full-frame enemy/elite/boss packs and
  SCRUM-380 death-row references.

Runtime result: active runtime frames pass safe slicing. Found `0`
neighboring-frame/crop-edge captures, `0` edge-touching frames, and `0`
crop-edge chroma remnants. 122 frames contain green-dominant pixels somewhere
inside the frame, but `green_edge_frames = 0`, so they are not chroma remnants
on crop edges. 145 runtime frames are below the new ideal transparent padding
target, mostly bottom-baseline/death rows, but they are individual PNG frames
with no current neighbor capture. No runtime asset rewrite was made to avoid
scale/pivot regressions.

Source sheet result: all 45 checked source/reference sheets are exact 6x4 grids
with `0 px` structural gutter and `0 px` outer padding against the new `24 px`
standard for `256x256` cells. This is Design-owned source compliance work, not
an Animator runtime fix. Created handoff:
`docs/tasks/design_animation_source_sheets_safe_gutters_task.md`.

Report:
`docs/design/reviews/animation_safe_slicing_audit_2026_06.md`.

QA artifacts:
- `build/qa/animation_sprite_sheet_safe_slicing_audit/animation_manifest.json`
- `build/qa/animation_sprite_sheet_safe_slicing_audit/runtime_frame_audit.json`
- `build/qa/animation_sprite_sheet_safe_slicing_audit/source_sheet_audit.json`

Verification:

```bash
python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_sprite_sheet_safe_slicing_audit/animation_manifest.json
# FantasyDisk animation manifest OK: 30 entities

/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd
# Animation smoke test passed.
```

`runtime_smoke_test.gd` was not required because this task did not change
runtime registry, scenes, shared scripts, or gameplay resources.
