# Аудит: неиспользуемые спрайты и картинки (SCRUM-269, Quality Pass v2)

Дата: 2026-06-14. Роль: Design→Back-end (Claude). READ-ONLY (Фаза 1) — находки +
спека удаления + порождённая execution-задача; ничего не удаляется в этой задаче
сверх неё.

Окружение: Godot 4.6.3 headless, ветка `dev`. Инструмент:
`tools/audit_unused_assets.py` (консервативный — литеральные `res://`-ссылки в
tscn/gd/tests/tools/project.godot). Аудит сырых кандидатов вручную сверён с
ДИНАМИЧЕСКИМИ путями загрузки.

## Главный вывод

**Мёртвого игрового арта НЕТ.** Все 79 `unused_asset`-кандидатов аудита —
ложные срабатывания (динамическая загрузка по ID) либо арт в ожидании вайринга
(0.1.5). Удалять спрайты/картинки НЕ нужно.

Единственный реальный мусор — **64 осиротевших `« 2.png.import»`-сайдкара**
(остаток дублей SCRUM-270, пропущенный regex'ом) + локальный untracked-скретч.

## Сводка

| Категория | Объём | Вердикт |
| --- | --- | --- |
| `vfx_weapon_<id>.png` (эффекты) | 51 | **KEEP** — `attack_vfx.weapon_signature()` строит путь `vfx_weapon_%s.png % weapon_id` |
| `weapons/<id>.png` (иконки оружия) | 18 | **KEEP** — `ui_screens.gd:2045` строит `weapons/%s.png % asset_id` |
| `bosses/boss_{ashen_colossus,bone_archon,brood_mother}.png` | 3 | **KEEP** — новый арт боссов 0.1.5, вайринг в процессе (`docs/design/backlog/vfx_015/`) |
| `elites/mini_*.png` | 6 | **KEEP** — мини-элитки, спрайты ещё подключаются (явно в ТЗ) |
| `assets/marketing/**` | 2 | **KEEP** — маркетинговый коллатераль (promo/steam-logo), не runtime-арт |
| `« N.<ext>.uid/import»` осиротевшие сайдкары | **110** | **УДАЛИТЬ** — source отсутствует, 0 ссылок; остаток дублей SCRUM-270 (64 `.png.import` + 46 `.gd.uid`) |
| `tmp/*.bak`, `**/.DS_Store` | 7 | local-скретч (untracked) — репо-действий не требует |

## Почему 79 «unused» — ложные срабатывания (динамическая загрузка)

Аудитор видит только литеральные `res://…png`. Боевой арт грузится по ID:

- `scripts/attack_vfx.gd:29` — `const WEAPON_SIGNATURE_PATH := "res://assets/sprites/effects/vfx_weapon_%s.png"`, заполняется `weapon_id` в `weapon_signature()` (стр. 43). → все 51 `vfx_weapon_*.png` достижимы (суффикс == один из 51 weapon_id; сверено программно — 100% совпадение).
- `scripts/ui_screens.gd:2045` — `var direct_path := "res://assets/sprites/weapons/%s.png" % asset_id`. → все 18 `weapons/*.png` достижимы по weapon_id.

Перекрёстная сверка: 69/69 спрайт-кандидатов с суффиксом-weapon_id совпали с
реальным ID из `progression_data_weapons.gd` (51 оружие). Ложного мёртвого арта
по оружию — ноль.

## Арт в ожидании вайринга (НЕ удалять)

- **Боссы 0.1.5**: `boss_ashen_colossus/bone_archon/brood_mother` — НЕ в
  `sliced_rig_manifest.gd` (там только rift_warden/disk_devourer/iron_bastion/…),
  но их VFX-сайдкары лежат в `docs/design/backlog/vfx_015/effects/` — контент
  патча 0.1.5 «Бой и баланс» на стадии интеграции.
- **Мини-элитки**: `mini_bone_warden/plague_bellringer/rot_hound/scavenger_reaper/
  shadow_devourer/spark_wight` — динамической загрузки пока нет; подключение в
  работе (явно отмечено в ТЗ — «спрайты ещё подключаются»).

## Реальный мусор под удаление

### 110 осиротевших сайдкаров `« N.<ext>.uid/import»` (удалено в этой цепочке)

Остаток случайного копирования дерева (см. SCRUM-267/270). Cleanup SCRUM-270
удалил 275 `« N.ext»`-дублей по regex `git ls-files | grep -E ' [0-9]\.[a-z]+$'`,
но этот шаблон НЕ ловит ДВОЙНОЕ расширение (`« 2.png.import»`, `« 2.gd.uid»` —
после ` 2.` идёт `png.import`/`gd.uid` с точкой, `[a-z]+$` не матчит). Поэтому
110 сайдкаров пережили чистку: **64 `.png.import` + 46 `.gd.uid`**.

Безопасность: у всех source (` N.png`/` N.gd`) ОТСУТСТВУЕТ (удалён в SCRUM-270),
ссылок ноль. Это мёртвые сайдкары несуществующих дублей — Godot регенерирует
`.uid/.import` из source, которого нет → чистый мусор.

**Execution**: `cleanup_remove_orphan_import_sidecars_task` (SCRUM-271,
file-изолированно). Исполнено в этой же цепочке: `git rm` всех
`git ls-files | grep -E ' [0-9]\.[a-z]+\.[a-z]+$'` (110 шт), runtime +
content_registry smoke зелёные. Регресс regex'а SCRUM-270 закрыт.

### Локальный скретч (untracked, репо-действий не требует)

`tmp/{pd_broken_worker,pd_slice2,pd_slice3,progression_data.gd,ui_screens}.bak`
(мои бэкапы из сплита progression_data) + `**/.DS_Store` — НЕ в git, репо не
раздувают. Опционально снести локально; в `.gitignore` `tmp/` и `.DS_Store`
уже игнорируются.

## content_registry-сверка

Несоответствий арт↔реестр не выявлено: весь боевой арт грузится по weapon_id,
совпадающему с `progression_data_weapons.gd`; новый арт боссов/элиток —
ожидаемо вне реестра до завершения вайринга.

## Acceptance

- [x] Прогон `audit_unused_assets.py` + ручная сверка динамических путей.
- [x] Разделение: точно неиспользуемые / превью-артефакты / wiring-pending.
- [x] Учтён свежий арт 0.1.4/0.1.5 (боссы, мини-элитки) — не помечен мёртвым.
- [x] Отчёт со списками удалить/оставить/скретч + обоснованием.
- [x] Порождена file-изолированная execution-задача (64 осиротевших сайдкара).
