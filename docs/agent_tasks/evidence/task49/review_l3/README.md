# Task49 独立 L3 Review（第四次复验 PASS）

Review 日期：2026-08-13  
实际模型：`gpt-5.6-sol`  
thinking：`high`  
Review Level：`L3`  
Result：`PASS`（不自行标记 `ACCEPTED`）

本目录根层保留上一轮确定性 `FAIL` 的日志、CSV 与六图，作为不可改写的失败历史；本次正式证据位于 `rerun_02/`，并取代上一轮结论。

## 候选构造与 overlay provenance

- 当前已接受基线：`616867f9f736f53d41d4dfe9587eaee07c48070f`。
- 未直接复用执行者 `fc7b531` 冷根、`C:\tmp\element-dungeon-task49-formal-20260813-02` 或共享混合工作树。
- 第四次独立冷根：`C:\tmp\element-dungeon-task49-review-20260813-02`；独立 profile：`C:\tmp\element-dungeon-task49-review-profile-20260813-02`。
- 构造方式：从 `git archive 616867f` 解出基线，逐项覆盖 32 个最新 Task49 运行时文件及最新任务书，并显式删除旧六战 flow。相对基线 34 个状态差异全部在精确 allowlist，范围外为 0。
- `rerun_02/overlay_provenance.csv` 的 34/34 项来源与冷根 SHA-256 一致；旧 flow 删除态一致。
- 相对上一轮失败候选，运行时仅有两处窄修：Boss `display_name` 从“战 6”到“战 4”；Task49 capture 在第 5 图前仅增加 `await create_timer(1.0).timeout`。其余 30 个运行时 overlay 文件 SHA-256 不变。
- 冷根不含 `.git`，第一条 Godot 命令是 cold-first editor/import scan；冷根未带入共享用户保护项 `global_instakill`。

## 静态合同与范围结论

- 正式顺序严格为 `combat_01_entry -> combat_02_swarm -> shop_demo_mid -> combat_04_validation -> combat_06_final_boss -> run_result`，验证常量为 `4 combat / 1 shop / 0 route`。
- 旧 flow 文件不存在。对活跃 `growth/combat/scripts/scenes/resources` 的旧路径、“六战原型”、`/6`、旧结算计数复扫为 0；Task49 专项保留的 `OLD_FLOW_PATH` 仅是负向断言。
- 首房资源为 2 个初始敌人、0 援军、`single_wave=true`、`guaranteed_active_skill_reward=true`；清场不等待 reinforcement delay。
- 首箱权威候选仍限定 `reward_pool + unowned + is_active_skill()`；主动池耗尽复用类型化 `DREAM_DUST=150`；command replay 与 claimed-room 幂等保持。
- 两份 UI 均为“五阶段演示”与 `4/1/0`，通用路线面板总战斗数读取 `RunFlowDefinition.REQUIRED_COMBAT_ROOMS`。
- Boss 资源窄修仅改变玩家可见 `display_name`；`room_id`、spawn、生命、防御、位置、模板、标签与奖励未改。

## 动态矩阵

Godot：`4.7.1.stable.official.a13da4feb`。

- cold-first editor/import scan：exit `0`。
- 上一轮同等集成候选的 11-runner 直接影响域矩阵：`54 tests / 3796 assertions / 0 failures`。本轮两处窄修只有显示资源与 capture 等待，因此按 L3 规则复用。
- 本轮必要新鲜抽查：Task49 专项 `5/103`、Task30 UI `9/166`、Task41 物理波次/Boss `4/84`，合计 `18 tests / 353 assertions / 0 failures`，全部 exit `0`。
- Task49 当前 `RunGame` 完整五阶段 capture：`1 test / 6 images / 0 failures`，exit `0`。
- Task40 拖拽/紧凑 HUD/分辨率代表性 capture：`1 test / 140 assertions / 7 images`，exit `0`。
- Task41 物理波次/商店/Boss/结算代表性 capture：`10 authority-checked images`，exit `0`。
- 当前主场景独立 `--quit-after 180` smoke：exit `0`；final editor/import scan：exit `0`。

命令级结果、复用边界与日志路径见 `rerun_02/runner_summary.csv`。

## 原尺寸视觉结论

Task49 六张 `1920x1080` 图均逐张原尺寸检查：

1. 首房同屏恰好 2 个敌人。
2. 两敌被 `CombatReceiver` 清除后立即清场，宝箱出现，无援军。
3. 首箱授予未拥有主动技能并进入主动槽。
4. 两战后进入唯一商店，主体可读且无裁切。
5. Boss 图明确显示“战 4 · 占位最终 Boss · 终焉王座”，Boss 与标题均无遮挡，测试产生的 `99999` 已按生产 tween 自然消退。
6. 结算明确显示 `4/4`、`1/1`、`0/0`。

另外原尺寸抽查 Task40 的 1920×1080、1366×768、2560×1440 HUD/拖拽/商店/Boss 图，以及 Task41 的商店、低位弹体跳跃路径和结算图，未见越界、遮挡或迁移门禁削弱。全部 23 张本轮图的尺寸、bytes、SHA-256 与结论见 `rerun_02/screenshots.csv`。

## 日志、保护与可重复性

- 本轮 9 份正式日志中的 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException` 均为 0，见 `rerun_02/log_marker_summary.csv`。
- 在未放行 `C:\tmp` 写权限时，Task40/41 启动曾停在日志创建前；外层超时强制终止时工具 stdout 出现 signal 11。用可写临时 profile 立即复现出明确的冷根写权限错误；对用户已授权冷根/profile 受控放行后，同命令均快速 exit `0`。该基础设施事件没有正式候选日志，也没有用旧图替代，详情见 `rerun_02/environment_incident.md`。
- `project.godot`、`scripts/player.gd`、`scripts/enemy.gd` 精确保持 `616867f` blob `2c0714d...`、`88d7c21...`、`903044f...`。
- 冷根 sidecar 为 771→771，逐路径/bytes/SHA-256 完全一致；共享 `.godot` 1169→1169、共享 sidecar 3991→3991、共享 status 11939→11939 均精确一致。
- 外部 `godot-ai`/Godot PID `3964,16380,17624` 前后不变；Review 未连接、控制或关闭它们。
- 用户保护的共享 `global_instakill` 未复制、未验证、未修改、未认领、未作为内容写入证据；冷根路径计数为 0。
- Git 暂存、提交、push 均为 0。证据 manifest 覆盖整个 `review_l3/`（排除 manifest 自身），无 Godot sidecar。

## 最终结论与风险

`PASS`。上一轮确定性视觉阻塞已被两处授权窄修消除，静态、动态、视觉、日志、保护和共享零漂移门禁均通过。保留风险仅为本轮未机械重跑全部历史 70 图；该风险已由前轮 `54/3796` 直接 runner、当前 `18/353` 抽查、Task49 全六图及 Task40/41 共 17 张代表性 capture 覆盖。是否转为 `ACCEPTED` 仍由中枢决定。
