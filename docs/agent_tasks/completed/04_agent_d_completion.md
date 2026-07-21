# Agent D 集成交付说明

## 完成范围

已将 Agent A/B/C 的冻结接口接入正式 Player、Enemy 与测试房间，形成以下可玩闭环：

```text
水形态释放 → 水附着 → E 切火 → 火命中 → 1:1 消耗 → 反应倍率伤害
```

正式路径不再依赖 `receive_interaction()`，`PrototypeSkillCaster` 与 `InteractionHitbox` 已从 `scenes/player.tscn` 移除。`prototype_skill` 目录按任务要求保留，只作为待协调者删除的历史参考。

## 正式场景组件

```text
Player
├── BodyCollision                         PlayerBody / WorldBlocker
├── CombatHurtbox                         PlayerHurtbox → CombatReceiver
├── DamageReceiver                        100 HP
├── CombatReceiver                        team=player；MVP 无 ElementCarrier
├── EnergyComponent                       100 Energy；默认 5/秒恢复
├── ElementFormController                 初始水形态
├── SkillExecutor                         唯一施法状态机
├── SkillController                       水/火独立 Loadout
└── AnimatedSprite2D

Enemy
├── BodyCollision                         EnemyBody / WorldBlocker
├── CombatHurtbox                         EnemyHurtbox → CombatReceiver
├── DamageReceiver                        240 HP / 0 Defense
├── ElementCarrier                        水火各 0..10
├── CombatReceiver                        team=enemy
├── AnimatedSprite2D
└── Prompt

TestRoom
├── RoomCollision / Platforms             WorldBlocker
├── Player
├── Orc
├── Camera2D
├── WorldFeedbackLayer                    CombatResult 飘字/反应反馈
└── CombatHUD                             固定屏幕 HUD + DebugOverlay
```

## 数据流

```text
InputMap(Q/J/左键/E)
→ Player
→ SkillController.try_cast_slot()
→ SkillExecutor 原子扣能量、锁定 CastSnapshot/RuntimeAttackPayload
→ ElementProjectile 或 TransientMeleeDelivery
→ CombatHurtbox
→ CombatReceiver.receive_hit()
→ 静默提交 DamageReceiver/ElementCarrier
→ CombatResult / 提交后信号
→ CombatHUD + CombatFeedback（只读表现）
```

敌人普通攻击同样创建锁定的中性 Payload，经 `TransientMeleeDelivery → Player CombatHurtbox → CombatReceiver` 结算，不使用旧交互方法。

## 输入与首批内容

| 输入 | 行为 |
| --- | --- |
| A/D、方向键 | 左右移动 |
| 空格/W/上方向键 | 跳跃 |
| J/鼠标左键 | 普通攻击；5 基础伤害、无元素附着、0 能量 |
| Q | 元素弹；10 基础伤害、3 层、20 能量 |
| E | 水/火形态切换 |
| F3 | DebugOverlay 显示/隐藏 |
| F4 | 减少动态效果 |
| R | 重载测试房间 |

首批资源：

- `resources/water_element.tres`
- `resources/fire_element.tres`
- `resources/element_bolt.tres`
- `resources/element_slash.tres`
- `resources/water_loadout.tres`
- `resources/fire_loadout.tres`

Resource 只保存静态配置，能量、形态、冷却、Cast、命中缓存和元素层均留在每角色运行时组件中。

## HUD 与战斗反馈

- 常驻 HUD 将“法雅雅”的角色状态与技能槽拆为两个独立面板；角色面板显示生命、能量和文字+色块元素标识，技能面板显示两个技能槽；phase 仅在 F3 DebugOverlay 中显示。
- 数值标签固定最小宽度，生命/能量立即读取组件真实值；低于 30% 显示“低生命”文字提示。
- 能量不足有 650ms 限频提示与 200ms 脉冲，不影响施法状态机。
- 能量消费后延迟 1 秒，以默认 5 点/秒恢复；STARTUP/ACTIVE、受击和死亡期间恢复与延迟计时均暂停。
- 飘字只由已提交 `CombatResult.final_damage` 产生；拒绝、重复命中和纯附着不生成伤害数字。
- 反应显示单个“反应 + 最终伤害”增强数字，不伪装成第二次伤害。
- 同屏飘字上限 28，显示身份缓存上限 128；减少动态时取消漂移和缩放。
- DebugOverlay 显示技能/phase/cast、冷却、目标生命与水火层、命中身份、反应消耗/倍率、元素 delta 和拒绝原因。

## 自动测试

使用 Godot 4.7.1：

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --log-file .godot/combat.log --script res://combat/tests/run_combat_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --log-file .godot/skill.log --script res://combat/tests/run_skill_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --log-file .godot/delivery.log --script res://combat/tests/run_delivery_tests.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --log-file .godot/protocol.log --script res://combat/tests/run_delivery_skill_integration_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --log-file .godot/agent_d.log --script res://combat/tests/run_agent_d_integration_tests.gd
```

最终结果：

- Agent A：27 tests / 123 assertions
- Agent B：25 tests / 143 assertions
- Agent C：16 tests / 56 assertions
- B→C 协议：1 test / 4 assertions
- Agent D 正式场景：9 tests / 72 assertions
- 合计：78 tests / 398 assertions，全部通过
- 主场景额外执行 10 帧 headless smoke test，通过
- 1152×648 正常渲染截图与 F3 DebugOverlay 均完成视觉检查

Agent D 测试覆盖正式场景组件、内容资源、输入/碰撞层、真实水弹命中、反应与剩余元素、飞行中切形态、STARTUP 打断不退款、5 点/秒恢复与各暂停状态映射、敌人 Delivery 命中玩家、HUD 数据一致、窗口缩放与减少动态。精确水 5/火 2、水 10/火 10、去重、多段、多目标、薄墙阻挡、无组件目标、格挡/无敌、共享 Resource 隔离等由上游冻结测试继续覆盖。

## 手动验收

1. 直接运行 `scenes/test_room.tscn`，确认左上 HUD 初值为 `100/100`、`100/100`、水形态。
2. 按 Q 发射水弹；F3 查看目标水层增加 3、生命减少，命中只出现一个最终伤害数字。
3. 按 E 切火，再按 Q；确认火与水 1:1 消耗、倍率和剩余层在 DebugOverlay 中正确，画面只出现一个增强反应数字。
4. 水弹飞行途中按 E，确认飞行弹仍为水色/水 Payload，下一发才为火。
5. 连续释放至能量不足，确认 HUD 立即显示实际能量并出现限频“能量不足”；停止动作后确认延迟 1 秒、按 5 点/秒恢复。
6. 贴近目标使用 J/左键，确认普通攻击同样通过正式 Delivery 且不重复命中。
7. 等敌人近身攻击，确认玩家生命条与 `CombatResult` 同步，受击可取消 STARTUP 且不退款。
8. F4 切换减少动态，确认飘字保留但不漂移/缩放；F3 隐藏调试层；R 重置房间。

## 已知边界与后续建议

- 本阶段按任务书不制作主页、选关、设置页或完整技能栏美术。
- 数值只用于系统验收，尚未进行正式战斗平衡。
- 测试环境因沙箱不能读取 Windows 根证书库，会输出一次系统 CA 警告；项目脚本与战斗日志无错误。
- `prototype_skill` 已完全脱离正式路径，但未删除；后续由协调者统一决定清理。


