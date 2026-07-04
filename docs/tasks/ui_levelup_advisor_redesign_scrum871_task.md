# Level Up 3.0 — прогноз статов и подсказки лучшего выбора

Jira: SCRUM-871
Статус: review
Контур: Claude
Owner: claude-busy-taussig-7e019f (user-directed chat)
Thread: current Claude worker
Worktree: .claude/worktrees/busy-taussig-7e019f
Branch: claude/busy-taussig-7e019f (auto-land в dev по зелёному smoke)
Locked paths: scripts/ui_screens.gd; scripts/level_up_advisor.gd; assets/sprites/ui/frames/level_up_scrum682/; tests/level_up_advisor_test.gd; docs/design/mockups/level_up_advisor/; docs/design/systems/menus_ui.md; docs/design/mechanics_extract.md

## Source Request

Пользователь (2026-07-04): «переделай с нуля экран выбора аттрибута при получении
уровня, должно быть ясно и понятно что увеличивается, я бы хотел чтобы игроку
подсказывало что лучше взять чтобы больше урона наносить (лучший выбор для дпс)
и лучший выбор для (выживаемости) разработай дизайн с нуля согласно лучшим
практикам UI UX».

## Проблема

Текущие SCRUM-682/683 карточки показывают иконку, название («+Урон») и краткое
описание («+15% к урону»). Игрок не видит: (а) какие КОНКРЕТНО его параметры и
на сколько вырастут; (б) какой из трёх вариантов сильнее всего поднимет его
урон в секунду, а какой — живучесть. Выбор делается вслепую.

## Решение (информационная архитектура с нуля)

1. **Честный прогноз.** Новый `scripts/level_up_advisor.gd` (static, class_name
   `LevelUpAdvisor`) делает dry-run применения награды: копия `stats` +
   `run_modifiers` (та же семантика, что `player.apply_reward`/`_apply_reward_mods`),
   пересчёт `ProgressionData.derived_parameters(stats, mods, weapon_config)`
   до/после. Никаких вручную дублированных формул урона.
2. **Блок «до → после»** на каждой карточке: до 3 самых значимых изменений
   производных статов в формате «Урон 145 → 167 (+15%)»; полный список — в
   тултипе карточки.
3. **Бейджи-рекомендации.**
   - DPS-скор: `derived[damage_parameter оружия] × attack_speed × (1 + crit_chance ×
     (crit_mult − 1))` по экипированным оружиям (в меню — по `weapon_config`) +
     DoT-трек `dot_damage × dot_speed`.
   - Surv-скор: EHP-модель боевого `take_damage`: `(HP + (reген + вампиризм) ×
     окно) / доля_проходящего_урона`, где доля = `(1 − dodge) × (1 − defense) ×
     absorb-фактор(типовой удар)` с капами из `ProgressionData`.
   - Карточка с максимальным ΔDPS% получает бейдж «Лучший урон», с максимальным
     ΔSurv% — «Выживание»; если это одна карточка — единый бейдж «Лучший выбор».
     Нулевые/отрицательные приросты бейдж не получают.
4. **Арт.** Базовый принятый кит SCRUM-682 сохраняется (панель/карточки/Позже).
   Новые PixelLab-ассеты: три риббон-бейджа (урон / выживание / лучший выбор),
   textless, текст рантаймом. Плашка «до → после» — тёмная StyleBox-вставка в
   пустой контент-зоне карточки. Правило фреймов соблюдается: весь новый контент
   внутри `LU_CARD_CONTENT_RECT`.
5. **Механика не меняется:** 3 варианта, «Позже» (пик сохраняется), анти-реролл
   `level_up_offer`, SCRUM-695 релевантность, capstone «Озарение», SCRUM-812
   фокус-раскладка клавиатуры/геймпада.

## Acceptance Criteria

- [x] На каждой карточке виден блок изменений «X -> Y (+N%)» (до 3 строк) без
      наложения на орнамент рамки; при отсутствии измеримых дельт — прежняя
      строка эффекта.
- [x] Бейдж «Лучший урон» стоит на карточке с максимальным приростом расчётного
      DPS; «Выживание» — с максимальным приростом EHP; совпадение → «Лучший выбор».
- [x] Рекомендации считаются от живых stats/run_modifiers/weapon_config текущего
      игрока (бой и меню-снапшот) и совпадают по направлению с фактическим
      применением награды (единый пересчёт `ProgressionData.derived_parameters`).
- [x] `tests/level_up_advisor_test.gd`: 10 проверок — PASSED.
- [x] `ui_no_overlap_matrix` (слот level_up) — PASSED; `runtime_smoke` — PASSED;
      фокус-раскладка SCRUM-812 не менялась.
- [x] Mockup-spec пакет в `docs/design/mockups/level_up_advisor/` (превью,
      зоны, margins, provenance PixelLab).

## Files

- `scripts/level_up_advisor.gd` (new)
- `scripts/ui_screens.gd` (карточка level-up, бейджи, дельта-блок, тултипы)
- `assets/sprites/ui/frames/level_up_scrum682/ui_badge_lu_best_dps.png|_surv|_both` (new)
- `tests/level_up_advisor_test.gd` (new)
- `docs/design/mockups/level_up_advisor/` (spec + превью)
- `docs/design/systems/menus_ui.md`, `docs/design/mechanics_extract.md`

## Result

Done 2026-07-04 by claude-busy-taussig-7e019f (ожидает QA-вердикта).

- `scripts/level_up_advisor.gd`: dry-run применения награды к копиям
  stats/run_modifiers (семантика `player.apply_reward`) → пересчёт
  `ProgressionData.derived_parameters` до/после; DPS-прокси (урон родного типа
  класса × атак/с × ожидание крита + DoT-трек) и EHP-модель боевого
  `take_damage` (absorb → защита → уворот + окно регена/вампиризма 12 с);
  бейджи argmax положительного прироста, совпадение осей → «Лучший выбор»;
  изоляция типов урона SCRUM-524 в дельтах.
- Карточка level-up перестроена (SCRUM-871 раскладка в контент-зоне 354x426):
  риббон-бейдж сверху (PixelLab textless, подпись рантаймом в label-зоне поля),
  иконка 120, титул, описание, блок «до -> после» до 3 строк
  (`LevelUpRewardEffectText`/`...2`/`...3`) в 9-slice `effect_preview`-фрейме,
  пересобранном в родной аспект 354x132. Тултип карточки: полный список
  изменений + классовая интерпретация + объяснение бейджа с процентом прироста.
- Авто-подбор шрифта подписи под ширину зоны (`_shrink_label_font_to_width`,
  fit_ratio 0.62) + выравнивание титулов ряда по минимальному; клип/ellipsis —
  страховка. Хост строк — Control с нулевым minimum size (PanelContainer не
  растёт от текста — гейт матрицы держится).
- Данные: титул `max_hp_up` сокращён до «+Макс. здоровье».
- Механика не менялась: 3 варианта, «Позже», анти-реролл `level_up_offer`,
  SCRUM-695 релевантность, capstone «Озарение», фокус SCRUM-812.

Tests:
- `tests/level_up_advisor_test.gd` — PASSED (новый гейт, 10 проверок).
- `tests/ui_no_overlap_matrix_test.gd` — PASSED (слот level_up в матрице).
- `tests/runtime_smoke_test.gd` — PASSED.
- `tests/attribute_relevance_test.gd` — PASSED (контент-данные не сломаны).

Evidence: `build/qa/scrum871/level_up_advisor_{1280x720,1920x1080,2560x1440}.png`
+ `level_up_advisor_rects.md` (ректы и подобранные шрифты всех ключевых узлов).

Disk cleanup: removed tools/debug_badge_font.gd (временный дебаг);
worktree .godot-кэш остаётся до закрытия ветки чата (переиспользуемый).

### Reopen-фикс 2026-07-04 (фидбек пользователя)

Подписи бейджей «ЛУЧШИЙ УРОН»/«ВЫЖИВАНИЕ» стояли не по центру поля риббона и
слегка наслаивались на орнамент. Причина: label-зоны были прикинуты на глаз,
а фактические поля риббонов лежат в ВЕРХНЕЙ части PNG (хвосты ниже) и левее.
Фикс: `LU_BADGE_META.label_zone` заменены на поля, замеренные по пикселям
(scratch measure_badge_fields: максимальный низкодисперсный ран в средней
полосе + вертикальные границы от центра поля): dps (0.33, 0.23, 0.46, 0.29),
surv (0.36, 0.26, 0.51, 0.50), both (0.33, 0.31, 0.45, 0.35); подпись держится
по вертикальному центру поля с учётом кламппа минимальной высоты Label; базовый
шрифт 12 (cap 15). Гейты и капчи перегнаны — зелёные.
