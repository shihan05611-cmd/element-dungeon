# Agent E 新任务书：共享 Loadout 与元素变化事件契约迁移

状态：ACCEPTED
负责人：Agent E
依赖：05_agent_e_growth_core 完成 Review 并验收通过

## 1. 任务定位

把上一轮成长域中按元素保存的 Loadout 契约迁移为全元素共享的 3 个主动位置和 1 个被动位置，并补齐遗物按元素切换来源筛选所需的事件字段。

这是上一轮 Agent E 任务完成后的新任务，不得改写或覆盖 05 的历史交付。

## 2. 开工前检查

- 先确认 05 的 growth 交付已经 Review 验收通过。
- 如果 05 与本任务仍有未完成的文件重叠，先报告协调者，不得覆盖。
- 阅读 docs/design/共享技能槽与元素释放规则.md。

## 3. 独占范围

可以修改：

- growth/contracts/runtime_loadout_slot_snapshot.gd
- growth/contracts/runtime_loadout_snapshot.gd
- growth/contracts/run_snapshot.gd
- growth/contracts/runtime_loadout_change_result.gd
- growth/ports/runtime_loadout_port.gd
- growth/shop/shop_draft.gd
- growth/run_session.gd 中仅与 Loadout 契约和拥有校验有关的部分
- growth/events/form_changed_event.gd
- growth/relics 中仅与元素变化来源筛选和事件去重有关的部分
- growth/tests 与 growth/README.md、growth/TESTING.md

不得修改 combat、scripts、scenes、resources 或 completed 任务文档。

## 4. Loadout 契约

- RuntimeLoadoutSlotSnapshot 删除 form_id，只保留 slot_id 和 skill_id。
- RuntimeLoadoutSnapshot 表达唯一的 slot_id → skill_id 映射。
- 快照继续保持不可变、复制集合、带 revision 和结构化 validation_error。
- Growth 不负责判断主动/被动槽兼容性；该静态规则由 Agent B 的 RuntimeLoadoutPort 实现验证。
- RunSession 继续在商店确认前校验所有非空 skill_id 已属于本局。
- ShopDraft 的换装命令改为 try_assign_slot(slot_id, skill_id) 或等价签名。
- 旧 form_id 接口不得继续作为正式路径保留或双写。
- B 提供的端口必须能对整个四槽快照进行纯验证与原子整体替换。

## 5. 元素变化事件

FormChangedEvent 或其替代 DTO 必须包含：

- previous_element_id
- current_element_id
- source：MANUAL 或 SKILL_AUTO
- 单调递增 sequence
- timestamp_msec 或等价稳定时间字段
- event_id 与 room_id

规则：

- 新旧元素相同时事件无效，不能进入遗物分发。
- 重复 event_id 或 sequence 不得重复触发。
- 遗物效果可以明确配置响应全部、仅 MANUAL 或仅 SKILL_AUTO。
- Growth 只消费集成层投影后的事件，不直接依赖 Agent B 的 CurrentElementController。

## 6. 兼容与迁移

- 只定义新快照契约；旧水火 Loadout 的具体合并算法由 Agent B 实现。
- 若需要读取旧结构，只能通过一次性迁移 DTO 或适配器，不得让 RunSnapshot 同时暴露新旧格式。
- 更新 growth README 中所有 form_id → slot_id 示例。

## 7. 必测用例

- 四个共享位置的快照、复制、排序和 revision。
- 重复 slot_id、空 slot_id 和非法 entry 拒绝。
- ShopDraft 按 slot_id 换装、reset、过期检测和失败无部分提交。
- RunSession 拒绝未拥有技能，允许 0 主动 + 4 被动的合法四槽快照由 B 端口通过。
- 相同元素不产生有效事件。
- MANUAL 与 SKILL_AUTO 过滤正确。
- 重复 event_id、重复 sequence 不重复触发遗物。
- 两个 RunSession 状态隔离。
- 上一轮 growth 30 tests / 170 assertions 全部回归通过，并更新新增计数。

## 8. 交付

- 报告测试结果、修改文件清单和剩余限制。
- 不执行任何 Git 命令；由用户统一提交。
