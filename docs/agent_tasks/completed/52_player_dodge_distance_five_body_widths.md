# 任务 52：玩家闪避距离调整为 5 身位

状态：ACCEPTED
负责人：独立执行任务（中枢派发）
依赖：任务 48（ACCEPTED，提交 `616867f`）
Git 基线：`main` HEAD `616867f9f736f53d41d4dfe9587eaee07c48070f`
Execution Model：`gpt-5.6-sol`
Execution Thinking：`medium`
Review Level：L2
Review Model：`gpt-5.6-sol`
Review Thinking：`medium`

升级/停线触发：5 身位导致真实碰撞 sweep 穿墙、无敌帧不能覆盖完整动作、必须修改精确 allowlist 外文件、需要改变 `CombatReceiver`/碰撞层/输入/时长/冷却/公共接口，或共享 `global_instakill` 无法与 Task52 精确分离时，立即停线回传并升级，不得自行扩域。

## 1. 用户冻结需求

将 Task48 已接受闪避的开放地面距离从玩家碰撞体水平完整宽度的 `1.5` 倍调整为 `5.0` 倍。

除距离外保持 Task48 全部既有合同：`0.18s` 动作、动作结束后 `0.55s` 冷却、方向选择、完整动作无敌、穿敌不穿墙、真实 `move_and_collide`、碰撞 mask 保存/恢复、输入和动作门禁、透明度表现及所有中断清理均不得改变。

## 2. 实现口径

1. 仅将 `PlayerCharacter.DODGE_DISTANCE_IN_BODY_WIDTHS` 从 `1.5` 改为 `5.0`。
2. 现有 Task48 专项已经按该常量计算期望距离，同步仍写死“1.5 body widths”的断言说明；敌人仍固定在起点右侧 `35px`，原“动作结束仍占据敌人体空间”只适用于 1.5 身位，迁移为“完整位移未被敌体截断且终点越过敌人中心”。不得移动夹具敌人、放宽 `2%` 距离容差或削弱墙体门禁。
3. 不修改 Task48 已归档任务书；Task48 保留当时接受的历史事实，新的距离合同由 Task52 记录。
4. 不新增输入、资源、sprite、残影系统、位移算法或兼容参数。

## 3. 精确 allowlist

1. `scripts/player.gd`
2. `combat/tests/run_task48_dodge_integration.gd`
3. `docs/agent_tasks/pending/52_player_dodge_distance_five_body_widths.md`
4. `docs/agent_tasks/evidence/task52/**`

其余文件全部只读。`combat/tests/capture_task48_dodge_visuals.gd` 可原样运行，不得修改。

## 4. 范围污染与候选构造（强制）

- 当前共享 `scripts/player.gd` 与 `project.godot` 含用户独立实现、明确归属于用户的未提交 `global_instakill`；对应 runner/UID 同属该用户修改，不属于 Task48/52。它们必须保留在共享工作区，但不得进入 Task52 候选、evidence、allowlist、暂存或后续提交。
- 执行验证必须从固定基线 `616867f` 的纯 Task48 文件构建安全隔离候选，只覆盖上述 Task52 两处修改；不得从共享 live 工作区整文件复制 `scripts/player.gd`。
- 正式候选全树搜索 `global_instakill|GLOBAL_INSTAKILL` 必须为 0；`project.godot`、`CombatReceiver`、`scenes/player.tscn` 与基线 blob 必须一致。
- 回写共享 `scripts/player.gd` 时只做常量单行编辑，保留共享 `global_instakill` 每一处既有内容不变。执行者不得删除、修改、测试、解释或认领该功能。

## 5. L2 验收

执行者在安全隔离候选中至少运行：

1. Task48 专项，证明开放地面左右方向均为 `5.0` 身位且原容差不放宽；
2. 敌体穿越与墙体提前截断，证明高速位移仍使用真实 sweep、不穿墙；
3. 完整动作伤害拒绝、冷却、mask 与中断恢复原门禁；
4. 原 Task48 capture 或等价单组实际动作视觉 smoke，确认动作仍可读、结束恢复；无需新增正式截图，除非现有 capture 失败或视觉不可读；
5. 主场景短 smoke 与日志五类标记检查。

独立 L2 Review 重点复核精确 diff、纯候选 provenance、Task48 专项结果、墙体碰撞和共享污染隔离；只有触发升级条件才转 L3，不默认重建第二套发布级冷根。

## 6. 禁止项与交付

- 不修改 `project.godot`、`CombatReceiver`、`scenes/player.tscn`、Task48 归档/evidence、输入、时长、冷却、碰撞层或视觉资源。
- 不触碰 Task49、Task20、共享 `.godot`、translation/import、中文保护文档或其他未跟踪产物。
- 不连接、关闭、重启或控制共享 Godot/editor/godot-ai。
- 不执行 `git add/commit/push/reset/restore/checkout/clean/stash`，不自行 `ACCEPTED`。
- 完成后状态更新为 `REVIEW`，回填修改、候选构造、tests/assertions、日志、保护哈希和共享单行回写证明，然后冻结并自动回传中枢。

## 7. 执行阻塞回填（2026-08-13）

- 实际模型：`gpt-5.6-sol`；推理等级：`medium`。按 L2 执行，未读取 `REVIEW_L3_PLAYBOOK.md`。
- 已按冻结范围完成两处实现：共享 `scripts/player.gd` 只将 `DODGE_DISTANCE_IN_BODY_WIDTHS` 从 `1.5` 改为 `5.0`，完整保留用户独立实现的 `global_instakill`；`combat/tests/run_task48_dodge_integration.gd` 只把断言说明 `1.5 body widths` 同步为 `5.0 body widths`，期望计算、`2%` 容差及其他门禁未改。
- 正式隔离候选：`tmp/element-dungeon-task52-exec-20260813-02`；独立 profile：`tmp/element-dungeon-task52-profile-20260813-02`。候选由固定 Git 对象 `616867f9f736f53d41d4dfe9587eaee07c48070f` 导出，只叠加上述两处修改。因该基线的 Task48 历史归档/evidence 自身包含 3 个用于审计旧污染事故的字面量，导出时仅排除那 3 个非运行时历史文件，使正式候选全树 `global_instakill|GLOBAL_INSTAKILL` 命中为 0；共享 Task48 历史归档未修改。
- 候选相对同一过滤基线只变更 `scripts/player.gd` 与 `combat/tests/run_task48_dodge_integration.gd`。`project.godot`、`combat/components/combat_receiver.gd`、`scenes/player.tscn` 的 blob 分别为 `2c0714d6b08e04ea69b3d697b2540e53d875259f`、`11a724c3854bb06540c50ad55d79b909f289681b`、`e1d8819a402391c336b79d3854186c6fe50fbdda`，均与固定基线一致。
- Task48 专项正式结果：`5 tests / 55 assertions / 1 failure / exit 1`；日志五类标记 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。其余 `54/55` 通过，包括开放地面按常量完成 5 身位、完整 DODGED 伤害拒绝、冷却、墙体提前截断、真实 `move_and_collide`、mask 与中断恢复及动作门禁。
- 唯一失败为既有门禁 `player occupies enemy body space without disabling world collision`：夹具把敌人固定在起点右侧 `35px`，但 5 身位完整位移会越过敌人并停在更远处，因此动作结束时不再与敌人体重叠。若要让专项全绿，必须修改该冻结门禁或测试布置；任务明确禁止修改其他门禁，故立即停线，未改算法/接口/其他文件，未继续 capture 或主场景 smoke。
- 首次沙箱内 cold import exit 0，但因沙箱拒绝读取 Windows 根证书库产生 1 条环境级 `ERROR:`，仅作诊断且不进入正式成功证据。随后专项在沙箱外使用同一隔离候选/profile 运行，五类日志标记为 0。
- 保护对账：Task48 归档 blob `cdfa268e054125b975dd2901fc03028698cfcae3` 与基线一致；共享 `project.godot` 未触碰；未读取、修改、运行或认领用户的 `global_instakill` runner/UID。Git 写操作为零；未 add/commit/push/reset/restore/checkout/clean/stash。
- 详细证据见 `docs/agent_tasks/evidence/task52/README.md`。任务冻结为 `BLOCKED`，等待中枢决定是否授权调整冲突测试门禁。

## 8. 中枢测试合同对齐（2026-08-14）

- 中枢确认唯一失败是旧 1.5 身位夹具语义：敌人在起点右侧 `35px`，5 身位闪避正确完成完整位移后必然不再与其重叠；前置断言已证明敌体未截断真实移动。
- 授权仅将该终点重叠断言改为终点越过敌人中心，并保留敌人位置、按常量计算的开放距离、`2%` 容差、真实 sweep、墙体截断、无敌帧及 mask 恢复全部门禁。生产范围不扩大，Review Level 保持 L2，任务恢复执行。

## 9. 对齐后执行交付（2026-08-14）

- 按中枢授权，仅将失败断言从“动作结束仍占据敌人体空间”迁移为 `player.global_position.x > enemy.global_position.x`，即完成 5 身位后终点越过敌人中心。敌人仍固定在起点右侧 `35px`；前置完整期望距离断言、`2%` 容差、墙体截断、真实 sweep、i-frame、mask 与中断门禁均未修改。
- 生产仍只有 `scripts/player.gd` 的常量单行 `1.5 -> 5.0`；测试相对 `616867f` 只有两处合同文字/断言迁移。正式候选和独立 profile 继续使用 `tmp/element-dungeon-task52-exec-20260813-02` 与 `tmp/element-dungeon-task52-profile-20260813-02`。
- Task48 专项全量：`5 tests / 55 assertions / 0 failures / exit 0`。开放地面左右 5 身位、敌体不截断且终点越过敌人、墙体提前截断、完整 DODGED 拒伤、冷却、真实 `move_and_collide`、mask/中断恢复与动作门禁全部通过；五类日志标记全 0。
- 原 Task48 非 headless OpenGL capture：`1 test / 3 images / 0 failures / exit 0`；五类日志标记全 0。三张 `1920x1080` 原图逐张复核：ready 清晰，mid 玩家透明且已穿过敌人，recovered 位于敌人另一侧并恢复不透明，动作起止可读。
- 正式主场景短 smoke：`180 frames / exit 0`；五类日志标记全 0。
- 最终保护对账：候选 `rg -uuu -i global_instakill` 全树命中 `0`；`project.godot`、`CombatReceiver`、`scenes/player.tscn` blob 继续与 `616867f` 一致。共享 `scripts/player.gd` SHA256 `1E821B9DE4BC341F5DE23910FBA5C26DB3C964D0FDCEA5629E06D3899C8AA093` 与恢复执行前一致，用户 `global_instakill` 原样保留；共享 `project.godot` 未触碰，相关 runner/UID 未读取、修改、运行或认领。
- Task48 历史归档 blob `cdfa268e054125b975dd2901fc03028698cfcae3` 与基线一致。Git 写操作为零；未 add/commit/push/reset/restore/checkout/clean/stash，也未连接、关闭、重启或控制共享 Godot/editor/godot-ai。
- 详细结果与截图哈希见 `docs/agent_tasks/evidence/task52/README.md`。状态更新为 `REVIEW`，执行者冻结，不自行 `ACCEPTED`。

## 10. 独立 Review 回填（L2，2026-08-14）

- Review 实际模型：`gpt-5.6-sol`；推理等级：`medium`；结论：`PASS`。本结论不等于 `ACCEPTED`，任务状态继续保持 `REVIEW`，最终接受由中枢决定。未读取 `REVIEW_L3_PLAYBOOK.md`。
- 精确 provenance 通过：过滤基线根的 `player.gd` / Task48 runner blob 分别与 `616867f` 的 `88d7c21...` / `11a2da8...` 一致；候选 source overlay 仅为生产常量 `1.5 -> 5.0` 及 runner 的说明文字、终点越过敌人中心两项合同迁移。敌人仍在起点右侧 `35px`，`2%` 容差及其他门禁未改。
- 独立复跑 Task48 专项 `5/55/0`，覆盖左右 5 身位、敌体穿越、墙体提前截断、完整 i-frame、真实 sweep、mask/中断恢复；直接 combat 回归 `27/124/0`；主场景 `180 frames / exit 0`。三份正式日志五类标记均为 0。
- 复用冻结的三张 `1920x1080` capture 并逐张原尺寸检查：ready 清晰不透明，mid 透明且已越过敌人，recovered 在敌人另一侧恢复不透明；动作起止可读。
- 候选全树 `global_instakill|GLOBAL_INSTAKILL` 命中 0；`project.godot`、`CombatReceiver`、`scenes/player.tscn` blob 与 `616867f` 一致。共享 `scripts/player.gd` SHA256 `1E821B9D...A093` 与执行冻结记录一致；未读取、修改或运行用户 runner/UID，未控制共享 Godot/editor/godot-ai。
- 隔离根内 `.godot/**` 与三张重新生成的 Task48 PNG 记为运行产物，不属于 Task52 source overlay，且未回流共享项目。未发现高速穿墙、算法/接口扩域、随机不稳或候选运行时污染，无 L3 升级信号。
- Review evidence：`docs/agent_tasks/evidence/task52/review_l2/`。Git 写操作为零；Review 完成后冻结，等待中枢接受决定。
- 独立 L2 Review 结论：`PASS`。独立复跑 Task48 专项 `5 tests / 55 assertions / 0 failures`、直接 combat 回归 `27/124/0`、主场景 180 帧 smoke exit 0；三份日志五类标记全 0。既有三张 1920×1080 capture 原尺寸检查通过。完整证据见 `docs/agent_tasks/evidence/task52/review_l2/`。

## 11. 中枢接受与归档（2026-08-14）

- 中枢采纳独立 L2 的 `PASS`，Task52 更新为 `ACCEPTED` 并归档。
- 接受范围严格为 `DODGE_DISTANCE_IN_BODY_WIDTHS 1.5 -> 5.0`，以及现有 Task48 runner 的说明文字和终点穿敌合同迁移；时长、冷却、真实 sweep、完整 i-frame、墙阻挡、mask/中断恢复、输入、视觉和公共接口均保持不变。
- 用户独立 `global_instakill` 不属于 Task52；共享版本保持原样，Task52 候选、evidence 和 Git 检查点均排除该功能。
