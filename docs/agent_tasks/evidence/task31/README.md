# Task31 内容/数值与完整局 E2E 最终执行证据

状态：`ACCEPTED`
日期：2026-08-06
执行基线 / Task32 ACCEPTED 检查点：`8ae7f9083b7da3d9f01b32966fa207162a623fd0`
历史 Task31 协调检查点：`d3ab3e627d8aa34df06d1aefb3ca695c8a238b9f`

## 最终结论

Task32 补齐正式四被动后，Task31 在全新冷副本中完成全部门禁：静态内容/14 场景、正式 `RunGame` 安全与风险两条完整局、真实六战/三商店/两路线、四被动跨房、Boss 零梦尘直结算、新局 authority 重建、真实玩家失败、29 个正式 runner、双 180 帧 smoke、19 张真实 Viewport 与最终 editor rescan 均通过。Task31 没有调整任何 `.tres`/`.tscn` 数值；现有 Task32 基线数值已经满足内容门禁，因此交付只新增三个 Task31 验证夹具及本 evidence。

最终自动化数字为：

- Task32 接受基线：`27/27 runners / 287 tests / 3338 assertions`；
- Task31 专项：`13 tests / 757 assertions`；
- 正式合计：`29/29 runners / 300 tests / 4095 assertions`；
- Task20 历史非门禁：`7 tests / 68 assertions`，单列、不追认；
- 图形 capture：`1 test / 627 assertions / 19 screenshots`；
- 35 份正式日志五类标记全部为 `0`。

## 修改与 allowlist 对账

### 实现/协调文件

| 文件 | 字节 | SHA-256 | 说明 |
|---|---:|---|---|
| `docs/agent_tasks/completed/31_run_content_balance_e2e_regression.md` | 归档后更新 | 见 Git 检查点 | 状态、Task32 恢复、执行交付和中枢独立验收记录 |
| `growth/tests/run_task31_content_balance_tests.gd` | 20,164 | `FFBA13CF39331937DE52A62A4B2A017D0A48EFCFDE23633B43CD3FE6FE30242B` | 静态内容、预算、返还、房间、路线、Boss、14 场景领域门禁 |
| `combat/tests/run_task31_full_run_e2e_tests.gd` | 33,084 | `4EB091947E59F057D5746A529F9576AA494B2DDFE15535A933759AAF3568E980` | 两条正式完整局、新局、返回入口禁用和失败 E2E |
| `combat/tests/capture_task31_full_run_visuals.gd` | 29,133 | `5C47207E1F14B1A9E5F5D81BEF40C8FFF92D90CF1470F103E2530192AA3B5035` | 非 headless 真实 RunGame 19 图 capture；保存前完整 authority/Viewport 断言 |

本 README 的最终字节/SHA 具有自引用不可能性，冻结后的精确值在自动回传中报告。除此之外，本 evidence 新增 `35` 份 UTF-8/LF 日志（`99,650` bytes）和 `19` 张 PNG（`4,131,914` bytes）；逐文件 SHA 见后文。未复制 `.gd.uid`、`.import`、冷副本 `.godot` 或失败开发产物。

### 未修改的 allowlist 静态内容

`resources/content/run_content_catalog.tres`、六份首批技能内容、`prototype_two_layer_six_combat.tres`、八份房资源及四张房模板均与 HEAD 一致，`git diff` 为零。未修改任何 Task27～30 权威/UI/runner/evidence、`project.godot`、`TestRoom`、Player、Enemy、VFX 或正式 HUD/Overlay。

## 最终技能内容与经济数值

### 主动价格、等级曲线与返还

等级只改变已接受白名单中的伤害倍率或回收资源倍率；SP 消耗、冷却、范围、前后摇、元素政策和反应公式均不变。

| 技能 | 购买价 | Lv1 | Lv2 升级/效果 | Lv3 升级/效果 | Lv3 累计升级 | Lv2/Lv3 重置返还 |
|---|---:|---|---|---|---:|---|
| `element_bolt` 元素弹 | 80（开局已拥有） | 伤害×1.00 | 55 / 伤害×1.25 | 95 / 伤害×1.55 | 150 | 38 / 105 |
| `elemental_fury` 元素之怒 | 110 | 伤害×1.00 | 70 / 伤害×1.20 | 120 / 伤害×1.45 | 190 | 49 / 133 |
| `elemental_laser` 元素激光 | 120 | 伤害×1.00 | 65 / 伤害×1.20 | 110 / 伤害×1.45 | 175 | 45 / 122 |
| `element_reclaim` 回收 | 90 | 回能×1.00 | 50 / 回能×1.25 | 90 / 回能×1.50 | 140 | 35 / 98 |

70% 返还始终向下取整，仅返还累计升级实付；四条 Lv2/Lv3 买入—重置净损失分别为元素弹 `17/45`、元素之怒 `21/57`、元素激光 `20/53`、回收 `15/42`，不存在循环套利。购买价不纳入重置返还。

### 四个正式被动

| ID | 显示名 | 价格 | 等级/重置 | 效果 |
|---|---|---:|---|---|
| `burning` | 燃烧 | 75 | 无等级、无重置 | 每秒按火附着层数造成 5% 攻击力伤害 |
| `unending` | 不息 | 75 | 无等级、无重置 | 沿用既有常驻被动定义 |
| `passive_vitality` | 坚韧体魄 | 75 | 无等级、无重置 | 最大生命 +20，不治疗 |
| `passive_energy` | 元素储备 | 75 | 无等级、无重置 | 最大 SP +10，不立即回能 |

正式 catalog 为 `1` 个固定普通攻击 + `8` 个商店内容（四主动、四被动）；七槽严格为 A1–A3 + P1–P4，同一技能不可重复。

## 八房、路线与 Boss

| 房间 | 模板 | 敌群（生命/防御） | 敌人梦尘 | 房完成梦尘 | 总梦尘 |
|---|---|---|---:|---:|---:|
| `combat_01_entry` | `arena_flat` | `entry_guard` 70/0 | 20 | 100 | 120 |
| `combat_02_swarm` | `arena_flat` | `swarm_left` 55/0 + `swarm_right` 55/0 | 30 | 70 | 100 |
| `combat_02_pressure` | `arena_platforms` | `platform_pressure` 105/1 | 40 | 80 | 120 |
| `combat_03_layer_elite` | `arena_platforms` | `layer_elite` 145/2 | 35 | 90 | 125 |
| `combat_04_validation` | `arena_flat` | `validation_left` 75/0 + `validation_right` 75/0 | 40 | 85 | 125 |
| `combat_05_stable` | `arena_flat` | `stable_guard` 130/1 | 25 | 100 | 125 |
| `combat_05_risk` | `arena_corridor` | `risk_vanguard` 105/1 + `risk_rearguard` 105/1 | 70 | 140 | 210 |
| `combat_06_final_boss` | `arena_boss` | `final_boss_placeholder` 280/3 | 0 | 0 | 0 |

四张模板均含有效 PlayerSpawn，八房敌人出生点在可达几何内且与玩家出生点至少相隔 120 px。没有配置离店或流程隐式全恢复；跨房生命/SP 由常驻 Player 与正式被动 Runtime 保留。

| 门牌 | 安全/风险 | 模板/遭遇 | 风险层 | 梦尘差异 |
|---|---|---|---:|---:|
| `route_01_swarm` | 安全 | 平地双敌，55+55 HP | 1 | 100 |
| `route_01_pressure` | 风险 | 双层平台单重装，105 HP/1 DEF | 2 | 120（+20） |
| `route_02_stable` | 安全 | 平地单精英，130 HP/1 DEF | 1 | 125 |
| `route_02_risk` | 风险 | 狭廊双强化，210 总 HP/2 总 DEF | 3 | 210（+85） |

Boss 的 `280 HP / 3 DEF` 同时高于任一普通单体的最大值 `145 HP / 2 DEF`；Boss 敌人和房完成梦尘都精确为 `0`，其唯一 successor 是 `run_result`。

## 三条构筑预算

| 构筑 | 权威预算 | 支出 | 结论 |
|---|---:|---:|---|
| 主力主动专精 | 安全线第二商店前 345 | 元素弹 Lv2+Lv3 = 150 | 可行，余 195 |
| 多主动购买/升级 | 安全线第二商店前 345 | 回收 90 + 激光 120 + 两个 Lv2 50+65 = 325 | 可行，余 20 |
| 主动 + 四被动 | 第二商店前 345 / 安全全局 595 | 四被动 300；再加元素弹 Lv3 累计 150，总 450 | 两阶段均可行，全局余 145 |

## 两条正式完整局测量

### 总表

| 局 | 路线 | 总时长 | earned | purchases | upgrades | refunded | balance | 最终主动 | 最终 P1–P4 | 使用占比 |
|---|---|---:|---:|---:|---:|---:|---:|---|---|---|
| 安全 | `route_01_swarm → route_02_stable` | 1,992 ms | 595 | 300 | 300 | 105 | 100 | A1 元素弹 Lv3 | 燃烧 / 不息 / 坚韧体魄 / 元素储备 | 元素弹 100%（1 次） |
| 风险 | `route_01_pressure → route_02_risk` | 2,585 ms | 700 | 510 | 115 | 0 | 75 | A1 元素弹 Lv1、A2 激光 Lv2、A3 回收 Lv2 | 燃烧 / 不息 / 坚韧体魄 / 元素储备 | 元素弹 33.3%（1）、激光 66.7%（2） |

安全局购买四被动共 300；元素弹先升级至 Lv3（150），重置返还 105，再重新升至 Lv3（150），因此升级总支出 300。风险局购买回收、激光和四被动共 510，升级回收/激光至 Lv2 共 115。两局均通过正式 Shop/Overlay 按钮、正式命令和 expected revision 事务完成，无直接钱包/配装/等级写入。

### 安全局六个真实房实例

| 次序 | room_id | instance_id | 模板 | 敌数 | 房内推进时长 |
|---:|---|---:|---|---:|---:|
| 1 | `combat_01_entry` | 142438566773 | `arena_flat` | 1 | 72 ms |
| 2 | `combat_02_swarm` | 216845520795 | `arena_flat` | 2 | 6 ms |
| 3 | `combat_03_layer_elite` | 222063235006 | `arena_platforms` | 1 | 54 ms |
| 4 | `combat_04_validation` | 361230240804 | `arena_flat` | 2 | 20 ms |
| 5 | `combat_05_stable` | 371883774172 | `arena_flat` | 1 | 55 ms |
| 6 | `combat_06_final_boss` | 478905635293 | `arena_boss` | 1 | 22 ms |

### 风险局六个真实房实例

| 次序 | room_id | instance_id | 模板 | 敌数 | 房内推进时长 |
|---:|---|---:|---|---:|---:|
| 1 | `combat_01_entry` | 527643445571 | `arena_flat` | 1 | 58 ms |
| 2 | `combat_02_pressure` | 612301277427 | `arena_platforms` | 1 | 5 ms |
| 3 | `combat_03_layer_elite` | 616076153366 | `arena_platforms` | 1 | 55 ms |
| 4 | `combat_04_validation` | 765947021995 | `arena_flat` | 2 | 18 ms |
| 5 | `combat_05_risk` | 789468680582 | `arena_corridor` | 2 | 60 ms |
| 6 | `combat_06_final_boss` | 945631005256 | `arena_boss` | 1 | 26 ms |

两局每次活动房 instance ID 均不同；风险局实际覆盖全部四张 PackedScene 模板。每个敌人都由真实 `CombatReceiver.receive_hit()` 接受致命 Hit 后触发正式清房；runner 没有调用 room-complete、terminal 或 result 构造函数。Boss 前后余额不变，结果中 `pending_reward == null && shop == null`。

安全结果的“返回入口”按钮保持禁用，点击不改变 coordinator/session/revision；“开始新一局”创建新的 RunFlowCoordinator、RunSession、run ID 并清零经济/进度/四被动。风险结果后再次新开一局也完成同样 authority 重建；随后由真实 Player CombatReceiver 接受致命敌方 Hit，进入 `RUN_FAILED`，0/6、0 梦尘、无陈旧构筑。

## 产品需求 14 场景覆盖矩阵

| # | 产品场景 | 本轮/接受回归证据 | 结论 |
|---:|---|---|---|
| 1 | 单梦尘，无金币/经验/属性/遗物候选 | `02_task31_content_balance_tests.log` modes；Task27 economy；两张结果图只显示梦尘账本 | 通过 |
| 2 | 购买主动 Lv1、只扣一次、余额不足不变 | Task27 economy `11/307`；Task31 风险局正式购买回收/激光 | 通过 |
| 3 | 被动可装四槽且不能升级 | Task32 `5/173`；Task31 static + 两局 P1–P4 | 通过 |
| 4 | 主动/被动严格分区，失败无部分状态 | Task28 `6/154`；Task31 七槽精确映射和真实失败结算 | 通过 |
| 5 | 四被动各注册一次，跨房不重叠 | Task28；Task31 每房 runtime mapping 与六个不同 instance | 通过 |
| 6 | SP 事务不改成全局冷却/强制轮换 | Task27 level effects `7/86`；Task31 白名单 + 正式技能 cast | 通过 |
| 7 | 主动升级扣款、等级和累计投入原子 | Task27 economy；安全/风险局正式升级账本 | 通过 |
| 8 | 卸下/换槽/跨房保留等级且不退款 | Task28、Task29 接受 runner；Task31 跨房 snapshot/runtime 一致 | 通过 |
| 9 | 重置只返升级实付 70%，回 Lv1，防重放 | Task27；Task31 静态无套利和安全局 150→105→重升 | 通过 |
| 10 | 成长关闭但事件仍可供其他系统消费 | Task31 modes；Task27/Task29 接受事件链 | 通过 |
| 11 | 成长关闭后被动/临时效果仍工作 | Task28 runtime；Boss 图/结果显示 +20 HP/+10 SP 与四被动 | 通过 |
| 12 | 遗物资源保留但正式路线/UI/Runtime无遗物 | Task31 modes；Task29/30 回归；19 图无遗物入口/候选 | 通过 |
| 13 | 商店 UI 与权威快照一致，离店无属性草稿 | Task30 `9/172`；Task31 三商店正式按钮和精确账本 | 通过 |
| 14 | Boss 后直结算，无无效梦尘/成长奖励 | Task31 static + 两局 E2E + Boss/结果图；0+0 梦尘且 successor=result | 通过 |

## 自动化门禁与日志

### 命令顺序/结果

| 顺序 | 门禁 | 结果 | 日志 |
|---:|---|---|---|
| 1 | Godot 4.7.1 headless editor scan（冷副本第一条 Godot 命令） | exit 0 | `logs/01_initial_editor_scan.log` |
| 2 | Task32 接受基线 27 runners | 27/27；287 tests / 3338 assertions | `logs/baseline27/*.log` |
| 3 | Task31 静态内容 | 9 tests / 310 assertions | `logs/02_task31_content_balance_tests.log` |
| 4 | Task31 两条完整局 E2E | 4 tests / 447 assertions | `logs/03_task31_full_run_e2e_tests.log` |
| 5 | Task20 历史非门禁 | 7 tests / 68 assertions | `logs/04_task20_non_gate.log` |
| 6 | 正式 RunGame `--quit-after 180` | exit 0 | `logs/05_run_game_180_frames.log` |
| 7 | TestRoom `--quit-after 180` | exit 0 | `logs/06_test_room_180_frames.log` |
| 8 | 非 headless 真实 RunGame capture | 1 test / 627 assertions / 19 screenshots；exit 0 | `logs/07_task31_visual_capture.log` |
| 9 | capture 后 headless editor rescan | exit 0 | `logs/08_final_editor_rescan.log` |

### 29 个正式 runner

| runner | tests | assertions |
|---|---:|---:|
| `run_agent_d_growth_integration_tests` | 10 | 145 |
| `run_agent_d_integration_tests` | 9 | 73 |
| `run_combat_tests` | 27 | 124 |
| `run_delivery_reuse_tests` | 10 | 105 |
| `run_delivery_skill_integration_test` | 1 | 4 |
| `run_delivery_tests` | 16 | 56 |
| `run_first_batch_delivery_tests` | 26 | 163 |
| `run_growth_06_contract_tests` | 10 | 84 |
| `run_growth_contract_edge_tests` | 4 | 10 |
| `run_growth_session_isolation_test` | 1 | 5 |
| `run_growth_tests` | 25 | 155 |
| `run_hud_loadout_feedback_tests` | 13 | 113 |
| `run_passive_runtime_contract_tests` | 5 | 55 |
| `run_reward_authority_tests` | 3 | 15 |
| `run_skill_content_catalog_tests` | 11 | 231 |
| `run_skill_execution_contract_tests` | 16 | 102 |
| `run_skill_tests` | 28 | 144 |
| `run_skill_vfx_runtime_tests` | 9 | 124 |
| `run_task24_compact_hud_reward_tests` | 10 | 237 |
| `run_task25_immediate_shop_equip_tests` | 8 | 242 |
| `run_task27_run_economy_progression_tests` | 11 | 307 |
| `run_task27_skill_level_effect_tests` | 7 | 86 |
| `run_task28_seven_slot_passive_tests` | 6 | 154 |
| `run_task29_real_room_flow_tests` | 1 | 93 |
| `run_task29_run_flow_contract_tests` | 6 | 166 |
| `run_task30_run_ui_tests` | 9 | 172 |
| `run_task32_formal_four_passive_content_tests` | 5 | 173 |
| `run_task31_content_balance_tests` | 9 | 310 |
| `run_task31_full_run_e2e_tests` | 4 | 447 |
| **总计** | **300** | **4095** |

Task12/16/18/24/27 迁移数字分别保持 `13/113、11/231、9/124、10/237、11/307`。全部 35 份日志均已规范为 UTF-8/LF，CRLF 对为 0；`SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException` 的跨日志计数依次为 `0/0/0/0/0`。

### 日志 SHA-256 清单

| 相对 `logs/` 路径 | 字节 | SHA-256 |
|---|---:|---|
| `01_initial_editor_scan.log` | 72018 | `D96D765D5F1BC09726C26E7B95FB5F0662368238814B5A592690E2E4C311EDB3` |
| `02_task31_content_balance_tests.log` | 653 | `92A15EC00634DC03D97721057D34EEAD673F769A0D384981AA5FD9A45C5755AC` |
| `03_task31_full_run_e2e_tests.log` | 3744 | `DA496BCA6335D6ABF8B50187FEAF2212FF05EAAA495CB3348D5FBA0F1AB7E215` |
| `04_task20_non_gate.log` | 489 | `186A32A783294D325DD9F10827E37C682BA70933D0A1AB590DE097098A01652A` |
| `05_run_game_180_frames.log` | 156 | `2CD695EC97EF4A0B74A8FDBD5DF84ED79891B8F7118E57234292AC6C9BDBBA11` |
| `06_test_room_180_frames.log` | 156 | `2CD695EC97EF4A0B74A8FDBD5DF84ED79891B8F7118E57234292AC6C9BDBBA11` |
| `07_task31_visual_capture.log` | 332 | `D8F8B664826ED52E5AD8D52676863B549E3DFD78462D8C2B56C5CD5AC8222B56` |
| `08_final_editor_rescan.log` | 4714 | `D8B85AFE258954D2FC0D167082CA7E45D3E2D032DCF93DE842F9705F3E2DD66B` |
| `baseline27/run_agent_d_growth_integration_tests.log` | 561 | `7AA3BEC54E361F6B6D9B0096EC17AD9938C0A9AF562BBF87A743DB0129B324E4` |
| `baseline27/run_agent_d_integration_tests.log` | 521 | `2A7463427EA3A159D90D4E8B63827B43294E82B4AF69D90DF0AC35A3B85D6D17` |
| `baseline27/run_combat_tests.log` | 1272 | `7988EE1358D643FCB64E2C32897507C442B068D69F969CF0257AE6F28DD5E7F6` |
| `baseline27/run_delivery_reuse_tests.log` | 717 | `5E3A90E6F47AFB4C7C5001625A78AD95BD20213B808B13D632A1B44330F9A8B0` |
| `baseline27/run_delivery_skill_integration_test.log` | 217 | `F4AEDDEEBF9C7AACE577EC9696078386773883784141564ECBAAFB3BFE8BFFD8` |
| `baseline27/run_delivery_tests.log` | 861 | `958E28A892CF812B6563DF5EDABE0BA9903A9219CF53C59E75EC1E891D30312F` |
| `baseline27/run_first_batch_delivery_tests.log` | 1339 | `1C533F47B878A81E248B0F4E5821F2E7D448B7CBF230DE8E09910448A0AA4CCC` |
| `baseline27/run_growth_06_contract_tests.log` | 652 | `3D193213FBBD30248002AC29B130AC6314E69D4D3F137B70C8161018C3E66D73` |
| `baseline27/run_growth_contract_edge_tests.log` | 214 | `61C715027CE89C790ABD184E4F30BE69690FA558591675795E22D6F0319BDDB3` |
| `baseline27/run_growth_session_isolation_test.log` | 215 | `E8D305F980606F78DF5C68A2DD6E66DA4562EEDEDEDAE6D07BB2CCDDCE1C4A86` |
| `baseline27/run_growth_tests.log` | 1239 | `A788E09B1B1BC440BE4C5C34BD03BC4A0A315843E6A9D77B7A42465A1CC048EB` |
| `baseline27/run_hud_loadout_feedback_tests.log` | 784 | `67CEDCB7588240DC6F025125B68E4989DECC63BB5E0845B28D0DE8D4C685C28E` |
| `baseline27/run_passive_runtime_contract_tests.log` | 384 | `79755FB5A60B505E0ACC495EEEA8E89952F3DAD90106595D1733765E094D5AEB` |
| `baseline27/run_reward_authority_tests.log` | 210 | `A18EF0E6B2FBAAD1A828D4C35129DD0AFBC88E8D908627DE465B3A77BD5E30B8` |
| `baseline27/run_skill_content_catalog_tests.log` | 531 | `EB9802D0894095121B9BE329E2ECBA8D6DE1CFA74B86BC37269161905130D61C` |
| `baseline27/run_skill_execution_contract_tests.log` | 831 | `E6A7002115A505F996F1CC087B368AB50558B9D0D2471CE1C3BE41A555477049` |
| `baseline27/run_skill_tests.log` | 1501 | `7EF79CE052C50A6335C88B4429DD555D88C940D36A041F4618DFA0789EAECDCE` |
| `baseline27/run_skill_vfx_runtime_tests.log` | 569 | `383B694DD4BDB9323950E5F8AF04E6DD181C798930FD431B465457946497F4F5` |
| `baseline27/run_task24_compact_hud_reward_tests.log` | 680 | `C5C23883796497301E270AC783641B8997FCA043F4AC2B0052F97556327F9BEF` |
| `baseline27/run_task25_immediate_shop_equip_tests.log` | 562 | `2A08E02AAB66CEF74DF041E023B4EF8DF8DBDC3DC771BB9D4DDC119FC0C8D21D` |
| `baseline27/run_task27_run_economy_progression_tests.log` | 642 | `A30208B584FBADCF1E2F22C390415688112D99D65FADB0D2DB9A0F7960542923` |
| `baseline27/run_task27_skill_level_effect_tests.log` | 538 | `2108F338EA5498E2B4E7D953FD81DB40BC08FA0A39124A98EB1B392CCCCBE625` |
| `baseline27/run_task28_seven_slot_passive_tests.log` | 541 | `AB38FE9A59503DF558EE0378040FC109351125468855314F138310EF62ADC8F8` |
| `baseline27/run_task29_real_room_flow_tests.log` | 216 | `7BD4C883B5346EBFD7D9612AA3BAF531AAC120801C95353C3A61B06B0D7368CA` |
| `baseline27/run_task29_run_flow_contract_tests.log` | 500 | `3C5C7ADA0D61F8D96918E1CA0B707CC28316DEB6E280C8E5FD559E9CC675DCB9` |
| `baseline27/run_task30_run_ui_tests.log` | 563 | `1F5BDAE802F408193D3758AB222D4AE2CF413FC6157A53254BB6AB15592003A6` |
| `baseline27/run_task32_formal_four_passive_content_tests.log` | 528 | `B1C3FE6BB5A5C3BD4780421097BF9EAF2DC7CE4A03FC18255BF795A5FDC33FBD` |

## 实际 Viewport 与人工检查

所有 PNG 都由 cold copy 的 Godot 4.7.1 非 headless OpenGL 3.3 进程从正式 `scenes/run/run_game.tscn` 当前 Viewport 取得；每张保存前断言窗口/Viewport 尺寸、phase、snapshot、房间实例/模板或 Overlay kind、梦尘、七槽和被动数。PNG 转 RGB8 后以无滤波方式写出并解码逐像素 round-trip。执行者已使用原始分辨率逐张打开以下 19 张图，确认无不可恢复裁切、HUD/角色/敌人关键遮挡、几何落点错误、目标附着文字或跨房瞬时伤害残留。

| 文件 | 尺寸 | 字节 | SHA-256 | 权威状态与人工检查 |
|---|---:|---:|---|---|
| `01_safe_combat1_flat_1920x1080.png` | 1920×1080 | 71193 | `F52FE11BD467EB51477139BB81F8576D1A5C0744D09F0A440AF82FE75304E27E` | 安全战1、`arena_flat`、0被动；角色/敌人/三块 HUD 清晰 |
| `02_safe_shop1_build_1920x1080.png` | 1920×1080 | 314778 | `55EDC3672D25F09E070E306EE75454A275F2865D70950A17D3CF81FA6B99F847` | 商店1，余额45，P1燃烧；滚动区/账本/槽位在界内 |
| `03_safe_route1_swarm_1920x1080.png` | 1920×1080 | 169812 | `06672779D7C0A7A42DE796CBB5B944661022D085021748CB6C3DE34365BB2484` | 路线1聚焦 swarm，独立确认可见 |
| `04_safe_combat3_platforms_1920x1080.png` | 1920×1080 | 76565 | `F34B31C6E4D256D4A308D4B50EE85D289C6B4A513CA34EEC46485FFD2059AA50` | 安全战3、`arena_platforms`、P1持续；无旧伤害数字 |
| `05_safe_shop2_four_passives_1920x1080.png` | 1920×1080 | 337822 | `E4A10148216A3A801450B04A3B2B78A22434E3AE5A2A11DE6D704B91A9440801` | 商店2余额45，P1–P4四个不同被动全部可见 |
| `06_safe_route2_stable_1920x1080.png` | 1920×1080 | 174812 | `A8C6F8AF0A0707763107F6471CE1E8E6CDBBAEF1E4E3B03B29330AB0D88DFDF0` | 路线2聚焦 stable，风险/遭遇/环境差异清晰 |
| `07_safe_boss_1920x1080.png` | 1920×1080 | 94871 | `A9FFF30CD4CE0EFCFF21CE8446864C3FD82839B4926752BBEC360B9CF3D4785D` | Boss房、`arena_boss`、四被动、HP120/SP110、余额100冻结 |
| `08_safe_result_1920x1080.png` | 1920×1080 | 189202 | `F3A7C2DF6D8CE58CA32B5739A6592D0FC634093F43D4439142CCAD94F517B98A` | VICTORY，6/6、3/3、2/2、100余额、四被动；返回入口禁用 |
| `09_risk_new_run_flat_2560x1440.png` | 2560×1440 | 106097 | `87C29C2EBAE4A08C7017D2CAF52C9072AAB7B86919D912882133067035C50CE9` | 安全结果后的新 authority，战1/余额0/四被动清空 |
| `10_risk_route1_pressure_2560x1440.png` | 2560×1440 | 255799 | `2D3E1617195FCC43853B66ED58F2908E620362B1654A28029D89F9A6800D51CE` | 路线1聚焦 pressure，Tier2 与平台重装披露清晰 |
| `11_risk_combat2_pressure_2560x1440.png` | 2560×1440 | 117722 | `A38EA7B29128C06A00CA6A71C342877DB666797F3BBA788B97EBB8921E59B81F` | 风险战2、`arena_platforms`、A3回收；无瞬时反馈残留 |
| `12_risk_shop2_multi_active_2560x1440.png` | 2560×1440 | 488164 | `AAB72B96325DA06A28B4388B3C4D27219236BAF3ACC6F287D155CD6E3254A09B` | 商店2余额5，A1/A2/A3多主动、P1/P2被动 |
| `13_risk_route2_corridor_2560x1440.png` | 2560×1440 | 264360 | `0A2BAB4548B928EBF6A5C151CBC357534774850F63C37440FE7F66BCB2757F1B` | 路线2聚焦 risk，Tier3/双强化/狭廊/额外梦尘清晰 |
| `14_risk_combat5_corridor_2560x1440.png` | 2560×1440 | 145595 | `8B42B42AC1243A473BE35DA925E1D75F247085FAFB0558C9C1BAA7D4199483C2` | 风险战5、`arena_corridor`、双敌夹击、两主动+回收/P1–P2 |
| `15_risk_shop3_four_passives_2560x1440.png` | 2560×1440 | 508929 | `ED27D8856DBFCB69A345C497E8BA8178CB9DCDE37CA0731BDAFF666BD2FF956A` | 商店3余额75，A1–A3 + P1–P4 完整构筑、账本精确 |
| `16_risk_boss_2560x1440.png` | 2560×1440 | 160688 | `4436ED174AD66DE7366B95DD4BA6EF336DCB7AB9DFE4514B1D24A905B8C631F2` | 风险 Boss、四被动、四模板闭环、余额75冻结 |
| `17_risk_result_2560x1440.png` | 2560×1440 | 297209 | `8405387929DDD40DA9A8056F76918AA733F8FFDD1A611B23ECF80DD0F4BA108A` | VICTORY，700/510/115/0/75，三主动等级、四被动、风险路线 |
| `18_new_run_reset_2560x1440.png` | 2560×1440 | 105996 | `2541909550F7AB9734A66705BAEC9B932CBD75CEFD934AF084F75EB673A6830B` | 风险结果后第二次新 authority，0/6、0梦尘、默认 A1、P1–P4空 |
| `19_failed_result_2560x1440.png` | 2560×1440 | 252300 | `76440EF69BB9D43B8DB3E93AD3CE04CFD73F3AB15F3BE9363497E898D25AAE63` | 真实 Player receiver 失败，DEFEAT、0/6、0账本、无陈旧构筑 |

capture 开发过程中曾用“240 帧”等待瞬时反馈，在无垂直同步的图形进程中不足真实 0.86 秒，五个跨房战斗点按夹具断言失败且未写 PNG。夹具改为最多 2.5 秒真实单调时间、同时等待 HUD feedback 和 `FinalDamage` 控件清空；最终 clean capture 为 `627 assertions`、19 图，失败运行日志/图片未进入共享 evidence。

## 冷副本、共享漂移与 Git 保护

- 冷根：`C:\tmp\element-dungeon-task31-exec-20260806-01`；项目：`...\project`；独立 profile：`...\profile\Roaming` 与 `...\profile\Local`；日志工作目录：`...\artifacts\logs`。
- 该冷根在创建前不存在；复制排除 `.git/.godot/.workbuddy/cache`。首次 Godot 前源/冷副本均为 `1533 files / 45,761,395 bytes`，`only-source 0 / only-cold 0 / content mismatch 0`；冷副本 `.godot` 不存在，Task31 viewport 文件数为 0。
- 所有 Godot 命令只在上述冷项目/profile 执行；共享 Godot 进程仅被动保留，最终只读观察到 `Godot_v4.7.1-stable_win64` PID 43452 与 `godot-ai` PID 21632，未调用/控制/save/reload/reimport/run/test/capture/close。
- 共享 `.godot` 开始/结束均为 `754 files / 37,416,266 bytes / latest 2026-08-06T12:52:36.9297954Z`。
- 全部 sidecar 开始/结束均为 `537 files / 198,428 bytes / latest 2026-08-06T12:46:32.2117630Z`；其中既有未跟踪 sidecar 均为 `66 files / 28,555 bytes / same latest`。未删除、修改、认领或复制 Task31 `.gd.uid/.import` 到共享区。
- `.workbuddy/**`、`docs/架构评估与扩展性改进建议.md`、66 个既有 sidecar、两枚无关 `docs/vfx/tools/__pycache__/*.pyc` 及其他无关项全部保留。
- 最终 HEAD 仍为 `8ae7f9083b7da3d9f01b32966fa207162a623fd0`。未使用子 Agent；`git add/commit/push/reset/restore/checkout/clean/stash` 均为 0，未暂存任何文件。

## 历史阻塞记录（Task32 之前，原文保留）

以下各节记录 Task32 尚未补齐四被动时的正确结构阻塞，保留用于审计；它们不代表当前最终状态。

## 历史阻塞结论

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

## 中枢 Review 5.0 最终独立验收（2026-08-07）

Task32 前置解除后，中枢在全新 `C:\tmp\element-dungeon-task31-review5-20260806-01\project` 与独立 profile 中重新生成全部正式证据并判定 `PASS / ACCEPTED`：

- 冷复制 `1583 files / 49,970,105 bytes`，逐文件 `0 mismatch`；旧 19 张截图在首次 Godot 前移出项目。
- 首次 scan、29/29 runner（`300 / 4095`）、Task20 单列（`7 / 68`）、双 180 帧 smoke、`1 / 627 / 19` 图形 capture 和最终 rescan 全部 exit `0`；35 份 Review 日志五类错误标记全为 `0`。
- 19 张新图逐张原尺寸检查通过。唯一非阻塞观察为 `14_risk_combat5_corridor_2560x1440.png` 的 HP 面板遮住房间标题最左侧一小段；战斗控制、玩家/敌人、三主动、四被动、路线、梦尘账和结果均未受影响，作为后续 UI 抛光项记录。
- 共享 `.godot`、全部/未跟踪 sidecar、Task31 核心对象和 allowlist 外 tracked 内容在验收前后零漂移。

本 evidence 随任务31归档；Task20继续历史 `BLOCKED`。
