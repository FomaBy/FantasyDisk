# SCRUM-962 Artifact Icons QA — 100 NEW иконок редизайна артефактов

- Генератор: OpenAI Images API (`gpt-image-2`, quality high) через `~/.codex/skills/fantasydisk-asset-generator/scripts/generate_asset.py`, батч-обвязка `tools/build_scrum962_artifact_icons.py` (workers 4, чанки по 25).
- **Явный override PixelLab-first правила**: тикет несёт метку `openai-image-generator`; прецедент — SCRUM-690 (`docs/design/reports/artifact_icons_triggered_openai_qa.md`); стиль существующего пака (71 иконка) создан этим же пайплайном — единство стиля требует того же генератора.
- **Оркестраторский override §7.3 матрицы**: удаление 17 легаси-иконок ПЕРЕНЕСЕНО в SCRUM-961 (атомарно с данными). Здесь только +100 новых; 54 REUSE не тронуты.
- Промпт-шаблон: D&D + Dark Fantasy Dragon game icon, isolated artifact, transparent background, no frame/text/letters/numbers/panel/watermark/cropping (полный текст — в `prompt_notes.md` каждого референса).
- Постпроцесс на иконку: удаление запечённого матта (border-connected flood fill) при отсутствии реальной альфы -> крупнейшая альфа-компонента -> кроп по bbox -> вписывание в 256x256 RGBA (субъект <=200px, паддинг ~28px) -> рантайм PNG.
- Манифест/мотивы: `docs/design/references/icons/artifacts/scrum962_icons_manifest.json` (style notes дословно из §2.2/§4 `docs/design/systems/artifact_system_matrix.md`; для 7 перегенераций мотив уточнён void-free формулировкой, см. ниже).
- Стиль-якорь сверен по `artifact_field_kit.png`, `artifact_guardian_bulwark.png`, `artifact_sharp_talisman.png`.

## Перегенерации (выбраковка)

Единственный систематический дефект генератора — запечённая «шахматка прозрачности» в замкнутых полостях предмета (border flood-fill её не достаёт). Лечится void-free мотивом. Перегенерировано 7 id (13 доп. вызовов API):

- `root_snare`: x2 (шахматка в открытом зеве -> сомкнутые челюсти)
- `return_arc_rune`: x2 (шахматка в отверстии чакрама -> сплошной диск)
- `impact_string`: x3 (шахматка в зазоре лук/тетива -> катушка тетивы на браслете)
- `feedback_loop`: x2 (шахматка внутри петли -> плотный клубок без зазоров)
- `drone_gyroscope`: x3 (шахматка между кольцами -> энерго-сфера заполняет интерьер)
- `elemental_recoil`: x1 (шахматка в отверстии кольца -> энергия заполняет центр)
- `anchor_core`: x1 (шахматка в петле стружки -> стружка на поверхности сферы)

Модерация OpenAI не отбила ни один промпт (включая «blood-soaked» crimson_grip и «bloody teeth» bonesaw_teeth). Фейлов генерации нет: 100/100.

## Иконки (все 100)

Паддинг и corner-alpha пересчитаны с финальных рантайм-PNG; readability — визуальная приёмка контакт-щитов (ряд 40px) + full-size выборки.

| ID | Runtime path | Size/mode | Padding L/T/R/B | Corner alpha max | SHA1-12 | 32/40/64 readable |
| --- | --- | --- | --- | --- | --- | --- |
| `battle_fan` | `assets/sprites/ui/icons/artifacts/artifact_battle_fan.png` | 256x256 RGBA | 33/29/32/29 | 0 | `52b3ac67cc27` | PASS |
| `iron_scale` | `assets/sprites/ui/icons/artifacts/artifact_iron_scale.png` | 256x256 RGBA | 63/29/63/28 | 0 | `de7a86b4d84c` | PASS |
| `arcane_prism` | `assets/sprites/ui/icons/artifacts/artifact_arcane_prism.png` | 256x256 RGBA | 73/29/74/29 | 0 | `2ddabc211e1c` | PASS |
| `ram_horn` | `assets/sprites/ui/icons/artifacts/artifact_ram_horn.png` | 256x256 RGBA | 74/28/75/29 | 0 | `1f3f21138c69` | PASS |
| `executioner_edge` | `assets/sprites/ui/icons/artifacts/artifact_executioner_edge.png` | 256x256 RGBA | 54/28/54/28 | 0 | `5142dfd9bdc4` | PASS |
| `ghost_ribbon` | `assets/sprites/ui/icons/artifacts/artifact_ghost_ribbon.png` | 256x256 RGBA | 73/29/75/29 | 0 | `febca835b1f0` | PASS |
| `venom_vial` | `assets/sprites/ui/icons/artifacts/artifact_venom_vial.png` | 256x256 RGBA | 66/29/67/29 | 0 | `40c651f9a18c` | PASS |
| `plague_metronome` | `assets/sprites/ui/icons/artifacts/artifact_plague_metronome.png` | 256x256 RGBA | 62/29/64/28 | 0 | `dd501fecd107` | PASS |
| `falcon_feather` | `assets/sprites/ui/icons/artifacts/artifact_falcon_feather.png` | 256x256 RGBA | 28/29/29/29 | 0 | `0a896a4d3ed3` | PASS |
| `wide_halo` | `assets/sprites/ui/icons/artifacts/artifact_wide_halo.png` | 256x256 RGBA | 60/29/61/29 | 0 | `79c99db79ac5` | PASS |
| `war_banner` | `assets/sprites/ui/icons/artifacts/artifact_war_banner.png` | 256x256 RGBA | 79/29/79/28 | 0 | `16b94606ce2b` | PASS |
| `aegis_shard` | `assets/sprites/ui/icons/artifacts/artifact_aegis_shard.png` | 256x256 RGBA | 77/29/77/28 | 0 | `85c0b58ccded` | PASS |
| `troll_blood` | `assets/sprites/ui/icons/artifacts/artifact_troll_blood.png` | 256x256 RGBA | 69/29/70/29 | 0 | `5a40b2e54904` | PASS |
| `thirsty_ruby` | `assets/sprites/ui/icons/artifacts/artifact_thirsty_ruby.png` | 256x256 RGBA | 68/29/68/29 | 0 | `a9064e4c5b15` | PASS |
| `overcharge_rune` | `assets/sprites/ui/icons/artifacts/artifact_overcharge_rune.png` | 256x256 RGBA | 68/28/68/28 | 0 | `3c0c4ffa924b` | PASS |
| `perfect_edge` | `assets/sprites/ui/icons/artifacts/artifact_perfect_edge.png` | 256x256 RGBA | 103/29/102/29 | 0 | `b1e5bea21430` | PASS |
| `shadow_twin` | `assets/sprites/ui/icons/artifacts/artifact_shadow_twin.png` | 256x256 RGBA | 48/29/48/29 | 0 | `09a32f74505f` | PASS |
| `venom_spool` | `assets/sprites/ui/icons/artifacts/artifact_venom_spool.png` | 256x256 RGBA | 54/28/55/29 | 0 | `66253f441aa0` | PASS |
| `evasion_shroud` | `assets/sprites/ui/icons/artifacts/artifact_evasion_shroud.png` | 256x256 RGBA | 60/29/60/29 | 0 | `d010fff24f04` | PASS |
| `return_arc_rune` | `assets/sprites/ui/icons/artifacts/artifact_return_arc_rune.png` | 256x256 RGBA | 29/29/29/29 | 0 | `80f08a21dd17` | PASS |
| `crimson_grip` | `assets/sprites/ui/icons/artifacts/artifact_crimson_grip.png` | 256x256 RGBA | 84/28/85/29 | 0 | `0d9db928c133` | PASS |
| `spectral_axe` | `assets/sprites/ui/icons/artifacts/artifact_spectral_axe.png` | 256x256 RGBA | 72/29/72/29 | 0 | `89c3343555e9` | PASS |
| `hammer_weight` | `assets/sprites/ui/icons/artifacts/artifact_hammer_weight.png` | 256x256 RGBA | 51/29/52/29 | 0 | `9ab602c81c4b` | PASS |
| `blood_roar` | `assets/sprites/ui/icons/artifacts/artifact_blood_roar.png` | 256x256 RGBA | 31/29/30/29 | 0 | `8e267af9028a` | PASS |
| `last_onslaught` | `assets/sprites/ui/icons/artifacts/artifact_last_onslaught.png` | 256x256 RGBA | 35/28/35/29 | 0 | `5ad2c60869a6` | PASS |
| `spore_capacitor` | `assets/sprites/ui/icons/artifacts/artifact_spore_capacitor.png` | 256x256 RGBA | 51/29/52/29 | 0 | `624fdd494648` | PASS |
| `sample_chain` | `assets/sprites/ui/icons/artifacts/artifact_sample_chain.png` | 256x256 RGBA | 59/28/60/28 | 0 | `9899b086a10d` | PASS |
| `symbiote_sheath` | `assets/sprites/ui/icons/artifacts/artifact_symbiote_sheath.png` | 256x256 RGBA | 65/29/66/29 | 0 | `220e0a1748b6` | PASS |
| `inhibitor_colony` | `assets/sprites/ui/icons/artifacts/artifact_inhibitor_colony.png` | 256x256 RGBA | 29/29/30/29 | 0 | `e8f5481034a9` | PASS |
| `split_analysis` | `assets/sprites/ui/icons/artifacts/artifact_split_analysis.png` | 256x256 RGBA | 60/29/62/29 | 0 | `e396c5b0900f` | PASS |
| `lucky_coin` | `assets/sprites/ui/icons/artifacts/artifact_lucky_coin.png` | 256x256 RGBA | 28/28/29/29 | 0 | `df6fa7375135` | PASS |
| `magnetic_purse` | `assets/sprites/ui/icons/artifacts/artifact_magnetic_purse.png` | 256x256 RGBA | 57/29/59/28 | 0 | `82477930933f` | PASS |
| `paralyzing_blade` | `assets/sprites/ui/icons/artifacts/artifact_paralyzing_blade.png` | 256x256 RGBA | 58/28/60/29 | 0 | `ab3820f29245` | PASS |
| `smoke_cache` | `assets/sprites/ui/icons/artifacts/artifact_smoke_cache.png` | 256x256 RGBA | 49/29/50/29 | 0 | `aa738ea34b55` | PASS |
| `stolen_crest` | `assets/sprites/ui/icons/artifacts/artifact_stolen_crest.png` | 256x256 RGBA | 47/29/47/29 | 0 | `7cba761b4e45` | PASS |
| `overdrive_pick` | `assets/sprites/ui/icons/artifacts/artifact_overdrive_pick.png` | 256x256 RGBA | 45/28/45/29 | 0 | `fcaee561efd2` | PASS |
| `bass_resonator` | `assets/sprites/ui/icons/artifacts/artifact_bass_resonator.png` | 256x256 RGBA | 57/29/58/29 | 0 | `227eb6c59e9b` | PASS |
| `stage_amplifier` | `assets/sprites/ui/icons/artifacts/artifact_stage_amplifier.png` | 256x256 RGBA | 42/28/43/29 | 0 | `2c60684f40f9` | PASS |
| `feedback_loop` | `assets/sprites/ui/icons/artifacts/artifact_feedback_loop.png` | 256x256 RGBA | 29/29/29/29 | 0 | `62d4bf0a08c7` | PASS |
| `rhythm_counter` | `assets/sprites/ui/icons/artifacts/artifact_rhythm_counter.png` | 256x256 RGBA | 55/29/56/29 | 0 | `815620009e59` | PASS |
| `surgical_oath` | `assets/sprites/ui/icons/artifacts/artifact_surgical_oath.png` | 256x256 RGBA | 76/29/76/28 | 0 | `4f0e5d22259f` | PASS |
| `bonesaw_teeth` | `assets/sprites/ui/icons/artifacts/artifact_bonesaw_teeth.png` | 256x256 RGBA | 29/29/31/28 | 0 | `393884c43981` | PASS |
| `plague_carrier` | `assets/sprites/ui/icons/artifacts/artifact_plague_carrier.png` | 256x256 RGBA | 49/29/50/29 | 0 | `c746f22bc172` | PASS |
| `restorative_vapor` | `assets/sprites/ui/icons/artifacts/artifact_restorative_vapor.png` | 256x256 RGBA | 71/28/73/29 | 0 | `4c7456425f78` | PASS |
| `triage_protocol` | `assets/sprites/ui/icons/artifacts/artifact_triage_protocol.png` | 256x256 RGBA | 69/28/69/29 | 0 | `d51ca8761700` | PASS |
| `spirit_pack_banner` | `assets/sprites/ui/icons/artifacts/artifact_spirit_pack_banner.png` | 256x256 RGBA | 70/28/69/28 | 0 | `c7591a3c4323` | PASS |
| `wolf_call` | `assets/sprites/ui/icons/artifacts/artifact_wolf_call.png` | 256x256 RGBA | 69/29/70/29 | 0 | `3012d41afa94` | PASS |
| `blue_totem` | `assets/sprites/ui/icons/artifacts/artifact_blue_totem.png` | 256x256 RGBA | 44/28/43/28 | 0 | `700b7c531779` | PASS |
| `briar_seal` | `assets/sprites/ui/icons/artifacts/artifact_briar_seal.png` | 256x256 RGBA | 47/29/47/29 | 0 | `c932409b516f` | PASS |
| `pack_alpha` | `assets/sprites/ui/icons/artifacts/artifact_pack_alpha.png` | 256x256 RGBA | 56/28/56/29 | 0 | `5140a01ea60f` | PASS |
| `turret_magazine` | `assets/sprites/ui/icons/artifacts/artifact_turret_magazine.png` | 256x256 RGBA | 29/29/31/28 | 0 | `de19d1c2d5c1` | PASS |
| `drone_gyroscope` | `assets/sprites/ui/icons/artifacts/artifact_drone_gyroscope.png` | 256x256 RGBA | 37/28/38/28 | 0 | `16fb3a3b640d` | PASS |
| `mine_satchel` | `assets/sprites/ui/icons/artifacts/artifact_mine_satchel.png` | 256x256 RGBA | 39/29/40/29 | 0 | `a28f57698cff` | PASS |
| `field_blueprint` | `assets/sprites/ui/icons/artifacts/artifact_field_blueprint.png` | 256x256 RGBA | 29/46/28/48 | 0 | `4786b945703b` | PASS |
| `salvage_core` | `assets/sprites/ui/icons/artifacts/artifact_salvage_core.png` | 256x256 RGBA | 42/28/42/29 | 0 | `638ed6ca9221` | PASS |
| `impact_string` | `assets/sprites/ui/icons/artifacts/artifact_impact_string.png` | 256x256 RGBA | 35/29/35/29 | 0 | `7154f47f5b11` | PASS |
| `moon_splitter` | `assets/sprites/ui/icons/artifacts/artifact_moon_splitter.png` | 256x256 RGBA | 44/29/44/28 | 0 | `bfa19b296cee` | PASS |
| `storm_piercer` | `assets/sprites/ui/icons/artifacts/artifact_storm_piercer.png` | 256x256 RGBA | 78/29/79/29 | 0 | `40ee2f1f125b` | PASS |
| `root_snare` | `assets/sprites/ui/icons/artifacts/artifact_root_snare.png` | 256x256 RGBA | 34/29/36/29 | 0 | `3e17d24546fb` | PASS |
| `hunters_mark` | `assets/sprites/ui/icons/artifacts/artifact_hunters_mark.png` | 256x256 RGBA | 47/29/46/28 | 0 | `40da4fb70549` | PASS |
| `armor_protocol` | `assets/sprites/ui/icons/artifacts/artifact_armor_protocol.png` | 256x256 RGBA | 36/28/35/29 | 0 | `3412fb1f09dc` | PASS |
| `anchor_core` | `assets/sprites/ui/icons/artifacts/artifact_anchor_core.png` | 256x256 RGBA | 57/29/57/29 | 0 | `4e45c2ccdb55` | PASS |
| `press_calibrator` | `assets/sprites/ui/icons/artifacts/artifact_press_calibrator.png` | 256x256 RGBA | 54/29/54/28 | 0 | `26824daafbe5` | PASS |
| `reactor_chronometer` | `assets/sprites/ui/icons/artifacts/artifact_reactor_chronometer.png` | 256x256 RGBA | 41/29/41/29 | 0 | `37909a51c7cd` | PASS |
| `repair_subroutine` | `assets/sprites/ui/icons/artifacts/artifact_repair_subroutine.png` | 256x256 RGBA | 65/29/65/29 | 0 | `b6d502209529` | PASS |
| `rebound_plate` | `assets/sprites/ui/icons/artifacts/artifact_rebound_plate.png` | 256x256 RGBA | 58/29/58/28 | 0 | `5b31df478017` | PASS |
| `triple_thrust` | `assets/sprites/ui/icons/artifacts/artifact_triple_thrust.png` | 256x256 RGBA | 59/28/60/29 | 0 | `e3c7408c1449` | PASS |
| `tower_slam` | `assets/sprites/ui/icons/artifacts/artifact_tower_slam.png` | 256x256 RGBA | 54/29/54/28 | 0 | `9b4b08f43474` | PASS |
| `holy_chain` | `assets/sprites/ui/icons/artifacts/artifact_holy_chain.png` | 256x256 RGBA | 65/28/66/28 | 0 | `fe07f5aafca8` | PASS |
| `vanguard_oath` | `assets/sprites/ui/icons/artifacts/artifact_vanguard_oath.png` | 256x256 RGBA | 82/29/81/29 | 0 | `f50b907f65b4` | PASS |
| `prayer_beads` | `assets/sprites/ui/icons/artifacts/artifact_prayer_beads.png` | 256x256 RGBA | 67/29/68/29 | 0 | `4921c1449525` | PASS |
| `reliquary_salvo` | `assets/sprites/ui/icons/artifacts/artifact_reliquary_salvo.png` | 256x256 RGBA | 68/29/68/29 | 0 | `e25ecb479379` | PASS |
| `censer_vow` | `assets/sprites/ui/icons/artifacts/artifact_censer_vow.png` | 256x256 RGBA | 57/28/57/29 | 0 | `16723674adff` | PASS |
| `twin_bell` | `assets/sprites/ui/icons/artifacts/artifact_twin_bell.png` | 256x256 RGBA | 42/29/42/29 | 0 | `4f4282c9958f` | PASS |
| `martyr_shroud` | `assets/sprites/ui/icons/artifacts/artifact_martyr_shroud.png` | 256x256 RGBA | 80/29/80/29 | 0 | `872140b3233d` | PASS |
| `longshot_scope` | `assets/sprites/ui/icons/artifacts/artifact_longshot_scope.png` | 256x256 RGBA | 28/62/29/63 | 0 | `a4684bb98f7f` | PASS |
| `deadeye_round` | `assets/sprites/ui/icons/artifacts/artifact_deadeye_round.png` | 256x256 RGBA | 95/29/96/29 | 0 | `d95f7fd2213e` | PASS |
| `spotter_mark` | `assets/sprites/ui/icons/artifacts/artifact_spotter_mark.png` | 256x256 RGBA | 29/34/28/35 | 0 | `1ee9663ae419` | PASS |
| `shatter_drum` | `assets/sprites/ui/icons/artifacts/artifact_shatter_drum.png` | 256x256 RGBA | 29/31/29/31 | 0 | `5f5add6d7f21` | PASS |
| `clean_line` | `assets/sprites/ui/icons/artifacts/artifact_clean_line.png` | 256x256 RGBA | 80/28/81/29 | 0 | `57ade72ff21b` | PASS |
| `second_volley` | `assets/sprites/ui/icons/artifacts/artifact_second_volley.png` | 256x256 RGBA | 46/29/46/29 | 0 | `aa420bab0699` | PASS |
| `arquebus_shrapnel` | `assets/sprites/ui/icons/artifacts/artifact_arquebus_shrapnel.png` | 256x256 RGBA | 29/36/29/37 | 0 | `176ab5123bda` | PASS |
| `long_fuse` | `assets/sprites/ui/icons/artifacts/artifact_long_fuse.png` | 256x256 RGBA | 46/29/47/29 | 0 | `4049945c0251` | PASS |
| `bayonet_trigger` | `assets/sprites/ui/icons/artifacts/artifact_bayonet_trigger.png` | 256x256 RGBA | 28/39/28/38 | 0 | `97166ca59d3a` | PASS |
| `battle_doctrine` | `assets/sprites/ui/icons/artifacts/artifact_battle_doctrine.png` | 256x256 RGBA | 44/29/45/29 | 0 | `d5aecb11acd0` | PASS |
| `chain_wand` | `assets/sprites/ui/icons/artifacts/artifact_chain_wand.png` | 256x256 RGBA | 90/28/92/28 | 0 | `8229d90a0039` | PASS |
| `curse_font` | `assets/sprites/ui/icons/artifacts/artifact_curse_font.png` | 256x256 RGBA | 56/28/56/29 | 0 | `8a47400f8975` | PASS |
| `mirror_page` | `assets/sprites/ui/icons/artifacts/artifact_mirror_page.png` | 256x256 RGBA | 46/29/47/29 | 0 | `25cbb2dd3b1a` | PASS |
| `void_hunger` | `assets/sprites/ui/icons/artifacts/artifact_void_hunger.png` | 256x256 RGBA | 46/29/46/29 | 0 | `515327cb4f81` | PASS |
| `black_bargain` | `assets/sprites/ui/icons/artifacts/artifact_black_bargain.png` | 256x256 RGBA | 63/29/65/29 | 0 | `0d427446d293` | PASS |
| `volatile_dust` | `assets/sprites/ui/icons/artifacts/artifact_volatile_dust.png` | 256x256 RGBA | 37/29/38/29 | 0 | `d470abd629b7` | PASS |
| `acid_catalyst` | `assets/sprites/ui/icons/artifacts/artifact_acid_catalyst.png` | 256x256 RGBA | 71/29/70/29 | 0 | `f93175b0499d` | PASS |
| `clear_acid` | `assets/sprites/ui/icons/artifacts/artifact_clear_acid.png` | 256x256 RGBA | 72/29/73/29 | 0 | `b09f7c5b1cb1` | PASS |
| `tank_homunculus` | `assets/sprites/ui/icons/artifacts/artifact_tank_homunculus.png` | 256x256 RGBA | 38/28/37/29 | 0 | `ac0a88d78e3a` | PASS |
| `reactor_homunculus` | `assets/sprites/ui/icons/artifacts/artifact_reactor_homunculus.png` | 256x256 RGBA | 75/29/77/29 | 0 | `e67239fda7ed` | PASS |
| `fourth_ring` | `assets/sprites/ui/icons/artifacts/artifact_fourth_ring.png` | 256x256 RGBA | 38/29/37/29 | 0 | `fe4a5552e1aa` | PASS |
| `prismatic_cross` | `assets/sprites/ui/icons/artifacts/artifact_prismatic_cross.png` | 256x256 RGBA | 64/28/63/29 | 0 | `ee5e3af88dcd` | PASS |
| `meteor_heart` | `assets/sprites/ui/icons/artifacts/artifact_meteor_heart.png` | 256x256 RGBA | 63/28/64/29 | 0 | `8a65278bcccc` | PASS |
| `mana_overflow` | `assets/sprites/ui/icons/artifacts/artifact_mana_overflow.png` | 256x256 RGBA | 65/29/66/29 | 0 | `b9276ae99dfa` | PASS |
| `elemental_recoil` | `assets/sprites/ui/icons/artifacts/artifact_elemental_recoil.png` | 256x256 RGBA | 52/28/52/29 | 0 | `f172e140f00f` | PASS |

## Дубль- и альфа-чеки

- SHA1-дубликаты среди 100 новых: **нет**.
- SHA1-дубликаты по всей директории (171 PNG, включая 71 существующую): **нет** (проверка встроена в батч-скрипт + отдельный прогон после ребейза — 15 placeholder-PNG от SCRUM-960 замещены реальными генерациями, дублей-доноров не осталось).
- Все 100 финалов: 256x256 RGBA, corner alpha = 0, прозрачность вне субъекта, паддинг >=28px по вертикали (широкие предметы — больше по горизонтали, ожидаемо).
- Запрещённый контент: текст/цифры/рамки/панели/ватермарки — не обнаружены (визуальная приёмка всех чанков + full-size выборок; прицельная сетка longshot_scope — элемент линзы, не текст).
- Именование: все 100 — `artifact_<canonical_id>.png`, id дословно из матрицы SCRUM-959.
- Чистка iCloud-дублей «artifact_<id> 2.png» (артефакт синка ~/Documents во время rebase): 136 untracked-файлов удалены, в коммиты не попали.

## Contact sheets

- Универсалы (15): `docs/design/previews/artifact_icons_scrum962_universal_contact.png` (96px + 40px ряд)
- Классовые (85): `docs/design/previews/artifact_icons_scrum962_class_contact.png` (96px + 40px ряд)

## Автоматическая шахматка-проверка

Свип-детектор интерливинга светло-серых/белых зон внутри альфы по всем 100: финально флагует только `censer_vow` (живописный дым кадила) и `prismatic_cross` (световые лучи) — приняты, регулярной сетки нет (full-size ревью).

## Checks

- PASS: `python3 tools/godot_gate.py --headless --path . --import` — .import сайдкары созданы; 100/100 новых PNG имеют пару `.png.import`.
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/no_duplicate_artifact_files_test.gd` — «Duplicate-artifact guard passed (просканировано 15203 файлов...)».
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/asset_reference_integrity_test.gd` — «Asset reference integrity test passed (195 файлов, 2406 уникальных res://-ссылок)».
- INFO (не гейт до 960/961-данных): `python3 tools/validate_artifact_icons.py` — предупреждения detached components только по 3 легаси-иконкам SCRUM-690 (chain_spark, soul_harvest, second_wind); по 100 новым замечаний нет.

## Locked paths

- `assets/sprites/ui/icons/artifacts/artifact_<100 новых id>.png` (+`.png.import`)
- `docs/design/references/icons/artifacts/<100 id>/` + `scrum962_icons_manifest.json` (+`.result.json`)
- `docs/design/previews/artifact_icons_scrum962_{universal,class}_contact.png`
- `docs/design/reports/artifact_icons_scrum962_qa.md`
