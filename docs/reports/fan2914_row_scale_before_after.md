## FAN-2914 row-scale measurements

Each value is the largest `max(frame scale) / min(frame scale)` inside one
animation row. The old builder calculated every frame from its own alpha bbox;
the rebuilt runtime packs use one scale for the whole row. The measured frame
count is the complete runtime pack.

| Pack | Frames | Before | After |
| --- | ---: | ---: | ---: |
| rift_cutter | 224 | 2.185× | 1.000× |
| ash_marksman | 184 | 2.194× | 1.000× |
| spark_runner | 208 | 1.791× | 1.000× |
| stone_bruiser | 240 | 2.395× | 1.000× |
| bone_caller | 184 | 2.411× | 1.000× |
| void_mage | 184 | 1.531× | 1.000× |
| venom_spitter | 184 | 1.444× | 1.000× |
| rift_shieldbearer | 184 | 2.500× | 1.000× |
| small_biter | 184 | 1.484× | 1.000× |
| bone_shaman | 184 | 2.090× | 1.000× |
| winged_spark | 224 | 1.295× | 1.000× |
| plague_prophet | 248 | 2.532× | 1.000× |
| mini_rot_hound | 264 | 2.107× | 1.000× |
| disk_devourer | 328 | 1.785× | 1.000× |
| homunculus_tank | 206 | 1.366× | 1.000× |
| iron_bastion | 344 | 2.146× | 1.000× |

The named regression cases reproduce the visible death inflation before the
fix: `bone_shaman/death_north` is 2.090× (`3.951613..8.258065`) and
`mini_rot_hound/death_north` is 2.107× (`4.152542..8.750000`). Both are
1.000× after the rebuild.

`tests/full_frame_row_scale_invariant_test.gd` uses the committed legacy
reports as its negative control on an old tree, then requires the rebuilt
runtime report. It also checks every referenced runtime PNG is 512×512 RGBA
with alpha bottom `480`.
