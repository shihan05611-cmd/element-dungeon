# Task51 执行证据

状态：`REVIEW` 候选（执行者不自行 `ACCEPTED`）  
执行日期：2026-08-13  
派发基线：`fc7b5318f3b32860ee10265c23aa1cff199e1b99`  
实际模型：`gpt-5.6-sol`，thinking=`high`

## 隔离环境

- 正式候选冷根：`C:\Users\heliashi\Documents\元素地牢-4.7\tmp\task51_validation_20260813_a\candidate_b`
- 独立 profile：`...\candidate_b_profile\Roaming` / `...\candidate_b_profile\Local`，每条正式 Godot 命令均显式设置 `APPDATA` 与 `LOCALAPPDATA`。
- Godot：`4.7.1.stable.official.a13da4feb`。
- 候选冷根由 `git archive fc7b531` 全新解包，只叠加 `scripts/enemy.gd` 与 Task51 runner；第一条 Godot 命令是 editor scan，scan 前无 `.godot`。
- 最初一次 `GODOT_USER_HOME` 隔离探测因该 Windows 构建仍访问系统 AppData 而作废；正式候选改用全新 `candidate_b` 与 `APPDATA/LOCALAPPDATA` 后从零执行。作废根没有回流共享区，也未作为正式证据。

## 精确修改

1. `scripts/enemy.gd`：Boss 专属出生 Transform 的 Y 从 `global_position.y + 84.0` 改为 `global_position.y`；水平 `±58`、方向、payload、speed、shape、mask 与生命周期均不变。
2. 新增 `combat/tests/run_task51_boss_projectile_spawn_clearance_tests.gd`：正式 Boss 房高台/真实 AI 走下高台落稳主地面 × 左右四象限，直接检查初始 layer-4 overlap、authority/可见底边净空、首物理帧实际位移与生命周期。
3. 新增该 runner 的 cold-first UID `uid://bnln7lbceavwq`。

未修改公共 `ProjectileDelivery`/sweep、弹道场景、mask/shape/speed、Boss 房、AI、玩家或 Task48/49 文件。

## 基线失败

同一最终版 Task51 runner 叠加到未修复 `fc7b531`：exit `1`，`2 tests / 92 assertions / 18 failures`。主地面左右均测得 `1` 个 layer-4 初始重叠，首帧各触发 `1` 次 blocker contact，弹体未存活、未产生期望 X 位移、累计距离为零。失败日志为 `logs/task51_baseline_failure_clean.log`，五类错误标记为零；失败来自专项断言，不是脚本/引擎错误。

## 候选结果

- Task51 专项：`2 tests / 92 assertions`，exit `0`。
- Task41：`4 / 112`，exit `0`；保留低速、既有 mask/scene 与 Boss 结算路径。
- Task43：`4 / 125`，exit `0`；Boss defeated 后节点释放且不再生成弹体。
- 公共 Delivery：`16 / 56`，exit `0`。
- Delivery reuse：`10 / 105`，exit `0`。
- Delivery/skill integration：`1 / 4`，exit `0`。
- Task34 projectile transaction：`11 / 211`，exit `0`。
- 合计直接 runner：`48 tests / 705 assertions`，全部通过。
- 正式主场景 smoke：`180` 帧，exit `0`。
- Boss 房场景 smoke：`180` 帧，exit `0`。
- initial/final editor scan：均 exit `0`。

Task51 四个候选射击均为：初始 layer-4 overlap `0`；circle radius `13`、blocker mask `4`、hurtbox mask `16`、speed `255`；`centerY + 13 < supportTop` 且 `centerY + 15.04 < supportTop`；首 physics frame 存活、X 位移为 `255 / physics_ticks_per_second`（容差 `0.08`）、Y 不漂移、累计距离大于零；之后正常 hit/block 且只 finish 一次。

## 日志、sidecar 与风险

- `logs/` 保存 baseline failure 与 11 份正式候选日志；`log_marker_summary.csv` 对 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全部计数为 `0`。
- 冷根相对 HEAD 的非 `.godot` 新文件只有 Task51 runner 和 cold-first `.gd.uid`；共享区未回流 `.godot`、`.import` 或 `.translation`。
- 共享 `scripts/enemy.gd` 在落笔前 SHA-256 为 `C519...ECCF`，候选为 `6482...4719`，且与正式冷根一致。弹道场景与 Boss 房哈希继续精确等于 Task50 记录。
- Task49 正在修改 Task41/43 的五阶段流程断言，因此 Task51 没有使用共享中间态；Task41/43 回归来自固定 `fc7b531` 冷根，避免并发候选混入。Task48/49 与 Task51 修改文件无重叠。
- 残余风险：本任务未增加截图 capture；四象限的真实物理几何、可见 alpha 底边数值、首帧运动和两个 180 帧 smoke 已直接覆盖冻结缺陷。最终视觉接受仍由独立 L2 Review 决定。
- Git 写操作为零；未连接、关闭或控制共享 Godot/editor/godot-ai。

