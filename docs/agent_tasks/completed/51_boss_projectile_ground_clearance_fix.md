# 任务 51：Boss 远程弹道地面出生重叠修复

状态：ACCEPTED
负责人：独立执行任务（中枢派发）
依赖：Task 50（DIAGNOSED）
Git 基线：`main` HEAD `fc7b531`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`high`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`high`

升级触发：若只改 Boss 专属出生 Transform 不能解决，或必须修改公共 `ProjectileDelivery`/sweep、弹道场景、碰撞层/shape、Boss 房几何、Task 48/49 文件，则立即停线回传并升级 L3。

## 1. 已确认根因

Task 50 只读诊断已确认唯一根因：`scripts/enemy.gd::_spawn_boss_projectile()` 使用 `global_position.y + 84`。Godot `+Y` 向下；Boss 留在高台根 Y=420 时弹道圆处于高台与主地面之间，但 Boss 落到主地面根 Y=508 后，弹道中心 Y=592、半径 13 的 authority 圆完整生成于 Ground `Y=540..628` 内。sweep 首个 `intersect_shape` 返回 blocker fraction `0`，弹体首帧零位移并以 blocked 结束。

碰撞 mask、生命周期、弹道场景、Boss 房 Ground 与可见 Sprite 偏移均正确，不得顺带修改。

## 2. 冻结修复

仅把 Boss 弹道出生 Y 从 `global_position.y + 84.0` 改为 `global_position.y`，保持水平偏移 `±58`、方向、Transform、payload、速度、shape、mask 和生命周期不变。

修复后在高台和主地面两种支撑面上，authority 圆底均应位于支撑面 top 上方 `19px`；可见 alpha 底约留 `16.96px`，不嵌地。

## 3. 精确 allowlist

允许修改/新增：

1. `scripts/enemy.gd`
2. `combat/tests/run_task51_boss_projectile_spawn_clearance_tests.gd`
3. 对应 `.gd.uid`（仅隔离 Godot 首扫确实生成时）
4. `combat/tests/capture_task51_boss_projectile_clearance.gd`（仅有必要时）
5. 对应 `.gd.uid`（仅隔离 Godot 首扫确实生成时）
6. `docs/agent_tasks/pending/51_boss_projectile_ground_clearance_fix.md`
7. `docs/agent_tasks/evidence/task51/**`

Task 41、Task 43 和公共弹道 runner 只运行回归，不修改。

## 4. 禁止项

不修改公共 ProjectileDelivery/sweep、`boss_arc_projectile.tscn`、碰撞 mask/shape/speed、Boss 房/模板、敌人 AI、玩家、Task 48/49；不删除或认领共享未跟踪产物；不连接、关闭或控制共享 Godot/editor/godot-ai；不执行 Git 写操作，不 push，不自行 `ACCEPTED`。

## 5. 专项门禁

新增确定性专项，当前 `fc7b531` 必须因主地面出生重叠而失败，修复候选必须覆盖：

1. 正式 Boss 房，Boss 高台与真实走下高台落稳后的主地面两种状态，各验证左/右发射。
2. 创建时圆半径 `13`、既有 mask/layer 不变；起始 layer4 `intersect_shape` 零命中。
3. `centerY + 13 < supportTop`，可见 alpha bottom 也在支撑面上方。
4. 首 physics frame 弹体仍有效，X 按现有 `255 * delta` 前进、Y 不漂移、累计距离大于 0、未触发 blocked。
5. 后续正常命中玩家或墙且只结束一次。
6. 回归 Task 41 的低弹道可跳语义，以及 Task 43 的敌人 defeated 后释放/不再生成新弹体语义。

## 6. L2 验收

执行者在全新隔离副本与独立 profile 完成 editor scan、专项、公共弹道直接回归、Task 41/43 相关 runner、Boss 主场景 smoke 和 final scan；所有成功日志五类标记为零。交付时状态为 `REVIEW`，回填命令、退出码、tests/assertions、sidecar、证据和风险；中枢独立复验后才能 `ACCEPTED`。

## 7. 执行交付（2026-08-13）

- 实际模型：`gpt-5.6-sol`，thinking=`high`。
- 精确生产 diff：`scripts/enemy.gd` 仅将 Boss 出生 Y 的 `global_position.y + 84.0` 改为 `global_position.y`。
- 新增专项及 cold-first UID：`run_task51_boss_projectile_spawn_clearance_tests.gd`、`uid://bnln7lbceavwq`。
- 固定 HEAD baseline 使用同一最终专项稳定失败：exit `1`，`2 tests / 92 assertions / 18 failures`；主地面左右均为 `1` 个 layer-4 初始 overlap、首帧各 `1` 次 blocker contact、零有效位移。
- 候选专项 `2/92`、Task41 `4/112`、Task43 `4/125`、Delivery `16/56`、reuse `10/105`、skill integration `1/4`、Task34 projectile transaction `11/211` 全部 exit `0`；直接 runner 合计 `48 tests / 705 assertions`。
- 正式主场景与 Boss 房各 `180` 帧 smoke、initial/final editor scan 均 exit `0`。
- 11 份候选成功日志和 baseline failure 日志五类标记均为零。
- 冷根非缓存新增只包含专项 runner 与其 UID；共享区未回流 `.godot`、`.import` 或 `.translation`。
- Task41/43 回归固定在 `fc7b531` 冷根，未消费 Task49 的共享中间态；Task48/49 无文件重叠且未修改。
- 完整日志、命令矩阵、哈希、sidecar 与风险见 `docs/agent_tasks/evidence/task51/README.md`。
- 未执行 Git 写操作，未连接、关闭或控制共享 Godot/editor/godot-ai。执行者现冻结为 `REVIEW`，不得自行 `ACCEPTED`。

## 8. 中枢独立 L2 Review（2026-08-13）

- 结论：`PASS / ACCEPTED`。
- 独立冷根 `C:\tmp\element-dungeon-task51-review-20260813-01`，独立 profile `C:\tmp\element-dungeon-task51-review-profile-20260813-01`，固定 `fc7b531` 加 Task51 精确 overlay。
- initial/final editor scan、Task51 专项 `2/92`、Task41 `4/112`、Boss 房 180 帧 smoke 均 exit `0`；所有正式 Review 日志五类标记均为 `0`。
- 静态 diff 确认生产仅把 Boss 弹道 spawn Y 从 `global_position.y + 84.0` 改为 `global_position.y`；公共 delivery、shape/mask/speed、房间与 AI 未变。
- 执行者误建在共享仓库下的 `tmp/task51_validation_20260813_a` 不属于候选。中枢核对其精确绝对路径为 Task51 自有冷副本（12,013 files / 393,034,967 bytes）后，仅删除该目录；顶层 `tmp` 与其他来源目录未删除。共享漂移已收口。
