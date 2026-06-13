# Changelog — FantasyDisk

Формат: [Keep a Changelog](https://keepachangelog.com/), версии: [SemVer](https://semver.org/) (0.MINOR.PATCH до релиза 1.0).

## [Unreleased] — ветка dev

- Content (SCRUM-192): `sprite_path` новых классов выровнен с canonical registry — Вор, Элементалист, Снайпер, Священник, Биолог и Инженер теперь используют собственные full-art PNG вместо proxy-спрайтов старых классов; добавлен focused registry alignment test на все 17 персонажей.

- Tests (SCRUM-203): добавлен focused UI no-overlap matrix test для main/settings/codex/patch/hero/victory/death peer-controls на 1152x648, 1280x720, 1600x900 и 2560x1440; rect dump пишется в `build/qa/ui_no_overlap_matrix.md`.

- Performance (SCRUM-197): добавлен `CombatTargetQuery` с per-frame cache для enemy target lookups; hot-path запросы в ClassWeapon/BerserkWeapon/player ultimates/allies/summoner переведены на nearest/radius/corridor/segment helpers, добавлен focused cache test.

- Баланс-аудит (SCRUM-190): добавлен сценарный survivability harness для fragile/steady/sturdy/tank профилей и roster projection по реальным классам; отчеты `build/survivability_report.md` и `build/survivability_scenarios_report.md` фиксируют текущие TTD/mitigation слои без изменения балансовых констант.

- Локализация (SCRUM-210): добавлен data-driven русский глоссарий `scripts/glossary.gd`, вкладка «Глоссарий» в Кодексе, пунктирные интерактивные термины и tooltip hook (hover / Alt+hover для popup-контекста); русифицированы ключевые visible strings магазина, level-up наград, HUD и кодексных описаний.

- Bugfix (SCRUM-211): товары магазина перенесены из старой правой wall-зоны в центр нового shop backdrop; frameless стиль и node-bound stock сохранены, runtime smoke проверяет центр группы (`center_delta_x=0.0`) и no-overlap на 1280x720/2560x1440.

- UI Art (SCRUM-147): user correction applied — Parchment & Wax Seal remains only on buttons, button PNGs are taller so the wax seal fits, and all non-button panels/cards/HUD/tooltips/shop frames were restored to the old interface look; active preview `docs/design/previews/ui_button_only_legacy_panels_contact.png`, pipeline `tools/apply_button_only_ui_revert.py`.

- UI Theme (SCRUM-222): Back-end style layer remains path-compatible — buttons use real primary/secondary/danger 4-state Parchment & Wax Seal PNG (`idle/hover/pressed/disabled`), while `dark_fantasy` non-button frame paths now visually mirror the old interface after the SCRUM-147 correction.

- UI (SCRUM-224/SCRUM-225/SCRUM-226/SCRUM-227): экран выбора героя собран в единую правую информ-панель (досье слева от радара), выбор оружия показывает PNG-спрайт и русские статы в легких кликабельных карточках, level-up варианты стали text-field карточками без тяжелой reward-button рамки, а wax-seal кнопки подняты до читаемой высоты с компактным no-seal стилем для utility/dropdown controls. Runtime smoke пишет dumps `build/qa/hero_select_radar_rects.md`, `weapon_select_clean_layout.md` и `parchment_button_seal_sizes.md`.

- Tests (SCRUM-228): стабилизирован `tests/melee_weapon_targeting_test.gd` — hammer AoE блок теперь ждет один frame после добавления enemies, чтобы тест не читал устаревший per-frame target cache; production `combat_target_query.gd` не менялся.

- UI Art (SCRUM-223): игровой курсор заменен на выбранный пользователем dark steel dragon/clawed fire pointer — default/hover/attack PNG обновлены в `assets/sprites/ui/cursor/`, hotspot выверен на `(2, 2)`, preview `docs/design/previews/cursor_clawed_fire_before_after.png`.

- UI Art (SCRUM-229): панели/окна/плашки/чекбоксы переведены с временного legacy вида на leather+gold dark fantasy kit из пользовательских референсов `docs/design/references/interface/`; добавлен пайплайн `tools/build_leather_gold_ui_kit.py`, source kit `assets/sprites/ui/frames/leather_gold/`, live replacements для `dark_fantasy/global/escape/shop/system` PNG и QA preview `docs/design/previews/interface_leather_gold_panel_kit_contact.png`.

- Баланс-аудит (SCRUM-188): добавлен route-level отчет `build/route_economy_xp_model.md` для balanced/combat-heavy/shop-heavy маршрутов; модель подтверждает 8-9 level-up и healthy/high покупательную способность, поэтому текущий XP uplift +7.1% оставлен без дополнительного повышения.

- Animation API (SCRUM-208): добавлен Back-end side-channel `weapon_animation_event` для delayed/pulse/deploy/channel оружия; phase metadata (`windup/release/pulse/burst/deploy/channel/recover`) идет из существующих gameplay таймингов и не меняет урон, targeting, VFX spawn или баланс.

- Visual integration (SCRUM-170): центральные экраны получили role-specific dark fantasy backdrops из `assets/backgrounds/ui/` с cover scaling: cathedral для системных экранов, merchant archive для магазина, arcane lab для event/level-up/meta, reward hall для наград/победы и crypt для поражения/danger screens.

- Visual integration (SCRUM-157): призывные союзники и deployables теперь различаются по источнику — Друидский амулет выбирает beast/pack-spirit, гомункул Химика использует отдельный homunculus sprite, звуковой усилитель и вороний тотем ставят собственные field sprites без изменения баланса и cleanup-групп.

- VFX (SCRUM-181): все 19 активных `assets/sprites/effects/*.png` перерисованы в более сдержанный painterly D&D/tabletop стиль без кислотного неона и голой геометрии; добавлены before/after и meadow/marsh readability previews, Godot import и `attack_vfx_smoke_test` проходят.

- UI Art (SCRUM-182): derived stat icons, shop-only icons and shop state sprites refreshed in-place as compact fantasy raster objects/frames with transparent alpha; added before/after and 40px readability previews for Escape stats, level-up, shop and tooltip usage.

- Design Audit (SCRUM-183): confirmed obsolete legacy placeholder/root prototype sprite candidates and updated Back-end cleanup handoff; no runtime assets were deleted in Design scope, with live exceptions documented for `berserk_walk_sheet_v2.png`, `enemy_projectile_magic_64.png`, and active `assets/sprites/enemies/*.png`.

- Bugfix (SCRUM-207): магазин больше не регенерирует сток при повторном открытии того же shop-узла — набор товаров привязан к конкретной точке маршрута, купленные позиции остаются снятыми со стены, повторная покупка невозможна; новый shop-узел получает свежий сток.

- UX (SCRUM-205): Escape в активном забеге теперь везде открывает единое меню паузы поверх текущего экрана; досье персонажа доступно кнопкой из этого меню, повторный Escape возвращает к подлежащему экрану без сброса состояния. Магазин получил единый «Назад», события показывают «Назад» с пояснением, если skip недоступен.

- Bugfix (SCRUM-206): на экране выбора героя радар характеристик увеличен до 370x230, опущен ниже шапки и получил резервное пространство в досье; runtime smoke проверяет rect/no-overlap на 1280x720, 1600x900 и 2560x1440, dump сохранен в `build/qa/hero_select_radar_rects.md`.

- Bugfix (SCRUM-172): исправлена потенциальная «немая» аудио-конфигурация — `master_volume=0` больше не hard-mute'ит Master bus, старые профили с нулем без явного intent-флага мигрируют к 100%, кроссфейд музыки сбрасывает застрявшие low-volume состояния, а вкладка «Звук» получила кнопку «Сбросить звук по умолчанию».

- UI (SCRUM-160): магазин больше не показывает товары в золотых карточках — предметы висят на стене фона как реальные товары лавки, с контактной тенью, компактным ценником с монетой, hover tooltip, затемнением недоступного товара и empty-hook состоянием после покупки; runtime smoke проверяет отсутствие frame-style слотов и no-overlap на 1280x720/2560x1440.

- Контент (SCRUM-164): добавлен финальный класс Class Sheet — Инженер (`engineer`) с 3 уникальными оружиями: ключ часового (`engineer_sentry_link`), ремонтный дрон (`engineer_repair_drone`) и минная сетка (`engineer_pressure_mines`); выбор героя/кодекс/тесты расширены под 17 классов и 51 weapon variant. Арт и rig/motion переданы Design/Animator handoff-задачами.
- Арт (SCRUM-164): подготовлен canonical Engineer visual kit — `assets/sprites/characters/engineer.png`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_repair_drone.png`, `assets/sprites/weapons/engineer_pressure_mines.png`; добавлен preview `docs/design/previews/engineer_art_contact.png`, Godot import и PNG/alpha validation пройдены.

- Контент (SCRUM-166): добавлен класс Робот (`robot`) с 3 уникальными оружиями — магнитный якорь (`robot_magnetic_anchor`), гидравлический пресс (`robot_compression_line`) и реакторное ядро (`robot_reactor_vent`); выбор героя/кодекс/тесты расширены под 16 классов и 48 weapon variants. Runtime smoke blocker по indentation в weapon-mechanics awaits исправлен. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.
- Арт (SCRUM-166): подготовлен canonical Robot visual kit — `assets/sprites/characters/robot.png`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `assets/sprites/weapons/robot_hydraulic_press.png`, `assets/sprites/weapons/robot_reactor_core.png`; добавлен preview `docs/design/previews/robot_art_contact.png`, Godot import и PNG/alpha validation пройдены.

- Контент (SCRUM-162): добавлен класс Биолог (`biologist`) с 3 уникальными оружиями — споровая линза (`bio_spore_bloom`), инъектор образцов (`bio_sample_dart`) и семя симбионта (`bio_symbiote_web`); выбор героя/кодекс/тесты расширены под 15 классов и 45 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.
- Арт (SCRUM-162): подготовлен canonical Biologist visual kit — `assets/sprites/characters/biologist.png`, `assets/sprites/weapons/biologist_spore_lens.png`, `assets/sprites/weapons/biologist_sample_injector.png`, `assets/sprites/weapons/biologist_symbiote_seed.png`; добавлен preview `docs/design/previews/biologist_art_contact.png`, Godot import и PNG/alpha validation пройдены.

- Контент (SCRUM-165): добавлен класс Священник (`priest`) с 3 уникальными оружиями — светлый реликварий (`priest_sanctify`), кадило обета (`priest_ward`) и колокол молитвы (`priest_prayer_chain`); выбор героя/кодекс/тесты расширены под 14 классов и 42 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Контент (SCRUM-167): добавлен класс Снайпер (`sniper`) с 3 уникальными оружиями — винтовка Мертвого Глаза (`sniper_lockshot`), прицел Наводчика (`sniper_kill_zone`) и осколочные патроны (`sniper_split_round`); выбор героя/кодекс/тесты расширены под 13 классов и 39 weapon variants. Runtime smoke blocker по GDScript type inference в sniper weapon methods исправлен явными типами/casts. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Музыка (SCRUM-154): меню и бой переведены на струнный тавернный эмбиент (RandomMind, CC0/OpenGameArt) — «The Old Tower Inn» в меню, «Minstrel Dance» в бою, тёмная вариация «Battle» в босс-бою; бесшовные лупы (шов меню сглажен микро-фейдом), громкость треков нормализована к одному уровню, добавлен кроссфейд меню↔бой 0.9с; источники и лицензии в docs/design/audio.md.

- Контент (SCRUM-163): добавлен класс Элементалист (`elementalist`) с 3 уникальными оружиями — кольцо стихий (`elemental_orbit`), призматический фокус (`prism_rift`) и ядро метеора (`meteor_shards`); выбор героя/кодекс/тесты расширены под 12 классов и 36 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Контент (SCRUM-169): добавлен класс Вор (`thief`) с 3 уникальными оружиями — кошель рикошета (`coin_ricochet` + steal money), плащ захода (`shadow_backstab`) и дымовая бомба (`smoke_bomb` + временный dodge); выбор героя/кодекс/тесты расширены под 11 классов и 33 weapon variants. Финальный арт и rig/motion переданы Design/Animator handoff-задачами.

- Контент (SCRUM-168): добавлен класс Солдат (`soldier`) с 3 уникальными оружиями — аркебуза строя (`suppression_burst`), граната с фитилем (`grenade_cook`) и штык-стойка (`bayonet_brace`); подключены canonical Soldier character/weapon PNG, выбор героя/кодекс/тесты стали data-driven под 10 классов и 30 weapon variants. Rig/motion передан Animator handoff-задачей.

- Контент (SCRUM-155, ч.2): 3 новых финальных босса — Костяной Архонт (волны скелетов, веер черепов, костяная стена с проходом), Матерь Роя (выводок паучат, паутинные зоны замедления, рывок в финальной фазе) и Пепельный Колосс (slam-волны с тлеющими зонами, энрейдж ниже четверти HP); ротация финального узла теперь из 5 боссов, у всех русские титулы в баннере появления, кодекс пополнен. Арт — placeholder с тинтом до готовности SCRUM-156.

- Visual: добавлены dark fantasy UI backdrops `2560x1440` для экранов с центральными окнами и заменен арт главного меню на новую battle-сцену с героями/боссами FantasyDisk; существующие shop/event/campfire background paths обновлены совместимо, расширенное screen-role подключение вынесено в Back-end handoff.

- Контент (SCRUM-155, ч.1): свита Возвышения L7 получила 6 data-driven видов мини-элиток (Жнец-Падальщик, Чумной Звонарь, Костяной Страж, Искровик, Гнилая Гончая, Теневой Пожиратель) — каждый со своим профилем HP/скорости/урона и тинт-идентичностью на placeholder-спрайтах; свита выбирает случайный вид. Все 6 добавлены в кодекс (раздел «Мини-элитки»). Боссы ростера — следующим инкрементом.

- UX/баланс: Escape в активном забеге теперь открывает досье персонажа поверх боя, карты, магазина, события, level-up, докачки и награды элитки; досье показывает портрет, оружие, уровень/XP, Возвышение и выделяет приоритетные атрибуты класса из единого `ATTRIBUTE_PRIORITIES`.

- Баланс: level-up переведен на 3 фиксированных варианта, редкие основные характеристики стали существенно реже (~5% на слот), обычные награды взвешены по профильным атрибутам класса; вампиризм получил cap лечения в секунду и малую долю урона, а регенерация/защита/уклонение усилены.

- UX: экран победы очищен от технических строк (`Meta points`, raw `asc_` IDs) и показывает только русский пользовательский итог: победа над боссом, очки наследия, прогресс Возвышения и смысл новой награды.

- Bugfix: cleanup эффектов оружия стал устойчивее при смене оружия Гитариста — отложенные callbacks старого усилителя больше не создают новые VFX после cleanup; summon-союзники Друида получили корректный импорт ассетов и устойчивый spawn parent.

- UX: вкладка «Звук» в настройках получила читаемые слайдеры громкости — видимый трек на всю ширину, отличающуюся заполненную часть, шаг 2%, keyboard focus и понятный mute-переключатель «Вкл./Выкл.»; QA-скриншот сохранен в `build/qa/settings_volume_slider_ux.png`.

- Баланс: дроп и экономика перебалансированы по классам целей — bruiser/shield, мини-элитки, элитки и боссы дают заметно больше XP/золота; магазин, докачка, reroll и платные event-исходы подорожали через общий multiplier x1.10; XP-кривая замедлена до `ceil(req*1.42+3)`. Balance harness показывает +10.6% эффективной покупательной способности и +7.1% XP в типовом маршруте.

- Bugfix: верхний боевой HUD больше не пересекается на 1152x648/1280x720/2560x1440 — ресурсная панель адаптивно сжимается, таймер/бейдж Возвышения уступают место, ряд артефактов переносится ниже при нехватке ширины; runtime smoke пишет `build/qa/hud_no_overlap_rects.md`.

- Visual: добавлен D&D/painterly набор призывных союзников и deployable-объектов (`assets/sprites/allies/`); `AllyMinion.tscn` получил raster fallback вместо Polygon2D-placeholder, а source-specific mapping вынесен в Back-end handoff.

- Visual: 4 элитки (`iron_bastion`, `night_stalker`, `plague_prophet`, `shard_marshal`) и 2 босса (`boss_rift_warden`, `boss_disk_devourer`) переведены на native 512x512 PNG и перенарезаны в cutout rig pipeline, чтобы убрать мыло на epic scale в QHD/Retina без изменения хитбоксов и gameplay scale.

## [0.1.3] — 2026-06-12

- Элитки и боссы — крупнее, сложнее, эпичнее: элитки ~1.73x, боссы ~2.35x моба с согласованными хитбоксами; в фазе 2 элитки бьют чаще (-20% кулдаун) и получают второе применение атаки, боссам добавлен паттерн «волна зон» с гарантированным безопасным коридором; подача — баннеры появления, умеренная тряска камеры (тумблер «Тряска камеры» в настройках) на спавне/ударах/смерти и hit-stop на смерти элитки/босса.

- UX: level-up теперь дает 5 фиксированных вариантов, ровно 1 выбор за уровень, редкие основные характеристики с visual rare-пометкой и отложенный выбор через Escape/«Позже» + нижнюю кнопку «Повышение уровня (N)».

- UX: убрано дублирование входа в level-up — при pending-уровнях видна только нижняя кнопка с бейджем, а `UpgradeFabButton` остается отдельным режимом докачки атрибутов за золото при pending=0.

- UX: экран выбора героя переведен на v3-компоновку — крупный портрет слева, досье/оружие/Возвышение/программный радар 8 BASE_STATS справа, лента 9 героев снизу и отдельная кнопка «Выбрать» для перехода к оружию.

- Bugfix: выбор героя v3 очищен от layout-дублей — нижняя карусель теперь только из картинок без подписей, радар характеристик вынесен в правый верхний угол, имя героя осталось только в досье.

- Bugfix: окно «Трофей элитки» больше не уезжает в правый нижний угол — панель центрируется через full-rect `CenterContainer`, а smoke-тест проверяет фактический `global_rect` центр на 1280x720, 1469x908 и 2560x1440.

- Bugfix: в босс-бою больше не создается замороженная панель таймера — boss combat flags выставляются до создания HUD, а smoke-тест проверяет фактическое отсутствие `CombatTimerPanel`/`timer_label`.

- Награда элитки: окно выбора 1 из 3 артефактов переоформлено крупными карточками (иконка 112px, название и тир в цвете тира, эффект, классовая интерпретация), центрировано на любом разрешении, выбор обязателен (Escape не закрывает), добавлена навигация клавиатурой/геймпадом (стрелки + Enter); награда гарантированно показывается до экрана докачки даже если элитка пала на последней секунде таймера.

- VFX: боссовский hazard смены фазы переведён с голого красного круга на оформленный HazardVfx (баг QA); 19 эффект-спрайтов перерисованы в приглушённый D&D-стиль (без неона).

- Bugfix: рестайл 6 новых классов (Ассасин/Рейнджер/Доктор/Химик/Рыцарь/Друид) реально подключён в выбор героя — игра загружала placeholder-спрайты вместо принятого арта.

- Чистка проекта: обновлен conservative audit `tools/audit_unused_assets.py`, из `assets/` вынесены obsolete preview/source PNG и временные `.DS_Store`/swap в `build/cleanup_backup_2026_06_12/`; активные фоновые ресурсы `field_dry_road`/`field_stone_garden` восстановлены после missing-resource проверки.

- VFX: DoT-тики на врагах получили искру-маркер; level-up эффект и баннер переведены с программных Polygon2D/ColorRect на текстурные спрайты (вспышка/кольцо/искры); перф на 120 врагах с зонами в норме.

- VFX: лечение игрока получило зелёный восстановительный отклик (пульс+искры) вместо безмолвного хила; подтверждено, что ульты 9 классов уже на оформленном VFX.

- Возвышения 2.0: режим усложнения из 10 кумулятивных уровней (враги/цены/орда/элитки/трофеи/лечение/мини-элитки/таймер/босс/макс-HP), прогресс и разблокировка по персонажу, селектор в выборе героя, HUD-индикатор, раздел кодекса; старые asc-баффы стали наградным треком меты.

- VFX: аура командира-элитки получила визуальный пульс (золотая расходящаяся волна) вместо невидимого бафа.

- Анимация оружия: held-оружие в сокете получило отдачу/выпад/подъём по типу атаки (anticipation→удар→follow-through), снаряды — трейлы; ранее статичные дальнобой/каст-оружия ожили.

- VFX: опасные зоны (боссовские rift/disk-slam и зона смены фазы, элитный яд и лужи) переведены с голых программных кругов на оформленный телеграф→детонацию (HazardVfx) с бурлящими лужами яда.

- Боевые фоны: переотрисованы как профессиональные D&D-батлмапы (2560x1440, top-down) и расширены до 10 активных арен; добавлены 6 новых фонов без крупных камней/кустов (`ruined_courtyard`, `misty_marsh`, `dusty_badlands`, `enchanted_meadow`, `ashen_rift`, `cursed_grove`), подключены в ротацию боев/боссов.

- Баланс классов: добавлен Godot budget harness `tools/balance_harness.gd`, отчет `build/balance_report.md`, профили solo/aoe/balanced+tank для 27 пар класс+оружие, auto budget tuning и smoke-проверка отклонения ≤ ±10% по solo и 5-target DPS.

- Сложность акта: добавлен единый `stage_scale` для силы монстров и цен, усилены обычные волны, элитки получили HP-бюджет под ~45-90с и награду 1 из 3 артефактов, боссы получили 3 HP-фазы с фазовыми hazard-зонами и гарантированный tier-3 артефакт за победу.

- Случайные события: добавлен data-driven пул из 12 сценариев с историями, 2-3 выборами, no-repeat за акт, attribute checks, отдыхом, наградами с ценой и боевыми исходами через временный event combat payload.

- Debug cleanup: убран Godot debug spam `Lambda capture ... was freed` в level-up intro и weapon VFX/deploy callbacks; editor/import, runtime smoke и animation smoke проходят без красных ошибок в свежем Godot log.

- VFX-полировка: persistent pools Химика/Друида больше не программные круги — добавлены растровые `poison_pool`, `spark_pool`, `briar_pool` с мягкой пульсацией/fade-out и QA preview.

- VFX-арт: все 19 PNG в `assets/sprites/effects/` перерисованы в сдержанный D&D/tabletop стиль без кислотного неона и пересветов; preview-лист использовался для QA и затем вынесен из runtime assets чисткой проекта, import + attack/runtime smoke green.

## [0.1.2] — 2026-06-12

- UI: тёплый рестайл интерфейса под D&D-таверну — рамки/панели/кнопки/окна из тёмного дерева и кожи с латунной окантовкой и заклёпками, системные иконки в тёплом золоте, без циановых самоцветов; светлый текст сохранён читаемым.

- Артефакты: старый pictogram/пентаграммный набор заменен на 53 realistic epic D&D/tabletop raster magic item PNG (`256x256`, RGBA, transparent), с предметами по смыслу каждого artifact ID и QA-превью `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png`.

- Оружие v2: перерисованы `long_spear`, `tower_shield`, `holy_flail`, Рыцарь переведен на unarmed base sprite без встроенного копья/щита, все 27 weapon scenes теперь используют matching PNG и уменьшенный visual scale для лучшей читаемости персонажей.

- Design overhaul: добавлен reusable fantasy UI texture kit (`assets/sprites/ui/frames/global/`, system icons), основные панели/кнопки/HUD/level-up/route nodes переведены на texture frames; 4 боевых фона заменены на плоские top-down 2560x1440 ground textures; добавлены отдельные motion profiles для 6 новых классов.

- Новые классы (art pass): 6 полноценных dark fantasy full-art спрайтов персонажей (512x512 RGBA) и 6 weapon PNG (256x256 RGBA) для Ассасина/Рейнджера/Доктора/Химика/Рыцаря/Друида приняты Design-review. Cutout rig-части нарезаны `tools/slice_rig_cutouts.py` и добавлены в `assets/sprites/characters/cutout/`; манифест `scripts/sliced_rig_manifest.gd` обновлён.

- Шесть новых классов (фундамент): Ассасин, Рейнджер, Доктор, Химик, Рыцарь, Друид — статы, сигнатурное оружие с механиками архетипов, релевантность/аффинити/вознесение/кодекс; Design visual set готов: новые герои art-approved, полный набор 27 weapon PNG для 9 классов добавлен в `assets/sprites/weapons/`.

- Полный набор атрибутов: подключены поглощение, регенерация, вампиризм (новый артефакт «Клык Пиявки»), дальность отталкивания, множитель дальности; «Сила ульты» теперь усиливает ultimate ability.

- Настройки v2: выбор монитора при нескольких экранах, честные оконные разрешения (масштаб ОС, центрирование, без вылезания за экран), слайдеры громкости Общая/Музыка/Эффекты с mute-чекбоксами, сохранение в user://settings.cfg.

- UX: выбор героя переведен в fullscreen 3x3 grid без скролла — все 9 классов видны сразу, портреты крупнее, статы перенесены в tooltip/нижнюю панель.

- Классовая идентичность: 9 классов разведены по уникальным паттернам — crit dash Ассасина, stance charge Рейнджера, drain-link Доктора, combo clouds Химика, block/counter Рыцаря и command pets Друида; кодекс и smoke-проверки обновлены.

- Прогрессия: вторичные атрибуты стали универсально полезными для всех классов — старая фильтрация «нерелевантных» статов отключена, level-up/докачка/артефакты показывают иконки и интерпретации, чужие affinity-эффекты работают через class-specific hooks (magic enchant, DoT, echo weapon, battle shout, Energy cooldown/charge scaling).

- Берсерк: data-driven конфиг двуручного меча синхронизирован со сценой и актуальным геймплеем — вместо старой узкой `strip`-полосы теперь используется `frustum`-замах 90° радиусом 600; melee targeting regression test обновлен под новую геометрию.

- Настройки: экран разделен на вкладки «Экран» / «Звук» / «Управление», аудио-слайдеры стали full-width и снова видимы на 1280x720, добавлены persisted keybindings для движения/паузы/`ultimate` с конфликт-чеком и reset defaults.

- Ультимейты: добавлен data-driven framework заряда 0-100 от урона/полученного урона, HUD-шкала `ULT`, активация через ребиндящийся action `ultimate`, boss damage cap и 9 классовых ульт: Неистовство, Темная буря, Соло, Танец клинков, Лунный залп, Переливание, Цепная реакция, Бастион, Зов стаи.

## [0.1.1] — 2026-06-11

- Hotfix сборки: исправлен битый NSIS CRC Windows-инсталлера (makensis на macOS писал неверную контрольную сумму), добавлены SHA256SUMS.txt.

- Прогрессия: классовая релевантность атрибутов (чужие damage-статы не предлагаются и честно отражены в превью), фикс эксплойта бесплатного реролла — наборы level-up и пары докачки фиксируются до выбора.

- Иконки артефактов: финальный Design pass — все 52 активные `artifact_*.png` переведены в `256x256` epic dark fantasy item icons с прозрачным фоном, усиленной светотенью/магическими акцентами и 40px preview; инструмент `tools/final_redesign_artifact_icons.py`.
- Флоу забега: баннер «Победа» после боя, окно докачки атрибутов за золото (1 из 2, reroll x2), желтая FAB-кнопка прокачки на небоевых экранах с бейджем уровней.
- Экономика: цены магазина x3.5; артефакты получили тиры 1-3 (сила x2.5, редкость и цена по тиру), 6 новых легендарных билдообразующих артефактов; классовая совместимость class_affinity с честными пометками в магазине/наградах/HUD/паузе/кодексе.
- Классы/оружие: у всех 9 классов теперь по 3 выбираемых стартовых оружия (27 weapon IDs); добавлены backend-режимы `stab_flurry`, `dot_beam`, `trap`, summon/deploy fallback-сцены и smoke-проверка всех вариантов.

- UX: Escape возвращает назад на всех экранах (единый стек, в бою — пауза), карточки персонажей кликабельны целиком с hover, крупнее картинки в кодексе/HUD/паузе/магазине, pointer-курсор на кнопках, подключение фона карты route_map_backdrop.png с fallback.

- Анимации: вариантные замахи Берсерка под формы оружия (выпад/дуга/верхний слэм), фазовые анимации уникальных атак элиток, переработанный walk Темного Мага.

- Кодекс в главном меню: энциклопедия персонажей, монстров (с каноническими именами умений), артефактов и характеристик.

- Сборочная инфраструктура релизов: Windows-пресет (x86_64, embed_pck, icon.ico), `tools/build_release.sh` (worktree-сборка из тега, dmg + NSIS-инсталлер + zip), `tools/windows_installer.nsi`.

- Усиление элиток: размер x1.35, уникальные телеграфированные атаки.
- HP-бары над всеми монстрами, элитками и боссами: синхронизация с фактическим `health / max_health` после runtime-скейлинга и после урона; ревизия контактных хитбоксов, красная виньетка урона.
- Идентичность оружия Берсерка: меч — узкая полоса, топор — широкая дуга, молот — слабый старт/мощный рост.
- Фикс прицеливания: атака всегда по ближайшему врагу.
- Усиление Темного Мага (2 луча, 2 взрыва), переработка Гитариста (бас — скорость/контроль, амп — деплой с лимитом от Лидерства).
- Артефакты: иконки в HUD/паузе, размещение в магазине на «стене», dark-fantasy рестайл 46 иконок артефактов до 256x256.
- Артефакты: 46 иконок перегенерированы в dark-fantasy стиле элиток/боссов, 256x256 PNG с прозрачным фоном; финальное Design review принято, точечные доработки old_codex/ink_candle/summoners_bell.
- Артефакты: v3 pass — 52 иконки перегенерированы в glossy RPG item style с визуальными тирами 1-3, 256x256 PNG с прозрачным фоном; готово к Design review.
- Артефакты: финальный пользовательский rework — все 52 иконки заменены в яркий, жуткий epic dark fantasy artifact style (черненый металл, кость, руны, трещины, магические акценты), 256x256 PNG с прозрачным фоном.
- Стилизованный таймер боя с красной подсветкой на последних 5 секундах.
- Фоны арены в нативном 2560x1440.
- Жутковатый нейтральный фон маршрутной карты `route_map_backdrop.png` в 2560x1440.
- Полное код-ревью, чистка debug-ошибок и мертвого кода.

## [0.1.0] — 2026-06-11

Первая зафиксированная версия (срез разработки).

- Полный игровой цикл: меню → выбор персонажа и оружия → вертикальная маршрутная карта → бои/события/магазин/костер → финальный босс.
- 3 класса: Берсерк (меч/топор/молот), Темный Маг (книга/череп/палочка), Гитарист (электро/бас/усилитель).
- Монстры, элитки (4), боссы (2), волны по таймеру `30 + 5 * route_stage`.
- Мета-прогрессия: уровни вознесения (10 x 3 персонажа), артефакты (46), характеристики.
- Боевая арена 2560x1440 с камерой, зумом и физическими стенами; 4 биома фонов.
- HUD, экраны паузы/статов, настройки видео и управления.
- Smoke-тесты: runtime, animation, meta progression.
