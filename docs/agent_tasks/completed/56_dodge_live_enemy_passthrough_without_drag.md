# 任务 56：闪避穿过活跃敌人且不携带目标位移

状态：ACCEPTED
负责人：独立玩法执行任务（中枢派发）
依赖：任务 48、52（均 ACCEPTED）
Git 基线：`main` HEAD `5c0f2ee24ab8c1e494e1e185666c94edd7b79228`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级/停线触发：若修复必须修改敌人公共移动/碰撞协议、项目碰撞层定义、`CombatReceiver`、场景资源或 allowlist 外生产文件；活跃 Boss 复现存在随机/帧序偶发；只能控制共享 Godot 才能验证；或无法从用户未提交 `global_instakill` 中精确隔离 Task56 候选，则停止并交付 `BLOCKED`/建议 `ESCALATE L3`，不得自行扩域。

## 1. 用户观察与可观察目标

用户在 Boss 战确认：闪避碰到敌人后，敌人会被玩家沿闪避方向强制携带到终点。

本任务冻结结果：

1. 玩家闪避应穿过普通敌人与 Boss 的身体，完整开放地面位移继续为玩家身体宽度的 `5.0` 倍。
2. 穿越过程中不得由闪避碰撞求解把目标拖拽、顶推或传送到玩家终点。
3. 世界墙壁、地面和平台继续阻挡闪避；不得借修复获得穿墙能力。
4. 闪避结束或被中断后，玩家与敌人的正常实体碰撞必须恢复。
5. Task48/52 的 `0.18s` 动作、结束后 `0.55s` 冷却、完整动作无敌、真实碰撞移动、输入/动作门禁和视觉表现保持不变。

## 2. 根因与实现路径对齐

当前实现只在玩家 mask 一侧关闭敌人身体层；玩家自身仍暴露在 Player 身体层，活跃敌人/Boss 继续执行 `move_and_slide()` 并从敌人一侧检测玩家。连续重叠恢复会把敌人沿闪避轨迹推出。Task48 既有穿敌夹具执行了 `enemy.set_physics_process(false)`，因此没有覆盖该行为。

推荐的最低风险路径：闪避进入时保存玩家完整 `collision_layer` 与 `collision_mask`，在保留玩家对 WorldBlocker 检测的前提下，让敌人身体在闪避期间也检测不到玩家身体；所有正常结束与中断路径精确恢复原值。优先局部修改玩家闪避生命周期，不修改所有敌人的 AI/速度或逐个传送敌人，不为本修复建立新的全局碰撞协议。

若执行者发现关闭玩家某个身体层会破坏必要 Area/Hurtbox/交互消费者，必须列出实际引用证据并停线；不得静默改成遍历敌人、强制固定敌人坐标或动作结束后回滚敌人位置。

## 3. 权威与事务边界

1. 闪避状态及碰撞保存/恢复仍以 `PlayerCharacter` 为唯一权威。
2. `CombatReceiver.dodging` 继续只负责伤害拒绝，不改公共语义。
3. 敌人的自主移动保持敌人权威；测试应区分正常 AI 位移与闪避碰撞造成的额外位移。
4. 不允许通过记录敌人起点并在闪避结束后强制复位来伪造“不携带”。
5. 玩家世界碰撞依旧通过真实 `move_and_collide` sweep 完成，不直接改 `global_position`。

## 4. 精确 allowlist

1. `scripts/player.gd`
2. `combat/tests/run_task56_dodge_live_enemy_passthrough_tests.gd`
3. `combat/tests/run_task56_dodge_live_enemy_passthrough_tests.gd.uid`（仅隔离 scan 自然生成时）
4. `combat/tests/capture_task56_dodge_live_enemy_passthrough.gd`
5. `combat/tests/capture_task56_dodge_live_enemy_passthrough.gd.uid`（仅隔离 scan 自然生成时）
6. `docs/agent_tasks/56_dodge_live_enemy_passthrough_without_drag.md`
7. `docs/agent_tasks/evidence/task56/**`

Task48 runner、Boss 房、玩家/敌人场景和 `scripts/enemy.gd` 仅可读取与运行，不得修改。若无需新增 capture 即能提供一次可判定的实际 Boss 视觉 smoke，可不创建第 4、5 项；未使用项在交付中注明。

## 5. 强制保护与候选隔离

共享工作区存在用户独立、未提交的 `global_instakill`：

- `M project.godot`
- `M scripts/player.gd`
- `?? combat/tests/run_global_instakill_tests.gd`
- `?? combat/tests/run_global_instakill_tests.gd.uid`
- `?? tmp/codex-global-instakill-validation-20260813/`

Task56 只授权修改 `scripts/player.gd` 的闪避碰撞生命周期，不授权修改、运行、暂存、删除、解释或认领上述功能及其 runner/产物。正式实现与验证优先从固定 Git 基线构造隔离候选，不得从共享 live `scripts/player.gd` 整文件复制到候选。若最终需要把纯 Task56 小改动回写共享文件，只能精确应用闪避相关 hunk，并证明用户既有 `global_instakill` diff 原样保留。

另有 task12..34 历史 `.import` 删除、Task47 未跟踪归档、Task54/55 取消产物、translation/import/`.godot`/中文保护文档等外部状态，全部不得恢复、修改、删除、暂存或认领。Godot PID17624、godot-ai PID3964 为共享实例；禁止连接、关闭、重启、reload、reimport、保存或控制。

## 6. L2 专项与回归门禁

专项必须至少覆盖：

1. **活跃普通敌人**：敌人物理进程保持开启；可将 AI 水平意图稳定为 0 以隔离碰撞恢复，但不得 `set_physics_process(false)`。玩家从敌人一侧完成闪避并越过其中心，敌人相对起点的非自主位移不超过明确小容差。
2. **活跃 Boss**：使用正式 terminal enemy/Boss 配置或等价正式实例，物理进程保持开启；玩家穿过后 Boss 不被携带到终点。若为排除自主追击而关闭 AI，仍须保留 Boss 的 `_physics_process`/`move_and_slide()` 路径。
3. **世界阻挡**：墙体提前截断，平台/地面合同不退化；不得关闭玩家全部碰撞。
4. **生命周期恢复**：正常结束、撞墙中断、死亡/退出等现有可安全触发路径均恢复进入前完整 layer/mask；不得硬编码恢复值覆盖其他来源状态。
5. **既有闪避合同**：5 身位、0.18s、0.55s、完整 DODGED 拒伤、技能/输入门禁和动作后正常移动继续通过。
6. **恢复后的实体碰撞**：闪避结束后玩家与敌人重新发生正常身体阻挡，不永久幽灵化。

执行侧至少运行：Task56 专项、完整 Task48 专项、一个直接 combat 回归、正式 Boss 房或等价实际场景 smoke、一次可判定的实际视觉检查，以及本轮正式日志的脚本/解析/引擎错误与崩溃扫描。L2 默认使用安全隔离候选和独立 profile，不要求全新第二冷根或全游戏回归。

## 7. 禁止项与交付

- 不修改 `project.godot`、`scripts/enemy.gd`、`combat/components/combat_receiver.gd`、玩家/敌人场景、Boss 房、碰撞层定义、Task48/52 归档或历史 evidence。
- 不以关闭敌人物理进程、冻结所有敌人、结束后复位敌人坐标、缩短距离或直接传送玩家通过测试。
- 不使用子 Agent；不执行 `git add/commit/push/reset/restore/checkout/clean/stash`；不自行标记 `ACCEPTED`。
- 完成后将本任务状态更新为 `REVIEW`，回填精确修改、测试/断言/日志、视觉检查、保护对账和 Git 写操作为零声明，然后在执行任务内冻结。中枢继续通过 `wait_threads` 主动收取；冻结后仅按最新 `CENTRAL_REVIEW_RULES.md` 向本次派发的当前中枢发送一次固定格式单行回执，禁止大段跨对话交付。

## 8. 协调记录

- 执行职责候选审计：当前可见项目任务中没有空闲且同职责、可证明无上下文压力的玩法执行对话；Task54/53 分别属于已取消地图可行性与美术 Review，不复用。处置：创建新的独立玩法执行任务，任务书自包含，压力等级 `GREEN`。
- 执行对话：`threadId=019ffef1-5a9e-7050-a516-0e837a163100`，`hostId=local`；实际派发模型 `gpt-5.6-sol`，推理等级 `high`；隔离 Codex worktree `C:\Users\heliashi\.codex\worktrees\abf7\元素地牢-4.7`。
- 首个 `wait_threads(timeoutMs: 0)` cursor：`ffc26f01-65d1-41d0-af01-db09011a0919:1`；快照为执行中。中枢后续使用该实际任务 id/cursor 主动跟踪，单行回执仅作断线唤醒。
- 执行冻结收取：单行回执于 2026-08-14 成功唤醒当前中枢；随后 `wait_threads` cursor 更新为 `ffc26f01-65d1-41d0-af01-db09011a0919:6`，并由 `read_thread` 收取完整交付。回执未作为验收依据。
- 独立 L2 Review 对话：`threadId=019fff0f-a838-7ee1-8fb6-fdc9b75ea330`，`hostId=local`；模型 `gpt-5.6-sol`，推理等级 `high`；隔离 worktree `C:\Users\heliashi\.codex\worktrees\953f\元素地牢-4.7`。
- Review 首个 `wait_threads(timeoutMs: 0)` cursor：`9f1a9ddf-7f3d-463d-b4fd-9ee04538ccdc:1`；快照为执行中。Review 不由执行者自验收。
- Review 冻结收取：单行回执于 2026-08-14 唤醒当前中枢；中枢随后通过 `wait_threads` 收取完成事件，cursor 更新为 `7abeadbd-c942-49fa-b402-e54abcee3ece:1`，并通过 `read_thread` 读取完整 Review 过程与冻结记录。回执未作为验收依据。

## 9. L2 执行交付（2026-08-14，冻结）

- 实际执行模型：`gpt-5.6-sol`；推理等级：`high`。独立 worktree 起点 `HEAD fffc91ec5e371ce06f5e5b69d19ce313b8d7f061`，生产基线为其父 `5c0f2ee24ab8c1e494e1e185666c94edd7b79228`。
- 生产修复仅涉及 `scripts/player.gd` 的闪避碰撞生命周期：保存完整 `collision_layer`，闪避期间只关闭 PlayerBody 层暴露，继续保留 WorldBlocker mask，并由既有统一 `_finish_dodge()` 精确恢复完整 layer/mask。
- Task56 专项：修复前稳定复现普通敌人被携带 `134.7315px`、正式 terminal Boss 被携带 `79.7279px`；修复后 `4 tests / 36 assertions / 0 failures / exit 0`。覆盖活跃普通敌人、正式 Boss、5 身位穿越、`0.35px` 非自主位移容差、墙阻挡、正常/撞墙/死亡/退出恢复和闪避结束后的实体阻挡。
- Task48 完整回归：`5 tests / 55 assertions / 0 failures / exit 0`；直接 combat 回归：`27 tests / 124 assertions / 0 failures / exit 0`。
- 正式 Boss 房非 headless OpenGL 视觉 smoke：`1 test / 3 images / 0 failures / exit 0`。三张 `1920×1080` 原图分别证明 ready、mid-overlap、recovered，Boss 未被携带到终点。
- 正式日志 `05..09` 合并扫描 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 命中 `0`。
- 最终候选及 evidence 全部位于 Task56 allowlist；执行未修改敌人、`CombatReceiver`、场景、碰撞层定义或 Task48 runner，未控制共享 Godot/editor/godot-ai，Git 写操作为零。

## 10. 中枢接受记录（2026-08-14）

- 独立 L2 Review：`PASS`。Review 使用 Godot `4.7.1.stable.official.a13da4feb`、独立 profile 和 `GODOT_AI_MODE=disabled` 复跑 Task56 专项 `4/36/0`、Task48 完整回归 `5/55/0`、正式 Boss 房 smoke `1 test / 3 images / 0 failures`，正式 stdout 五类错误标记为 `0`。
- Review 确认普通敌人和正式 Boss 的物理进程保持开启，仅关闭自主水平意图；玩家开放地面完成 5 身位穿越、墙体继续截断、所有结束/中断路径恢复进入前 layer/mask，且目标水平非自主位移均不超过 `0.35px`。
- mid-overlap 图因动画采样发生可解释哈希变化，但原尺寸视觉仍明确显示半透明玩家与 Boss 重叠，专项数值断言独立证明 Boss 未被携带；L2 接受该残余风险。
- 中枢集成时仅向共享 `scripts/player.gd` 精确应用四处 Task56 闪避 hunk；用户既有未提交 global_instakill hunk保持原样，未运行、暂存、删除或认领其 runner、UID 与产物。
- 结论：Task56 `ACCEPTED`；归档并建立精确 Git 检查点，不 push。
