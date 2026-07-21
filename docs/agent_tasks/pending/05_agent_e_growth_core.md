# Agent E 任务书：局内成长核心、奖励、遗物与角色等级

状态：PENDING  
负责人：Agent E  
依赖：上一轮战斗 MVP 已验收；开工前读取 `docs/design/元素地牢_技能遗物与局内成长系统策划案.md`

## 1. 任务定位

你负责新建独立的局内成长领域。该领域跨房间保存本局状态，但不得直接依赖 Player、HUD、场景树或具体战斗组件。

本轮只有角色等级，没有技能等级。技能拥有状态只保存唯一技能 ID；已拥有技能不得重复获得。

## 2. 独占范围

你可以创建和修改：

- `res://growth/**`
- `res://growth/tests/**`
- 本任务需要的纯数据测试场景，但优先使用无场景纯测试

你不得修改：

- `res://combat/**`
- `res://scripts/player.gd`
- `res://scripts/enemy.gd`
- `res://scripts/combat_hud.gd`
- `res://scripts/test_room.gd`
- `res://scenes/**`
- 上一轮 `docs/agent_tasks/completed/**`

如果公共接口不能满足需求，先记录缺口并停止相关实现，不得越界修改 A/B/C/D 文件。

## 3. 公共契约检查点

先完成并冻结以下最小契约，通知协调者复核后，Agent B/D 才开始依赖：

- `RunPhase`：至少包含 `COMBAT / REWARD / ROUTE_CHOICE / SHOP / RUN_COMPLETE`。
- `RewardType`：`SKILL / RELIC`。
- `RunCommandResult`：结构化表达接受、拒绝原因和只读结果。
- `ProgressionSnapshot`：角色等级、经验、下一级需求、未分配点和已分配属性。
- `SkillInventorySnapshot`：只读已拥有技能 ID 集合。
- `RelicInventorySnapshot`：只读已拥有遗物 ID 和必要的显示状态。
- `RuntimeLoadoutSnapshot`：只读的 `form_id → slot_id → skill_id` 映射；具体可变实现归 Agent B。
- `RunSnapshot`：组合各子快照，不暴露可变内部集合。
- `RewardOption / RewardOffer`：不可变选项、稳定 offer ID 和房间身份。
- 类型化 RunEvent DTO：至少覆盖形态切换、已提交战斗结果、击杀和房间完成。
- 成长侧窄端口：恢复能量、恢复生命、临时属性修正等；不得包含任意 Node 查询。

关键 DTO 禁止使用任意 Dictionary 代替明确字段。集合必须复制后再向外暴露。

## 4. 实现范围

### 4.1 RunSession 与子状态

`RunSession` 作为本局门面，组合而不是吞并以下职责：

- `ProgressionState`
- `SkillInventoryState`
- `RelicInventoryState`
- `RouteState`
- `PendingRewardState`
- Agent B 提供的 Runtime Loadout 端口或只读快照

运行时只保存稳定 ID、标量和快照，不保存 Node、可变 Resource 或场景实例。

### 4.2 角色等级与属性

- 实现经验增加、连续升级和每级 1 点未分配属性点。
- 首版属性为攻击、体质、能量。
- 每点效果分别为攻击倍率 +5%、最大生命 +10、最大能量 +5。
- 战斗中只累积未分配点；属性分配只能通过 ShopDraft 确认事务提交。
- 拒绝负经验、负点数、超额分配、未知属性和重复提交。

### 4.3 奖励生成

`RewardGenerator` 必须是确定性的纯服务：

```text
RunSnapshot + RoomRewardContext + Seed → RewardOffer
```

- 第一关必须生成 3 个合法、未拥有的初始技能；不足视为配置错误。
- 后续技能奖励最多生成 3 个合法未拥有技能。
- 遗物奖励不得包含本局已拥有遗物。
- 同一个 Offer 内不得出现重复 ID。
- 已生成 Offer 保存到 PendingReward；关闭界面不能重抽。
- 一个 Offer 只能成功领取一次。
- 没有合法技能候选时，RunDirector 不再生成技能奖励路线。

### 4.4 遗物

- 静态 `RelicDefinition` 与运行时 `RelicRuntimeState` 分离。
- `RelicController` 只接受类型化事件并通过窄端口产生效果。
- 内部冷却、每房次数和触发身份属于运行时状态。
- 首版使用小型策略类或注册表；不得实现万能规则 DSL。
- 不得修改反应倍率、元素容量或元素 Resolver。

### 4.5 RunDirector 与商店草稿

- 实现冻结的房间状态机，非法跳转必须结构化拒绝。
- 击杀经验和房间完成经验必须支持稳定身份去重。
- `ShopDraft` 保存进入商店时的基线、拟分配属性和拟调整 Loadout。
- 确认时完整校验并一次提交；失败不得产生部分修改。

## 5. 必测用例

- 单次经验不足、刚好升级、跨越多级、非法经验。
- 升级只增加未分配点，不直接改变属性。
- 属性草稿正常提交、超额分配拒绝、重复确认拒绝、失败无部分提交。
- 同种子同快照生成相同奖励；不同 Offer 内无重复项。
- 已拥有技能和遗物不会再次出现。
- 第一关不足 3 个候选时明确配置失败。
- PendingReward 重开不变化，只能领取一次。
- 技能池耗尽后不再提供技能奖励路线。
- 遗物内部冷却、每房限制和重复事件身份安全。
- RunPhase 所有合法迁移和非法跳转。
- 两个 RunSession 共享静态 Resource 时运行时状态完全隔离。
- 所有外部通知只能观察到提交后的完整状态。

## 6. 交付

- 公共契约字段和生命周期说明。
- RunSession 聚合关系和端口依赖图。
- Agent B 所需的 Runtime Loadout 接口说明。
- Agent D 所需的事件、属性和 UI 只读接口示例。
- 可重复执行的测试命令与结果。
- 限制清单，不得把未实现功能包装成已支持。

