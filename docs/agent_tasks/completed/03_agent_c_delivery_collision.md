# Agent C 任务书：Delivery、Hurtbox、碰撞与命中去重

## 1. 任务定位

你负责攻击如何抵达目标，包括近战、投射物、Hurtbox/Receiver 桥接、连续碰撞、命中身份和去重。

开始编码前必须读取 Agent A 冻结的 `CastSnapshot`、Runtime Payload、`HitRequest` 和 `CombatReceiver` 接口。公共契约尚未完成时，只做碰撞方案和测试设计，不得创建平行协议。

项目根目录：`C:\Users\heliashi\Documents\元素地牢-4.7`

原始策划与技术方案：

- `C:\Users\heliashi\Downloads\横板动作地牢_元素系统策划案_更新版.md`
- `C:\Users\heliashi\Downloads\元素地牢_技能与元素系统技术方案.md`

## 2. 文件边界

你负责：

- Delivery 公共基类或窄协议。
- `MeleeDelivery`。
- `ProjectileDelivery`。
- 明确的 `CombatHurtbox` 到 `CombatReceiver` 桥接。
- 命中身份生成和每目标去重。
- 连续碰撞与墙体阻挡。
- 专用物理测试场景和自动测试。

你不得修改：

- Agent A 的公共 DTO、Resolver、Carrier 和 Receiver 内部规则。
- Agent B 的状态机、能量或技能配置。
- `scripts/player.gd`、`scripts/enemy.gd` 和三个主场景；由 Agent D 独占。

如果现有碰撞层不够，先在专用测试场景通过导出 mask/layer 验证；对 `project.godot` 的正式碰撞层命名修改交给 Agent D。

## 3. 已冻结的命中规则

- MVP 仅攻击敌对目标。
- 闪避、格挡、无敌、阵营非法和重复命中整体拒绝。
- AOE/一次近战覆盖多个目标时，每个目标获得完整伤害和完整元素量。
- 多段攻击通过不同 `hit_index` 表达，每段独立携带配置的完整元素量。
- 同一 Cast 可以生成多个 Delivery；每个 Delivery 必须有同一 Cast 内唯一的 `delivery_id`。
- 命中身份至少由 `cast_id + delivery_id + hit_index` 构成。
- 同一命中身份对同一目标只能成功提交一次；对不同目标可以各成功一次。
- 第二次 Cast 即使发生在同一物理帧，也必须拥有不同 `cast_id`，不能被前一次错误去重。
- 元素量为整数层，每种元素上限 10；Delivery 只携带 Agent A/B 已生成的 Payload，不得自行截断、反应或修改元素。
- 投射物生成后使用释放瞬间锁定的数据，不读取玩家当前形态或当前攻击属性。

## 4. Delivery 初始化协议

必须支持 Agent B 的以下顺序：

1. `PackedScene.instantiate()`。
2. 在节点加入树前调用初始化方法。
3. 写入不可变 `CastSnapshot`、Runtime Payload、`delivery_id`、起始变换和方向。
4. `add_child()`。
5. `_ready()` 只根据已缓存数据连接节点和开启物理行为。

初始化阶段不得访问 `@onready` 子节点；加入树后不得允许外部替换攻击快照。

投射物在施法者切形态或被释放后仍可命中。关键归属、阵营和数值必须来自快照；Node 引用只用于可选表现，使用前检查有效性和待删除状态。

## 5. Hurtbox/Receiver 定位

不要对碰撞到的任意 Node 无限向上搜索，也不要依赖 `has_method("receive_interaction")`。

实现明确桥接，例如独立 `CombatHurtbox`：

- Hurtbox 明确持有或解析一个受控的 `CombatReceiver` 引用。
- 墙体、受击区域和生命主体使用清晰的碰撞层职责。
- Delivery 命中 Hurtbox 后构造 Agent A 的 `HitRequest`，并只调用标准 `receive_hit()`。
- `HitRequest` 必须包含准确的命中世界坐标和方向，供提交后的表现层定位。
- 伤害飘字由表现层根据 `CombatResult` 生成；Delivery/Hurtbox 不直接创建 UI。
- Hurtbox 不计算伤害、不改元素、不保存技能规则。
- 同一实体如有多个 Hurtbox，MVP 默认共享同一个 Receiver，并通过 Receiver 实例 ID 视作同一目标进行去重。
- Boss 部位独立状态不在 MVP 范围内。

## 6. 近战实现要求

现有原型在移动 Area 后立刻 `get_overlapping_bodies()`，可能读取旧物理状态。不得复制该模式。

推荐使用显式命中窗和确定性空间查询：

- ACTIVE 开始前确定朝向和查询 Transform。
- 每个物理步使用 `PhysicsDirectSpaceState2D.intersect_shape()` 或等价的显式形状查询。
- 查询结果映射到 CombatHurtbox/Receiver。
- 每个 `hit_index` 保存已命中 Receiver ID 集合。
- 命中窗关闭或 Delivery 销毁时清空集合。
- 同一帧多个目标按稳定规则处理，不依赖 Signal 连接顺序。

不得通过刚移动碰撞节点后立即读取 overlap 的偶然行为判断命中。

## 7. 投射物实现要求

现有原型通过 `global_position += step` 移动，高速或低帧时可能穿过薄目标。首版正式投射物必须进行从旧位置到新位置的 sweep/raycast/shape cast，至少满足：

- 不穿过薄墙或 Hurtbox。
- 找到路径上距离最近的有效碰撞。
- 墙体位于目标之前时先撞墙并终止。
- 墙和目标处于等距离或无法稳定区分时，默认墙体优先，避免隔墙命中。
- 不依赖 `body_entered` 回调先后作为结算优先级。
- 命中、超距、关卡卸载和显式销毁均能正确断开连接并清理命中缓存。

首版不要求对象池。先保证正确性，压力测试证明需要后再优化。

## 8. 去重所有权与生命周期

主要命中记录由 Delivery/命中窗持有，而不是让每个 Receiver 永久积累 token。

建议逻辑：

```text
dedup_key = cast_id + delivery_id + hit_index
per_delivery_hits[hit_index] = Set<receiver_instance_id>
```

- 相同 `hit_index` 持续重叠：同一目标只提交一次。
- 不同 `hit_index`：允许同一目标再次被命中。
- 同一 Delivery 的不同目标：各提交一次。
- 同一 Cast 的两枚投射物：因 `delivery_id` 不同，按设计可分别命中。
- 新 Cast：完全独立。
- Delivery 关闭或销毁：缓存随对象释放，不产生无界增长。

未来 PersistentArea 的定时 tick、离开重入和间隔命中不在本任务实现；只保留能够新增命中策略的窄接口，不做通用策略 DSL。

## 9. 必测矩阵

### 9.1 去重

- 同一键、同一目标、持续多帧重叠：一次。
- 同一键、两个目标：每目标一次。
- 同一目标、不同 `hit_index`：每段一次。
- 同一 Cast、两个 `delivery_id`：可分别命中。
- 两次 Cast 同帧发生：互不去重。
- 多 Hurtbox 指向同一 Receiver：按同一目标去重。

### 9.2 快照与生命周期

- 水弹发出后玩家切火：投射物仍携带水。
- 发出后施法者释放或待删除：命中不访问失效对象，归属 ID 和 team 仍正确。
- 目标在查询后、提交前已失效：安全拒绝，不报错。
- Delivery 销毁后无遗留连接、缓存或迟到回调。

### 9.3 物理碰撞

- 左右转身近战均使用新方向，无旧位置漏判。
- 多敌人重叠时全部合法命中。
- 高速投射物不穿薄墙、不穿薄 Hurtbox。
- 墙在敌人前方时不隔墙命中。
- 敌人在墙前方时先命中敌人。
- 墙和敌人近似同点时按冻结规则墙体优先。
- 大物理 delta 下结果仍可复现。

### 9.4 职责边界

- Delivery 中没有伤害公式、元素反应、能量或形态查询。
- Hurtbox 中没有规则计算。
- 所有状态修改只通过 `CombatReceiver.receive_hit()`。

## 10. 禁止项

- 不直接扣血或修改元素 Dictionary。
- 不调用旧 `receive_interaction()` 作为正式路径。
- 不在命中时读取 Player 当前形态。
- 不让 Receiver 保存永久、无界 token 历史。
- 不实现未来 PersistentArea、陷阱、召唤物或 Boss 部位。
- 不加入对象池或第三方物理/测试依赖。
- 不修改主场景和现有 Player/Enemy 脚本。
- 不删除 `prototype_skill`。

## 11. 交付与验收

交付时提供：

- Delivery 初始化和销毁协议。
- Hurtbox 到 Receiver 的接线示例。
- 命中 ID、去重作用域和缓存清理说明。
- 近战与投射物的自动物理测试结果。
- Agent B 的生成调用示例和 Agent D 的场景接线说明。

验收条件：近战无旧物理状态问题；高速投射物不穿透；同目标去重和合法多段均正确；施法者或目标失效时无错误；Delivery 完全不拥有战斗规则。
