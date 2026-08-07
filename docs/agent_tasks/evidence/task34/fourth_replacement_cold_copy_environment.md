# Task34 第四次接替冷副本环境

## 全新路径

- final after：`C:\tmp\element-dungeon-task34-fourth-final-after-20260807-01`
- final before：`C:\tmp\element-dungeon-task34-fourth-final-before-20260807-01`
- after profile：`C:\tmp\element-dungeon-task34-fourth-final-after-profile-20260807-01`
- before profile：`C:\tmp\element-dungeon-task34-fourth-final-before-profile-20260807-01`
- 原始 artifacts：`C:\tmp\element-dungeon-task34-fourth-final-artifacts-20260807-01`

这些路径在本轮创建前均不存在。after 从修改后的共享树复制，排除 `.git/.godot/.workbuddy/cache/__pycache__/*.pyc`；before 使用只读 `git archive` 从固定 HEAD `102720086c53a84901b788726ad609d15263d64a` 创建，再注入同一双兼容 runner。未执行任何 Git 写操作。

Godot 前，after 为 2023 files / 53780339 bytes，before 为 1519 files / 49987231 bytes，均无 `.godot`。两侧第一条 Godot 命令均为 4.7.1 headless editor scan：`01_after_initial_editor_scan.log` 与 `02_before_initial_editor_scan.log` 均 exit 0、错误模式 0。最终 after rescan 同样 exit 0。

同 runner 在 shared/before/after 的 SHA-256 均为 `83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`。正式 after 内 37 项 Task34 实现/测试文件与共享冻结树逐项 `0 mismatch`。

最终 post-scan 冷副本清单：

- before：`fourth_replacement_before_manifest_sha256.txt`，1616 entries，清单 SHA-256 `FA923C6CE2984683571964DD6C04AFC0462D40BFA62A563B321B4EDF4F101D96`。
- after：`fourth_replacement_after_manifest_sha256.txt`，2165 entries，清单 SHA-256 `5B489BE2F266E32698C7C602C11979861F823217FC911F3BA52117CDEC7A877F`。
- 持久化 artifacts：194 files，`fourth_replacement_artifacts_sha256.txt` 清单 SHA-256 `C777489A1865D35F5AB5819AF0C9285EA28834BAD8A4B3E7986900A6362B22EB`。

post-scan 清单排除冷副本 `.godot/**`，但保留冷副本内 Godot 正常生成的 sidecar；因此 entries 高于 Godot 前的源文件计数。
