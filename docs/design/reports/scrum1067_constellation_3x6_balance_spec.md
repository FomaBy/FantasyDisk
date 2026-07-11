# SCRUM-1067 — Созвездия 3×6: баланс-спецификация

Статус: утверждённый design/data contract для реализации в SCRUM-1068. Эта
задача не меняет runtime, UI или арт. Машинный источник истины:
`docs/design/data/scrum1067_weapon_finals_manifest.json`.

## Решение

Каждое из 17 созвездий получает ровно 21 узел:

- одно бесплатное всегда активное ядро с +1 primary characteristic;
- три ветви, строго соответствующие трём `weapon_id` класса;
- пять явных сильных weapon-scoped boons и один уникальный weapon final в
  каждой ветви; каждый из 306 branch nodes содержит `class_id`, точный
  `weapon_id`, order, cost, axis, effect profile, cap, consumer и fixture;
- две скрытые боковые звезды: подвиг сначала раскрывает звезду, после чего она
  покупается за 1 эмблему; скрытая звезда не блокирует путь к финалу.

Полный выкуп стоит `3 × 6 + 2 × 1 = 20`. Все три купленных финала активны
одновременно, но каждый применяется только к собственному `weapon_id`.
Взаимоисключение `active_keystones` для оружейных финалов удаляется в schema 6.

## Канонические трио

| class_id | weapon 1 | weapon 2 | weapon 3 |
| --- | --- | --- | --- |
| `berserk` | `sword` | `axe` | `hammer` |
| `soldier` | `soldier_rifle` | `soldier_grenade` | `soldier_bayonet` |
| `thief` | `thief_coin_pouch` | `thief_shadow_cloak` | `thief_smoke_bomb` |
| `elementalist` | `elementalist_orb_ring` | `elementalist_prism_focus` | `elementalist_meteor_core` |
| `sniper` | `sniper_deadeye_rifle` | `sniper_spotter_scope` | `sniper_shatter_rounds` |
| `priest` | `priest_reliquary` | `priest_censer` | `priest_chime` |
| `biologist` | `biologist_spore_lens` | `biologist_sample_injector` | `biologist_symbiote_seed` |
| `robot` | `robot_magnetic_anchor` | `robot_hydraulic_press` | `robot_reactor_core` |
| `engineer` | `engineer_sentry_wrench` | `engineer_repair_drone` | `engineer_pressure_mines` |
| `dark_mage` | `dark_book` | `cursed_skull` | `dark_wand` |
| `guitarist` | `electric_guitar` | `bass_guitar` | `sound_amp` |
| `assassin` | `chakrams` | `shadow_daggers` | `venom_wire` |
| `ranger` | `moon_crossbow` | `storm_longbow` | `hunter_trap` |
| `doctor` | `restore_potion` | `plague_syringe` | `bone_saw` |
| `chemist` | `blast_powder` | `acid_flask` | `homunculus_vial` |
| `knight` | `long_spear` | `tower_shield` | `holy_flail` |
| `druid` | `summon_amulet` | `briar_staff` | `raven_totem` |

Validator сравнивает эту матрицу с 51 ключом manifest и отклоняет пропуск,
дубль, перестановку или чужой `weapon_id`.

## Before/after per weapon

`Before` — свежий current no-meta gate: solo DPS, calibrated 5-target AoE
DPS, CCT 5/10/20 и EHP/defense. `After` — обязательный design corridor
для SCRUM-1068, ещё не runtime-измерение. Полные absolute values и effect
profiles хранятся рядом с каждой ветвью в machine manifest.

| class/weapon | axis | solo dev | 5T AoE dev | EHP | CCT dev 5/10/20 | after 5/6 | after 6/6 | final vs 5/6 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `berserk/sword` | solo | +0.0% | +0.1% | 120.2 | +2.0% / +6.2% / +13.0% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `berserk/axe` | crowd | +0.0% | +0.0% | 120.2 | +2.0% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `berserk/hammer` | defense | +0.0% | -0.0% | 120.2 | +2.1% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `soldier/soldier_rifle` | defense | -0.0% | -0.0% | 103.1 | +0.0% / +4.2% / +10.9% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `soldier/soldier_grenade` | aoe | +0.0% | +0.0% | 103.1 | -3.9% / +0.1% / +6.5% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `soldier/soldier_bayonet` | solo | -0.0% | +0.0% | 106.0 | +2.0% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `thief/thief_coin_pouch` | crowd | +0.1% | +0.0% | 69.2 | +0.0% / +4.1% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `thief/thief_shadow_cloak` | solo | +0.0% | +0.0% | 69.2 | +0.0% / +4.2% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `thief/thief_smoke_bomb` | defense | +0.0% | -0.0% | 69.2 | -8.4% / -4.6% / +5.6% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `elementalist/elementalist_orb_ring` | aoe | +0.0% | -0.1% | 50.8 | -4.7% / -0.7% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `elementalist/elementalist_prism_focus` | crowd | +0.0% | +0.0% | 50.8 | +2.0% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `elementalist/elementalist_meteor_core` | aoe | +0.0% | +0.0% | 50.8 | -3.9% / +0.1% / +6.5% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `sniper/sniper_deadeye_rifle` | solo | +0.0% | -0.1% | 122.8 | +8.8% / +13.3% / +20.6% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `sniper/sniper_spotter_scope` | solo | +0.0% | +0.0% | 122.8 | +0.0% / +4.1% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `sniper/sniper_shatter_rounds` | crowd | -0.0% | +0.1% | 122.8 | -0.1% / +4.1% / +10.7% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `priest/priest_reliquary` | defense | +0.0% | -0.0% | 85.5 | -4.7% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `priest/priest_censer` | defense | +0.0% | +0.0% | 87.0 | -4.8% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `priest/priest_chime` | crowd | +0.0% | +0.0% | 85.5 | -4.8% / -0.8% / +9.7% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `biologist/biologist_spore_lens` | crowd | +0.0% | +0.0% | 69.4 | -8.4% / -4.6% / +5.5% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `biologist/biologist_sample_injector` | solo | +0.0% | +0.0% | 69.4 | +0.0% / +4.2% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `biologist/biologist_symbiote_seed` | crowd | +0.0% | -0.0% | 69.4 | -4.8% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `robot/robot_magnetic_anchor` | defense | +0.0% | -0.0% | 185.5 | -4.7% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `robot/robot_hydraulic_press` | crowd | +0.0% | -0.0% | 178.6 | +2.1% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `robot/robot_reactor_core` | aoe | -0.0% | +0.0% | 177.0 | +0.0% / +4.2% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `engineer/engineer_sentry_wrench` | solo | +0.0% | +0.0% | 85.0 | +4.1% / +8.5% / +20.0% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `engineer/engineer_repair_drone` | defense | -0.1% | -0.1% | 85.0 | +4.2% / +8.6% / +20.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `engineer/engineer_pressure_mines` | crowd | +0.0% | +0.1% | 85.0 | -8.5% / -4.7% / +5.5% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `dark_mage/dark_book` | aoe | +0.0% | -0.0% | 50.4 | -3.8% / +0.2% / +6.6% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `dark_mage/cursed_skull` | crowd | +0.0% | -0.0% | 50.4 | -4.8% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `dark_mage/dark_wand` | solo | +0.0% | -0.0% | 50.4 | +0.0% / +4.2% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `guitarist/electric_guitar` | solo | +0.0% | +0.0% | 68.0 | -4.8% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `guitarist/bass_guitar` | defense | -0.0% | +0.0% | 68.0 | -4.8% / -0.8% / +9.7% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `guitarist/sound_amp` | crowd | +0.0% | -0.0% | 68.0 | +4.2% / +8.5% / +20.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `assassin/chakrams` | solo | +0.0% | -0.0% | 87.6 | +2.1% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `assassin/shadow_daggers` | defense | +0.0% | -0.0% | 87.6 | +2.1% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `assassin/venom_wire` | solo | +0.1% | -0.2% | 87.6 | +2.2% / +6.5% / +13.3% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `ranger/moon_crossbow` | solo | +0.0% | -0.0% | 68.1 | +0.0% / +4.2% / +10.9% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `ranger/storm_longbow` | crowd | +0.0% | +0.0% | 68.1 | +0.0% / +4.1% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `ranger/hunter_trap` | defense | +0.0% | -0.0% | 68.1 | -4.7% / -0.8% / +9.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `doctor/restore_potion` | defense | -0.1% | -0.0% | 94.0 | -3.8% / +0.2% / +6.6% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `doctor/plague_syringe` | crowd | +0.0% | -0.0% | 87.8 | +0.0% / +4.2% / +10.8% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `doctor/bone_saw` | solo | +0.0% | -0.0% | 95.5 | +2.1% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `chemist/blast_powder` | aoe | -0.0% | +0.0% | 51.2 | -3.9% / +0.1% / +6.5% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `chemist/acid_flask` | crowd | +0.0% | -0.0% | 51.2 | -3.8% / +0.2% / +6.6% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `chemist/homunculus_vial` | defense | -0.0% | +0.0% | 58.2 | +4.1% / +8.5% / +20.0% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `knight/long_spear` | solo | -0.0% | -0.0% | 184.0 | +2.1% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `knight/tower_shield` | defense | -0.0% | +0.0% | 203.3 | +2.0% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `knight/holy_flail` | crowd | -0.0% | +0.0% | 175.7 | +2.0% / +6.3% / +13.1% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `druid/summon_amulet` | solo | +0.2% | -0.1% | 83.9 | +4.3% / +8.7% / +20.2% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `druid/briar_staff` | crowd | +0.0% | +0.0% | 83.9 | -3.9% / +0.1% / +6.5% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |
| `druid/raven_totem` | defense | -0.0% | +0.0% | 83.9 | +4.1% / +8.5% / +20.0% | 1.34–1.66× | 1.60–2.00× | ≥1.20× |

## Текущий baseline и диагноз

Источник: последний полный class-trio closeout
`build/qa/full_class_rebalance/final_class_trio_qa_report.md` и baseline
`docs/design/reports/full_class_rebalance_identity_audit.md`. Исторический
closeout имел худший CCT `doctor/restore_potion/20` `+22%`. Свежий gate от
`origin/dev` для этой спецификации снова проверил все 51 пары: `PASS`, худший
CCT `sniper/sniper_deadeye_rifle/20` `+20.6%`. Оба результата внутри старого
коридора `±30%`; расхождение — обычная смена актуального baseline, а не новая
meta-сила.

| class_id | solo | AoE | crowd | defense raw | total (`defense≤1.50`) | meta-цель |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `berserk` | 1.000 | 1.000 | 0.935 | 1.41 | 1.087 | сохранить melee risk: точный меч / cleave-топор / stagger-молот |
| `soldier` | 1.000 | 1.000 | 0.960 | 1.22 | 1.045 | suppression / delayed AoE / brace-counter |
| `thief` | 1.000 | 1.000 | 0.979 | 0.81 | 0.948 | экономика не заменяет боевую силу; дым ценится как defense |
| `elementalist` | 1.000 | 1.000 | 0.972 | 0.60 | 0.893 | geometry-first AoE без копий grenade |
| `sniper` | 1.000 | 1.000 | 0.928 | 1.44 | 1.093 | solo-сила не получает универсальный full-screen crowd бонус |
| `priest` | 1.000 | 1.000 | 0.978 | 1.05 | 1.006 | heal/ward/chain имеют разные окна и caps |
| `biologist` | 1.000 | 1.000 | 0.991 | 0.82 | 0.953 | rings / sample ramp / web transfer |
| `robot` | 1.000 | 1.000 | 0.960 | 2.12 | 1.115 | контроль учитывается как defense, но не дублируется как damage |
| `engineer` | 1.000 | 1.000 | 0.946 | 1.01 | 0.989 | deploy caps сохраняются, финалы меняют ownership/tempo |
| `dark_mage` | 1.000 | 1.000 | 0.960 | 0.59 | 0.888 | glass AoE: mirror / curse-only / pierce-decay |
| `guitarist` | 1.000 | 1.000 | 0.961 | 0.80 | 0.940 | направленный riff / beat control / deploy echo |
| `assassin` | 1.000 | 1.000 | 0.935 | 1.03 | 0.992 | return / close execute / poison ramp без heal loop |
| `ranger` | 1.000 | 1.000 | 0.953 | 0.80 | 0.939 | charged precision / fan / owned trap |
| `doctor` | 1.000 | 1.000 | 0.887 | 1.18 | 1.016 | только weapon-owned sustain; внешний lifesteal не возвращается |
| `chemist` | 1.000 | 1.000 | 0.963 | 0.63 | 0.898 | reagent combo / pool stack / tank-control summon |
| `knight` | 1.000 | 1.000 | 0.935 | 2.21 | 1.109 | stored/counter force ограничена caps, бессмертие запрещено |
| `druid` | 0.999 | 0.999 | 0.933 | 0.99 | 0.980 | command pack / root zone / support totem |

## After class-trio acceptance targets

Это per-class target table, не выдаваемая за реализованный after. SCRUM-1068
заменяет target значениями измеренных сценариев после runtime integration.

| class_id | before total | after each axis | after total ideal | hard fail | full trio gain | A5 rule |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `berserk` | 1.087 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `soldier` | 1.045 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `thief` | 0.948 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `elementalist` | 0.893 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `sniper` | 1.093 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `priest` | 1.006 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `biologist` | 0.953 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `robot` | 1.115 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `engineer` | 0.989 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `dark_mage` | 0.888 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `guitarist` | 0.940 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `assassin` | 0.992 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `ranger` | 0.939 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `doctor` | 1.016 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `chemist` | 0.898 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `knight` | 1.109 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |
| `druid` | 0.980 | 0.90–1.10 | 0.92–1.08 | 0.85–1.15 | 1.60–1.90× | A5>A0; speedup ≤15% |

Старый schema-5 контракт не подходит:

- 22 узла: core + 12 minor + 4 technique + 3 keystone + 2 hidden;
- стоимость 32; root→keystone стоит `3 + 2 + 4 = 9`;
- обычные звёзды дают примерно `0.53–1.3%`, техники около `0.8%`;
- keystone не имеют `weapon_id`, являются class-wide и взаимоисключающими;
- hidden cost 0 и автоматически активны сразу после подвига;
- доход 28 (`22 + 3×2`), а не целевые 20.

## Сила узлов и ветви

Первые пять узлов каждой из 51 ветви инстанцированы в manifest, а не наследуют
только словесный шаблон. Последовательность отделяет flat base, cadence,
weapon-axis geometry, осевой utility/payoff и prefinal identity; пять effect
keys внутри одной ветви различны. Каждый узел обязан давать измеримый вклад не
ниже `1.08×` на заявленной оси либо механический эквивалент, доказанный своим
уникальным fixture. Голое описание не считается. Если boon использует прямой
flat damage, значение не ниже `+10` и применяется только к собственному оружию.
Ориентиры:

- attack speed `≥8%`;
- radius/area `≥12%`;
- crit chance `≥5 п.п.`;
- EHP/HP `≥10%`;
- target/cadence/control/sustain hook — измеримый эквивалент `≥8%`.

Шестой узел — mechanic-first final. Он даёт `≥1.20×` относительно того же пути
`5/6`, а полный путь попадает в `1.60–2.00×` своей оси. Целевой коридор 5/6 —
`1.34–1.66×`: он позволяет final floor `1.20×` закончить внутри 6/6 corridor.
Generic multiplier-only final запрещён. Все 51 hook, caps, существующий runtime
consumer, positive fixture и два negative-control записаны в manifest.

Обе hidden stars каждого класса также являются явными cost-1 weapon-scoped
effect profiles. `reveal.reveals_only=true` и
`purchase_required_for_effect=true` разделяют открытие и применение; каждый из
34 hidden fixtures доказывает `≥1.08×` на своей оси.

## Модель class-trio

Для оружия:

```text
solo_ratio   = measured_solo_dps / target_solo_dps
aoe_ratio    = measured_5_target_dps / target_5_target_dps
crowd_ratio  = mean(target_CCT_N / measured_CCT_N), N ∈ {5,10,20}
defense_ratio = implemented_defense_value / target_defense_value
```

Контроль, absorb, guard, knockback, summon body-blocking и sustain считаются
только если реализованы и доказуемо снижают входящий урон. Один эффект нельзя
одновременно полностью посчитать как damage и defense.

Для класса:

```text
class_axis = mean(axis_ratio трёх оружий)
defense_for_total = min(class_defense_axis, 1.50)
class_total = mean(solo, aoe, crowd, defense_for_total)
```

`1.50` — явный compatibility cap из baseline SCRUM-856: raw defense Робота
`2.12` и Рыцаря `2.21` всё равно публикуется и проверяется survivability gates,
но не позволяет tank-идентичности одной осью поглотить весь trio score. Поэтому
baseline totals `1.115` и `1.109` арифметически используют `1.50`, а не скрыто
подставляют raw defense. Cap не ослабляет проверку бессмертия/TTD.

Итоговые коридоры:

- каждый class-axis: идеал `±10%` от roster target;
- class-total: идеал `±8%`, hard fail `±15%`;
- `max(class_total) / min(class_total) ≤ 1.15`;
- средний gain полного трио `1.60–1.90`;
- оружие не может доминировать одновременно по solo, AoE/crowd и defense;
- ни одно из 51 оружия не может быть dead slot.

Обязательные сценарии: `no_meta`, каждая ветвь `5/6`, каждая ветвь `6/6`, три
ветви `6/6` одновременно, полный `20/20` с hidden, live A5.

## A5 и anti-runaway

Полный meta-слой компенсирует давление, но не отменяет его:

- A5 остаётся сложнее A0;
- A5 с `20/20` не завершает контрольный бой быстрее A0 baseline более чем на
  `15%`;
- defense/sustain не создают immortality, permanent immunity или control loop;
- deploy/summon caps, Doctor/Priest sustain caps и target falloff сохраняются;
- negative-control двух чужих оружий класса обязан быть нулевым в пределах
  числового epsilon.

## Экономика schema 6

Первые клиры A0..A5 дают `[2,2,3,4,4,5] = 20`. Повторный клир не даёт валюту.
Классовые челленджи больше не дают spendable sigils: они только раскрывают
hidden. Это отделяет currency от discovery и гарантирует полный честный выкуп.

Миграция schema 5→6:

1. Полный респек старых constellation allocations.
2. Сохраняются ascension awards/levels, wins, challenge progress/completions и
   факты reveal.
3. `active_keystones` удаляется.
4. Spendable sigils пересчитываются и capped на 20.
5. `max(schema5_earned - 20, 0)` сохраняется как `legacy_mastery[class_id]` —
   постоянный non-combat prestige/badge, без влияния на stardust или силу.
6. Миграция идемпотентна по `constellation_schema6_migrated`.

`legacy_mastery` — осознанная компенсация: старый прогресс не исчезает молча,
но не ломает новый закрытый бюджет 20 и Guild Atlas economy.

## Runtime handoff для SCRUM-1068

Нужны отдельные слои:

1. `meta_progression_tree_data` строит три weapon-owned branches и hidden side
   edges из manifest-derived data.
2. `meta_progression` разделяет reveal и purchase, мигрирует schema, хранит
   `legacy_mastery`, не сериализует `active_keystones`.
3. Новый API уровня `skill_modifiers_for_weapon(state,class_id,weapon_id)`
   возвращает только core + общие безопасные class modifiers + owning branch.
4. `ProgressionData.weapon`, Player/ClassWeapon и специализированные weapon
   consumers применяют scoped boons/final profile только при совпадении
   `weapon_id`.
5. Final registry обязан иметь consumer для каждого `mechanic_id`; неизвестный
   или no-op hook — hard test failure.

### Effect-key / consumer gaps

| Gap | Нужный контракт SCRUM-1068 |
| --- | --- |
| class-wide aggregation only | per-weapon modifier API и negative-control |
| `damage_flat` не weapon-scoped | `weapon_damage_flat`/typed scoped profile |
| только float `effects` | typed `final_profile` с mechanic_id, params, caps |
| `active_keystones` | три owning finals без toggle/exclusive group |
| hidden auto-active | `revealed` отдельно от `purchased` |
| generic Player maps | специализированный consumer или проверенный generic subsystem |
| нет 51-fixture registry | 51 positive + 102 negative behavioral matrix |

## Dependencies

- SCRUM-1067 — единственный источник balance/data требований для SCRUM-1068.
- SCRUM-1070 должен закончить footer/respec geometry до большого Atlas UI pass.
- SCRUM-1069 меняет только Guild Atlas; class constellation IDs и 20-point
  economy он не переопределяет.
- SCRUM-1068 интегрирует результат поверх SCRUM-1070 и SCRUM-1069 и использует
  UI Director до изменения topology/layout. SCRUM-1067 не требует PixelLab.

## Проверка design contract

```bash
python3 tools/validate_scrum1067_constellation_spec.py
python3 tools/test_validate_scrum1067_constellation_spec.py
python3 -m json.tool docs/design/data/scrum1067_weapon_finals_manifest.json
```

Validator требует 17 canonical classes, 306 explicit branch nodes, 51
уникальный weapon/final/mechanic, 34 hidden, точную арифметику 21/20, caps,
positive fixtures и exact negative controls. Отдельный mutation gate принимает
canonical manifest и отклоняет critical topology/economy/profile/final/baseline
corruption; approved final и no-meta baseline projections закреплены SHA-256.
