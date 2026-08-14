# Task49 执行者 L3 候选证据

状态：候选待中枢复核（执行者不自行 `ACCEPTED`）  
执行模型：`gpt-5.6-sol`  
thinking：`high`  
基线：`fc7b531`  
Godot：`4.7.1.stable.official.a13da4feb`

## 候选结果

正式流程已经收敛为唯一线性序列：

`combat_01_entry → combat_02_swarm → shop_demo_mid → combat_04_validation → combat_06_final_boss → run_result`

结算冻结为 `4 combat（含 Boss）/1 shop/0 route`。旧资源 `resources/run/flows/prototype_two_layer_six_combat.tres` 已删除；活跃生产、runner 与 capture 中没有加载旧资源的引用，唯一保留字符串位于 Task49 专项，用于断言旧路径不存在。

首房由房间资源权威声明 `single_wave=true` 与 `guaranteed_active_skill_reward=true`，运行时为恰好 2 个初始敌人、0 援军；两敌清除后立即只触发一次清场。首箱候选仅来自 `reward_pool` 中玩家未拥有且 `is_active_skill()` 的内容，并保留排序、稳定哈希与 command replay。主动池耗尽时返回既有类型化 `DREAM_DUST` 奖励 150，提交一次后可重放，同房新 command 会被 `ALREADY_CLAIMED` 拒绝。非保底房间仍走原 50/50 逻辑。

## 隔离环境

- 冷根：`C:\tmp\element-dungeon-task49-formal-20260813-02`
- 独立 profile：`C:\tmp\element-dungeon-task49-formal-profile-20260813-02`
- 冷根来源：`git archive fc7b531` 加 Task49 精确 allowlist 候选覆盖，并显式移除旧 flow。
- 环境：独立 `APPDATA`/`LOCALAPPDATA`，`GODOT_AI_MODE=disabled`，未连接或控制共享 Godot。
- 当前候选源码与冷根中受测候选逐文件 SHA-256 一致；最终仅任务书状态与 evidence 元数据在验证后更新。
- 中枢未来独立 L3 应从当前接受 HEAD `616867f` 加 Task49 overlay 重建，以同时保留 Task48/51；本执行冷根仅用于本轮候选及第三次范围修正验证。

## 验证摘要

- 11 个 runner：54 tests、3796 assertions、0 failures。
- 9 个 capture：70 screenshots、至少 2303 条显式 assertions；全部退出码 0。
- Task49 专项：5 tests、103 assertions、0 failures。
- Task49 全流程 capture：1 test、6 images、0 failures；六图均为 1920×1080 并已逐张目检。
- 主场景冷启动：退出码 0。
- 最终 `--import` editor scan：退出码 0。
- 32 份正式日志中 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException` 均为 0。

## 第三次范围修正

- `scenes/run/run_flow_smoke_panel.tscn` 默认标题由“六战原型”同步为“五阶段演示”。
- `scripts/ui/run_overlay_interface.gd` 的通用路线面板保留，但战斗总数改读 `RunFlowDefinition.REQUIRED_COMBAT_ROOMS`，不再硬编码 `/6`。
- 活跃 `growth/combat/scripts/scenes/resources` 旧六战语义扫描仅剩 Task49 专项中的旧路径不存在断言，生产残留为 0。
- 最小重验：Task49 专项 5/103、Task30 UI 9/166、烟测 scene 启动、Task49 六图、主场景启动与 final import scan 均通过；详见 `third_scope_revalidation.csv`。

## 第四次范围修正

- `resources/run/rooms/combat_06_final_boss.tres` 仅将玩家可见 `display_name` 从“战 6”改为“战 4”；`room_id`、spawn、数值、位置、模板、其余标签与奖励不变。
- Task49 capture 保留 `99999` 与 `CombatReceiver.receive_hit()` 清场路径，仅在 Boss 截图前等待 1 秒，让既有伤害字按生产 tween 生命周期自然消退；未隐藏或修改生产伤害 UI。
- 六图原尺寸复核通过：第 5 张清晰显示“战 4 · 占位最终 Boss · 终焉王座”，Boss 无旧伤害字遮挡；其余五图门禁保持。
- 最小重验：Task49 专项 5/103、六图 capture 1/6、主场景 smoke 与 final import scan 全部通过；32 份日志五类标记全零。详见 `fourth_scope_revalidation.csv` 与 `fourth_scope_protection_hashes.csv`。

详表见 `runner_summary.csv`、`capture_summary.csv`、`third_scope_revalidation.csv`、`fourth_scope_revalidation.csv`、`log_marker_summary.csv`、`sidecar_summary.csv` 与保护哈希表。

## 六图视觉门禁

1. `task49_01_first_room_two_enemies_1920x1080.png`：首房同屏恰好 2 敌。
2. `task49_02_first_room_immediate_clear_1920x1080.png`：清场后宝箱出现、传送门等待开箱，无援军。
3. `task49_03_first_chest_active_guarantee_1920x1080.png`：获得主动技能“回收”并权威自动配装至 A2。
4. `task49_04_mid_shop_after_two_combats_1920x1080.png`：两场战斗后进入唯一商店。
5. `task49_05_final_boss_fourth_combat_1920x1080.png`：Boss 为第 4 场战斗。
6. `task49_06_result_four_one_zero_1920x1080.png`：结算显示 4/4、1/1、0/0。

## 边界与风险

- Task49 未修改 `project.godot`、`scripts/player.gd`、`scenes/player.tscn`。共享工作区中前两者相对 Task49 基线已有外部 Task48 漂移；冷根中的三份保护文件均与 `fc7b531` 一致，详见保护对账表。
- 中枢独立产出的 `review_l3/**` 保持原样，执行者 manifest 明确不纳入该外部证据目录。
- 旧分支房间与路线素材按任务书保留为未使用素材；新正式 flow 没有路线节点或兼容分支。
- Task29/30/31/32/40/41/42/43 runner/capture 仅迁移正式流程推进；其拖拽、HUD、权威恢复、奖励经济、被动配装、物理波次、Boss、结算与分辨率门禁均保留并通过。
- 未执行 Git 写、暂存、提交或 push；未认领共享 `.translation`、`.import`、`.godot` 或其他任务 evidence。
