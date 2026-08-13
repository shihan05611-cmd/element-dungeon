# Task 48 执行证据

状态：`REVIEW` 候选（执行者不自行 `ACCEPTED`）  
固定基线：`fc7b5318f3b32860ee10265c23aa1cff199e1b99`  
最终冷根：`C:\tmp\element-dungeon-task48-exec-20260813-03`  
独立 profile：`C:\tmp\element-dungeon-task48-profile-20260813-03`  
Godot：`4.7.1.stable.official.a13da4feb`

## 实现

- `Shift` 注册为新输入 `dodge`；不覆盖任何既有输入。
- 闪避仅在存活、着地、未受击、SkillExecutor 为 `IDLE`、未闪避且冷却完成时启动。
- 参数为 `0.18s` 动作、动作结束后 `0.55s` 冷却、玩家实际 BodyCollision 世界宽度的 `1.5` 倍水平位移；当前正式 Capsule 宽 30px，因此开放地面目标为 45px。
- 每个物理帧使用真实 `move_and_collide(Vector2(horizontal_step, 0))`；没有 `test_only`、传送或关闭全部碰撞。进入时保存完整 mask，仅关闭敌体第 2 层并保持世界第 3 层，结束/撞墙/受击式中断/暂停/死亡/重生/退出树均由同一幂等函数恢复原 mask、视觉、速度和 `CombatReceiver.dodging`。
- `CombatReceiver.dodging` 在首次位移/表现前设为 true，最后一帧后恢复；未修改 Receiver 源码，也未读取或写入 `invulnerable`。
- 闪避期间阻断跳跃、技能和元素切换；结束后专项证明三者恢复。轻量表现只复用现有 AnimatedSprite2D，以声明过的物理 Tween 做透明度脉冲。

## 正式验证

- 首次 editor scan：exit 0。
- Task 48 专项：`5 tests / 55 assertions / exit 0`。
- Agent D 玩家/战斗集成：`9 tests / 73 assertions / exit 0`。
- Task 16 技能目录/元素门面：`11 tests / 236 assertions / exit 0`。
- Task 31 双路线完整局：`4 tests / 534 assertions / exit 0`。
- RunGame 主场景 180 帧 smoke：exit 0。
- 非 headless 真实 Viewport capture：`1 test / 3 images / 0 failures / exit 0`，三图均为 1920×1080 并已原尺寸检查。
- final editor scan：exit 0。
- 8 份正式成功日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。

## UID、sidecar 与保护

- 两枚 `.gd.uid` 均由最终冷根首次 scan 生成并逐文件回流：runner `uid://cmty4vmexgy5e`，capture `uid://42uiiv6aoel1`；在最终冷根各唯一出现 1 次。
- 最终冷根 Task 48 evidence 下为 0 `.import`；共享 evidence 只回流三张 PNG、8 份日志和文本汇总，不回流 `.godot`、`.import`、`.translation` 或失败产物。
- 共享 `.godot` 前后均为 `1154 files / 31,899,157 bytes / latest 2026-08-13T11:31:22.1201304Z`；共享 Godot PID 17624 与 godot-ai PID 3964 保持存活且未受控制。
- 排除外部新增顶层 `tmp/` 后，共享 sidecar 从 `377/128/329` 变为 `379/128/329`（`.gd.uid/.import/.translation`），唯一新增即本任务两枚授权 UID。
- 执行期间外部新增的未跟踪顶层 `tmp/` 含 `1891 .gd.uid / 1124 .import / 889 .translation`，时间戳为保留的旧值；它不在 allowlist、不进入固定基线或冷候选，未删除、移动、修改、认领或回流。
- `combat/components/combat_receiver.gd` 与 `scenes/player.tscn` 对固定基线均 `git diff --quiet`；没有修改公共战斗接口或项目碰撞层定义。

## 失败/诊断隔离

- `-01` 因把 `USERPROFILE` 指到空 profile 触发 4 条 Windows `get_system_dir` 错误，作为隔离包装失败保留，不计入成功门禁；其后仅作专项诊断。
- `-02` 的首次 headless capture 卡在渲染帧等待，已精确终止隔离 PID；随后非 headless 诊断暴露手动位移没有同步推进 Tween。修正 capture 让真实 `_physics_process` 同时推进位移与 Tween 后通过。`-02` 不作为最终冻结候选。
- 上述失败和诊断日志、失败截图只留在各自冷根/profile，不进入本 evidence manifest。

## 剩余风险

- 最终接受仍需中枢在另一全新冷副本独立 L3 验收；执行侧不作 `PASS/ACCEPTED` 结论。
- 当前残影表现采用透明度脉冲而非新增残影节点，满足轻量与无新资源边界，但最终手感和可读性仍由中枢独立视觉复核决定。

