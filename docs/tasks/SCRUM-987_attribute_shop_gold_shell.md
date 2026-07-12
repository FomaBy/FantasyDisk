# SCRUM-987 — Attribute Shop gold shell

Статус: done
- Контур: `Codex`
- Owner: `/root/scrum982_remove_gold_stat`
- Combined scope: `SCRUM-982` + `SCRUM-987` + `SCRUM-988`
- Locked screen: `AttributeShopScreen`.

## Контракт

- Единый hollow gold frame поверх background; декоративная рама всегда последний mouse-ignore child.
- Никакой второй центральной рамки/панели.
- Все live controls и текст строго внутри exact gold-shell inner rect.
- Карточка показывает название, классовую интерпретацию, «Влияет на», полный предпросмотр до четырёх строк и цену без зависимости от tooltip.
- Responsive matrix: `1280×720`, `1920×1080`, `2560×1440`, включая live resize.

## Evidence

- UI Director content-zone planning: `ready_for_image`, zero errors/warnings at 1280×720, 1920×1080 and 2560×1440.
- PixelLab MCP source: `bf62b298-1df4-40d7-baeb-8fd30ac071d3`; compositor report `ok=true`.
- Runtime renderer captures at all three targets are under `docs/design/previews/scrum982_987_988_attribute_shop/runtime/`.
- No `AttributeShopPanel` or ScrollContainer remains; `AttributeShopFrame` is the final hollow mouse-ignore child.
- Every card renders visible influence and complete derived before/after lines inside its safe rect.
- Focused combined, full runtime and UI no-overlap gates: PASS.
- Independent read-only code review: PASS; 720p renderer copy-fit and frame rules re-verified.
- Disk cleanup: removed task `.godot` import cache; disposable worktree retained only through `dev` landing.

## QA-Вердикт (2026-07-10)

Статус: PASSED

Проверено: UI Director/PixelLab provenance, три content-zone plan report (`ready_for_image`, 0 ошибок/предупреждений), compositor `ok=true`, focused acceptance, runtime/UI-overlap/regression gates и независимый осмотр committed renderer captures `1280×720`, `1920×1080`, `2560×1440`.

Краевые случаи: live resize `2560→1280→1920`; 720p copy-fit с body font ≥ 11 px; frame — последний прямой mouse-ignore child, `draw_center=false`; title/money/cards/actions и все дочерние labels/hitboxes остаются внутри exact `gold_shell_inner_rect`; ScrollContainer и вторая центральная рама отсутствуют.

Баги: нет. Hard-правило «контент только в пустой зоне фрейма» выполнено на всей responsive-матрице.

Disk cleanup: QA import cache/generated UID sidecars are removed after the verdict push; final Jira comment records deletion of the disposable QA worktree.
