# Fury 旧语义断言等量迁移表

比较基线：`102720086c53a84901b788726ad609d15263d64a` → 当前 Task34 工作树。

只读 diff 结果：`_run(...)` 注册增删 `0`，含 `_expect` 的断言行增删 `0`。没有删测、跳过、改 expected、弱化条件或修改断言文案。迁移发生在 fixture：旧的“无空间预检也可直接接受”环境补为稳定 enemy sweep + 离树已准备 Delivery；直接 Delivery 测试则显式把旧 origin 等量写入新 snapshot 的 `impact_position`。

## `run_skill_execution_contract_tests.gd`

| 旧测试 | 旧断言数 | 当前断言数 | 等量迁移 |
|---|---:|---:|---|
| `all_energy_burst_rejects_19` | 4 | 4 | 最低 SP 拒绝发生在 sweep 前；断言与 fixture 语义均不变。 |
| `all_energy_burst_20_snapshot` | 7 | 7 | 旧 fixture 无目标也接受；当前统一 fixture 提供 `FixedEnemySweepPort`、合法 source、`TestBurstDeliveryPreparePort`，因此仍在合法 enemy contact 后验证完全相同的 20 SP/payload/radius/原子扣除断言。 |
| `all_energy_burst_100_snapshot` | 9 | 9 | 同上；完全保留 100 SP、800%、5 层、2.0 radius、接受后 snapshot 锁定断言。 |
| `all_energy_burst_200_snapshot` | 7 | 7 | 同上；完全保留 200/220、1600%、10 层、1.9 radius、全 SP 原子扣除断言。 |
| `all_energy_burst_220_caps_element_amount` | 8 | 8 | 同上；完全保留 220 SP、17.6 multiplier、10 层 cap、2.0 radius 与 `RejectReason.NONE`。 |
| 小计 | **35** | **35** | 其中 31 条旧成功断言由合法 enemy-contact fixture 承接；4 条最低 SP 拒绝断言不触及 sweep。 |

`_burst_skill()` 只新增共享正式 `SWEEP_PROFILE`；`_make_rig()` 对所有旧 test 保留同一 executor/energy/element，同时仅在缺省时注入 sweep/prepare Port。传入 reclaim services 时使用 narrow setter，未覆盖原 reclaim Port；相关 runner 总计仍为 `16 tests / 102 assertions`。

## `run_first_batch_delivery_tests.gd`

这里测试的是已接受 snapshot 之后的 Delivery，不是施法接受权威。旧 `_burst_snapshot()` 通过 `AllEnergyBurstExecution.prepare(context, null)` 绕过 Task34 新 sweep 前置条件；当前 helper 以完全相同公式构建已锁定 payload/radius，并新增 `impact_position`。`_submit_rage()` 的 origin 与 snapshot impact 一致，旧 Delivery 断言逐条保留。

| 旧测试 | 旧计数（直接 + helper） | 当前计数 | 等量迁移 |
|---|---:|---:|---|
| `rage_minimum_radius_and_payload` | 7 + 2 = 9 | 9 | impact 默认 `Vector2.ZERO`，与旧提交 origin 相同；最小伤害/层数/半径/内外目标断言不变。 |
| `rage_midpoint_radius` | 6 + 2 = 8 | 8 | 同位置迁移；50 SP 的 1.5 radius、400%、2 层和内外目标断言不变。 |
| `rage_maximum_multi_target_and_reaction` | 8 + 2 = 10 | 10 | 同位置迁移；多目标、反应倍率和元素层断言不变。 |
| `rage_wall_rule_is_explicit` | 2 + 4 = 6 | 6 | 两个旧 origin 分别写入 snapshot impact；wall-blocking on/off 两次提交及结果断言不变。 |
| `rage_duplicate_hurtboxes_hit_once` | 3 + 2 = 5 | 5 | impact 默认原点；重复 Hurtbox 一次命中断言不变。 |
| `rage_snapshot_remains_locked` | 5 + 2 = 7 | 7 | impact 默认原点；energy/element 后改不污染 locked payload 断言不变。 |
| 小计 | **45** | **45** | helper 中每次 initialize 与 trigger 的两条强断言也原样保留。 |

该 runner 总计保持 `26 tests / 163 assertions`。其余 20 个非 Fury 测试无代码变化。

## 总结

- 旧 Fury 相关断言：`35 + 45 = 80`
- 当前对应断言：`35 + 45 = 80`
- 删除/跳过/放宽：`0`
- 非 Fury 行为变更：`0`
- 语义变化只限任务书授权项：Fury 只有首个合法 enemy contact 才接受，并把爆发位置从施法者中心改为锁定 impact。
