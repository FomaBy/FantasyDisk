# FAN-3983 built-bytes combat check: FAN-3977 metrics + FAN-3981 M3 object count (new 0.3.1 PCK under the Godot 4.7 editor engine binary, --main-pack, windowed gl_compatibility, 2560x1440, vsync 120 Hz)

Driver: unchanged `evidence/FAN-3981/perf_driver.gd` (SHA-256 `2a386cddcb42089a147adde5efe2627fe80d19855d37d510749ce718c7ef2065`). Hard limits P2 <= 6,250 / P3 <= 5,000; checklist targets P2 <= 5,000 / P3 <= 4,000 (preliminary, FAN-2799 baseline pending).

| run (class) | boss mode | phase | s | avg FPS | 1% low | >50 ms | >100 ms | longest ms | peak tex MiB | objects peak | objects min | first s | last s | packs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| new031_berserk_natural (berserk) | natural | p1_main_menu | 20 | 120 | 119 | 0 | 0 | 16.2 | 172 | 2234 | 2232 | 2234 | 2234 | 0 -> 0 |
| new031_berserk_natural (berserk) | natural | route_map_first_show | 8 | 119 | 113 | 0 | 0 | 18.0 | 1315 | 2736 | 2604 | 2726 | 2726 | 0 -> 23 |
| new031_berserk_natural (berserk) | natural | p2_48_enemies | 60 | 140 | 110 | 1 | 0 | 83.7 | 1407 | 4051 | 2577 | 3125 | 3700 | 23 -> 23 |
| new031_berserk_natural (berserk) | natural | route_map_after_p2 | 3 | 141 | 132 | 1 | 1 | 106.1 | 1358 | 2910 | 2499 | 2503 | 2585 | 23 -> 23 |
| new031_berserk_natural (berserk) | natural | elite_night_stalker | 20 | 141 | 138 | 0 | 0 | 39.8 | 951 | 3870 | 2738 | 3159 | 3690 | 14 -> 14 |
| new031_berserk_natural (berserk) | natural | route_map_after_elite | 3 | 144 | 141 | 0 | 0 | 46.0 | 875 | 2897 | 2485 | 2489 | 2560 | 14 -> 14 |
| new031_berserk_natural (berserk) | natural | p3_boss_act1_rift_warden | 60 | 145 | 144 | 0 | 0 | 19.3 | 920 | 3242 | 2764 | 2802 | 3209 | 14 -> 14 |
| new031_berserk_natural (berserk) | natural | route_map_after_boss1 | 3 | 145 | 145 | 0 | 0 | 8.1 | 865 | 2957 | 2573 | 2577 | 2573 | 14 -> 14 |
| new031_berserk_natural (berserk) | natural | boss_act2_disk_devourer | 20 | 145 | 144 | 0 | 0 | 16.8 | 968 | 3383 | 2788 | 2824 | 3134 | 14 -> 14 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | p1_main_menu | 20 | 126 | 118 | 0 | 0 | 16.9 | 172 | 2232 | 2230 | 2232 | 2232 | 0 -> 0 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | route_map_first_show | 8 | 145 | 144 | 0 | 0 | 14.1 | 1315 | 2735 | 2602 | 2724 | 2724 | 0 -> 23 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | p2_48_enemies | 60 | 142 | 137 | 1 | 0 | 76.1 | 1407 | 3984 | 2575 | 3128 | 3766 | 23 -> 23 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | route_map_after_p2 | 3 | 141 | 131 | 1 | 1 | 112.7 | 1358 | 2783 | 2499 | 2503 | 2585 | 23 -> 23 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | elite_night_stalker | 20 | 140 | 134 | 0 | 0 | 46.1 | 951 | 4001 | 2738 | 3177 | 3967 | 14 -> 14 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | route_map_after_elite | 3 | 144 | 141 | 0 | 0 | 44.1 | 875 | 3025 | 2474 | 2478 | 2549 | 14 -> 14 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | p3_boss_act1_rift_warden | 60 | 141 | 136 | 0 | 0 | 38.8 | 920 | 4533 | 2762 | 3194 | 4371 | 14 -> 14 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | route_map_after_boss1 | 3 | 145 | 145 | 0 | 0 | 7.8 | 865 | 3080 | 2565 | 2569 | 2565 | 14 -> 14 |
| new031_berserk_topup (berserk) | 48-enemy top-up (FAN-3977 default) | boss_act2_disk_devourer | 20 | 138 | 134 | 0 | 0 | 48.6 | 968 | 4036 | 2783 | 3216 | 3609 | 14 -> 14 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | p1_main_menu | 20 | 145 | 144 | 0 | 0 | 11.0 | 172 | 2234 | 2232 | 2234 | 2234 | 0 -> 0 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | route_map_first_show | 8 | 145 | 144 | 0 | 0 | 10.4 | 1396 | 2757 | 2604 | 2746 | 2746 | 0 -> 28 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | p2_48_enemies | 60 | 141 | 132 | 1 | 0 | 70.0 | 1488 | 3614 | 2625 | 3089 | 3291 | 28 -> 28 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | route_map_after_p2 | 3 | 141 | 134 | 1 | 0 | 94.5 | 1439 | 2640 | 2535 | 2539 | 2621 | 28 -> 28 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | elite_night_stalker | 20 | 136 | 125 | 8 | 0 | 60.7 | 1032 | 3716 | 2776 | 3219 | 3324 | 19 -> 19 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | route_map_after_elite | 3 | 144 | 141 | 0 | 0 | 43.4 | 957 | 2588 | 2507 | 2511 | 2582 | 19 -> 19 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | p3_boss_act1_rift_warden | 60 | 135 | 124 | 13 | 0 | 69.8 | 1001 | 4184 | 2798 | 3217 | 3950 | 19 -> 19 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | route_map_after_boss1 | 3 | 145 | 145 | 0 | 0 | 7.7 | 946 | 2825 | 2593 | 2597 | 2593 | 19 -> 19 |
| new031_druid_topup (druid) | 48-enemy top-up (FAN-3977 default) | boss_act2_disk_devourer | 20 | 116 | 99 | 29 | 0 | 60.6 | 1049 | 3797 | 2814 | 3199 | 3244 | 19 -> 19 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | p1_main_menu | 20 | 120 | 119 | 0 | 0 | 17.1 | 172 | 2233 | 2231 | 2233 | 2233 | 0 -> 0 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | route_map_first_show | 8 | 119 | 115 | 0 | 0 | 18.3 | 1396 | 2756 | 2603 | 2745 | 2745 | 0 -> 28 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | p2_48_enemies | 60 | 115 | 102 | 2 | 0 | 86.4 | 1488 | 3624 | 2624 | 3112 | 3278 | 28 -> 28 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | route_map_after_p2 | 3 | 130 | 120 | 1 | 1 | 110.6 | 1439 | 2648 | 2537 | 2541 | 2623 | 28 -> 28 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | elite_night_stalker | 20 | 132 | 112 | 0 | 0 | 45.4 | 1032 | 3660 | 2777 | 3207 | 3334 | 19 -> 19 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | route_map_after_elite | 3 | 144 | 143 | 0 | 0 | 31.8 | 957 | 2606 | 2509 | 2513 | 2584 | 19 -> 19 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | p3_boss_act1_rift_warden | 60 | 122 | 95 | 7 | 0 | 82.3 | 1001 | 4293 | 2799 | 3202 | 4239 | 19 -> 19 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | route_map_after_boss1 | 3 | 120 | 119 | 0 | 0 | 12.2 | 946 | 3015 | 2594 | 2598 | 2594 | 19 -> 19 |
| new031_druid_topup_rerun (druid) | 48-enemy top-up (FAN-3977 default) | boss_act2_disk_devourer | 20 | 94 | 83 | 8 | 0 | 58.3 | 1049 | 3787 | 2815 | 3198 | 3251 | 19 -> 19 |

## M3 summary beside the FAN-3981 QA numbers

| run | boss mode | P2 peak | P2 hard <= 6,250 | P2 target <= 5,000 | P3 peak | P3 hard <= 5,000 | P3 target <= 4,000 | act-1 peak tex MiB | roster-miss warnings | menu objects before -> after (packs) |
|---|---|---|---|---|---|---|---|---|---|---|
| new031_berserk_natural | natural | 4051 | True | True | 3242 | True | True | 1408 | 0 | 1593 -> 2496 (0) |
| new031_berserk_topup | 48-enemy top-up (FAN-3977 default) | 3984 | True | True | 4533 | True | False | 1407 | 0 | 1593 -> 2497 (0) |
| new031_druid_topup | 48-enemy top-up (FAN-3977 default) | 3614 | True | True | 4184 | True | False | 1488 | 0 | 1595 -> 2496 (0) |
| new031_druid_topup_rerun | 48-enemy top-up (FAN-3977 default) | 3624 | True | True | 4293 | True | False | 1488 | 0 | 1595 -> 2497 (0) |

FAN-3981 QA (reviewer d7bc8435, run 01a0e60c…): candidate top-up P2 4042 / P3 4845 (exported PCK 4123 / 4808); candidate natural P2 4023 / P3 3288; v0.3.1 (165f14aa) top-up 8993 / 7362, natural 9176 / 5677; v0.3.0 top-up 4363 / 5305, natural 4251 / 3378; FAN-3964 Windows on the FAN-3980 package: P2 8643-8719, P3 5680.

Verdicts: {"no_synchronous_combat_loads_all_runs": true, "act1_peak_texture_within_1536_mib_all_runs": true, "p2_frames_over_100ms_zero_all_runs": true, "m3_within_hard_limits_all_runs": true, "m3_within_checklist_targets_per_run": {"new031_berserk_natural": {"p2_48_enemies": true, "p3_boss_act1_rift_warden": true}, "new031_berserk_topup": {"p2_48_enemies": true, "p3_boss_act1_rift_warden": false}, "new031_druid_topup": {"p2_48_enemies": true, "p3_boss_act1_rift_warden": false}, "new031_druid_topup_rerun": {"p2_48_enemies": true, "p3_boss_act1_rift_warden": false}}}
