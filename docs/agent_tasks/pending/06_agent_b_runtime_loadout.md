# Agent B 新任务书：本局动态技能槽与成长系统接入

状态：PENDING  
负责人：Agent B  
依赖：Agent E 公共契约检查点通过；上一轮 Agent B 任务保持归档且不得覆盖

## 1. 任务定位

你负责把现有静态 `SkillLoadout` 模板扩展为本局可调整的运行时技能槽，并让现有 `SkillController` 在不破坏施法快照语义的前提下读取运行时装备。

本轮没有技能等级。不得创建升级表、技能经验、重复升级或 `ResolvedSkillSpec`。

## 2. 独占范围

你可以修改：

- `res://combat/definitions/skill_loadout.gd`
- `res://combat/components/skill_controller.gd`
- 与运行时 Loadout 直接相关的新文件，建议位于 `res://combat/loadouts/**`
- `res://combat/tests/run_skill_tests.gd` 或新的专用 Loadout 测试入口
- 如确有必要，最小增量修改 `SkillDefinition` 的装备约束字段

你不得修改：

- `res://growth/**`
- `res://combat/components/skill_executor.gd` 的阶段、扣费、冷却和快照事务语义
- Agent A 的战斗协议和 Resolver
- Agent C 的 Delivery
- Player、HUD、Enemy 和正式场景
- `docs/agent_tasks/completed/**`

## 3. 冻结规则

- `SkillLoadout` 继续作为静态初始模板，不保存本局改装结果。
- 新的 Runtime Loadout 只保存稳定技能 ID 或受控只读引用，不能修改 SkillDefinition。
- 普通近战固定存在，不进入奖励池且不能被卸下。
- 水、火形态各有 2 个主动技能槽。
- 通用技能允许同时装备到水、火槽位。
- 水专属技能只能进入水槽，火专属技能只能进入火槽。
- 同一形态是否允许同一技能占多个槽位必须拒绝；跨形态重复装备允许。
- 装备和卸下操作必须原子验证，失败时旧槽位不变。
- SkillController 仍然只负责槽位解析，不拥有经验、遗物、角色等级或奖励逻辑。

## 4. 接口要求

- 提供从静态 Loadout 模板创建独立 Runtime Loadout 的工厂。
- 提供不可变 `RuntimeLoadoutSnapshot`，与 Agent E 契约对齐。
- 提供 `try_equip(form_id, slot_id, skill_id)` 和 `try_unequip(...)` 或等价命令结果。
- 提供装备合法性检查，不通过字符串拼接判断元素或技能类型。
- 所有外部集合必须复制，不能暴露内部 Dictionary 可变引用。
- SkillController 支持显式配置 Runtime Loadout；未配置时保留现有静态 Loadout 行为，避免上一轮场景和测试失效。
- 施法被接受时仍由现有 SkillExecutor 锁定 SkillDefinition、形态、属性和 Payload；后续换装不得污染已发出的攻击。

技能“是否已拥有”由成长域决定。你的接口应允许集成层在调用装备前进行拥有校验，但 `combat` 目录不得反向依赖 `growth` 目录。

## 5. 必测用例

- 从同一静态模板创建两个 Runtime Loadout 时状态互不污染。
- 水火槽位独立。
- 通用技能跨形态装备成功。
- 专属技能进入错误形态时拒绝且无部分变化。
- 同形态重复装备拒绝。
- 未知 form、slot、skill ID 和无效配置结构化拒绝。
- 卸下空槽、卸下固定近战和非法换装行为安全。
- 运行时换装不修改 SkillLoadout/SkillDefinition Resource。
- 施法中换装不改变当前 Cast，下一次施法才读取新槽位。
- 未配置 Runtime Loadout 时上一轮静态路径全部回归通过。

## 6. 交付

- Runtime Loadout 的数据模型和公开命令。
- Agent E 获取只读 Loadout 快照的调用示例。
- Agent D 初始化模板、检查拥有状态并执行装备的调用示例。
- 新增测试与全部技能回归测试结果。

