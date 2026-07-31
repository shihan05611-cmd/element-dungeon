# Agent F 任务书：架构减负与防御边界收敛

状态：ACCEPTED
负责人：Agent F
依赖：05～10 已完成 Review 并验收通过
后续：本任务全部阶段验收通过后，才能开始 `12_agent_d_hud_loadout_feedback.md`

## 1. 任务定位

在不改变战斗、成长、共享技能栏和元素规则的前提下，删除已经完成迁移的兼容层，合并重复状态与去重责任，把静态配置验证移出高频运行路径。

本任务减少的是理解系统所需的状态源、分支和中间层，不以机械压缩行数为目标。把代码搬到新文件、创建新的 Manager/Service/Result，或用更抽象的框架替换现有代码，不算减负。

## 2. 当前基线

- `combat/`、`growth/`、`scripts/` 共 120 个 GDScript 文件。
- 非测试代码：107 个文件，约 9844 行。
- 测试代码：13 个文件，约 4725 行。
- 全量回归 12 个入口：143 tests / 887 assertions，全通过。
- 任务 10 专项：10 tests / 121 assertions，全通过。
- Windows headless 环境存在已知根证书读取警告；它不是脚本错误，也不是本任务目标。

开始修改前，Agent F 必须独立重跑并记录基线。不得把测试数量下降当作减负成果。

## 3. 工作方式与停点

Agent F 第一次接到任务时只做只读审计，不修改文件：

1. 阅读本任务书及 `docs/design/共享技能槽与元素释放规则.md`。
2. 阅读任务 05～10 的任务书和实现入口。
3. 输出“准备删除 / 准备合并 / 必须保留 / 暂不处理”四类清单。
4. 列出预计修改文件、删除文件、公共 API 变化和测试影响。
5. 停止并等待用户明确回复“执行第一阶段”。

实施也必须分阶段停止：一个阶段完成并 Review 通过后，才能执行下一阶段；不得一次性重写全部系统。

## 4. 冻结规则：不得改变

- 全元素共享唯一一套 `ACTIVE_1～3 + PASSIVE_1`。
- 普通攻击位于共享技能栏之外。
- ACTIVE 位置允许被动；PASSIVE_1 拒绝主动；`0 主动 + 4 被动` 合法。
- 角色只有一个 CurrentElement 状态源。
- 专属技能失败不切换，接受成功才自动切换；打断和取消不回滚元素。
- 通用技能、投射物、延迟攻击和多段攻击使用接受时锁定的元素快照。
- 反应增伤公式、伤害顺序、层数消耗、成长、奖励、商店和遗物规则不变。
- UI 需要的结构化失败原因、快照和提交后事件不得降级成布尔值或字符串猜测。

## 5. 必须保留的防御

以下保护对应真实的 Godot 生命周期、物理帧或异步表现风险，不属于删减目标：

- 信号回调中的施法重入、取消、节点释放和 `queue_free` 防护。
- 大帧时间跨越多个施法阶段时，Delivery 仍只生成一次。
- Delivery 命中窗对连续 overlap 的去重。
- CombatReceiver 的有界近期命中缓存和提交后通知顺序。
- CastSnapshot、RuntimeAttackPayload、元素快照及投射物锁定状态。
- Delivery 对象池复用、脱树和重新入树时的状态清理。
- 被动整体替换、死亡停用、重生恢复、换层和读档重建。
- Runtime Loadout revision、ShopDraft 过期检测和原子提交。
- GDScript 可变 Array/Dictionary 穿越只读边界时的必要复制。
- 外部 Resource、场景输入、存档和目录数据进入系统边界时的验证。

## 6. 第一阶段：删除确定无价值的兼容层

第一阶段只做低风险、可机械验证的收缩。

### 6.1 共享 Loadout 单一初始化

- 正式 RuntimeSkillLoadout 只由 RunSessionHost/运行局入口创建一次。
- 删除 SkillController 中旧水火 Loadout 的运行时初始化分支、重复迁移状态和重复目录收集。
- `water_loadout`、`fire_loadout` 只允许作为一次性迁移输入，不得继续成为 Player 或 SkillController 的长期字段。
- 旧配置迁移仍由 `SharedLoadoutPersistenceAdapter + LegacyElementLoadoutMigrator` 在局入口完成一次。
- 不得删除旧存档迁移能力。
- 当前 RunSessionHost 尚未把 `migration_overflow_skill_ids` 并入 RunSession 的初始拥有技能库。第一阶段必须在创建 RunSession 前合并这些溢出技能，保证旧配置超过三个唯一技能时“前三个装备、其余仍拥有但未装备”。
- 新增正式迁移回归：至少四个旧技能迁移后，溢出技能出现在拥有库、未占用第四个被动槽，并能在后续商店合法装备。

重点审查：

- `combat/components/skill_controller.gd`
- `combat/loadouts/legacy_element_loadout_migrator.gd`
- `scripts/player.gd`
- `scripts/run_session_host.gd`
- `scenes/player.tscn`

### 6.2 统一 CurrentElement 词汇

- 正式代码统一使用 `CurrentElementController`、`current_element_id`、`element_changed`、`request_element` 和 `cycle_next`。
- 更新 Player、现有 HUD 接线和测试后，删除仅用于兼容命名的 `ElementFormController` 空壳。
- 删除 `current_form_id`、`form_changed`、`request_form`、`toggle_form` 等重复别名。
- 场景节点名称可以暂时保持稳定，但节点脚本和类型只能有一个权威实现。

### 6.3 删除无调用公共面

只删除经全项目搜索确认没有生产调用、场景连接和 Callable 字符串引用的成员：

- 只暴露内部状态但没有消费者的调试 getter。
- 只被旧测试访问、没有行为意义的兼容 getter。
- 与唯一正式入口重复的包装方法。

不能仅凭 `rg` 零引用删除 Godot 生命周期函数、信号回调或场景绑定方法；必须同时检查 `.tscn`、Signal 连接和 Callable 字符串。

## 7. 第二阶段：合并事件投影与去重责任

第二阶段在第一阶段 Review 通过后执行。

### 7.1 元素事件投影

- CurrentElementController 继续生成完整、不可变的 FormChangedEvent。
- RunSessionHost 作为集成边界，直接把提交后的事件交给 RunSession。
- 若 `ElementEventBridge` 只剩复制事件、替换 room_id 和转发信号，应删除并由 Host 直接连接。
- room_id 在开始和切换房间时一次性同步；不得每次事件再制造副本修正配置错误。

### 7.2 去重责任表

| 风险 | 权威层 |
|---|---|
| 手动输入序号 | CurrentElementController |
| 单个命中窗重复 overlap | DeliveryBase |
| 非法调用方重复提交命中 | CombatReceiver 的有界缓存 |
| 局内 RunEvent 身份 | RunSession |
| 同房间同敌人重复结算 | RunSession 的逻辑击杀身份 |
| 遗物冷却与单房触发上限 | RelicRuntimeState |
| 临时属性效果的活动实例 | PlayerGrowthAdapter，键包含效果来源和事件身份 |

重点审查：

- RunSession 与 RelicController 的重复事件账本。
- Host、Enemy、RunSession 对同一次死亡的多层重复拦截。
- CurrentElementController 的生成序号、发布序号和 RunSession 事件身份是否在防御同一问题。
- PlayerGrowthAdapter 是否再次防御已经由上游保证唯一的事件。
- 当前临时攻击修正只以 `event_id` 为键；两个不同遗物响应同一事件时会互相吞掉。第二阶段必须改为“来源 relic_id + event_id”的活动实例身份，并覆盖两个遗物同事件均生效、同一来源同一事件不重复的测试。

不得为了删字典而失去“同一击杀换一个 event_id 仍不能重复领取经验”的逻辑身份保护。

## 8. 第三阶段：把静态验证移出每次施法

第三阶段属于中等风险，必须单独 Review。

### 8.1 Delivery 公共协议

- 评估让所有正式 Delivery 和测试替身统一继承 `DeliveryBase`。
- `initialize_delivery`、关闭命中窗和完成清理应成为明确的基类协议。
- 类型边界明确后，删除每次施法的 `has_method`、Variant `call` 和临时实例探针。
- Delivery 场景类型与协议在技能目录/运行 Loadout 建立时验证一次。
- 运行时实例化失败仍须返回结构化失败且不生成攻击。

### 8.2 同步事务中的不可能失败

重点审查 SkillExecutor：

- `can_spend` 已通过且中间没有回调时，静默扣能再次失败。
- 冷却已验证且没有并发写入时，冷却提交再次失败。
- 专属元素可用性已验证且处于同一同步事务时，元素静默提交再次失败。
- RuntimeSkillLoadout 已验证的 SkillDefinition 在每次按键时再次完整验证。
- `_ready/configure` 已确认的 NodePath 依赖在每次输入时重新查找。
- Player 提供的已知 bool Callable 在每次调用时再次做动态类型防御。
- 当前 `element_commit_invariant_failed` 分支发生在冷却提交之后，若触发只恢复能量而不会撤销冷却，会留下部分提交。第三阶段必须消除这个可返回失败的部分提交路径；不能只补一个新的回滚分支。

处理原则：

- 外部输入失败继续返回结构化 RejectReason。
- 内部不变量若理论上不可能失败，改为开发期断言或消除失败分支。
- 不得删除接受前的能量、冷却、控制状态、元素可用性、快照和 Delivery 可生成性检查。
- 不得出现扣能、进冷却后返回失败但留下部分状态的路径。

## 9. 第四阶段：测试维护减负（可选）

只有前三阶段全部验收后才评估：

- 合并重复搭建同一正式房间的 Agent D 测试入口。
- 仅提取确实重复且稳定的测试 Rig；若辅助代码更难读，则不提取。
- 删除只验证已删除兼容 API 的测试，并替换为正式行为测试。
- 不减少冻结规则、失败事务、元素快照、对象池复用和生命周期覆盖。

测试或断言数量减少必须逐项说明删除了哪条重复断言，以及对应行为仍由哪条测试覆盖。未经 Review 不得执行本阶段。

## 10. 禁止的“伪减负”

- 不得创建 GodManager、GlobalServiceLocator 或新的永久全局单例。
- 不得把明确的 Result 类型合并成 Dictionary/Variant。
- 不得移除结构化失败原因，交给 UI 解析日志或字符串。
- 不得用事件总线替代清晰的直接依赖。
- 不得为了减少文件数把成长、技能、Delivery 和 UI 规则塞进同一大类。
- 不得删除对象池支持，除非策划明确取消对象池复用要求。
- 不得删除全部内部验证后依赖“调用方不会犯错”；系统边界仍必须验证。
- 不得顺手修改数值、策划规则、视觉表现或任务 12 的 HUD/配装需求。
- 不得通过降低测试覆盖、跳过入口或注释失败断言获得通过。

## 11. 文件范围与协作

Agent F 可以按阶段修改：

- `combat/components/**`
- `combat/loadouts/**`
- `combat/passives/**`
- `combat/delivery/**`
- `growth/run_session.gd`
- `growth/relics/**`
- `scripts/run_session_host.gd`
- `scripts/player.gd`
- `scripts/element_event_bridge.gd`
- `scripts/player_growth_adapter.gd`
- 为类型和节点更新所必需的 Player/TestRoom 场景
- 对应测试与架构说明

默认不得修改：

- 伤害公式、Resolver 和反应规则。
- Skill、Relic、奖励的正式数值 Resource。
- 任务 12 的新 HUD、配装和视觉文件。
- `docs/agent_tasks/completed/**`。
- 与本轮减负无关的项目文件。
- `docs/current_gameplay_design_handoff.md` 当前仍描述水火双 Loadout，属于已登记的独立文档债务。Agent F 不得在第一阶段顺手修改；由协调者另行安排文档对齐任务。

执行期间不得让 Agent B、C、D、E 并行修改上述重叠文件。Agent F 完成一个阶段并进入 Review 后，协调者再决定下一阶段。

## 12. 每阶段验收标准

- 列明删除了哪些状态、分支、文件和公共 API；仅移动代码不算完成。
- 修改范围内必须净减少，且不得用新增同等复杂度的抽象抵消。
- 每个状态只有一个明确所有者；不得让新旧两套 API 长期并行。
- 冻结规则和用户可观察行为不变。
- 第一至第三阶段期间，现有 12 个测试入口全部通过，行为测试不得减少。
- 当前基线 143 tests / 887 assertions；数量变化必须有明确、可 Review 的原因。
- 任务 10 专项、正式多敌人和保存恢复闭环继续通过。
- 主场景 headless smoke 退出码为 0，无脚本错误。
- 除已知 Windows 根证书警告外，不新增错误或警告。
- 报告修改前后：生产文件数、生产代码行数、关键类行数及仍保留的防御边界。

## 13. Git 与交付

- 不执行任何 Git 命令，包括 status、add、commit、push、rebase 和 reset。
- 每阶段报告：修改文件、删除文件、测试结果、净减少指标、保留风险和下一阶段建议。
- Agent F 不得自行把任务改为 ACCEPTED，也不得自行开始下一阶段。


## 14. 最终 Review 证据（2026-07-22）

- Review 已复验任务全部阶段和最后两项返修，结论为 `ACCEPTED`。
- 全量 12/12 测试入口通过：144 tests / 917 assertions。
- 任务 10 专项通过：10 tests / 143 assertions。
- 主场景 headless smoke 退出码为 0，无脚本错误或新增警告；仅保留既有 Windows 根证书读取警告。
- 旧配置溢出技能已覆盖正式闭环：迁移后仍拥有，经过真实奖励、路线与商店事务装备成功，并写入 Host 持久快照。
- 全项目零调用的 `DeliveryBase.has_recorded_target()` 已删除。
- 本文由协调者在 Review 通过后移入 `completed/`；未执行 Git 操作。
