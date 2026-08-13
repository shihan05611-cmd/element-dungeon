# Task 48 独立 L3 Review 证据

结果：`PASS`（仅 Review 结论；未写 `ACCEPTED`）  
实际模型：`gpt-5.6-sol`  
实际推理等级：`high`  
固定基线：`fc7b5318f3b32860ee10265c23aa1cff199e1b99`  
正式冷根：`C:\tmp\element-dungeon-task48-review-20260813-04`  
独立 profile：`C:\tmp\element-dungeon-task48-review-profile-20260813-04`  
Godot：`4.7.1.stable.official.a13da4feb`

## 候选重建与执行证据失效点

执行者 `-03` 的 `project.godot`、`scripts/player.gd` 是从共享 live 工作区整文件复制，二者与共享 SHA 全等，因此同时带入了 Task48 之外的 `global_instakill`。原执行全绿证据不能证明纯 Task48，且其保护表中的 `CombatReceiver` 哈希取自共享文件而非 `-03` 冷根。该证据只作为污染来源说明，不作为本次 PASS 依据。

Review 从 Git 对象以 `git archive --format=zip` 导出固定基线；`project.godot` 只叠加 `dodge/Shift`，`scripts/player.gd` 只叠加闪避实现。重建时从 `-03` 精确剔除完整 `global_instakill` action、常量、静态 cast id、输入分支、`release_global_instakill` 及两个 helper；全冷根搜索结果为 0。runner、capture 与两枚 UID 从 `-03` 字节复制；`scenes/player.tscn` 保持基线不变。精确来源见 `csv/overlay_provenance.csv`，文件哈希见 `csv/allowlist_hashes.csv`。

正式根为此前不存在的 `-04`。`-01` 因 Windows tar 中文路径解码失败，`-02/-03` 因 `--quit-after` 提前结束 scan thread，均作为诊断根保留在 `C:\tmp` 且未进入正式 evidence。先在已排除根验证 `--import` 会等待完整导入且五类标记为零，随后才创建 `-04`；`-04` 的第一条 Godot 命令即正式 `--headless --editor --import`。

## 静态合同

- `project.godot` 仅新增物理 Shift 的 `dodge`，没有 `global_instakill`，既有输入未覆盖。
- 闪避启动门禁覆盖存活、着地、未受击、SkillExecutor `IDLE`、未闪避和冷却结束；方向采用当前水平输入或最后朝向。
- 参数为 `0.18s / 0.55s / 1.5 body widths`；每帧使用水平 `move_and_collide`，无 `test_only`、无传送、无全 mask 关闭。
- 首次移动/表现前设置 `CombatReceiver.dodging`；仅临时关闭敌体第 2 层、保持世界第 3 层；自然结束、碰墙、暂停、受击式中断、死亡、重生和退出树均经幂等清理恢复完整 mask、视觉和状态。
- 未读写其他来源的 `invulnerable`，未修改 `CombatReceiver`、公共战斗接口或碰撞层定义；未新增 Sprite、纹理、音频或动画资源。

## 正式命令与结果

所有命令均设置独立 `APPDATA`、`LOCALAPPDATA`、`GODOT_EDITOR_DATA_PATH`，项目路径固定为 `-04`。完整命令结果见 `csv/execution_summary.csv`，完整输出见 `logs/`。

- cold-first editor `--import`：exit 0。
- Task48 专项：`5 tests / 55 assertions / exit 0`。
- Agent D 玩家/战斗回归：`9 / 73 / exit 0`。
- 技能目录/元素门面回归：`11 / 236 / exit 0`。
- Task31 双路线完整局：`4 / 534 / exit 0`。
- 正式 RunGame 主场景：`180 frames / exit 0`。
- 非 headless OpenGL Viewport capture：`1 test / 3 images / 0 failures / exit 0`。
- final editor `--import` rescan：exit 0。

8 份正式成功日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全部为 0，见 `csv/log_marker_summary.csv`。

## 视觉检查

三张图均为本轮 `-04` 生成的 1920×1080 原图并逐张原尺寸打开：ready 清晰；mid 玩家明显透明并与敌人身体重叠；end 已越过敌人、恢复不透明和正常构图。完整 i-frame、敌体穿越和墙体截断由专项真实伤害/碰撞断言证明；画面没有新增 Sprite。尺寸、bytes、时间与 SHA256 见 `csv/screenshots.csv`。

## sidecar、共享保护与并发

- 共享 `.godot`：前后均 1154 文件，逐项 bytes/mtime/SHA 差异 0。
- 共享 `.gd.uid/.import/.translation`：前后均 1674 文件，逐项差异 0。
- 冷根项目 sidecar：前后均 768 文件，内容差异 0；Task48 evidence 下 `.import` 为 0。
- 8 个候选关键文件前后哈希差异 0；两枚 Task48 UID 在冷根 UID sidecar 中各唯一出现 1 次。
- 共享 Godot PID 17624 与 godot-ai PID 3964 前后不变，Review 未连接、关闭或控制它们。
- 验证窗口内 Task49/外部并发新增三个共享 tracked 修改：`combat/tests/run_task40_drag_compact_hud_tests.gd`、`scripts/run/run_flow_smoke_panel.gd`、`scripts/ui/run_overlay_interface.gd`。它们未进入 Git 对象导出的冷根，未被修改、删除或认领，不影响候选真实性；精确哈希见 `csv/shared_concurrent_changes.csv`。

## 结论与剩余风险

纯 Task48 候选满足任务书 L3 的静态、专项、直接回归、主场景 smoke、真实 Viewport、日志、UID/sidecar、manifest 与共享保护门禁，Review 结论为 `PASS`。视觉为轻量透明度脉冲而非残影节点；这是任务书允许的表现路径。最终接受、归档和 Git 检查点仍由中枢决定。
