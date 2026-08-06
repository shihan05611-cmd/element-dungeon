# Task31 阻塞证据

状态：`BLOCKED`
日期：2026-08-06
阶段检查点：`d3ab3e627d8aa34df06d1aefb3ca695c8a238b9f`

## 结论

Task31 在完成全部必读材料、Task30 正式 runner/capture 入口、allowlist 静态资源及全仓调用点的只读审计后冻结。正式内容只有两个不同的可装备被动技能，无法在不越权、不破坏接受基线且不伪造测试的前提下，从正式 `RunGame` 完成任务书要求的“四被动跨房”、保存前“四被动”断言和“主动加四被动”权威预算。

应退回任务 27 的正式内容/catalog 职责：增加至少两个不同且可购买的正式被动内容，并同步重新冻结 catalog 与 Task16/Task27 精确接受基线。任务 28 已提供四被动 Runtime，任务 30 已提供 `P1–P4` UI；本次审计未发现二者的结构缺陷。

## 可复核事实

| 事实 | 只读证据 | 结论 |
|---|---|---|
| 正式 catalog 总计七项 | `resources/content/run_content_catalog.tres` 的 `skill_contents` 为基础攻击 `element_slash` 加六个可购买内容 | 不能把空的 P3/P4 当成被动内容 |
| 六个可购买内容的类型 | 主动：`element_bolt`、`elemental_fury`、`elemental_laser`、`element_reclaim`；被动：`burning`、`unending` | 正式 RunGame 最多装备两个不同被动 |
| 接受基线冻结 catalog 数量 | `combat/tests/run_skill_content_catalog_tests.gd:112-129` 断言 7 个 gameplay、6 个 obtainable，并断言旧 `passive_vitality/passive_energy/passive_focus/passive_balance` 不得注册 | 直接向 catalog 增加两项会使 Task30 的 26-runner 接受基线失败 |
| Task27 也冻结六个商店内容 | `growth/tests/run_task27_run_economy_progression_tests.gd:60-68` 断言 `shop_contents().size() == 6` | Task31 无权修改该已接受 runner |
| 七槽禁止重复技能 | `combat/loadouts/runtime_skill_loadout.gd:97-103` 对重复技能返回 `duplicate_equipped_skill` | 不能用 `burning`/`unending` 重复填满 P1–P4 |
| Task31 要求真实四被动 | 任务书 6.2、7.2、8 节分别要求“主动加四被动”、正式 RunGame“四被动跨房”及截图保存前断言“四被动” | 两个被动不满足完成定义 |
| Task31 内容 allowlist | 任务书 4.1 只列 catalog 和六份既有技能内容；4.3 只允许新增三个验证夹具/evidence | 无权新增两份正式被动内容资源 |

可选但不合法的绕过均已排除：

- 在 Task31 runner 中临时注入 Task28 的四被动 fixture，不是正式 RunGame 静态内容，且违反禁止 mock/伪造正式系统的门禁；
- 将同一被动重复装备到两个槽会被正式 Runtime 原子拒绝；
- 把两个主动改成被动会破坏六技能冻结合同、Task16/27/30 接受基线和现有 VFX/行为语义；
- 修改 Task16/Task27 runner、扩大 allowlist 或降低“四被动”断言均未经授权。

## 执行与保护对账

- 开工时只把任务书从 `PENDING` 置为 `IN_PROGRESS`；发现结构缺陷后按任务书改为 `BLOCKED` 并停止实现。
- 未修改任何 `.tres`、`.tscn`、权威脚本、正式 UI、Task27～30 runner/evidence 或 `project.godot`。
- 未新增 `run_task31_content_balance_tests.gd`、`run_task31_full_run_e2e_tests.gd` 或 `capture_task31_full_run_visuals.gd`；不以无法满足四被动门禁的夹具冒充交付。
- 未运行 Godot/MCP，未控制共享编辑器，未创建 `C:\tmp` 冷副本/profile，因此不存在 scan、runner、smoke、capture、rescan 或 PNG 数字可报告。
- 开工只读基线 HEAD：`d3ab3e627d8aa34df06d1aefb3ca695c8a238b9f`。
- 共享 `.godot` 复核为 `754 files / 37,416,266 bytes`，最新写入时间仍为 `2026-08-06T12:52:36.9297954Z`；与 Task30 最终稳定数量/字节一致。
- 既有未跟踪 sidecar 复核为 `66 files / 28,555 bytes`，最新写入时间仍为 `2026-08-06T12:46:32.2117630Z`；与 Task30 最终稳定数量/字节一致。
- `.workbuddy/memory/2026-07-31.md`、`docs/架构评估与扩展性改进建议.md` 及 66 个既有 sidecar 均保持未跟踪、未修改、未认领。
- 未使用子 Agent；Git 写操作、暂存、提交、切换、重置均为 `0`。

## 未执行门禁

正式 28 runners、Task20 单列、双 smoke、两条完整局、14 场景矩阵、至少 14 张实际 Viewport 与最终 rescan 均未运行。原因不是测试失败，而是其前置内容条件在当前 allowlist 和冻结基线下不可满足；运行或构造部分证据会掩盖结构缺陷。

任务保持冻结，等待中枢决定是否退回任务 27 补齐正式被动内容及其接受基线，或修订 Task31 的 allowlist/完成定义。

## 中枢 Review 5.0 阻塞审计

中枢已独立核对并确认本阻塞成立。最高优先级需求明确要求“四个不同被动同时装备”，因此不降低 Task31 完成定义；改由前置任务32正式接入 `passive_vitality` 与 `passive_energy`、补齐独立图标并迁移 Task16/27 catalog 断言。Task32 独立验收通过前，Task31保持 `BLOCKED` 和冻结。
