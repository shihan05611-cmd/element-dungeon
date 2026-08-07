# Task34 第三次接替冷副本与环境

- after：`C:\tmp\element-dungeon-task34-third-final-after-20260807-01`
- after profile：`C:\tmp\element-dungeon-task34-third-final-after-profile-20260807-01`
- before：`C:\tmp\element-dungeon-task34-third-final-before-20260807-01`
- before profile：`C:\tmp\element-dungeon-task34-third-final-before-profile-20260807-01`
- temp artifacts：`C:\tmp\element-dungeon-task34-third-final-artifacts-20260807-01`
- Godot：`C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`，版本 `4.7.1.stable.official.a13da4feb`

两侧目录创建前均不存在；两侧第一条 Godot 命令均为 headless editor scan，日志为 `01_after_initial_editor_scan.log` 与 `02_before_initial_editor_scan.log`。APPDATA/LOCALAPPDATA 分别指向独立 profile，从未把共享工程传给 Godot。

before 来自 `git archive` 的固定 HEAD：1518 个 Git blob，逐项 `git hash-object --no-filters` 验证 mismatch 0；只额外注入同一双兼容 performance runner。

after 从当时共享树逐文件复制，排除 `.git/.godot/.workbuddy/cache/__pycache__/*.pyc`。源 1812 项全部存在于冷副本且 hash mismatch 0；scan 后冷副本额外生成 69 个 sidecar（33 `.import`、31 `.translation`、5 `.uid`），全部只存在冷副本。结构化摘要见 `third_replacement_final_artifacts/cold_copy_manifest_summary.json`。
