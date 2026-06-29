# UI Mockup Spec Template

Create one spec for every FantasyDisk UI mockup. The spec is the bridge between OpenAI-generated mockup art and Godot implementation.

```markdown
# UI Mockup Spec - <Screen Name>

Status: draft | ready_for_integration | implemented | blocked
Role owner: Design | Back-end | PM/Coordination
Task: <docs/tasks/...md or none>
Jira: SCRUM-<id or none>
Base resolution: 1920x1080
Responsive targets: 1280x720, 1920x1080, 2560x1440
Mockup PNG: <path>
Preview PNG: <path>
Generated with: OpenAI Images API via <script/skill>

## Source Request

<Short copy of the user/task request.>

## Screen Elements

| ID | Type | Runtime content | Rect @ 1920x1080 | Anchors | Min size | Z | States | Safe-zone parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| hero_portrait | TextureRect | selected hero art | x,y,w,h | left/top | w,h | 10 | selected/locked | portrait_frame |

## Frames And Safe Zones

| Frame ID | Asset path | Asset size | Texture margins | Content margins | Forbidden zones | 9-slice |
| --- | --- | --- | --- | --- | --- | --- |
| portrait_frame | <path> | 512x768 | L/R/T/B | L/R/T/B | corners, border, gems | yes/no |

## Generated Assets

| Asset ID | Path | Purpose | Size | Alpha | Texture margins | Content margins | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Responsive Rules

- 1280x720:
- 1920x1080:
- 2560x1440:

## Interaction States

- Button/slot hover:
- Button/slot pressed:
- Disabled/locked:
- Selected/focus:
- Empty/loading:

## Implementation Notes

- Godot scene:
- Control node structure:
- StyleBoxTexture/NinePatchRect requirements:
- Runtime text/icon containers:

## Acceptance Checks

- [ ] Mockup generated through OpenAI Images API.
- [ ] Preview shown in chat when generated.
- [ ] All visible elements are listed in the elements table.
- [ ] Every frame has texture margins and content margins.
- [ ] No UI content overlaps frame border, ornament, gem, metal, or decorative corner.
- [ ] Runtime content fits inside safe zones at every responsive target.
- [ ] Hover/focus/pressed/disabled states do not resize or shift layout.
- [ ] Screenshot comparison completed after implementation.
- [ ] Task/Jira updated when applicable.

## Deviations

<Any difference between mockup and implementation, with reason.>
```

## Geometry Rules

Use pixel rectangles for the base resolution. Percent-only descriptions are not enough. For responsive screens, include anchor behavior and min/max constraints.

Use the real safe content area. Do not treat an ornate frame's full bounding box as usable space.

If a generated mockup is beautiful but geometrically unclear, create an annotated overlay or regenerate it with more explicit empty content zones.
