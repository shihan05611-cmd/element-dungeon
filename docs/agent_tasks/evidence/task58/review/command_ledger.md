# Task58 Review command ledger

所有 Godot 命令均使用 `C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`，正式进程仅设置独立 `APPDATA/LOCALAPPDATA`，`--path` 始终指向 Review 冷根。命令通过 `Start-Process -WindowStyle Hidden -Wait -PassThru` 执行并分别重定向 stdout/stderr。

1. `git archive --format=zip --output=<temporary zip> 51b8ffde...`，随后 `Expand-Archive` 到全新冷根；逐项 `Copy-Item` 22 个冻结文件和 evidence glob；逐项 `Remove-Item` 十个指定旧文件。完成后删除临时 ZIP。退出 0。
2. 首次 Godot 命令：`--headless --editor --path <cold> --quit`。命令类型正确但因额外隔离 `USERPROFILE` 在 stderr 出现 Windows `get_system_dir ERROR`；退出 0，列为排除尝试。日志 `01_*`。
3. 精确删除并重建同名 Review 冷根/profile，再次由固定基线 + 22 overlay + 10 deletion 构建；`.godot=false`、profile files `0`、`.gdignore=true`。
4. 正式 cold-first：`--headless --editor --path <cold> --quit`，退出 0，日志 `02_*`。
5. Task58：`--headless --path <cold> --script res://combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd`，退出 0，日志 `03_*`。
6. Task41：`--headless --path <cold> --script res://growth/tests/run_task41_physical_flow_waves_boss_tests.gd`，退出 0，日志 `04_*`。
7. Task43：`--headless --path <cold> --script res://growth/tests/run_task43_combat_loadout_world_cleanup_tests.gd`，退出 0，日志 `05_*`。
8. Task51：`--headless --path <cold> --script res://combat/tests/run_task51_boss_projectile_spawn_clearance_tests.gd`，退出 0，日志 `06_*`。
9. Task29：`--headless --path <cold> --script res://combat/tests/run_task29_real_room_flow_tests.gd`，退出 0，日志 `07_*`。
10. Task31：`--headless --path <cold> --script res://combat/tests/run_task31_full_run_e2e_tests.gd`，退出 0，日志 `08_*`。
11. Task57：`--headless --path <cold> --script res://combat/tests/run_task57_full_room_background_collision_tests.gd`，退出 0，日志 `09_*`。
12. Headless capture：`--headless --path <cold> --script res://combat/tests/capture_task58_formal_interactables_crown_sentry.gd`；无 `frame_post_draw`，仅终止本轮 PID38244/32880，退出 -1，日志 `10_*`。
13. 正式 capture：`--display-driver windows --audio-driver Dummy --path <cold> --script res://combat/tests/capture_task58_formal_interactables_crown_sentry.gd --resolution 1920x1080`，隐藏窗口，退出 0，日志 `10b_*`。
14. Smoke：`--headless --path <cold> --quit-after 180`，退出 0，日志 `11_*`。
15. Final scan：`--headless --editor --path <cold> --quit`，退出 0，日志 `12_*`。
16. Review-only 诊断：`--headless --path <cold> --script <review worktree>/review_task58_shop_initial_visibility.gd`，退出 1并确定性复现 SHOP UI 预先可见；脚本未复制进候选，日志 `13_*`。
17. 诊断后 final freeze scan：`--headless --editor --path <cold> --quit`，退出 0，日志 `14_*`；sidecar `1091 → 1091`、added/removed/changed `0/0/0`。
18. 只读审计：`rg` 旧引用；`Test-Path` 十项删除；`Get-FileHash` 六 PNG/overlay/evidence；`git ls-tree` + `git hash-object` 保护 blob；`Get-Process` PID17624/3964；`git status` 执行工作树；sidecar before/after CSV；正式日志五类 marker 统计。均未写生产候选或 Git。
