# Task58 rework2 Review 命令账本

所有 Godot 命令均使用 `Godot_v4.7.1-stable_win64_console.exe`、本轮全新冷根和仅隔离 `APPDATA/LOCALAPPDATA` 的全新 profile；未设置 `USERPROFILE`，未连接共享进程。正式命令按以下顺序执行：

1. `--headless --editor --quit --path <cold-root>`：cold-first scan，退出 0。
2. `--headless --path <cold-root> --script res://combat/tests/run_task58_formal_interactables_crown_sentry_tests.gd`：3/104。
3. 同形式 Task41 runner：4/95。
4. 同形式 Task43 runner：4/105。
5. 同形式 Task51 runner：2/49。
6. 同形式 Task29 runner：1/74。
7. 同形式 Task31 runner：4/393。
8. 同形式 Task57 runner：5/205。
9. 同形式 Reviewer evidence 下 review-only L/F 诊断：42 checks。
10. Windows/OpenGL 隔离 capture runner：1 test / 7 images / 0 failures。
11. `--headless --editor --quit --path <cold-root>`：post-capture scan，退出 0。
12. `--headless --path <cold-root> --quit-after 180`：RunGame 180 帧 smoke，退出 0。
13. sidecar-before 冻结后，`--headless --editor --quit --path <cold-root>`：final scan，退出 0；这是本轮最后一条 Godot 命令。

post-capture scan 在沙箱内两次退出 0，但 Windows 根证书库不可读，stderr 出现 `ERROR: Failed to read the root certificate store.`；两份 attempt 原样保留，不计入正式成功日志。随后在相同冷根/profile、沙箱外只为读取系统证书库重跑，正式日志退出 0 且 stderr 为空。此环境性 attempt 未触碰候选或共享 Godot。

final scan 后只执行只读文件哈希、Git blob/diff、文本搜索、进程存在性检查与 evidence 汇总；未再运行 Godot。
