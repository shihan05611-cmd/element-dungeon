# 任务 50：Boss 远程攻击卡入地形只读诊断

状态：DIAGNOSED
负责人：原流程与可玩性执行 3.0 / 成长与数值执行 2.0（只读复用）
依赖：任务 43（ACCEPTED）
Git 基线：`main` HEAD `fc7b531`
Diagnosis Model：`gpt-5.6-sol`
Diagnosis Thinking：`high`
Review Level：L2（当前仅诊断；实现等级在根因确认后重定）

## 1. 用户现象

Boss 关的远程攻击目前会出现“卡到地里”的可见错误。当前不预设根因，须区分：

1. Boss 弹道出生点位于地形内部或过低；
2. 弹道方向/Transform、碰撞 shape 或 sweep 初始重叠；
3. 弹道与世界碰撞层/掩码错误，发生嵌入、停止或重复碰撞；
4. ProjectileDelivery 的移动、命中、关闭窗口或销毁路径异常；
5. Boss 房间模板地面几何与其他房间不同导致的专属问题；
6. 仅为视觉贴图偏移而非 authority 碰撞位置错误。

## 2. 当前静态入口

`scripts/enemy.gd::_spawn_boss_projectile()` 使用 `boss_arc_projectile.tscn`，出生 Transform 当前由 Boss 位置加水平 `58`、垂直 `84` 构造；必须结合 Godot 2D 坐标方向、Boss sprite/body 原点、弹道碰撞 shape 和 Boss 房间地面几何验证，不能只凭该常量下结论。

## 3. 诊断边界

允许只读检查：

1. `scripts/enemy.gd`
2. `scenes/run/boss_arc_projectile.tscn`
3. Boss 弹道所引用的 delivery/definition/profile 脚本与资源
4. `resources/run/rooms/combat_06_final_boss.tres`
5. Boss 房间模板及其地面碰撞节点
6. Task 41–43 对 Boss 弹道、房间、smoke/capture 的测试与历史证据

允许写入仅限：

1. `docs/agent_tasks/pending/50_boss_projectile_ground_clipping_diagnosis.md`
2. `docs/agent_tasks/evidence/task50/diagnosis.md`
3. `docs/agent_tasks/evidence/task50/diagnosis_log.txt`（必要时）
4. `docs/agent_tasks/evidence/task50/screenshots/**`（必要时）

## 4. 禁止项

当前阶段不得修改任何游戏代码、场景、资源、测试或配置；不得触碰 Task 48/49 候选；不得执行 Git 写操作、push 或自行 `ACCEPTED`；不得连接、关闭或控制共享 Godot/editor/godot-ai。若需要运行复现，只能在全新隔离副本与独立 profile。

## 5. 诊断交付

1. 最小复现步骤和发生频率；明确是否必现、方向相关、与玩家位置/地形边缘相关。
2. 弹道出生 authority 坐标、碰撞 shape、首帧移动/碰撞结果、可见贴图坐标与地面碰撞边界。
3. 唯一根因或按证据排序的根因候选；不得只给猜测。
4. 最小修复文件与建议断言；说明是否触及公共 ProjectileDelivery 或仅 Boss 专属配置。
5. 与 Task 49 新五阶段正式流的关系：新流复用同一 Boss 房间，因此该 Bug 会进入演示主路径，但 Task 49 不负责顺手修复。
6. 完成后状态改为 `DIAGNOSED` 并回传中枢；不进入 `REVIEW/ACCEPTED`。

## 6. 对话压力审计

原负责人对话已连续承载 Task 42/43，判定 `YELLOW`，不再直接派发复杂生产实现；但当前任务为其原职责内、任务书自包含的只读诊断，允许复用。诊断后生产修复默认建立新的 5.6 执行任务。

## 7. 诊断结论（2026-08-13）

唯一根因已经由 authority 坐标、碰撞 shape、首帧 sweep 和房间边界共同确定：`scripts/enemy.gd::_spawn_boss_projectile()` 把 Boss 弹道固定生成在 Boss 根节点下方 `84 px`（Godot 2D 的 `+Y` 向下）。Boss 在高台时根节点为 `y=420`，弹道中心 `y=504`，位于高台底部 `y=480` 与主地面顶部 `y=540` 之间；Boss 走下高台并站到主地面后根节点为 `y=508`，同一公式把弹道中心放到 `y=592`，其半径 `13 px` 的 authority 圆完整落入主地面 `y=540..628`。

`PhysicsProjectileSweepQuery2D` 会先对起始 Transform 执行 `intersect_shape()`；该状态命中 blocker layer `4` 后返回 fraction `0.0`。`ProjectileDelivery.advance()` 因而首个物理步位移为 `0`、发出 blocker contact、以 `blocked` 结束并排队释放。碰撞层和生命周期均按合同工作，错误输入是 Boss 专属出生点；Boss 房地面尺寸与其他正式房一致，贴图 alpha 可见区也只比碰撞圆上下各多约 `2 px`，不是纯视觉偏移。

最小生产修复仅需 `scripts/enemy.gd`：移除 Boss 弹道的 `+84` 下移，把中心放回 Boss 根节点高度（建议 `y = global_position.y`）。这样在高台与主地面两种站立状态下，碰撞圆底部都距当前承载面 `19 px`，可见 alpha 底部约距承载面 `16.96 px`，无需修改公共 `ProjectileDelivery`、sweep、碰撞 mask、弹道场景或 Boss 房几何。修复须由新的生产任务实施并增加能让当前 HEAD 失败的 Boss 专项；本任务未实施修复。

完整坐标表、复现边界、Task 41 历史盲区、Task 49 关系及建议强断言见 `docs/agent_tasks/evidence/task50/diagnosis.md`。本次没有启动 Godot，也没有创建隔离运行副本；确定性静态闭环已足够诊断，且未连接或控制共享编辑器进程。
