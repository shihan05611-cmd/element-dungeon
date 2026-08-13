# Task 46 隔离验证证据

## 候选与隔离

- 固定 Git 基线：`03b2374b6dfedda20123c7c2a5fb5ee00950e4f1`
- 成功冷副本：`C:\tmp\element-dungeon-task46-exec-20260813-02`
- 独立 profile：`C:\tmp\element-dungeon-task46-profile-20260813-02`
- 冷副本由固定 HEAD 的只读 ZIP archive 建立，再精确叠加 Task 46 的 `.gdignore`、playbook 与任务书。
- 第一条 Godot 命令前，冷副本没有 `.git`、`.godot`，且永久
  `docs/agent_tasks/evidence/.gdignore` 已存在；profile 位于候选外。
- `-01` 冷根曾因 Windows `tar.exe` 无法解码 Git archive 中的中文路径而在 Godot 启动前失败；
  该不完整目录没有复用，也不构成验证依据。

## Godot editor scan

实际命令：

```text
& 'C:\Users\heliashi\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path 'C:\tmp\element-dungeon-task46-exec-20260813-02' --quit --log-file 'C:\tmp\element-dungeon-task46-profile-20260813-02\task46_editor_scan.log'
```

- Godot：`4.7.1.stable.official.a13da4feb`
- 退出码：`0`
- 正式日志：[godot_4.7.1_editor_scan.txt](godot_4.7.1_editor_scan.txt)
- 日志：`39,218 bytes`，SHA-256
  `0e4e3ceda575a65416b14ffbdf8d82f4efcdd1b24d804555a985511dde217d53`
- 日志标记：`SCRIPT ERROR=0`、`Parse Error=0`、`ERROR:=0`、`WARNING:=0`、
  `CrashHandlerException=0`、`log_marker_summary=0`、`.translation=0`

## evidence 前后对账

冷副本 `docs/agent_tasks/evidence/`（排除屏障本身与 Task 46 自身证据）：

- scan 前：`1522 files / 30,341,052 bytes / 51 CSV / 140 translation / 121 import`
- scan 后：`1522 files / 30,341,052 bytes / 51 CSV / 140 translation / 121 import`
- 前后逐文件 `path | bytes | SHA-256` 聚合 SHA-256 均为
  `4925eb382db36400b277e9ca4198aea4f00ffc28c45d79232ab9e67b8ad26fc2`
- 结论：没有新增或改写 `.translation`，历史 evidence 的 bytes/SHA 均未改变。

共享工作区历史 evidence（同样排除屏障本身与 Task 46 自身证据）：

- 执行前后均为 `1789 files / 30,700,276 bytes / 51 CSV / 329 translation / 195 import / 0 无扩展名`
- 前后聚合 SHA-256 均为
  `caa84fda93fc58a6ba199d4e8987fb8e3d5d40d09d7e3eb24eaa4411c8d8630b`
- 既有 `329` 个 `.translation`、`.import`、无扩展名产物和历史 Task 42/43 evidence 均未删除、移动、重命名或改写。

## 屏障范围与剩余风险

- 冷副本 scan 后的 `.godot/editor/filesystem_cache10` 为 `108,921 bytes`，其中抽查到
  `combat/=57`、`.gd=468`、`scenes/=27`、`.tscn=49`；候选源文件包含 `377 .gd` 与
  `32 .tscn`。项目脚本和场景仍被正常扫描，屏障仅覆盖归档 evidence 子树。
- 本任务只切断后续 evidence 导入源；共享区既有 `329` 个 `.translation`、`195` 个 `.import`
  以及共享 `.godot/editor` 缓存仍是受保护的遗留风险，未在本任务中清理或认领。
- 未连接、关闭、重启或控制共享 Godot/editor/godot-ai；Git 写操作为零，未 push。
