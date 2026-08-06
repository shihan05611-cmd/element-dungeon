# 任务 29：正式主入口与六战可玩关卡流程

状态：IN_PROGRESS  
负责人：Run Flow/Scene Integration Agent 2.0（threadId `019fd63e-f9d7-7760-b68c-45b552c90881`，hostId `local`）  
依赖：任务 28 `ACCEPTED`；任务 20 继续历史 `BLOCKED`

## 1. 目标与硬门禁

本任务依据：

- `docs/design/元素地牢_局内构筑与成长机制变更需求.md`
- `docs/design/元素地牢_局内构筑与关卡流程实现契约.md`
- `docs/agent_tasks/completed/26_architecture_build_progression_level_flow_contract.md`
- `docs/agent_tasks/completed/27_run_economy_skill_progression_authority.md`
- `docs/agent_tasks/completed/28_seven_slot_passive_runtime.md`

建立新的正式 `RunGame` 主入口和首版可完整游玩的关卡闭环。运行项目必须从新入口连续完成六个真实战斗节点、两次路线选择、三次商店、占位最终 Boss 和结算；不允许清完单一 `TestRoom` 后停住，不允许在同一房间重复刷新敌人冒充换房，也不允许只凭领域状态机 runner 宣称完成。

本任务先用最小 smoke panel 提供可玩交互和状态展示；任务30才替换为正式 HUD/商店/路线/结算 UI。本任务不承担精细关卡设计、最终数值平衡、新美术或多阶段 Boss。

## 2. 唯一流程

```text
run_entry
→ combat_01_entry
→ shop_01_early
→ route_01_first_branch
→ combat_02_swarm / combat_02_pressure
→ combat_03_layer_elite
→ shop_02_mid
→ combat_04_validation
→ route_02_second_branch
→ combat_05_stable / combat_05_risk
→ shop_03_preboss
→ combat_06_final_boss
→ RUN_COMPLETE / run_result
```

- 每局恰好六战；第2战和第5战各从两条真实配置中选择一个。
- 路线选项必须冻结资源、遭遇、环境、风险说明和真实 target；选择后必须加载不同的房间配置/PackedScene实例。
- 房1、房3、房5后各进入一次完整商店。房1梦尘保底必须足够购买至少一个主动技能。
- 新 `RunGame` 根节点整局常驻，持有唯一 RunSessionHost/RunSession、Player、HUD、七槽配装和被动 Runtime；只替换 RoomContainer 内的 `RunRoomInstance`。
- Boss 首版可强化复用现有敌人/配置，但 Boss击杀与房间完成梦尘均为0；Boss后不得生成奖励或商店，必须在同一权威事务中直达结算。
- 失败、重复完成、陈旧路线、场景加载失败和重复结算必须结构化拒绝且无部分状态。

## 3. 精确 allowlist

```text
project.godot
growth/contracts/run_phase.gd
growth/contracts/route_option.gd
growth/contracts/route_snapshot.gd
growth/contracts/run_snapshot.gd
growth/contracts/run_command_result.gd
growth/contracts/run_node_snapshot.gd
growth/contracts/run_result_snapshot.gd
growth/flow/run_node_kind.gd
growth/flow/run_flow_definition.gd
growth/flow/run_node_definition.gd
growth/flow/route_branch_definition.gd
growth/flow/combat_room_definition.gd
growth/flow/enemy_spawn_definition.gd
growth/state/route_state.gd
growth/run_director.gd
growth/run_session.gd
growth/shop/shop_draft.gd
scripts/run_session_host.gd
scripts/enemy.gd
scripts/run/run_flow_coordinator.gd
scripts/run/run_room_instance.gd
scripts/run/run_flow_smoke_panel.gd
scripts/vfx/skill_vfx_coordinator.gd
scenes/run/run_game.tscn
scenes/run/run_flow_smoke_panel.tscn
scenes/run/rooms/room_arena_flat.tscn
scenes/run/rooms/room_arena_platforms.tscn
scenes/run/rooms/room_arena_corridor.tscn
scenes/run/rooms/room_arena_boss.tscn
resources/run/flows/prototype_two_layer_six_combat.tres
resources/run/rooms/combat_01_entry.tres
resources/run/rooms/combat_02_swarm.tres
resources/run/rooms/combat_02_pressure.tres
resources/run/rooms/combat_03_layer_elite.tres
resources/run/rooms/combat_04_validation.tres
resources/run/rooms/combat_05_stable.tres
resources/run/rooms/combat_05_risk.tres
resources/run/rooms/combat_06_final_boss.tres
growth/tests/run_task29_run_flow_contract_tests.gd
combat/tests/run_task29_real_room_flow_tests.gd
combat/tests/capture_task29_full_run_visual.gd
docs/agent_tasks/pending/29_playable_six_room_run_flow.md
docs/agent_tasks/evidence/task29/**
```

`project.godot` 只允许修改 `run/main_scene`。`scripts/vfx/skill_vfx_coordinator.gd` 只在现有接口确实不足时用于逐房敌人重绑。其他路径不得创建、修改、删除或重序列化。

## 4. 禁止事项与保护边界

- 不修改 `scenes/test_room.tscn` 或 `scripts/test_room.gd` 来伪造流程；TestRoom继续作为独立调试/回归场景。
- 不新增 RunSession/钱包/配装玩法 Autoload、静态局内状态、第二份配装持久化或 UI 草稿权威。
- 不改变任务27梦尘、购买、升级、重置公式；不改变任务28七槽、类型、迁移或四被动规则。
- 不实现任务30最终 HUD，不做随机平台拼接、新敌人美术、精细/多阶段 Boss、新元素或任务31数值精调。
- 不在 Boss 后进入商店、奖励页或产生梦尘；不得用测试夹具直接调用终局函数跳过流程。
- Task20 runner/capture/evidence继续历史非门禁，禁止修改或据此接受任务20。
- 不使用子 Agent；不执行 `git add/commit/push/reset/restore/checkout/clean/stash` 等 Git 写操作。

共享 Godot 编辑器按用户决定可以被动保持开启以维持 MCP，但执行者不得在共享项目调用 Godot/MCP save、reload、reimport、运行、测试或截图。编辑器自动生成的 `.gd.uid/.import` 与共享 `.godot` 漂移必须单列审计，不得删除、认领或混入任务29交付。

## 5. 权威与场景职责

- RunSession/RunDirector拥有节点推进、路线、商店、梦尘、完成/失败和结果权威；每个命令使用预期 revision/session/节点身份并保证原子与幂等。
- RunFlowCoordinator只编排命令、常驻对象和真实房间实例；不得复制钱包、节点或结算规则。
- RunRoomInstance只暴露当前房间实例身份、出生点、敌人列表和完成事件；不能决定下一节点或奖励。
- RunSessionHost只建立一次 Session/七槽Runtime/被动Runtime，逐房重绑敌人与房间身份；Player、HUD、配装、技能等级和被动跨房常驻。
- 四张房间模板必须是完整 PackedScene；八份 room `.tres` 冻结模板、出生、敌人、环境和梦尘字段。路线分支必须产生可观察的真实资源/实例差异。
- 场景实例化失败、缺失出生点、敌人配置非法时不得推进权威节点；应保持旧房或进入明确失败结果，不得留下半切换状态。

## 6. 自动化与独立冷副本

- 所有 editor scan、runner、smoke、capture只进入此前不存在的 `C:\tmp` 冷副本与独立 profile；排除 `.git/.godot/.workbuddy/cache`并逐文件核对。冷副本第一条 Godot 命令必须是4.7.1 headless editor scan。
- Task29领域 runner覆盖：唯一节点图、每局恰好六战、两条分支真实 target、三个商店位置、Boss直结算、死亡、重复完成、陈旧路线、重复结算、scene failure及原子不变。
- 真实场景 runner必须从 `res://scenes/run/run_game.tscn` 开始，至少观察两次不同 PackedScene和实例ID，完成路线、商店消费、六战与结算；不得直接调用终局方法。
- 新 `run_game.tscn` 运行180帧 smoke；`test_room.tscn` 另跑180帧 smoke并保持可加载。
- 任务28接受基线为 `23/23 runners、266 tests / 2646 assertions`，必须逐个恢复。Task12/16/18/24保持 `13/110、11/209、9/124、10/190`。
- Task20 runner单列非门禁，继续历史 `BLOCKED`；正式日志中的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均须为0。

## 7. 实际可玩与 Viewport

- 执行侧必须从新 `RunGame` 入口实际完成一局，证明项目运行不再在单一测试房清场后停住。最小 smoke panel可以提供路线选择、商店命令、流程推进和结算信息，但不能持有权威。
- 独立非编辑器图形 Godot 4.7.1 至少生成四张1920×1080实际Viewport：入口/战1、路线选择、不同模板的后续房、占位 Boss 后结算。
- 保存截图前自动断言 `completed_combat_rooms == 6`、最终 phase/result、三次商店、两次路线选择，以及不同 PackedScene/实例ID记录；截图只能证明场景接线与可见状态，领域数值由runner断言。
- 执行侧必须实际打开原图人工检查房间差异、交互可读性、玩家/HUD常驻、Boss/结算和遮挡裁切；不得只给像素统计或静态mockup。

## 8. 完成与自动回传

只有新主入口可完整游玩、全部门禁和视觉通过、共享保护对账完成后，才可把本任务更新为 `REVIEW` 并冻结；不得自行 `ACCEPTED`。

交付必须列出：修改/新增文件与SHA；节点图和场景资源映射；六战/路线/商店/Boss/结果权威摘要；Task29专项与23-runner基线精确数字；两个smoke；全部日志错误计数；冷副本/profile与复制核对；四张Viewport路径/尺寸/SHA和人工验图；共享 `.godot`/sidecar/allowlist保护对账；风险；Git写操作为零。

完成或阻塞后必须由本职责对话直接调用 `send_message_to_thread` 回传当前中枢 Review 5.0：threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`、hostId `local`。完成回传 `REVIEW`，阻塞回传 `BLOCKED`，不要等待用户转述；回传后保持冻结。
