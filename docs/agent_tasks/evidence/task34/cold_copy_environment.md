# Task34 冷副本与环境

## 基线与副本

- 派发基线：`102720086c53a84901b788726ad609d15263d64a`
- final before：`C:\tmp\element-dungeon-task34-final-before-20260807-02`
- before profile：`C:\tmp\element-dungeon-task34-final-before-profile-20260807-02`
- final after：`C:\tmp\element-dungeon-task34-final-after-20260807-01`
- after profile：`C:\tmp\element-dungeon-task34-final-after-profile-20260807-01`
- artifacts：`C:\tmp\element-dungeon-task34-final-artifacts-20260807-01`

before 使用 `git archive --format=zip` 从指定 commit 构建，逐个 Git blob SHA-1 校验：1518 个 HEAD 文件、0 missing、0 mismatch；只额外注入一份双兼容 performance runner。一次更早的 `before-20260807-01` Unicode tar 展开失败，未被任何正式命令使用。

after 从共享树复制，排除 `.git/.godot/.workbuddy/cache/__pycache__/*.pyc`；创建时共享源与 cold copy 为 1611/1611、0 only-source、0 only-copy、0 hash mismatch。最后仅将 allowlist 内 windowed capture 修补同步到 cold copy，并经最终 editor rescan。

- before HEAD manifest：`before_head_manifest_sha1.txt`，1518 entries，manifest SHA-256 `A35DE9DA1F895685D2278C523A17D1BA1A176BD9C25CEBAC63F1BBBD605C821C`
- final-after source manifest：`after_final_manifest_sha256.txt`，1611 entries，manifest SHA-256 `42D985AFC6027CDADD74016D30A7DF6DCDB6F4EB01F622A73C92DCDA6762EE6C`
- performance runner 三方 SHA-256：`C134999607A3579F8420C0C8391AC34825ED7E4BD00C42FF45F86EB746489905`

两侧第一条 Godot 命令都为 Godot 4.7.1 headless editor scan，日志分别为 `final_artifacts/01_after_initial_editor_scan.log` 与 `02_before_initial_editor_scan.log`；均 exit 0 且五类关键字为 0。

## 机器与运行条件

- OS：Microsoft Windows NT `10.0.26200.0`，x64
- CPU：Intel64 Family 6 Model 158 Stepping 13，8 logical processors
- GPU：NVIDIA GeForce RTX 2060，driver `591.74`（Godot Compatibility renderer log）
- 电源计划：Windows `Balanced`，GUID `381b4222-f694-41f0-9685-ff5bb260df2e`
- Godot executable：`C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
- Godot version：`4.7.1.stable.official.a13da4feb`
- timezone：Asia/Shanghai

所有 scan、runner、benchmark、smoke 和 capture 都显式设置各自 cold profile 的 `APPDATA`/`LOCALAPPDATA`，从未把共享工程路径传给 Godot。

## 交错顺序

- seed：`4107`
- warmup 1～5：before → after
- measured 奇数轮：before → after
- measured 偶数轮：after → before
- 普通 projectile 与 Fury 补充 fixture 使用同一 runner SHA、同一 fixture/input 顺序和相同交错规则

CSV 保留 side/phase/round/order/exit code/elapsed/valid/trace/count vector；所有逐进程 Godot logs 均已持久化到 `final_artifacts/perf_projectile_cast_v1/**`。
