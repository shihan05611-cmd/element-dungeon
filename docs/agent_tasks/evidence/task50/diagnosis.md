# Task 50 Boss 弹道卡入地形诊断

诊断日期：2026-08-13  
诊断基线：`main` HEAD `fc7b5318f3b32860ee10265c23aa1cff199e1b99`  
结果：`DIAGNOSED`（只读诊断，未实施修复）

## 结论

唯一根因是 Boss 专属出生 Transform 的固定垂直偏移：`scripts/enemy.gd::_spawn_boss_projectile()` 使用 `global_position.y + 84.0`。Godot 2D 中 `+Y` 向下；Boss 从高台走到主地面后根节点随承载面下降 `88 px`，但出生公式没有根据承载面或 Boss body 的安全高度调整，导致弹道 authority 圆直接生成在主地面碰撞体内部。

这不是碰撞层错误、公共移动生命周期错误、Boss 房主地面异常或纯贴图偏移：blocker mask `4` 正确命中 world layer `4`，sweep 在起点重叠时按设计返回 fraction `0.0`，delivery 随后零位移结束；Boss 房主地面边界与其他正式房一致；贴图 alpha 与碰撞圆垂直中心基本重合。

## 最小复现与发生频率

1. 进入正式 Boss 房，让 Boss 保持正常 AI。
2. Boss 初始站在中央高台；此时发射可见且能水平移动。
3. 让 Boss 追逐玩家并从高台走下，等待其在主地面落稳。
4. 下一次远程攻击生成时，可见弹道位于地面内部并在首个物理步被 blocker 关闭，表现为“卡地/刚出现即消失”。

发生条件是状态确定的：

- Boss 在高台：不复现。
- Boss 落到主地面且发射中心的 `x` 落在地面范围内：每发必现。
- 左/右方向无关；两侧只改变 `x ± 58`，`y + 84` 相同。
- 玩家位置只影响水平朝向，不影响根因；零水平差时 fallback facing 仍不改变 `y`。
- 仅在房间极端边界使 `x ± 58` 落出主地面 footprint 时可能不触发地面初始重叠；正常 Boss 战活动范围不依赖该例外。

本次未运行 Godot。以下静态数值与公共 sweep 的确定性分支已经完整决定首帧结果，无需为了确认同一事实控制共享编辑器或额外运行项目。Task 41 已接受画面作为高台安全态的历史对照，复制件见 `screenshots/task50_01_task41_on_dais_safe_reference.png`；它不是本次 Bug 运行截图。

## Authority 坐标与几何

### Boss body 与承载面

`scenes/enemy.tscn` 的 Boss/Enemy body 使用半径 `16`、高度 `36` 的 capsule，`BodyCollision` 相对根节点位于 `(0, 14)`。该 body 的底部相对根节点约为 `14 + 18 = 32 px`。

`resources/run/rooms/combat_06_final_boss.tres` 给出：

| 状态 | Boss 根节点 Y | 承载面 | 承载面边界 | 推导 |
|---|---:|---|---|---|
| 初始 | `420` | BossDais | top `452`, bottom `480`, x `690..950` | `420 + 32 = 452` |
| 走下高台并落稳 | `508` | Ground | top `540`, bottom `628`, x `40..1112` | `508 + 32 = 540` |

BossDais 中心 `(820,466)`、矩形 `(260,28)`；Ground 中心 `(576,584)`、矩形 `(1072,88)`。二者均为 world layer `4`，高台为 one-way。

### 弹道 authority 与视觉范围

`scenes/run/boss_arc_projectile.tscn`：

- authority shape：以节点为中心的 `CircleShape2D`，半径 `13`；
- speed `255`，max distance `980`；
- hurtbox mask `16`，blocker mask `4`；
- Sprite2D 没有 position/offset，scale `(0.32,0.32)`。

源 PNG 是 `256×256`，非透明 alpha bbox 为 `x=18..237, y=80..175`。以纹理中心 `(128,128)` 并缩放 `0.32` 后，可见范围相对 authority 中心为：

- X：`-35.20 .. +34.88`；
- Y：`-15.36 .. +15.04`。

因此视觉底部只比碰撞圆底部低 `2.04 px`，视觉中心没有足以解释“卡地”的偏移。

| Boss 状态 | 弹道中心 Y (`bossY+84`) | authority Y | 可见 alpha Y | 相对地形 |
|---|---:|---|---|---|
| 高台 | `504` | `491..517` | `488.64..519.04` | 在高台 bottom `480` 下方、Ground top `540` 上方；安全 |
| 主地面 | `592` | `579..605` | `576.64..607.04` | authority 与视觉均完整位于 Ground `540..628` 内；必重叠 |

## 首个物理步

`combat/targeting/physics_projectile_sweep_query_2d.gd::_cast_fraction()` 在 `cast_motion()` 前先以出生 Transform 调用 `intersect_shape()`。主地面状态下，半径 `13` 的圆已位于 layer `4` Ground 内，因此初始 blocker hit 非空，接触点存为出生 origin，并返回 `0.0`。

`combat/delivery/projectile_delivery.gd::advance()` 收到 `BLOCKER_CONTACT` 后：

1. 以 contact fraction `0.0` 调用 `_move_fraction()`；
2. authority 位移 `0`，累计移动距离 `0`；
3. 发出 `blocker_contact`；
4. `finish("blocked")` 并排队释放。

所以画面中的“卡入”是错误出生位置被正确的首帧 blocker 路径立即终止，不是弹道先移动后钻入、速度为零、重复碰撞或销毁失灵。

## 候选排除与根因排序

| 排名 | 候选 | 结论与证据 |
|---:|---|---|
| 1 | Boss 出生点 `y + 84` | 唯一根因；高台中心 `504` 安全，主地面中心 `592` 完整进入 Ground |
| 2 | 房间几何触发条件 | 不是错误本身；BossDais 使旧测试只覆盖安全态，主 Ground 边界与其他正式房一致 |
| 3 | shape/sweep 初始重叠 | 是根因的直接后果；半径 `13` 与 Ground 重叠，sweep 正确 fraction `0` |
| 4 | 碰撞层/mask | 排除；world layer `4` 与 blocker mask `4` 正确，hurtbox mask `16` 独立正确 |
| 5 | ProjectileDelivery 生命周期 | 排除；零分数阻挡、结束、释放均符合公共合同 |
| 6 | 纯视觉偏移 | 排除；Sprite 无节点偏移，alpha bbox 仅比 authority 圆底多 `2.04 px`，且 authority 本身已深处地面 |

## Task 41 历史盲区

Task 41 的已接受 capture 在 Boss 初始高台态禁用了 AI，等待后再手动发射。对照图准确展示弹道中心处于 BossDais 与 Ground 之间，因此证明了高台态安全，却无法覆盖 Boss 走下高台后的根节点 `y=508` 状态。

Task 41 的断言覆盖 speed/masks/实例存在；Task 43 覆盖 Boss 节点释放和死亡后无新弹体。两者都没有断言“主地面站立态的出生 shape 不与 blocker 初始重叠”，所以本 Bug 能通过原门禁。

## 最小修复边界

生产文件只需：

- `scripts/enemy.gd`

建议在 `_spawn_boss_projectile()` 中删除 `+84.0` 下移，使 Boss 弹道中心使用 `global_position.y`（水平 `±58` 保持）。Boss body 根节点在高台/地面都恰好位于承载面上方 `32 px`；半径 `13` 的弹道放在根节点高度时：

- authority bottom 距承载面 `32 - 13 = 19 px`；
- visible alpha bottom 距承载面约 `32 - 15.04 = 16.96 px`。

这同时覆盖高台和主地面，并保持水平低弹道。无需触及：

- `combat/delivery/projectile_delivery.gd`；
- `combat/targeting/physics_projectile_sweep_query_2d.gd`；
- `scenes/run/boss_arc_projectile.tscn`；
- projectile masks/shape/speed；
- `combat_06_final_boss.tres` 或公共房间模板。

## 后续修复任务的强断言

新专项必须在当前 HEAD 上失败，并至少字面验证：

1. 正式 Boss 房高台态与“实际走下高台、连续物理帧落稳主地面”两种状态；不得只传送后立即读取。
2. 两种状态分别向左、向右发射；玩家 X 仅改变方向，不改变安全 Y。
3. delivery 创建时记录 authority center、CircleShape 半径 `13`、blocker mask `4`、hurtbox mask `16`。
4. 起始 `intersect_shape()` 对 world layer `4` 为零命中；`centerY + 13 < supportTop`，并以可见 alpha bottom `centerY + 15.04 < supportTop` 验证画面也不切地。
5. 首个真实 `physics_frame` 后实例仍有效、`velocity/motion.x` 与 `255*delta` 一致（容差内）、Y 不漂移、累计距离大于零、没有 blocker contact/`blocked` finish。
6. 后续能够正常命中玩家或墙体并只结束一次；不能用“仍生成过实例”替代生命周期断言。
7. 保留 Task 41 的低弹道可跳路径以及 Task 43 的 Boss defeated 后节点释放、无新弹体强门禁。

## 与 Task 49 的关系

Task 49 的新五阶段正式流复用同一 Boss 房，因此 Boss 离开高台后的该缺陷会进入演示主路径。Task 49 不负责顺手修复；本诊断没有读取、修改或认领 Task 49 候选。应以独立的后续生产任务修复后，再让五阶段正式流继承修复。

## 运行与保护声明

- 未启动 Godot，未创建或连接任何 shared/cold profile。
- 未连接、关闭或控制共享 Godot/editor/godot-ai。
- 未修改游戏代码、场景、资源、测试或配置。
- 未读取或触碰 Task 48/49 候选。
- 未执行 Git 写、add、commit、push、reset、restore、checkout、clean 或 stash。
- 本任务唯一写入为 Task50 taskbook、Task50 Markdown/TXT evidence 与一张来自已接受 Task41 evidence 的明确标注对照图。
