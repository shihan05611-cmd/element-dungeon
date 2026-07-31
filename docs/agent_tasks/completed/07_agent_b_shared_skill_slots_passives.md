# Agent B 任务书：共享 3+1 技能栏、技能分类与被动生命周期

状态：ACCEPTED
负责人：Agent B
依赖：06_agent_e_shared_loadout_event_contracts Review 验收通过

## 1. 任务定位

把现有水、火独立 Loadout 改为全元素共享的唯一技能栏，并建立主动/被动与元素策略两个正交维度。元素切换和释放事务留给下一份 Agent B 任务。

## 2. 独占范围

可以修改：

- combat/definitions/skill_definition.gd
- combat/definitions/skill_loadout.gd
- combat/components/skill_controller.gd
- 新建 combat/loadouts/**
- 新建 combat/passives/**
- combat/tests 中技能、Loadout 和被动相关测试
- 旧 Loadout 迁移所需的纯数据适配器
- 与本任务直接相关的静态技能 Resource

不得修改 growth、Agent A Resolver、Agent C Delivery、Player、HUD、正式场景或 completed 文档。

## 3. 技能静态模型

技能必须使用两个字段维度：

- ActivationKind：ACTIVE / PASSIVE。
- ElementPolicy：EXCLUSIVE_ELEMENT / CURRENT_ELEMENT / NEUTRAL。
- EXCLUSIVE_ELEMENT 额外保存 required_element_id。
- PASSIVE 保存稳定 passive_effect_id 或等价窄效果标识。

验证规则：

- ACTIVE 必须具有合法时序、Payload 和 Delivery。
- PASSIVE 不能发起释放；不能依赖能量、冷却、前摇、后摇或 Delivery。
- CURRENT_ELEMENT 的主动技能由释放时 CurrentElement 决定元素。
- NEUTRAL 的主动技能 Payload 必须无元素。
- EXCLUSIVE_ELEMENT 绑定固定元素，但不再表示“只能在该元素状态按键”；自动切换属于下一任务的接受事务。
- 不得继续用旧 FormPolicy 同时表达装备限制和释放语义。

## 4. 唯一共享栏位

正式结构固定为：

- ACTIVE_1
- ACTIVE_2
- ACTIVE_3
- PASSIVE_1

规则：

- 三个 ACTIVE 位置允许 ACTIVE 或 PASSIVE。
- PASSIVE_1 只允许 PASSIVE。
- 同一 skill_id 在四个位置中最多出现一次。
- 允许全部四个位置都是 PASSIVE。
- 允许所有位置为空，但固定普通攻击仍位于技能栏之外。
- 元素变化不能修改槽位内容。
- RuntimeLoadoutSnapshot 必须与 Agent E 的 slot_id → skill_id 新契约一致。
- 替换整个快照时纯验证后原子提交，失败保持旧映射与旧被动注册。

## 5. 被动生命周期

建立窄 PassiveEffectPort、PassiveSkillController 或等价结构：

- 每个已装备被动按 skill_id 注册一次。
- 被动位于 ACTIVE 位置时同样生效。
- ACTIVE 位置中的 PASSIVE 被按键时返回结构化 NOT_CASTABLE 或等价结果，不扣能、不进冷却、不触发释放事件。
- 换装整体提交时先验证新集合，再以不可观察半状态的方式更新注册。
- 卸下、死亡、重生、换层、重新载入时不会泄漏或重复注册。
- 三个 ACTIVE 位置装备三个不同 PASSIVE 时，每个效果恰好注册一次。
- 具体 Player/遗物效果由后续集成端口实现，本任务不直接引用 Player。

## 6. 删除元素独立入口

- SkillController 正式路径只读取一个共享 Runtime Loadout。
- 删除或禁用 water_loadout / fire_loadout 等元素独立配置入口。
- 初始静态 Loadout 也只有一个共享模板。
- 如为迁移保留旧字段，必须标记 legacy，仅允许迁移器读取一次，运行时不得双写。

## 7. 旧配置迁移

实现确定性纯迁移：

1. 优先读取旧存档 current_element 的槽位。
2. 再按有序可用元素列表读取其他旧槽位。
3. 去重 skill_id，前三个进入 ACTIVE_1～3。
4. PASSIVE_1 默认空。
5. 其余技能仍在拥有库中但不装备。
6. 输出只有新格式，重复迁移结果一致。

当前项目没有正式磁盘存档时，只实现并测试纯迁移器，不擅自建立完整存档系统。

## 8. 必测用例

- 共享四槽的创建、替换、快照和 revision。
- 元素切换前后同一 slot_id 对应同一 skill_id。
- ACTIVE/PASSIVE 和三种 ElementPolicy 的静态验证。
- ACTIVE 位置装备 PASSIVE 成功且按键不释放。
- ACTIVE 技能装入 PASSIVE_1 明确拒绝且无部分变化。
- 0 主动 + 4 被动可保存、恢复和进入运行态。
- 重复 skill_id 拒绝。
- 被动卸下、死亡、重生、换层、重载后注册次数正确。
- 三个 ACTIVE 位置装备不同 PASSIVE 不重复注册。
- 旧水火配置迁移顺序、去重、溢出和幂等。
- 现有 SkillExecutor 和静态路径回归测试在兼容层移除前后都有明确结果。

## 9. 交付

- 报告测试结果、修改文件清单和剩余限制。
- 不执行任何 Git 命令；由用户统一提交。
