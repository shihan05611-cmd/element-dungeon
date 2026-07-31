# Agent B 任务书：CurrentElement、自动切换与释放事务

状态：ACCEPTED
负责人：Agent B
依赖：07_agent_b_shared_skill_slots_passives Review 验收通过

## 1. 任务定位

建立唯一 CurrentElement 状态，把专属技能自动切换纳入现有 SkillExecutor 的接受事务，并完成手动切换缓冲、资源返还配置和元素快照回归。

## 2. 独占范围

可以修改：

- combat/components/element_form_controller.gd 或其明确替代类
- combat/components/skill_executor.gd
- combat/components/skill_controller.gd
- combat/components/energy_component.gd 的窄事务接口
- combat/definitions/skill_definition.gd 中退款策略和元素字段
- combat/contracts/cast_attempt_result.gd
- 与 CurrentElement 变化事件相关的新 combat/contracts/**
- combat/tests/run_skill_tests.gd 及新的事务测试

不得修改 growth、Agent A 伤害/元素 Resolver、Agent C Delivery、Player、HUD 或正式场景。

## 3. CurrentElement

- 玩家只有一个权威 CurrentElementController。
- 当前只配置水火，但可用元素来自有序配置列表；toggle/cycle 不能写死 WATER ↔ FIRE。
- 提供 request_element、cycle_next 或等价窄接口。
- 元素变化结果包含旧元素、新元素、MANUAL / SKILL_AUTO 来源、单调 sequence 和 timestamp。
- 新旧相同时返回成功但不发变化事件。
- 重复输入或重复序号不能重复发布。
- 对外事件必须发生在状态提交后。
- 保持兼容命名时也只能存在一个真实状态源，禁止 CurrentElement 与旧 FormController 双写。

## 4. 手动切换缓冲

- IDLE 和 RECOVERY 允许即时手动切换。
- STARTUP、ACTIVE、受击等暂时不可操作状态只保留最后一次切换请求。
- 进入允许阶段时执行一次缓冲请求。
- 死亡、换层、暂停退出和开始新局清空缓冲。
- 手动切换不耗能、不占槽位、不修改已接受 Cast。
- 三、四元素扩展只需改变有序列表，不增加技能栏或新的 switch 分支。

## 5. 接受事务

现有流程继续保持 REQUEST → VALIDATE → ACCEPT/COMMIT → STARTUP → ACTIVE → RECOVERY。

接受前完成：

- skill_id 与 slot_id 解析。
- ACTIVE/PASSIVE 检查。
- Busy、控制状态与外部门禁。
- 能量与冷却。
- 专属元素是否处于可用列表。
- Stat、Spawn、Payload 和 Delivery 配置。
- 所有不可变快照是否可创建。

全部验证通过后才允许提交：

- EXCLUSIVE_ELEMENT：在同一接受事务中自动切换到 required_element_id，并锁定该元素。
- CURRENT_ELEMENT：不切换，锁定提交瞬间 CurrentElement。
- NEUTRAL：不切换，CastSnapshot.cast_element_id 为 NONE。
- 技能 ID、元素、Stat、Payload、Spawn、能量和冷却整体锁定/提交。
- 外部监听者不能观察到“已切元素但释放失败”或“已扣能但没有 Cast”的半状态。
- 专属目标元素已经是当前元素时不发布变化事件。

失败必须保证不切元素、不扣能、不启动冷却、不生成攻击。

## 6. 打断、取消与退款

- 接受后自动切换不回滚。
- 未到 Delivery 生成点的攻击不生成；已生成攻击保持锁定快照。
- 增加 EnergyRefundPolicy：NEVER 为默认；BEFORE_DELIVERY 表示生成前取消时返还能量。
- 首版冷却在接受后不回滚。
- 退款与元素状态完全解耦。
- 接受回调重入、连续施法和大 delta 跨阶段仍保持现有事务保护。

## 7. 必测用例

- 能量不足请求火专属：保持旧元素、能量和冷却。
- 冷却中请求火专属：保持旧元素。
- 水状态成功接受火专属：进入 STARTUP 前 CurrentElement 已为火，事件来源 SKILL_AUTO。
- 火状态接受火专属：不派发变化事件。
- 自动切火后 STARTUP 被打断：保持火。
- 自动切火后取消：保持火；退款只按策略发生。
- CURRENT_ELEMENT 水投射物接受后手动切火：Cast/Payload 仍为水。
- NEUTRAL Cast 锁定 NONE。
- PASSIVE 槽按键不进入事务。
- IDLE/RECOVERY 手动切换即时；STARTUP/ACTIVE 只执行最后一个缓冲。
- 相同元素请求、重复输入和重复序号不刷事件。
- 三元素模拟配置按顺序循环，无新增技能栏。
- 现有大 delta、重入、取消、资源和快照测试全部回归。

## 8. 交付

- 报告测试结果、修改文件清单和剩余限制。
- 不执行任何 Git 命令；由用户统一提交。
