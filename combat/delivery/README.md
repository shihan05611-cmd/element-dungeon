# Delivery、Hurtbox 与碰撞接线

本目录只负责攻击如何抵达目标。伤害、元素、阵营拒绝、无敌、格挡和闪避仍由 `CombatReceiver.receive_hit()` 权威处理。

## 初始化与销毁协议

每个技能的 `delivery_scene` 根节点必须继承 `DeliveryBase`。`RuntimeSkillLoadout` 构造时会为每个主动技能实例化一次探针，验证根类型后立即释放；正式释放路径只使用强类型调用，不再逐次执行 `has_method()` / `call()` 探测。

Executor 会在提交能量、冷却和元素前创建真实实例，并在节点加入树前只初始化一次：

```gdscript
var delivery := skill.delivery_scene.instantiate() as DeliveryBase
if delivery == null or not delivery.initialize_delivery(
    cast_snapshot,
    runtime_payload,
    1,                 # 当前一个 Cast 只生成一个 Delivery
    spawn_transform,   # 世界 Transform2D
    facing_direction,
):
    if delivery != null:
        delivery.free()
    return CastAttemptResult.rejected(...)

# 资源事务提交并进入 STARTUP；到 ACTIVE 才执行：
delivery_parent.add_child(delivery)
```

初始化只缓存不可变 `CastSnapshot`、`RuntimeAttackPayload`、`delivery_id`、世界变换和方向，不访问树内节点。`_ready()` 才应用缓存的世界变换并启动物理行为。二次初始化会被拒绝，已锁定数据不变。准备失败属于请求拒绝，不会消耗资源；STARTUP 取消会释放尚未入树的实例。

`finish(reason)`、`cancel()`、撞墙、超距和离树都会清理 Cast、Payload、ID、方向、距离、命中缓存及 Delivery 自有信号连接。默认 `queue_free_on_finish = true`，所以现有非池路径仍在结束后安全 `queue_free()`。
## Hurtbox 到 Receiver

推荐目标结构：

```text
EnemyRoot
├── CombatReceiver
│   ├── ElementCarrier（可选）
│   └── DamageReceiver（可选）
└── CombatHurtbox (Area2D)
    └── CollisionShape2D
```

在场景中把 `CombatHurtbox.receiver_path` 明确指向 `CombatReceiver`，或在加入树前调用：

```gdscript
hurtbox.configure_receiver(receiver)
```

Hurtbox 不向上遍历、不中转旧 `receive_interaction()`、不计算伤害。多个 Hurtbox 可以指向同一 Receiver；Delivery 使用 Receiver 实例 ID 作为目标身份，因此同一 `hit_index` 只提交一次。

## 近战与投射物

- `MeleeDelivery` 在 `open_hit_window(hit_index)` 时锁定朝向和查询 Transform，每个物理步用 `intersect_shape()` 显式查询；不依赖移动 Area 后的旧 overlap 状态。`close_hit_window()` 会关闭查询并清空窗口缓存。
- `ProjectileDelivery` 对每段位移使用 shape sweep，分别求最近 Hurtbox 和最近墙体。墙更近时终止；距离差在 `wall_tie_distance` 内时墙优先。大 `delta` 下仍扫描整段位移。
- 两者只构造 `HitRequest` 并调用 `CombatReceiver.receive_hit()`。命中世界坐标和锁定方向写入 Request，表现层可消费 `CombatResult`；Delivery 不创建飘字或 UI。

默认测试层为 Hurtbox `1`、墙体 `2`。这些只是场景导出的 mask/layer 数值；正式的 `project.godot` 层命名由 Agent D 统一配置。

## Agent D 最小接线

1. 给敌人增加 `CombatReceiver`、可选 Carrier/Health，以及显式指向 Receiver 的 `CombatHurtbox`。
2. 墙体使用独立物理层，并让 Projectile 的 `blocking_collision_mask` 只包含该层。
3. 技能配置的 `delivery_scene` 根节点必须继承 `DeliveryBase`；可直接引用 `melee_delivery.tscn` 或 `projectile_delivery.tscn`，按技能覆写形状、速度、距离和偏移。
4. 近战场景默认 `active_on_ready = true`；若需由阶段手工控制，则关闭该属性并在 ACTIVE 调用 `open_hit_window(hit_index)`，离开 ACTIVE 调用 `close_hit_window()`。
5. 表现订阅 Receiver 的提交后信号或 Delivery 的 `hit_submitted`，只读 `CombatResult`。

## 自动测试

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_delivery_tests.gd
```

测试入口加载 `res://combat/tests/scenes/delivery_physics_test.tscn`，覆盖去重矩阵、左右近战、多 Hurtbox、树外初始化、快照生命周期、高速薄目标、薄墙阻挡、目标/墙先后、同点墙优先、大 delta 和清理行为。



## 锁定表现、多段与延迟攻击

- `ElementProjectile` 的颜色与 `locked_presentation_tags` 只在 `_ready()` 中从锁定的 Runtime Payload 复制；CurrentElement、Skill Resource 或同键配装后续变化不会重染已生成投射物。
- 多段近战继续通过 `open_hit_window(hit_index)` 使用不同段号；所有段共享 Delivery 初始化时的同一 CastSnapshot 与 Runtime Payload。
- `DelayedAreaDelivery` 在加入树前保存不可变快照，等待 `trigger_delay` 后用显式形状查询命中全部目标。延迟期间不会读取施法者、CurrentElement 或 SkillDefinition。

## 可选池复用边界

本轮只提供安全边界，不创建全局对象池。希望复用的实例必须预先设置 `queue_free_on_finish = false`：

```gdscript
# delivery_finished 已同步发出；此时运行时引用和命中缓存已经清理。
delivery_parent.remove_child(delivery)
if not delivery.prepare_for_reuse():
    delivery.free()
    return

# reset 后一轮只允许初始化一次；request_ready() 已由契约内部安排。
delivery.initialize_delivery(next_cast, next_payload, next_delivery_id, transform, direction)
delivery_parent.add_child(delivery)
```

`prepare_for_reuse()` 仅在 Delivery 已 finished、已离树、未排队删除且清理完成时成功。成功后清除完成状态并提升 `reuse_generation`；下一次入树会重新执行 `_ready()`。未 reset 的二次初始化、仍在树内 reset、未完成 reset、以及默认 queue-free 对象的 reset 都会明确拒绝。

子类清理范围：Melee 清除活动窗、运行时段号并把可变的 `initial_hit_index` 重置为 0；DelayedArea 继承该规则并额外清除延迟计时与 trigger 信号；Projectile 清除距离、运行时 hit_index 与 blocker 信号；ElementProjectile 清除旧颜色和表现标签。静态 Shape、速度、mask 等场景配置会保留，复用方如需非零初始段号，必须在 reset 后重新设置。

## 第二轮自动测试

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_delivery_reuse_tests.gd
```

该入口覆盖真实 CurrentElement 切换、专属技能自动切火、Skill Resource 换装污染、延迟 AOE、多段同快照、水→火对象复用、信号/引用/去重清理、撞墙、超距和离树重置。原 `run_delivery_tests.gd` 继续承担高速薄目标、墙优先和多 Hurtbox 回归。



