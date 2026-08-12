# 任务 38：回收视野范围与反应回能被动

状态：ACCEPTED
负责人：Gameplay/Passive Agent（threadId `019ff4cd-81c3-75a2-8cf0-2b68ea066497`，hostId `local`）
依赖：Task34 `ACCEPTED`；派发基线 `7c217775e7ffa22aeffe6dd6a2af6694aae72d92`
回传中枢：Review 6.0，threadId `019fd7fd-4476-7f73-b121-76760fabf284`，hostId `local`

## 1. 目标与冻结语义

本任务只完成两个小而完整的正式机制：

1. `element_reclaim` 的目标范围从固定半径改为当前游戏 Viewport 中相机可见的世界矩形。可见矩形内、即使隔着地形的合法敌人也计入；矩形外敌人不计入。保持现有同元素筛选、全层回收、SP 恢复、原子事务、等级效果和技能冷却。
2. 新增正式被动 `passive_reaction_energy`，显示名“元素回响”：玩家造成的一次已接受元素反应结算恢复 `10 SP`，上限钳制。一次 `CombatResult` 最多触发一次，不按消耗层数重复，不增加 ICD；未触发反应、被拒绝结果、敌人对玩家造成的反应都不回能。

项目以求职作品和尽快完成流程为目标。使用现有 `CombatResult`、Passive Runtime、OwnerPort、RunSessionHost 接线；不新增通用事件总线、服务定位器、规则 DSL、缓存层、兼容层或与这两个机制无关的防御分支。

Task39 并行提供 `assets/generated/vfx/passive_reaction_energy/icon.png`。本任务只引用该正式路径，不生成占位图；若最终门禁开始时资产尚未完成，通知中枢并等待，不得自行扩权。

## 2. 实现合同

### 2.1 回收视野范围

- 由当前 source 所属 Viewport 的可见矩形与 canvas transform 推导世界范围；不硬编码 1920×1080、2560×1440 或旧 `160` 半径。
- 实际目标查询必须按世界矩形过滤，视野对角外不能仅因落在包围圆内而误收。
- 当前正式相机无旋转；无需为任意旋转、多相机、分屏或编辑器预览建立通用框架。
- source/Viewport 不可用时沿用现有明确拒绝，不伪造全屏范围；不添加大量理论上不可达的 fallback。
- 现有 `RangeElementReclaimTransaction`、同元素匹配、稳定顺序、全有或全无提交不得改写。

### 2.2 元素回响

- 新定义/Runtime 走现有被动装备、卸下、跨房重建和死亡清理生命周期；不得接入已停用遗物运行时。
- Runtime 只消费玩家作为根来源、目标为敌人、`accepted && reaction_triggered` 的正式结算，并通过 `PassiveOwnerPort` 恢复 10 SP。
- 事件身份必须使用该结算已有的 cast/delivery/hit/target 信息，保证一次结算一次恢复；不引入额外计时器或全局去重表。
- `PassiveOwnerPort` 只补必要的 `restore_energy` 能力，实际恢复继续交给 `PlayerGrowthAdapter/EnergyComponent` 权威路径与上限钳制。
- 内容为可购买、可拥有、仅被动槽、不可升级、非默认装备；购买价 `75` 梦尘。旧免费奖励流程继续停用。Task41 的普通宝箱可将其作为未拥有技能候选。
- 正式 catalog 迁移为：固定普通攻击 1 个 + 可购买内容 9 个（4 主动 + 5 被动），共 10 个 gameplay definitions；初始拥有/默认 A1 不变。

## 3. 精确 allowlist

仅允许修改/新增：

```text
combat/targeting/combat_target_query_2d.gd
combat/targeting/range_element_reclaim_port.gd
combat/passives/passive_effect_runtime.gd
combat/passives/passive_owner_port.gd
combat/passives/reaction_energy_passive_effect_definition.gd
combat/passives/reaction_energy_passive_effect_definition.gd.uid
combat/passives/reaction_energy_passive_effect_runtime.gd
combat/passives/reaction_energy_passive_effect_runtime.gd.uid
scripts/player.gd
scripts/vfx/skill_vfx_coordinator.gd
scripts/passive_effect_adapter.gd
scripts/run_session_host.gd
resources/skills/passive_reaction_energy.tres
resources/content/skills/passive_reaction_energy_content.tres
resources/content/run_content_catalog.tres
combat/tests/run_first_batch_delivery_tests.gd
combat/tests/run_skill_execution_contract_tests.gd
combat/tests/run_passive_runtime_contract_tests.gd
combat/tests/run_skill_content_catalog_tests.gd
growth/tests/run_task27_run_economy_progression_tests.gd
growth/tests/run_task31_content_balance_tests.gd
growth/tests/run_task32_formal_four_passive_content_tests.gd
combat/tests/run_task38_reclaim_reaction_energy_tests.gd
combat/tests/run_task38_reclaim_reaction_energy_tests.gd.uid
combat/tests/capture_task38_reclaim_reaction_energy_visuals.gd
combat/tests/capture_task38_reclaim_reaction_energy_visuals.gd.uid
docs/agent_tasks/pending/38_reclaim_view_reaction_energy_passive.md
docs/agent_tasks/evidence/task38/**
```

Task39 独占 `assets/generated/vfx/passive_reaction_energy/**` 与资产 manifest；本任务不得修改。旧 runner 只允许迁移构造签名、catalog 精确数量和新机制直接断言，不重写历史场景。

上述四个 `.gd.uid` 仅允许由本任务此前不存在的冷副本与独立 Godot 4.7.1 profile 在 editor scan 中为对应新脚本生成，再按精确文件复制纳入交付；不得手写 UID、在共享项目运行 Godot 生成、认领或改动任何既有 `.gd.uid`/`.import` sidecar。

## 4. 非目标与禁止

- 不修改回收 SP 公式、技能等级、冷却、元素反应公式或其他主动/被动。
- 不做墙体 LOS/raycast、迷雾、屏幕边缘提示、相机旋转/分屏框架。
- 不新增被动等级、ICD、浮字、独立世界 VFX 或声音。
- 不改 HUD/Overlay、RunFlow、房间、敌群、Boss、商店流程或 Task39/40 范围。
- 不使用子 Agent；不执行任何 Git 写操作；不得控制共享 Godot/editor/godot-ai。

## 5. 验证门禁（精简但充分）

1. 在此前不存在的 `C:\tmp` 冷副本与独立 profile 中验证；第一条 Godot 命令为 4.7.1 headless editor scan。共享编辑器保持被动。
2. Task38 专项至少覆盖：屏内且超过旧 160 半径可回收、屏外不回收、隔墙屏内可回收、不同元素忽略、满 SP/无目标拒绝、原子提交保持；元素回响单次 +10、上限钳制、非反应/敌方反应不触发、卸下不触发、跨房重建只注册一次。
3. 迁移上述直接受影响 runner；随后复跑当前正式 `29/29 runners / 300 tests / 4095 assertions`，加 Task38 后应为 `30/30`，tests/assertions 按实际报告。Task20 `7/68` 单列，继续历史 `BLOCKED`。
4. `RunGame`、`TestRoom` 各 180 帧 smoke；capture 后 final rescan。正式日志五类标记均为 0。
5. 非 headless 真实画面至少 4 张：1920×1080 和 2560×1440 各一张屏内远距离回收、一张装备元素回响后的反应回能；保存前断言 Viewport、目标位置、SP 前后、被动 ID/Runtime。逐张原尺寸检查。

不要求穷举所有分辨率、缩放/旋转、几十种边缘像素或人为制造不可达异常；只验证上述用户路径和现有原子性。

## 6. 保护、状态与自动回传

开工前固化 HEAD/status、allowlist SHA、共享 `.godot`/sidecar 和进程；当前保护输入包括未跟踪 `AI协作中枢规则_浓缩版.md`、`AI协作中枢运行协议_通用版.md`，不得修改、删除、认领或暂存。Task20 保持唯一历史 pending 文件。

开工置 `IN_PROGRESS`；完成全部门禁只置 `REVIEW`，写完 evidence 与最终 allowlist/保护对账后冻结；阻塞置 `BLOCKED`。完成或阻塞后必须直接调用 `send_message_to_thread` 回传中枢 `019fd7fd-4476-7f73-b121-76760fabf284`（hostId `local`），不得等待用户转述，不得自行 `ACCEPTED`。

## 7. 执行记录（2026-08-12）

- 以派发 HEAD `7c217775e7ffa22aeffe6dd6a2af6694aae72d92` 完成 Viewport 世界矩形回收与 typed 元素回响被动；Task39 icon/import 只读消费，未修改其资产、sidecar、prompt/manifest 或 `docs/vfx/final_asset_manifest.md`。
- 原实现冷副本生成并精确复制的四枚 allowlist `.gd.uid` 保持冻结。本次 Review 6.0 唯一返工没有修改任何玩法代码、资源、catalog、runner/capture 源码或 UID，只重建 evidence 与本执行记录。
- 独立 Review 发现原 evidence 冷副本混入 Task40，旧 `304/4162` 与旧四图已作废并由本轮 clean evidence 完整替换。本轮从固定 HEAD 的只读 `git archive` 构建此前不存在的 `C:\tmp\element-dungeon-task38-clean-evidence-20260812-01`，只叠加 Task39 ACCEPTED 的 19 个资产/manifest 文件与 Task38 §3 的 27 个冻结文件；Task40、live README、中文保护文档与旧 Task38 evidence 均排除。
- 独立 profile 为 `C:\tmp\element-dungeon-task38-clean-profile-20260812-01`，第一条 Godot 命令仍是 4.7.1 headless editor scan。五个 Task40 tracked 文件逐一等于固定 HEAD blob，Task40 新 runner/capture/UID/taskbook/evidence 全缺席。
- clean Task38 专项 `3 tests / 38 assertions`；8 个直接受影响 runner 全通过；正式 baseline 加 Task38 为 `30/30 runners / 304 tests / 4161 assertions`，其中 `run_task30_run_ui_tests = 9/172`；Task20 单列 `7/68`；双 180 帧 smoke、`1/43/4` capture 与 final rescan 全部 exit 0。
- 本轮 44 份日志五类标记均为 0；四张 clean Viewport 已重新生成并逐张原尺寸检查。共享 `.godot` 保持 `990 files / 42,684,249 bytes`；共享 Godot/godot-ai 进程当前为 0，本轮未重启。
- 完整 clean provenance、HEAD blob、UID、日志、PNG SHA、外部 sidecar/保护对账见 `docs/agent_tasks/evidence/task38/README.md`。

## 8. 中枢验收记录（Review 6.0，2026-08-12）

- 独立 Review 在固定 HEAD + Task39 ACCEPTED + Task38-only 候选中完成静态审计与冷副本验证；Viewport 世界矩形回收、无 LOS、屏外排除、满 SP 拒绝、原子事务、元素回响单次 +10 SP/上限钳制/生命周期与 catalog 合同均通过。
- 执行阶段首次 evidence 曾混入 Task40 的 HUD/旧 runner 变化，旧 `304/4162` 与旧四图已明确作废。执行者以全新 clean root/profile 重生正式证据；独立 Review 复核 26 个实现/资源/runner/capture/UID 哈希零变化，Task40 文件全部排除。
- current-final 证据精确为 `README + 44 logs + 2 CSV + 4 PNG = 51 files`，50 个主要证据 clean→共享 SHA `0 mismatch`；正式 `30/30 runners / 304 tests / 4161 assertions`，Task38 `3/38`，Task20 单列 `7/68`，双 180 帧 smoke、`1/43/4` capture、final rescan 全通过，44 日志五类标记均为 0。
- 共享 `.godot` 保持 `990 files / 42,684,249 bytes`；共享 Godot/godot-ai 进程当前为 0 且未由本任务重启。两份中文保护文档与 Task39/40/中枢并行变化均原样保留。
- 中枢据此将 Task38 置为 `ACCEPTED` 并归档；不追认 Task20，不启动任何 Git push。
