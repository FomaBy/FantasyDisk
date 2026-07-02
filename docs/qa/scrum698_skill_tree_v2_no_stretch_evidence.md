# SCRUM-698 — Skill Tree v2 (PoE-style graph) — UI asset no-stretch evidence

Все generated-ассеты графового древа рендерятся в нативном/пропорциональном масштабе.
Узлы и маркер входа — `TextureButton`/`TextureRect` со `STRETCH_KEEP_ASPECT_CENTERED`
(равномерный масштаб, без деформации по одной оси). Коннекторы рисуются процедурными
линиями (`draw_line`) — спрайт-коннектор 128×48 НЕ растягивается под произвольную длину
ребра. Фон холста — `STRETCH_TILE` (нативные пиксели, тайлинг, без stretch).

## Узлы (квадрат → квадрат, аспект 1:1, KEEP_ASPECT_CENTERED)
| Ассет | kind | Source px | Display (world) px | Scale (default zoom 0.5) @1080p/2K | Aspect | No-stretch |
|---|---|---|---|---|---|---|
| node_state_* | minor | 148×148 | 72×72 | ~0.243 (uniform) | 1:1 | PASS |
| node_notable_* | notable | 192×192 | 98×98 | ~0.255 (uniform) | 1:1 | PASS |
| node_keystone_* | keystone | 256×256 | 126×126 | ~0.246 (uniform) | 1:1 | PASS |
| class_entry_marker | entry | 200×200 | 104×104 | ~0.260 (uniform) | 1:1 | PASS |
| class_entry_marker (focus glow) | — | 200×200 | 158×158 | ~0.395 (uniform) | 1:1 | PASS |

Зум (0.28…1.3) масштабирует холст РАВНОМЕРНО (`world.scale = Vector2(z, z)`), поэтому
аспект всех узлов сохраняется на любом уровне приближения и на любом разрешении.

## Рамки/бейдж/фон
| Ассет | Source px | Использование | Режим | No-stretch |
|---|---|---|---|---|
| ui_frame_skill_tree_main | 1280×720 (16:9) | SkillTreeMainPanel | 9-slice (углы фикс, центр-fill) | PASS — пропорц. рамка |
| ui_badge_skill_points | 180×132 | SkillTreePointsBadge | 9-slice (углы фикс) | PASS |
| ui_frame_skill_tree_class_select | 420×108 | селектор класса | 9-slice | PASS |
| ui_frame_skill_tree_class_popup | 560×440 | попап info/reset | 9-slice | PASS |
| bg_canvas | 688×384 | задник холста | TILE (нативные пиксели) | PASS |
| connector_active/locked | 128×48 | НЕ используются как спрайт | заменены на draw_line | PASS (нет axis-stretch) |

## Гейты (Godot 4.7, headless, godot_gate semaphore)
- tests/meta_skill_tree_smoke_test.gd — PASS (экран открывается, 88 узлов-кнопок, покупка/трата метаочка, сейв).
- tests/runtime_smoke_test.gd — PASS (включая SCRUM-331 skill-tree kit на 1280×720 / 1920×1080 / 2560×1440 + back-button frame-safe).
- tests/ui_no_overlap_matrix_test.gd — PASS на 1152×648 … 3840×2160 (SkillTreeBackButton/PointsBadge/ClassPanel/Canvas без наслоений, текст в рамках, нет STRETCH_SCALE на exact-frame).
