# Task 88 evidence

- `screenshots/task88_01_chest_14px_vs_transition_12px_1920x1080.png` is a Godot 4.7.1 real-window capture: the chest preserves its existing floating placement and styling at 14px, while the adjacent transition prompt remains 12px.
- `run_task75_world_prompt_font_and_motion_tests.log`: 1 test / 22 assertions passed; verifies chest-only 14px and 232x34 bounds, other prompts at 12px, and unchanged 2.4-second 3px float.
- `run_task81_ignition_tests.log`: 4 tests / 80 assertions passed; includes Lv1 and Lv3 1/5/20-layer multiplier checks, fixed fire attachment/range, lifecycle, and accepted-state stability.
- `run_task27_run_economy_progression_tests.log`: 12 tests / 342 assertions passed; verifies initial ignition Lv2/Lv3 upgrades, 60/100 charges, Lv3 block, and floor(160 * 70%) = 112 reset refund.
- `run_skill_content_catalog_tests.log`: 11 tests / 243 assertions passed.
- `run_task31_content_balance_tests.log`: the Task 88 catalog/progression cases pass, but 12 pre-existing room-layout assertions fail because the active room set now references three scene templates where that older test freezes two; this task did not change room scenes or spawns.
