# Task34 最终执行证据

记录日期：2026-08-07（Asia/Shanghai）

状态：`REVIEW`。当前权威交付来自第四个全新接替对话，已修复中枢第 16 节独立冷副本发现的普通 projectile median 不足，并从零重做全部门禁；等待中枢独立验收，本对话未自行标记 `ACCEPTED`。

## 第四次接替权威索引

- 总结：`fourth_replacement_review.md`
- 性能：`fourth_replacement_performance_summary.md`
- 功能矩阵：`fourth_replacement_validation_matrix.md`
- 冷副本：`fourth_replacement_cold_copy_environment.md`
- Viewport：`fourth_replacement_viewport_review.md`
- allowlist/保护：`fourth_replacement_allowlist_protection.md`
- 原始材料：`fourth_replacement_final_artifacts/`（185 logs、3 CSV、6 PNG）
- 清单：`fourth_replacement_before_manifest_sha256.txt`、`fourth_replacement_after_manifest_sha256.txt`、`fourth_replacement_artifacts_sha256.txt`、`fourth_replacement_modified_files_sha256.txt`、`fourth_replacement_delivery_sha256.txt`
- 当前结果：Task34 专项 `11/211`；正式基线 `29/29 = 300/4095`；Task20 `7/68`；projectile median 改善 `22.979%`、p95 改善 `5.444%`、build 下降 `96.694%`；五类日志关键字均为 0。

以下各节与第三次接替文件保留此前历史执行记录，用于解释中枢退回链；第四次接替结论以上述权威索引为准。

## 第二次接替历史结论（已被第 14 节 Review 退回）

- 零 collision mask 兼容修补后的首项复验 `run_delivery_reuse_tests.gd`：`10 tests / 105 assertions`，通过。
- Task34 专项：`10 / 159`；7 个直接 runner：`16/56`、`26/163`、`16/102`、`1/4`、`11/231`、`9/124`、Task27 `7/86`，全部通过。
- 完整 Task31 接受基线：`29/29 runners = 300 tests / 4095 assertions`，全部从零重跑通过。
- Task20 历史非门禁：`7/68`，单列通过，不改变其历史状态。
- RunGame 与 TestRoom 各 180 帧 smoke，均 exit 0。
- 实际 Windows Viewport 覆盖 Fury enemy contact、wall first、empty range；每种均为实际 `1920×1080` 和 `2560×1440` PNG，六张图逐张检查无遮挡。
- 初始 after/before scan 与最终 after rescan 均为 Godot `4.7.1.stable.official.a13da4feb`、exit 0。
- 全部 186 份最终日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 计数分别为 `0 / 0 / 0 / 0 / 0`。
- 普通 projectile 的 `5 warmup + 30 measured` 双侧交错复测满足全部性能门禁：scratch 下降 `96.694%`，median 改善 `15.163%`，p95 改善 `14.377%`。

## 公共合同和迁移

- `ProjectileSweepProfile2D` 统一 shape、速度、射程、hurtbox/block mask、margin 和 wall tie；普通 projectile 与 Fury 共用 `resources/combat/element_projectile_sweep_profile.tres`。
- `ProjectileSweepRequest2D`、`ProjectileSweepResult2D`、`ProjectileSweepQueryPort2D` 提供类型化同步首接触查询；`PhysicsProjectileSweepQuery2D` 是 Godot Physics adapter。
- `SkillExecutor.try_cast(skill, slot_id)` 是公共入口。生产客户端 `._try_cast_configured` 调用数为 0；仅 `SkillExecutor` 内部保留私有实现与公共包装。
- Fury 顺序为：基础校验 → snapshot/等级效果锁定 → sweep → enemy impact 锁定 → 离树 prepare/validate Delivery → 二次提交校验 → SP/冷却/状态提交 → 成功事件 → Delivery 接树。
- 普通 projectile 的旧零 mask 纯表现 fixture 仍兼容；Fury 继续独立要求两个正式 mask 大于 0。
- 两个受影响旧 runner 相对派发 HEAD 的 `_run(...)` 注册变化为 0、断言行变化为 0。完整逐项迁移见 `fury_assertion_migration.md`。

## Fury 事务结果

专项将拒绝归为五类：

1. no contact / empty range；
2. blocker / wall first / wall tie；
3. invalid caster 或 world context；
4. query failed；
5. Delivery prepare 失败或提交父节点失效。

五类均验证拒绝后 SP、冷却、CurrentElement、phase、成功事件、成功 VFX、真实飞行 Node、爆发 Delivery 为精确零变化。成功路径只在 enemy contact 接受：全 SP 一次提交、锁定 impact、1 个爆发 Delivery、0 个隐形飞行 Node、一次命中窗；真实专项 `real_fury_hits_once_without_flight_node` 通过。

## 冷副本与原始材料

- final after：`C:\tmp\element-dungeon-task34-final-after-20260807-01`
- final before：`C:\tmp\element-dungeon-task34-final-before-20260807-02`
- 双侧独立 profile：`C:\tmp\element-dungeon-task34-final-{after|before}-profile-20260807-0{1|2}`
- 原始 artifacts：`C:\tmp\element-dungeon-task34-final-artifacts-20260807-01`
- `before-20260807-01` 是一次 Unicode tar 展开失败的未使用目录；未参与任何正式命令、样本或结论。
- 持久化 artifacts：`final_artifacts/`，包含 186 logs、2 CSV 和 6 PNG；不包含两份临时基线 archive。
- before HEAD manifest：`before_head_manifest_sha1.txt`（1518 entries；文件 SHA-256 `A35DE9DA1F895685D2278C523A17D1BA1A176BD9C25CEBAC63F1BBBD605C821C`）。
- final-after source manifest：`after_final_manifest_sha256.txt`（1611 entries；文件 SHA-256 `42D985AFC6027CDADD74016D30A7DF6DCDB6F4EB01F622A73C92DCDA6762EE6C`）。
- 37 项 Task34 实现/测试 SHA-256：`modified_files_sha256.txt`，最终复算 `37/37` 存在、`0` mismatch。
- 完整交付 SHA-256：`delivery_files_sha256.txt`，覆盖上述 37 项、Task34 任务书和本 evidence 目录全部文件（manifest 自身除外）。

环境和复制核对见 `cold_copy_environment.md`；性能原始值见 `performance_summary.md`；29-runner 逐项见 `validation_matrix.md`。

## Viewport 说明

第一次捕获暴露 project 默认 fullscreen 使 `window_set_size()` 无效：两组初稿均为显示器物理 `3840×2160`，2560 组顶部信息被裁切，因此不作为最终视觉证据。allowlist 内 capture runner 增加切换 windowed 后重新捕获；最终六图物理尺寸与目标尺寸逐一相等，`save_error=0`。

- enemy contact：`accepted=true`、`reason=none`、`SP=0`、`impact=(760,684)`，绿色成功/锁定反馈。
- wall first：`accepted=false`、`reason=no_legal_target`、`SP=20`、`impact=none`，只有失败反馈且无成功残影。
- empty range：同样保持 `SP=20`、`impact=none`，无成功残影。

最终 capture log 为 `final_artifacts/16b_task34_viewport_capture_final.log`；六图在 `final_artifacts/viewport-final/`。初稿过程记录保留在 `16_task34_viewport_capture.log`。

## 隔离、保护与 Git 声明

- 所有 Godot 命令只在上述新 `C:\tmp` 冷副本和独立 profile；从未运行、控制或关闭共享 Godot/editor/godot-ai。
- 共享 Godot PID `43452`、godot-ai PID `21632` 在最终审计仍为同一原进程。
- 最终共享 HEAD 仍为 `102720086c53a84901b788726ad609d15263d64a`。
- Task34 实现/测试变化均在任务书第 5 节 allowlist；新增/更新 evidence 仅在 `docs/agent_tasks/evidence/task34/**`；状态更新仅在 Task34 任务书。
- `.godot`、全部 sidecar、`.workbuddy`、VFX `__pycache__`、架构建议文档和中枢文件的最终聚合值与接替前基线一致。
- 未执行 `git add/commit/push/reset/restore/checkout/clean/stash/apply` 等任何 Git 写操作；未修改或启动 Task35～37。

## 上下文压力

派发为 `GREEN`；本接替对话在全部正式输入已完整读取、阶段事实已固化后发生一次 `contextCompaction`，因此最终为 `YELLOW`。没有发生第二次压缩；未触发强制 `BLOCKED` 条件。
