# Tidal Dungeon Atlas v1 manifest

状态：`TASK53 FORMAL ART / REVIEW CANDIDATE`

## Import contract

- File: `assets/world/tilesets/tidal_dungeon/tidal_dungeon_atlas_v1.png`
- SHA-256: `2373F1950C52059FD6392CBA0B0E26B1F35A344ECE0655C38C89F8EC8157E519`
- Image: `512×512 RGBA`; grid `16×16`; cell `32×32`; margin `0`; separation `0`.
- Filtering: Nearest; mipmaps off; lossless; repeat disabled.
- Rows: `0–3 BackgroundWall`, `4–7 SolidTerrain`, `8–10 OneWayPlatform`, `11–12 FrontDecor`, `13–15 BackDecor`.
- Terrain mask bits: `N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128`.
- The 47 legal 8-neighbor masks are authored independently. Do not rotate or mirror; left-top lighting is directional.
- Blank cells are explicit reservations and must not be randomized into painted cells.

## Background variation contract

- Rows `0–3` contain `64/64` pixel-unique cyclic background tiles. Each column is a stable visual family and each row is an internal-layout variant; no duplicate pixels are renamed as variants.
- Required visibly distinct families are present: four broad base slabs, two crack structures, deep groove, dark arch and low-frequency macro wall. Additional tide mark, damp patch and sealed niche families remain sparse accents.
- Room preview uses hand-authored 4×3 macro zones: broad base families deliberately cluster into wide dark planes, while cracks/grooves/arches remain sparse. Exact source tiles are phase-cycled inside those planes to avoid stamp repetition.
- Audit reports: `background_uniqueness.csv`, `background_duplicate_groups.csv`, `preview_background_usage.csv`, and `background_variation_summary.md` under `docs/agent_tasks/evidence/task53/reports/`.

## Terrain coverage

The `terrain_47_blob` cells contain exactly 47 legal masks: isolated, four endpoints/edges, straight segments, independent outer corners, all concave inner-corner combinations, four T junction families, and the cross family. Row 7 supplies texture variants and wall/ground transitions without changing the collision footprint.

## Every atlas cell

| col | row | stable name | layer | category | collision suggestion | random variation | blank |
|---:|---:|---|---|---|---|---|---|
| 0 | 0 | `background_wall_base_a_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 1 | 0 | `background_wall_base_b_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 2 | 0 | `background_wall_base_c_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 3 | 0 | `background_wall_base_d_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 4 | 0 | `background_wall_crack_a_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 5 | 0 | `background_wall_crack_b_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 6 | 0 | `background_wall_deep_groove_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 7 | 0 | `background_wall_dark_arch_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 8 | 0 | `background_wall_macro_block_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 9 | 0 | `background_wall_base_e_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 10 | 0 | `background_wall_base_f_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 11 | 0 | `background_wall_base_g_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 12 | 0 | `background_wall_base_h_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 13 | 0 | `background_wall_tide_mark_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 14 | 0 | `background_wall_damp_patch_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 15 | 0 | `background_wall_sealed_niche_r0` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 0 | 1 | `background_wall_base_a_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 1 | 1 | `background_wall_base_b_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 2 | 1 | `background_wall_base_c_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 3 | 1 | `background_wall_base_d_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 4 | 1 | `background_wall_crack_a_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 5 | 1 | `background_wall_crack_b_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 6 | 1 | `background_wall_deep_groove_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 7 | 1 | `background_wall_dark_arch_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 8 | 1 | `background_wall_macro_block_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 9 | 1 | `background_wall_base_e_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 10 | 1 | `background_wall_base_f_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 11 | 1 | `background_wall_base_g_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 12 | 1 | `background_wall_base_h_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 13 | 1 | `background_wall_tide_mark_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 14 | 1 | `background_wall_damp_patch_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 15 | 1 | `background_wall_sealed_niche_r1` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 0 | 2 | `background_wall_base_a_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 1 | 2 | `background_wall_base_b_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 2 | 2 | `background_wall_base_c_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 3 | 2 | `background_wall_base_d_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 4 | 2 | `background_wall_crack_a_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 5 | 2 | `background_wall_crack_b_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 6 | 2 | `background_wall_deep_groove_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 7 | 2 | `background_wall_dark_arch_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 8 | 2 | `background_wall_macro_block_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 9 | 2 | `background_wall_base_e_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 10 | 2 | `background_wall_base_f_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 11 | 2 | `background_wall_base_g_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 12 | 2 | `background_wall_base_h_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 13 | 2 | `background_wall_tide_mark_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 14 | 2 | `background_wall_damp_patch_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 15 | 2 | `background_wall_sealed_niche_r2` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 0 | 3 | `background_wall_base_a_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 1 | 3 | `background_wall_base_b_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 2 | 3 | `background_wall_base_c_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 3 | 3 | `background_wall_base_d_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 4 | 3 | `background_wall_crack_a_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 5 | 3 | `background_wall_crack_b_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 6 | 3 | `background_wall_deep_groove_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 7 | 3 | `background_wall_dark_arch_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 8 | 3 | `background_wall_macro_block_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 9 | 3 | `background_wall_base_e_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 10 | 3 | `background_wall_base_f_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 11 | 3 | `background_wall_base_g_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 12 | 3 | `background_wall_base_h_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 13 | 3 | `background_wall_tide_mark_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 14 | 3 | `background_wall_damp_patch_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 15 | 3 | `background_wall_sealed_niche_r3` | `BackgroundWall` | `background` | none | allowed; same edge signature | no |
| 0 | 4 | `tidal_stone_solid_isolated_m000` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 1 | 4 | `tidal_stone_solid_endpoint_n_m001` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 2 | 4 | `tidal_stone_solid_endpoint_e_m004` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 3 | 4 | `tidal_stone_solid_corner_ne_inner_ne_m005` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 4 | 4 | `tidal_stone_solid_corner_ne_m007` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 5 | 4 | `tidal_stone_solid_endpoint_s_m016` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 6 | 4 | `tidal_stone_solid_straight_ns_m017` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 7 | 4 | `tidal_stone_solid_corner_es_inner_se_m020` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 8 | 4 | `tidal_stone_solid_tee_open_w_inner_ne_se_m021` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 9 | 4 | `tidal_stone_solid_tee_open_w_inner_se_m023` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 10 | 4 | `tidal_stone_solid_corner_es_m028` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 11 | 4 | `tidal_stone_solid_tee_open_w_inner_ne_m029` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 12 | 4 | `tidal_stone_solid_tee_open_w_m031` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 13 | 4 | `tidal_stone_solid_endpoint_w_m064` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 14 | 4 | `tidal_stone_solid_corner_nw_inner_nw_m065` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 15 | 4 | `tidal_stone_solid_straight_ew_m068` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 0 | 5 | `tidal_stone_solid_tee_open_s_inner_ne_nw_m069` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 1 | 5 | `tidal_stone_solid_tee_open_s_inner_nw_m071` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 2 | 5 | `tidal_stone_solid_corner_sw_inner_sw_m080` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 3 | 5 | `tidal_stone_solid_tee_open_e_inner_sw_nw_m081` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 4 | 5 | `tidal_stone_solid_tee_open_n_inner_se_sw_m084` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 5 | 5 | `tidal_stone_solid_cross_inner_ne_se_sw_nw_m085` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 6 | 5 | `tidal_stone_solid_cross_inner_se_sw_nw_m087` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 7 | 5 | `tidal_stone_solid_tee_open_n_inner_sw_m092` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 8 | 5 | `tidal_stone_solid_cross_inner_ne_sw_nw_m093` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 9 | 5 | `tidal_stone_solid_cross_inner_sw_nw_m095` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 10 | 5 | `tidal_stone_solid_corner_sw_m112` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 11 | 5 | `tidal_stone_solid_tee_open_e_inner_nw_m113` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 12 | 5 | `tidal_stone_solid_tee_open_n_inner_se_m116` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 13 | 5 | `tidal_stone_solid_cross_inner_ne_se_nw_m117` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 14 | 5 | `tidal_stone_solid_cross_inner_se_nw_m119` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 15 | 5 | `tidal_stone_solid_tee_open_n_m124` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 0 | 6 | `tidal_stone_solid_cross_inner_ne_nw_m125` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 1 | 6 | `tidal_stone_solid_cross_inner_nw_m127` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 2 | 6 | `tidal_stone_solid_corner_nw_m193` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 3 | 6 | `tidal_stone_solid_tee_open_s_inner_ne_m197` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 4 | 6 | `tidal_stone_solid_tee_open_s_m199` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 5 | 6 | `tidal_stone_solid_tee_open_e_inner_sw_m209` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 6 | 6 | `tidal_stone_solid_cross_inner_ne_se_sw_m213` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 7 | 6 | `tidal_stone_solid_cross_inner_se_sw_m215` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 8 | 6 | `tidal_stone_solid_cross_inner_ne_sw_m221` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 9 | 6 | `tidal_stone_solid_cross_inner_sw_m223` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 10 | 6 | `tidal_stone_solid_tee_open_e_m241` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 11 | 6 | `tidal_stone_solid_cross_inner_ne_se_m245` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 12 | 6 | `tidal_stone_solid_cross_inner_se_m247` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 13 | 6 | `tidal_stone_solid_cross_inner_ne_m253` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 14 | 6 | `tidal_stone_solid_cross_m255` | `SolidTerrain` | `terrain_47_blob` | full 32x32 | no rotation/mirroring | no |
| 15 | 6 | `blank_solid_reserved_6_15` | `SolidTerrain` | `reserved` | none | no | yes |
| 0 | 7 | `tidal_ground_top_a` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 1 | 7 | `tidal_ground_top_b` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 2 | 7 | `tidal_ground_top_c` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 3 | 7 | `tidal_vertical_wall_a` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 4 | 7 | `tidal_vertical_wall_b` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 5 | 7 | `tidal_vertical_wall_c` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 6 | 7 | `tidal_wall_foot_left` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 7 | 7 | `tidal_wall_foot_center` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 8 | 7 | `tidal_wall_foot_right` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 9 | 7 | `tidal_ground_edge_left` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 10 | 7 | `tidal_ground_edge_right` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 11 | 7 | `tidal_stone_full_variant_a` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 12 | 7 | `tidal_stone_full_variant_b` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 13 | 7 | `tidal_stone_full_variant_c` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 14 | 7 | `tidal_ground_to_wall_transition_a` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 15 | 7 | `tidal_ground_to_wall_transition_b` | `SolidTerrain` | `terrain_auxiliary` | full 32x32 | allowed only within named shape family | no |
| 0 | 8 | `platform_left_cap` | `OneWayPlatform` | `platform` | one-way y=10 | no | no |
| 1 | 8 | `platform_center_a` | `OneWayPlatform` | `platform` | one-way y=10 | center a/b/c only | no |
| 2 | 8 | `platform_center_b` | `OneWayPlatform` | `platform` | one-way y=10 | center a/b/c only | no |
| 3 | 8 | `platform_center_c` | `OneWayPlatform` | `platform` | one-way y=10 | center a/b/c only | no |
| 4 | 8 | `platform_right_cap` | `OneWayPlatform` | `platform` | one-way y=10 | no | no |
| 5 | 8 | `platform_broken_left` | `OneWayPlatform` | `platform` | one-way y=10; full standable span | no | no |
| 6 | 8 | `platform_broken_right` | `OneWayPlatform` | `platform` | one-way y=10; full standable span | no | no |
| 7 | 8 | `platform_support_short` | `BackDecor` | `platform` | none | no | no |
| 8 | 8 | `platform_support_tall` | `BackDecor` | `platform` | none | no | no |
| 9 | 8 | `platform_underhang_a` | `BackDecor` | `platform` | none | no | no |
| 10 | 8 | `platform_underhang_b` | `BackDecor` | `platform` | none | no | no |
| 11 | 8 | `blank_platform_reserved_8_11` | `OneWayPlatform` | `reserved` | none | no | yes |
| 12 | 8 | `blank_platform_reserved_8_12` | `OneWayPlatform` | `reserved` | none | no | yes |
| 13 | 8 | `blank_platform_reserved_8_13` | `OneWayPlatform` | `reserved` | none | no | yes |
| 14 | 8 | `blank_platform_reserved_8_14` | `OneWayPlatform` | `reserved` | none | no | yes |
| 15 | 8 | `blank_platform_reserved_8_15` | `OneWayPlatform` | `reserved` | none | no | yes |
| 0 | 9 | `blank_platform_reserved_9_0` | `OneWayPlatform` | `reserved` | none | no | yes |
| 1 | 9 | `blank_platform_reserved_9_1` | `OneWayPlatform` | `reserved` | none | no | yes |
| 2 | 9 | `blank_platform_reserved_9_2` | `OneWayPlatform` | `reserved` | none | no | yes |
| 3 | 9 | `blank_platform_reserved_9_3` | `OneWayPlatform` | `reserved` | none | no | yes |
| 4 | 9 | `blank_platform_reserved_9_4` | `OneWayPlatform` | `reserved` | none | no | yes |
| 5 | 9 | `blank_platform_reserved_9_5` | `OneWayPlatform` | `reserved` | none | no | yes |
| 6 | 9 | `blank_platform_reserved_9_6` | `OneWayPlatform` | `reserved` | none | no | yes |
| 7 | 9 | `blank_platform_reserved_9_7` | `OneWayPlatform` | `reserved` | none | no | yes |
| 8 | 9 | `blank_platform_reserved_9_8` | `OneWayPlatform` | `reserved` | none | no | yes |
| 9 | 9 | `blank_platform_reserved_9_9` | `OneWayPlatform` | `reserved` | none | no | yes |
| 10 | 9 | `blank_platform_reserved_9_10` | `OneWayPlatform` | `reserved` | none | no | yes |
| 11 | 9 | `blank_platform_reserved_9_11` | `OneWayPlatform` | `reserved` | none | no | yes |
| 12 | 9 | `blank_platform_reserved_9_12` | `OneWayPlatform` | `reserved` | none | no | yes |
| 13 | 9 | `blank_platform_reserved_9_13` | `OneWayPlatform` | `reserved` | none | no | yes |
| 14 | 9 | `blank_platform_reserved_9_14` | `OneWayPlatform` | `reserved` | none | no | yes |
| 15 | 9 | `blank_platform_reserved_9_15` | `OneWayPlatform` | `reserved` | none | no | yes |
| 0 | 10 | `blank_platform_reserved_10_0` | `OneWayPlatform` | `reserved` | none | no | yes |
| 1 | 10 | `blank_platform_reserved_10_1` | `OneWayPlatform` | `reserved` | none | no | yes |
| 2 | 10 | `blank_platform_reserved_10_2` | `OneWayPlatform` | `reserved` | none | no | yes |
| 3 | 10 | `blank_platform_reserved_10_3` | `OneWayPlatform` | `reserved` | none | no | yes |
| 4 | 10 | `blank_platform_reserved_10_4` | `OneWayPlatform` | `reserved` | none | no | yes |
| 5 | 10 | `blank_platform_reserved_10_5` | `OneWayPlatform` | `reserved` | none | no | yes |
| 6 | 10 | `blank_platform_reserved_10_6` | `OneWayPlatform` | `reserved` | none | no | yes |
| 7 | 10 | `blank_platform_reserved_10_7` | `OneWayPlatform` | `reserved` | none | no | yes |
| 8 | 10 | `blank_platform_reserved_10_8` | `OneWayPlatform` | `reserved` | none | no | yes |
| 9 | 10 | `blank_platform_reserved_10_9` | `OneWayPlatform` | `reserved` | none | no | yes |
| 10 | 10 | `blank_platform_reserved_10_10` | `OneWayPlatform` | `reserved` | none | no | yes |
| 11 | 10 | `blank_platform_reserved_10_11` | `OneWayPlatform` | `reserved` | none | no | yes |
| 12 | 10 | `blank_platform_reserved_10_12` | `OneWayPlatform` | `reserved` | none | no | yes |
| 13 | 10 | `blank_platform_reserved_10_13` | `OneWayPlatform` | `reserved` | none | no | yes |
| 14 | 10 | `blank_platform_reserved_10_14` | `OneWayPlatform` | `reserved` | none | no | yes |
| 15 | 10 | `blank_platform_reserved_10_15` | `OneWayPlatform` | `reserved` | none | no | yes |
| 0 | 11 | `foreground_tidal_occluder_00` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 1 | 11 | `foreground_tidal_occluder_01` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 2 | 11 | `foreground_tidal_occluder_02` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 3 | 11 | `foreground_tidal_occluder_03` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 4 | 11 | `foreground_tidal_occluder_04` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 5 | 11 | `foreground_tidal_occluder_05` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 6 | 11 | `foreground_tidal_occluder_06` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 7 | 11 | `foreground_tidal_occluder_07` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 8 | 11 | `foreground_tidal_occluder_08` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 9 | 11 | `foreground_tidal_occluder_09` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 10 | 11 | `foreground_tidal_occluder_10` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 11 | 11 | `foreground_tidal_occluder_11` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 12 | 11 | `foreground_tidal_occluder_12` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 13 | 11 | `foreground_tidal_occluder_13` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 14 | 11 | `foreground_tidal_occluder_14` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 15 | 11 | `foreground_tidal_occluder_15` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 0 | 12 | `foreground_tidal_occluder_16` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 1 | 12 | `foreground_tidal_occluder_17` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 2 | 12 | `foreground_tidal_occluder_18` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 3 | 12 | `foreground_tidal_occluder_19` | `FrontDecor` | `foreground` | none | allowed within same visual footprint | no |
| 4 | 12 | `blank_foreground_reserved_12_4` | `FrontDecor` | `reserved` | none | no | yes |
| 5 | 12 | `blank_foreground_reserved_12_5` | `FrontDecor` | `reserved` | none | no | yes |
| 6 | 12 | `blank_foreground_reserved_12_6` | `FrontDecor` | `reserved` | none | no | yes |
| 7 | 12 | `blank_foreground_reserved_12_7` | `FrontDecor` | `reserved` | none | no | yes |
| 8 | 12 | `blank_foreground_reserved_12_8` | `FrontDecor` | `reserved` | none | no | yes |
| 9 | 12 | `blank_foreground_reserved_12_9` | `FrontDecor` | `reserved` | none | no | yes |
| 10 | 12 | `blank_foreground_reserved_12_10` | `FrontDecor` | `reserved` | none | no | yes |
| 11 | 12 | `blank_foreground_reserved_12_11` | `FrontDecor` | `reserved` | none | no | yes |
| 12 | 12 | `blank_foreground_reserved_12_12` | `FrontDecor` | `reserved` | none | no | yes |
| 13 | 12 | `blank_foreground_reserved_12_13` | `FrontDecor` | `reserved` | none | no | yes |
| 14 | 12 | `blank_foreground_reserved_12_14` | `FrontDecor` | `reserved` | none | no | yes |
| 15 | 12 | `blank_foreground_reserved_12_15` | `FrontDecor` | `reserved` | none | no | yes |
| 0 | 13 | `decor_tidal_00` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 1 | 13 | `decor_tidal_01` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 2 | 13 | `decor_tidal_02` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 3 | 13 | `decor_tidal_03` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 4 | 13 | `decor_tidal_04` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 5 | 13 | `decor_tidal_05` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 6 | 13 | `decor_tidal_06` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 7 | 13 | `decor_tidal_07` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 8 | 13 | `decor_tidal_08` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 9 | 13 | `decor_tidal_09` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 10 | 13 | `decor_tidal_10` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 11 | 13 | `decor_tidal_11` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 12 | 13 | `decor_tidal_12` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 13 | 13 | `decor_tidal_13` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 14 | 13 | `decor_tidal_14` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 15 | 13 | `decor_tidal_15` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 0 | 14 | `decor_tidal_16` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 1 | 14 | `decor_tidal_17` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 2 | 14 | `decor_tidal_18` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 3 | 14 | `decor_tidal_19` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 4 | 14 | `decor_tidal_20` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 5 | 14 | `decor_tidal_21` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 6 | 14 | `decor_tidal_22` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 7 | 14 | `decor_tidal_23` | `BackDecor` | `decoration` | none | manual sparse placement | no |
| 8 | 14 | `blank_decor_reserved_14_8` | `BackDecor` | `reserved` | none | no | yes |
| 9 | 14 | `blank_decor_reserved_14_9` | `BackDecor` | `reserved` | none | no | yes |
| 10 | 14 | `blank_decor_reserved_14_10` | `BackDecor` | `reserved` | none | no | yes |
| 11 | 14 | `blank_decor_reserved_14_11` | `BackDecor` | `reserved` | none | no | yes |
| 12 | 14 | `blank_decor_reserved_14_12` | `BackDecor` | `reserved` | none | no | yes |
| 13 | 14 | `blank_decor_reserved_14_13` | `BackDecor` | `reserved` | none | no | yes |
| 14 | 14 | `blank_decor_reserved_14_14` | `BackDecor` | `reserved` | none | no | yes |
| 15 | 14 | `blank_decor_reserved_14_15` | `BackDecor` | `reserved` | none | no | yes |
| 0 | 15 | `blank_decor_reserved_15_0` | `BackDecor` | `reserved` | none | no | yes |
| 1 | 15 | `blank_decor_reserved_15_1` | `BackDecor` | `reserved` | none | no | yes |
| 2 | 15 | `blank_decor_reserved_15_2` | `BackDecor` | `reserved` | none | no | yes |
| 3 | 15 | `blank_decor_reserved_15_3` | `BackDecor` | `reserved` | none | no | yes |
| 4 | 15 | `blank_decor_reserved_15_4` | `BackDecor` | `reserved` | none | no | yes |
| 5 | 15 | `blank_decor_reserved_15_5` | `BackDecor` | `reserved` | none | no | yes |
| 6 | 15 | `blank_decor_reserved_15_6` | `BackDecor` | `reserved` | none | no | yes |
| 7 | 15 | `blank_decor_reserved_15_7` | `BackDecor` | `reserved` | none | no | yes |
| 8 | 15 | `blank_decor_reserved_15_8` | `BackDecor` | `reserved` | none | no | yes |
| 9 | 15 | `blank_decor_reserved_15_9` | `BackDecor` | `reserved` | none | no | yes |
| 10 | 15 | `blank_decor_reserved_15_10` | `BackDecor` | `reserved` | none | no | yes |
| 11 | 15 | `blank_decor_reserved_15_11` | `BackDecor` | `reserved` | none | no | yes |
| 12 | 15 | `blank_decor_reserved_15_12` | `BackDecor` | `reserved` | none | no | yes |
| 13 | 15 | `blank_decor_reserved_15_13` | `BackDecor` | `reserved` | none | no | yes |
| 14 | 15 | `blank_decor_reserved_15_14` | `BackDecor` | `reserved` | none | no | yes |
| 15 | 15 | `blank_decor_reserved_15_15` | `BackDecor` | `reserved` | none | no | yes |

## Collision rule summary

- SolidTerrain: full 32×32 rectangle; highlighted top remains the visual/collision top.
- OneWayPlatform standable pieces: one-way line or thin rectangle at local `y=10`; caps share the same span.
- Background, supports, underhangs, foreground and decorations: no collision by default.
- Broken platforms are explicit pieces, not random center variants; current v1 recommendation keeps the complete one-way span.
