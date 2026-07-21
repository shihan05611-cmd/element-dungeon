# Delivery、Hurtbox 与碰撞接线

本目录只负责攻击如何抵达目标。伤害、元素、阵营拒绝、无敌、格挡和闪避仍由 `CombatReceiver.receive_hit()` 权威处理。

## 初始化与销毁协议

`DeliveryBase.initialize_delivery()` 必须在节点加入树前调用，且只接受一次：

```gdscript
var delivery := skill.delivery_scene.instantiate()
var ok := delivery.initialize_delivery(
    cast_snapshot,
    runtime_payload,
    delivery_id,       # 同一 Cast 内唯一且 > 0
    spawn_transform,   # 世界 Transform2D
    facing_direction,
)
if not ok:
    delivery.free()
    return
delivery_parent.add_child(delivery)
```

初始化只缓存不可变 `CastSnapshot`、`RuntimeAttackPayload`、`delivery_id`、世界变换和方向，不访问树内节点。`_ready()` 才应用缓存的世界变换并启动物理行为。二次初始化会被拒绝，已锁定数据不变。

`finish(reason)`、`cancel()`、离树及近战命中窗关闭都会清理命中缓存。`ProjectileDelivery` 在命中、撞墙、超距或显式取消后发出 `delivery_finished(reason)` 并 `queue_free()`；没有对象池或永久连接。

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
3. 技能配置的 `delivery_scene` 可直接引用 `melee_delivery.tscn` 或 `projectile_delivery.tscn`，按技能复制/覆写形状、速度、距离和偏移。
4. 近战场景默认 `active_on_ready = true`；若需由阶段手工控制，则关闭该属性并在 ACTIVE 调用 `open_hit_window(hit_index)`，离开 ACTIVE 调用 `close_hit_window()`。
5. 表现订阅 Receiver 的提交后信号或 Delivery 的 `hit_submitted`，只读 `CombatResult`。

## 自动测试

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path <project> --script res://combat/tests/run_delivery_tests.gd
```

测试入口加载 `res://combat/tests/scenes/delivery_physics_test.tscn`，覆盖去重矩阵、左右近战、多 Hurtbox、树外初始化、快照生命周期、高速薄目标、薄墙阻挡、目标/墙先后、同点墙优先、大 delta 和清理行为。
