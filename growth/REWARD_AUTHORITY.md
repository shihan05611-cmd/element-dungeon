# Reward Authority Boundary

`RoomRewardContext` 是不可信请求 DTO，只包含 `room_id` 和请求的 `reward_type`。它不拥有“是否第一战”的权威信息。

当 `RunSession` 位于 `REWARD` 阶段时，`RewardGenerator` 使用 `RunSnapshot.route` 强制执行：

- `current_room_id` 必须与请求房间一致；
- `completed_combat_rooms == 1` 时唯一允许 `RewardType.SKILL`，并强制至少三个合法初始技能；
- 后续房间的请求类型必须等于 `selected_reward_type`；
- 缺失路线类型返回 `missing_route_reward_type`；
- 类型不一致返回 `reward_type_route_mismatch`。

旧三参数 `RoomRewardContext.new(room_id, reward_type, first_room_hint)` 的第三参数仅为未迁移测试的兼容占位，不保存也不读取，不能改变生成规则。正式调用只传前两个参数。
