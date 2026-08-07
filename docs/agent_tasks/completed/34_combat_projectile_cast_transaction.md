# 任务 34：战斗弹道查询与元素爆发原子施法事务

状态：ACCEPTED（2026-08-07 中枢第五套独立冷副本验收通过；Task35～37 继续冻结）

负责人：第四个全新 `Combat Execution & Delivery Contract Agent` 接替对话（threadId `019fdb2f-e40c-7342-bac9-3ede45d8af21`，hostId `local`）

依赖：任务 33 已 `ACCEPTED`；任务 20 继续保持历史 `BLOCKED`

回传中枢：临时中枢（threadId `019fd661-a35e-7732-b295-e70ee42afb69`，hostId `local`）

## 1. 任务定位

本任务是架构性能重构串行链 `34 → 35 → 36 → 37` 的第一项，只负责：

1. 将正式元素弹私有的 swept-shape 接触规则抽为稳定、类型化、可 fake 的同步查询 Port；
2. 让普通元素弹继续消费同一套方向、逻辑形状、射程、碰撞层、稳定排序与墙优先规则；
3. 把元素爆发改为提交前同步预检，只有首个合法敌人命中才扣 SP、进冷却并在命中点爆发；
4. 将 Fury Delivery 的实例化/配置提前到提交前，消除已接受后才可能失败的创建；
5. 新增公共 `SkillExecutor.try_cast`，清除生产 Player/SkillController 对私有 `_try_cast_configured` 的依赖；
6. 在普通 projectile 等价输入上证明确定性计数和实际耗时改善。

不得并发启动 Task35～37。Task34 只有经中枢独立 Review `ACCEPTED` 后，Task35 才能立项。

## 2. 权威输入与用户决定

必须完整读取：

1. `docs/agent_tasks/CENTRAL_REVIEW_RULES.md`
2. `docs/agent_tasks/completed/33_architecture_performance_refactor_contract.md`
3. `docs/design/元素地牢_架构性能重构实现契约.md`，重点第 0、4、5、6、7、11、15 节
4. 已归档任务 14、15、18、27、31 及对应相关 evidence
5. 本任务全部既有 allowlist 文件及其直接调用者

用户唯一允许的玩法变化：

- 元素爆发不选择最近敌人，不自动转向。
- 沿当前正式元素弹的发射方向、圆形逻辑 shape、射程、hurtbox/block masks、margin、wall tie 与合法目标规则做一次同步高速扫掠。
- 首个有效接触是合法敌方 Hurtbox 时，才在该接触点产生现有范围爆发。
- 未命中、墙先命中、超距、施法者/世界上下文失效、查询失败或交付准备失败时整次拒绝。
- 拒绝不扣 SP、不进冷却、不改变 CurrentElement/执行态、不发成功事件、不建爆发 Node、不播成功 VFX。
- 不创建真实隐形飞行 Node。

除上述成立条件和爆发位置外，Fury 的最低 SP、全 SP 消耗、伤害倍率、接受时等级效果、锁定元素、附着量、半径倍率、一次命中窗、成功事件和成功表现不变。

## 3. 上下文压力与负责人

- 原任务 33 架构职责对话在同一任务中发生两次 `contextCompaction`，已被中枢标记 `RED / 禁止复用`。
- Task34 是高风险核心代码任务，只允许派发到全新、无历史任务的接替对话；已创建 threadId `019fda65-793f-75a2-b4d7-5ece2a8496ea`、hostId `local`。
- 派发前审计：该对话为全新创建、无旧 turn、无 compaction、无未决任务，只承载本任务，且正式任务书可独立重建全部事实，评级 `GREEN / 可派发`。
- 执行期间若连续压缩、出现职责混淆或旧事实覆盖正式任务书，立即置 `BLOCKED` 回传；不得依靠摘要猜测继续。
- 执行对话不得使用子 Agent。

## 4. 权威、接口与事务顺序

### 4.1 单一权威

- `SkillExecutor` 继续是释放接受、SP、冷却、执行状态和成功通知的唯一权威。
- `ProjectileSweepQueryPort2D` 只回答同步空间查询，不扣 SP、不进冷却、不创建 Delivery、不发玩法事件。
- `CombatSkillDeliveryAdapter` 只负责预提交实例化/配置和提交后接树，不拥有命中或资源规则。
- Player/SkillController 只调用公共施法入口，不按 Fury 具体类型自行决定事务。
- VFX 只消费提交后事件；表现失败不得逆转玩法事务。

### 4.2 目标公共接口

至少建立等价类型化合同：

```text
ProjectileSweepProfile2D
ProjectileSweepRequest2D
ProjectileSweepResult2D
ProjectileSweepQueryPort2D.query_first_contact(request)
SkillDeliveryPreparePort.prepare(snapshot, spawn_snapshot)
SkillExecutor.try_cast(skill, slot_id)
```

`ProjectileSweepResult2D` 必须结构化区分 enemy contact、blocker、no contact、invalid context 和 query failed；同输入接触顺序稳定。

正式元素弹 profile 迁移前后逐字段保持：圆形 shape、`speed=720`、`max_distance=850`、hurtbox mask `8`、block mask `4`、margin `0.01`、wall tie `0.02`。Fury 与正式元素弹引用同一权威 profile，不复制一套常量。

### 4.3 Fury 唯一事务顺序

```text
基础配置/控制/槽位/元素/SP/冷却校验
→ 锁定 CastSnapshot 与等级效果
→ 同步 projectile sweep
→ 仅 enemy contact 锁定 impact_position
→ 离树 instantiate 并完整 validate/configure Fury Delivery
→ 再次检查提交前不变量
→ 提交预备外部事务
→ 扣 SP
→ 写冷却、元素和执行态
→ 发布原有 accepted/started/activated/success 事件
→ 把已准备 Delivery 接入有效父节点并在命中点触发一次爆发
```

所有可预见失败必须在提交点前完成。若 SceneTree/父节点上下文在最终提交窗口失效，必须映射为提交前拒绝；不得出现已扣 SP 但没有爆发的路径。

### 4.4 普通 projectile 不变量

- initial overlap、cast/rest/probe、稳定 ID 排序、墙与敌距离比较、wall tie、友军/非法 receiver、max distance、命中点、finish reason、signal 和池化清理保持。
- 查询 scratch 每个活动 adapter/Delivery 私有且有界，逐次完整覆写；不得静态共享或跨局残留。
- 不得减少物理查询覆盖、候选上限或碰撞层来达成绩效。

## 5. 精确 allowlist

### 5.1 既有实现

- `combat/components/skill_executor.gd`
- `combat/components/skill_controller.gd`
- `combat/execution/skill_execution_services.gd`
- `combat/execution/skill_execution_commit_transaction.gd`
- `combat/execution/all_energy_burst_execution.gd`
- `combat/execution/all_energy_burst_execution_snapshot.gd`
- `combat/delivery/projectile_delivery.gd`
- `combat/delivery/projectile_delivery.tscn`
- `combat/delivery/element_rage_delivery.gd`
- `combat/delivery/element_rage_delivery.tscn`
- `scripts/player.gd`
- `scripts/vfx/skill_vfx_coordinator.gd`，仅允许保留/追加 execution services Port 接线，不得重构 VFX
- `scenes/element_projectile.tscn`
- `resources/skills/elemental_fury.tres`
- `resources/content/skills/elemental_fury_content.tres`

### 5.2 新增契约、适配器与资源

- `combat/definitions/projectile_sweep_profile_2d.gd`
- `combat/definitions/projectile_sweep_profile_2d.gd.uid`
- `combat/contracts/projectile_sweep_request_2d.gd`
- `combat/contracts/projectile_sweep_request_2d.gd.uid`
- `combat/contracts/projectile_sweep_result_2d.gd`
- `combat/contracts/projectile_sweep_result_2d.gd.uid`
- `combat/ports/projectile_sweep_query_port_2d.gd`
- `combat/ports/projectile_sweep_query_port_2d.gd.uid`
- `combat/targeting/physics_projectile_sweep_query_2d.gd`
- `combat/targeting/physics_projectile_sweep_query_2d.gd.uid`
- `combat/ports/skill_delivery_prepare_port.gd`
- `combat/ports/skill_delivery_prepare_port.gd.uid`
- `combat/contracts/prepared_skill_delivery_transaction.gd`
- `combat/contracts/prepared_skill_delivery_transaction.gd.uid`
- `scripts/combat_skill_delivery_adapter.gd`
- `scripts/combat_skill_delivery_adapter.gd.uid`
- `resources/combat/element_projectile_sweep_profile.tres`

只有本节明确列出的新 `.gd.uid` 可由本任务独立 Godot 4.7.1 profile 生成并纳入交付；所有既有 `.gd.uid` 继续受保护。

### 5.3 测试与证据

- `combat/tests/run_task34_projectile_cast_transaction_tests.gd`
- `combat/tests/run_task34_projectile_cast_transaction_tests.gd.uid`
- `combat/tests/run_task34_performance_tests.gd`
- `combat/tests/run_task34_performance_tests.gd.uid`
- `combat/tests/capture_task34_fury_trajectory_visual.gd`
- `combat/tests/capture_task34_fury_trajectory_visual.gd.uid`
- `combat/tests/run_delivery_tests.gd`
- `combat/tests/run_first_batch_delivery_tests.gd`
- `combat/tests/run_skill_execution_contract_tests.gd`
- `combat/tests/run_delivery_skill_integration_test.gd`
- `combat/tests/run_skill_content_catalog_tests.gd`
- `combat/tests/run_skill_vfx_runtime_tests.gd`
- `combat/tests/run_task27_skill_level_effect_tests.gd`
- `docs/agent_tasks/pending/34_combat_projectile_cast_transaction.md`
- `docs/agent_tasks/evidence/task34/**`

除 `evidence/task34/**` 外，不存在目录级通配授权。

## 6. 明确禁止与保护

- 禁止修改 `project.godot`、Player 场景、其他技能/Delivery、Growth/RunSession、UI、正式伤害/SP/冷却/等级数值、图片、Task20、历史任务/evidence。
- 禁止修改 `scripts/element_projectile.gd`；若实现证明基类迁移必须触及它，置 `BLOCKED` 向中枢申请，不得自行扩 allowlist。
- 禁止新增最近敌人、自动瞄准、水平攻击带、真实隐形飞行物、全局事件总线、Service Locator、Autoload 或全局可变缓存。
- 禁止删除、覆盖、认领或暂存 `.workbuddy/**`、既有 `*.gd.uid`、`*.import`、`.godot/**`、`docs/vfx/tools/__pycache__/**`、`docs/架构评估与扩展性改进建议.md` 及来源无关内容。
- 禁止控制、关闭或使用共享 Godot/editor/godot-ai 做保存、reload、reimport、scan、runner、smoke 或 capture。
- 禁止执行 `git add/commit/push/reset/restore/checkout/clean/stash/apply` 等 Git 写操作；不得自行 `ACCEPTED`。

## 7. 性能前后测 `perf_projectile_cast_v1`

### 7.1 固定环境

- before 为 Task34 派发代码基线 `HEAD 102720086c53a84901b788726ad609d15263d64a`；after 为 Task34 最终实现。
- before/after 各使用此前不存在的 `C:\tmp` 冷副本和独立 profile；逐文件核对复制，排除 `.git/.godot/.workbuddy/cache`。
- 两侧第一条 Godot 命令均为 Godot 4.7.1 headless editor scan。
- 使用同一 benchmark runner 字节/SHA、seed `4107`、fixture 和输入顺序。新增 runner 必须写成 before/after 双兼容，不得在 before 静态引用不存在的新类导致 parse failure。
- 同一硬件、电源模式、Godot 可执行文件和进程参数；5 轮预热 + 30 轮正式交错测量，保留每轮 CSV/log、median 和 p95。
- 确定性计数是主证据，elapsed 为辅助；输出 trace 不等价的样本无效，Fury 明确变化单独登记。

### 7.2 固定样本

`projectile_step_reuse`：200 个普通 ProjectileDelivery，每个 60 个固定无接触/最终接触 step，共 12000 step；命中、距离、finish trace 前后逐项相同。

`fury_atomic_batch`：enemy first、wall first、no contact、equal-distance stable tie 各 1000 次，共 4000 次；只量化新语义的查询、Node 和事务成本，不用语义差异冒充普通 projectile 性能收益。

主计数：Physics 查询参数对象构建、shape/cast/rest/probe 次数、候选扫描/排序比较、Node instantiate/add/free、拒绝后 Delivery 数。

### 7.3 通过阈值

- Fury 所有拒绝路径真实飞行 Node和爆发 Delivery 均为 0；成功路径无隐形飞行 Node且只有 1 个爆发 Delivery。
- 普通 projectile 接触结果逐项相同，每 step 物理查询、候选扫描和排序比较不得增加。
- 查询参数 scratch 从随 step 构建降为每个活动 adapter 最多 4 个；12000-step 总构建数至少减少 95%，回收后无跨局残留。
- `projectile_step_reuse` median 至少改善 10%，p95 不得回退超过 10%。
- 若确定性计数达标但实际 median 未达 10%，仍视为性能门禁失败并 `BLOCKED`，不得以架构整洁替代。

## 8. 行为与自动化门禁

专项至少覆盖：

- fake query Port：enemy、miss、wall、tie、invalid caster/world、query failure；
- delivery prepare failure、父节点失效、nested cast、成功 impact lock；
- 真实 Physics：普通 projectile 与 Fury 共 profile，墙 tie 必须墙胜；
- Fury 成功的原伤害、全 SP、锁定元素、附着量、radius scale、等级倍率和一次窗口；
- 所有 Fury 拒绝的 SP/冷却/CurrentElement/phase/event/VFX/Node 精确 0 变化；
- Player 与 SkillController 生产调用公共 `try_cast`；生产 `scripts/**` 对 `_try_cast_configured` 静态调用为 0；
- `SkillExecutionServices` 更新单个 Port 不覆盖其他已配置 Port；
- 普通 projectile reuse/cleanup、finish reason 和信号顺序不变。

正式回归：

- 复跑任务 31 接受基线的 29/29 runner、`300 tests / 4095 assertions`。只有直接断言旧 Fury“无目标也成功/施法者中心爆发”的断言可以逐条登记并等量替换；不得删除、跳过或放宽其他断言。
- Task20 `7/68` 单列，继续历史非门禁，不得追认。
- RunGame 与 TestRoom 各 180 帧 smoke；scan、runner、smoke、capture、最终 rescan 的 `SCRIPT ERROR / Parse Error / ERROR / WARNING / CrashHandlerException` 为 0。
- 实际非 headless Viewport 至少覆盖 enemy contact 成功、wall first 拒绝、空射拒绝；核对命中点爆发、拒绝无成功残影/反馈，且 1920×1080、2560×1440 关键信息无遮挡。

## 9. 冷副本、共享不变性与证据

- 执行前固化共享 HEAD/status、allowlist、保护项、`.godot`、全部 sidecar 和 Godot/editor 进程；执行后逐项复核零无关漂移。
- 所有 Godot 命令、benchmark、runner、smoke 和 capture 只在 Task34 全新冷副本/独立 profile。
- Evidence 至少包含 README、before/after manifest/SHA、双兼容 runner SHA、环境、5+30 原始数据、确定性计数、median/p95、行为 trace、Fury 断言迁移表、29-runner 汇总、Task20 单列、双 smoke、Viewport、日志扫描、allowlist/保护项对账和所有修改文件 SHA-256。
- 任一结构、性能、自动化、视觉或不变性门禁失败，任务不得进入 `REVIEW`；在 allowlist 内无法安全修复则置 `BLOCKED`。

## 10. 交付与自动回传

开始执行后将状态改为 `IN_PROGRESS`。全部门禁通过后只置 `REVIEW` 并冻结，不得自行 `ACCEPTED`。

完成或阻塞后直接调用 `send_message_to_thread` 回传临时中枢：threadId `019fd661-a35e-7732-b295-e70ee42afb69`、hostId `local`；不要等待用户转述。

回传必须包含：

- `REVIEW`/`BLOCKED`、上下文压力等级及变化；
- 修改文件与 SHA-256、公共 API 和迁移摘要；
- Fury 五类拒绝与成功事务结果；
- before/after 固定 fixture、确定性计数、median/p95 和容量；
- 专项、29-runner、Task20、scan/smoke/Viewport/日志统计；
- allowlist、保护项、共享 `.godot` 对账；
- 风险、Fury 断言迁移和 Git 写操作为零声明。

回传后保持冻结，等待中枢另一全新冷副本独立验收。

## 11. 执行阻塞记录（2026-08-07）

- 最终状态：`BLOCKED`。
- 阻塞原因：本执行对话在 Task34 期间发生第二次 `contextCompaction`，命中第 3 节“连续压缩立即 BLOCKED 回传；不得依靠摘要猜测继续”的强制条件。触发后已停止实现、Godot runner、smoke、capture 与性能命令，只执行只读状态固化、证据写入和中枢回传。
- 上下文压力：派发时 `GREEN`；第一次压缩后继续依据正式文件和已固化日志工作；第二次压缩后升级为 `RED / 禁止继续执行`。
- 已完成且有原始日志的阶段结果：Task34 专项 `10 tests / 159 assertions`；7 个直接受影响 runner 分别通过 `16/56`、`26/163`、`16/102`、`1/4`、`11/231`、`9/124`、Task27 `7/86`；普通 projectile 同 runner SHA 的 `5 warmup + 30 interleaved` 性能测量通过确定性与量化门禁。
- 未完成门禁：完整 29-runner 只执行到第 4 项；第 4 项 `run_delivery_reuse_tests.gd` 报告 `4 failures / 10 tests / 105 assertions`。根因是旧的纯表现测试将两个 collision mask 都设为 0，新 profile 校验使 Delivery 提前结束。allowlist 内兼容修补已落盘（普通 projectile 允许零 mask 并跳过对应 sweep；Fury 仍要求两个正式 mask 大于 0），但尚未复验。剩余 25 个 baseline runner、Task20 `7/68`、双 smoke、Viewport/capture、最终日志扫描和 after 最终冷副本均未执行。
- 性能阶段结果：seed `4107`，双兼容 runner SHA-256 `C134999607A3579F8420C0C8391AC34825ED7E4BD00C42FF45F86EB746489905`；before/after trace 均为 `67ec8c0d02b36bc5d3de4a7d5383b3d71b42d788ae5313f444487d4252b1b798`；parameter build `24200 -> 800`（下降 `96.694%`）；median `130346us -> 108219us`（改善 `16.976%`）；p95 `136364us -> 113986us`（改善 `16.410%`）。
- 冷副本：before `C:\tmp\element-dungeon-task34-before-20260807-01`；after（注意：不是兼容修补后的最终副本）`C:\tmp\element-dungeon-task34-after-20260807-02`；独立 profile 与原始日志均在对应 `C:\tmp` 路径。
- 共享保护：未运行、控制或关闭共享 Godot/editor/godot-ai；阻塞时仍为 Godot PID `43452`、godot-ai PID `21632`。未执行任何 Git 写操作，未修改 Task35～37，未自行 `ACCEPTED`。
- 详细阶段证据：`docs/agent_tasks/evidence/task34/README.md`、`performance_summary.md`、`modified_files_sha256.txt`。

## 12. 中枢阻塞审计与第二次接替（2026-08-07）

- 中枢读取前一执行线程原始最终回合，确认 `contextCompaction` 为两次，原 threadId `019fda65-793f-75a2-b4d7-5ece2a8496ea` 正确升级为 `RED / 禁止复用`；Task34 未进入 REVIEW。
- 中枢重新计算 `modified_files_sha256.txt` 的 37 项文件：`37/37` 存在、`0` SHA mismatch；Task34 实现/测试改动全部位于第 5 节 allowlist。共享 tracked 的 CENTRAL/README 变化属于中枢协调；历史 sidecar、`.workbuddy`、`.godot`、pycache 和架构建议仍是保护项。
- 精确恢复点是“零 collision mask 兼容修补已写入共享工作树，但修补后未运行任何 Godot”；旧 after 冷副本、旧专项与旧性能 after 不代表当前最终代码。
- 新建第二个全新接替对话 threadId `019fdab8-1da2-7a72-8b83-5eca4659f9c7`、hostId `local`。派发前审计：无旧 turn、无 compaction、无未决任务，仅承载 Task34，任务书/evidence 可独立重建上下文，评级 `GREEN / 可派发`。
- 接替者必须从当前共享工作树建立新的 final-after，并从同一派发 HEAD 建立新的 before；同 runner SHA/seed/fixture 重新完成 5+30 交错性能测量。不得复用旧 after 结论拼接最终 REVIEW。
- 接替者先复验零 mask 的 `run_delivery_reuse_tests`，随后完成 Task34 专项、7 个直接 runner、完整 29-runner、Task20 单列、双 smoke、真实 Viewport、最终 rescan/日志扫描、Fury 断言迁移表和共享不变性对账。
- 本次是同一任务因执行上下文压力更换负责人，不是新需求或回归任务，因此不另开任务号；Task35 仍须等待 Task34 独立 `ACCEPTED`。

## 13. 第二次接替最终执行记录（2026-08-07）

- 最终状态：`REVIEW`；等待中枢在另一份全新冷副本独立验收，不得据此启动 Task35。
- 上下文压力：派发 `GREEN`；执行中发生一次 `contextCompaction` 后为 `YELLOW`，没有发生第二次压缩，未命中强制 BLOCKED 条件。
- final after：`C:\tmp\element-dungeon-task34-final-after-20260807-01`；final before：`C:\tmp\element-dungeon-task34-final-before-20260807-02`；两侧第一条 Godot 命令均为 4.7.1 headless editor scan，均使用独立 profile。
- 同 runner SHA `C134999607A3579F8420C0C8391AC34825ED7E4BD00C42FF45F86EB746489905`、seed `4107`、相同 fixture/input 的 5 warmup + 30 measured 交错复测：trace 前后唯一相同；parameter builds `24200 -> 800`（下降 `96.694%`）；median `129815us -> 110131.5us`（改善 `15.163%`）；p95 `137523us -> 117751us`（改善 `14.377%`）。
- 零 mask 首项 `10/105`；Task34 专项 `10/159`；7 个直接 runner 全通过；完整基线 `29/29 = 300/4095`；Task20 历史单列 `7/68`；RunGame/TestRoom 各 180 帧；最终 rescan 全通过。
- 实际非 headless Viewport 最终生成 enemy contact / wall first / empty range × 1920×1080 / 2560×1440 六张正确物理尺寸 PNG，六次 save_error 0，逐图无遮挡；初次 fullscreen 尺寸无效的过程日志保留但不作为最终视觉结论。
- 186 份最终日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。旧 Fury 相关断言 `80 -> 80`，注册/断言行增删均为 0，没有删测、跳过、放宽或非 Fury 行为变化。
- 37 项实现/测试文件最终 SHA 见 `docs/agent_tasks/evidence/task34/modified_files_sha256.txt`；最终复算 `37/37`、0 mismatch。详细总包见 `docs/agent_tasks/evidence/task34/README.md`。
- 所有 Godot 只在新 C:\tmp 冷副本；未运行、控制或关闭共享 Godot/editor/godot-ai；未执行任何 Git 写操作；未修改/启动 Task35～37；未自行 `ACCEPTED`。

## 14. 中枢独立 Review 退回与第三次接替（2026-08-07）

### 14.1 独立验收中已通过的事实

- 中枢新建 after `C:\tmp\element-dungeon-task34-central-review-after-20260807-01`、before `C:\tmp\element-dungeon-task34-central-review-before-20260807-01` 及各自独立 profile；两侧第一条 Godot 命令均为 4.7.1 headless editor scan。
- Task34 专项 `10/159`；正式基线 `29/29 = 300/4095`；Task20 历史单列 `7/68`；RunGame/TestRoom 各 180 帧；最终 rescan；上述日志错误模式均为 0。
- 同 runner SHA `C134999607A3579F8420C0C8391AC34825ED7E4BD00C42FF45F86EB746489905`、seed `4107`、5 warmup + 30 measured 交错复测：trace 前后均为 `67ec8c0d02b36bc5d3de4a7d5383b3d71b42d788ae5313f444487d4252b1b798`；parameter builds `24200 -> 800`（下降 `96.694%`）；median `134220.5us -> 114673us`（改善 `14.564%`）；p95 `142503us -> 120259us`（改善 `15.609%`）。
- Fury 5 warmup + 30 measured：每样本 4000 query、2000 成功事务、2000 成功 Delivery instantiate/add、拒绝后 Delivery 0、scratch build 4；30 份 trace 唯一稳定。
- 中枢重新生成并人工打开 enemy contact / wall first / empty range × 1920×1080 / 2560×1440 六张真实 Viewport；accepted/SP/impact 与用户冻结语义一致，拒绝图无成功残影。

以上通过项不能覆盖下述结构与证据缺陷，Task34 本次独立 Review 结论仍为 `FAIL / 不得 ACCEPTED`。

### 14.2 必须修复的两个 Review 缺陷

1. **公共 Result 不是稳定输出，且泄漏跨查询共享可变状态。** `PhysicsProjectileSweepQuery2D` 将同一个 `_result: ProjectileSweepResult2D` 返回给 `ProjectileSweepQueryPort2D.query_first_contact` 的所有调用；下一次查询会原地改写上一次已返回对象。`set_no_contact()` 及当前 no-contact 快路又只改 `status/detail`，没有清空旧 `point/fraction/distance/hurtbox/receiver/stable_id`。因此调用者保留的前一结果会变化，no-contact/invalid/query-failed 还可能暴露上一敌人引用，违反用户要求的稳定输入输出、避免共享可变状态、可独立测试/替换，也违反 Task33 的 immutable Result 边界。
2. **after 主计数不是 adapter 的真实 instrumentation。** `PhysicsProjectileSweepQuery2D` 声明并导出 `query/intersect/cast/rest/probe/candidate/sort` 计数，但实现只实际增加 parameter build；benchmark 在 after 路径中按 fixture 公式覆盖其余计数，Fury 路径同样把 `metrics_snapshot()` 返回值改写成预期常量。透明公式可辅助解释 before，但不得把 after 的预期值伪装成实测主证据；实际 adapter 计数必须由真实执行路径产生，runner 不得覆盖 after metrics。

### 14.3 修复约束与最小 allowlist

第三个接替只允许修改：

- `combat/contracts/projectile_sweep_result_2d.gd`
- `combat/targeting/physics_projectile_sweep_query_2d.gd`
- `combat/delivery/projectile_delivery.gd`，仅为消费私有 hot-path scratch 所需的最小类型/API 适配
- `combat/tests/run_task34_projectile_cast_transaction_tests.gd`
- `combat/tests/run_task34_performance_tests.gd`
- `docs/agent_tasks/pending/34_combat_projectile_cast_transaction.md`
- `docs/agent_tasks/evidence/task34/**`

不得修改其他生产文件、资源、场景、Task35～37、Task20、历史任务/evidence 或保护项；若需要新增生产脚本、扩大 allowlist 或改变 frozen gameplay，立即 `BLOCKED` 回传。

修复后的硬合同：

- 公共 Port 每次返回不可被后续查询改写的稳定 `ProjectileSweepResult2D`；公开字段只读，enemy/blocker/no-contact/invalid/query-failed 各状态只携带本状态合法数据。
- 普通 projectile 热路径仍可在 `PhysicsProjectileSweepQuery2D` 内部使用私有、有界 scratch，但该 scratch 不得作为公共 Port Result 泄漏；不得引入每 step 新 Node、无界缓存或静态共享状态。
- 新增 retained-result 专项：保存第一次 blocker/enemy Result，再执行第二次不同查询，第一次的所有字段必须保持不变；enemy 后的 no-contact/invalid/query-failed 必须为 null receiver/hurtbox、stable id 0 及无陈旧 contact 数据。
- after 的 query/intersect/cast/rest/probe/candidate/sort/build 计数全部由 adapter 实际执行累加；runner 只能读取，不得覆盖。before 若无 instrumentation，可继续用明确标注的 legacy 代码公式，但前后口径、trace 与 fixture 必须可核对。
- 修复后重新建立全新 before/after 冷副本，同一更新后双兼容 runner、seed 4107、5+30 交错重测；parameter build 仍至少下降 95%，普通 projectile median 仍至少改善 10%，p95 不回退，查询覆盖/候选/排序不增加，trace 完全相同。
- 重新完成 Task34 专项、7 个直接 runner、正式 29/29=`300/4095`、Task20 `7/68` 单列、双 180 帧 smoke、真实 Viewport、最终 rescan/日志扫描和共享保护对账；不得拼接旧 cold-copy 结论。

### 14.4 上下文压力与派发

- 第二个接替对话 `019fdab8-1da2-7a72-8b83-5eca4659f9c7` 已发生一次 compaction，为 `YELLOW`；本修复触及公共契约、热路径和性能证据，属于高风险代码，按中枢规则不得继续复用。
- 第三个全新接替对话：threadId `019fdaee-3b99-7743-8139-e2a1b2688128`、hostId `local`。派发前无旧任务、无 compaction、无未决修改，仅有“等待正式派发”的准备回合；本任务书可独立重建事实，评级 `GREEN / 可派发`。
- 回传中枢仍为 threadId `019fd661-a35e-7732-b295-e70ee42afb69`、hostId `local`。执行者完成后只置 `REVIEW` 并自动回传、冻结；不得自行 ACCEPTED，不得使用子 Agent，不得执行 Git 写操作。
- 用户于 2026-08-07 更新执行优先级：Task34 完成并由中枢 `ACCEPTED` 后，Task35～37 统一冻结，不得自动立项、派发或实现；后续优先转向游戏内容，具体内容任务等待用户另行确定范围。本决定只改变后续调度，不改变 Task34 当前合同、玩法语义或验收门禁。

## 15. 第三次接替最终执行记录（2026-08-07）

- 最终状态：`REVIEW`；等待中枢在另一份全新冷副本独立验收，不得自行 `ACCEPTED`。即使中枢后续 `ACCEPTED`，Task35～37 仍按第 14.4 节冻结。
- 上下文压力：派发 `GREEN`；执行中发生一次 `contextCompaction` 后为 `YELLOW`，没有发生第二次压缩，未命中强制 `BLOCKED` 条件。
- 结构修复：公共 `ProjectileSweepResult2D` 改为 getter-only、逐调用新建的状态合法值；enemy/blocker/no-contact/invalid/query-failed 不再共享可变 Result，contactless 状态只保留合法 detail。retained-result 专项用同一 adapter 保存 blocker/enemy 后继续查询 no-contact、invalid 和真实注入的 query-failed，旧 Result 全字段保持不变且所有 contactless 引用/稳定 ID/接触数据清零。
- 计数修复：`PhysicsProjectileSweepQuery2D` 在真实 intersect/cast/rest/probe/candidate/sort 路径累加 instrumentation；after runner 不再覆盖任何 adapter metric。普通 projectile 的耗时采用默认生产热路径，随后在 `elapsed_usec` 之外以同 fixture/同对象重放一次显式 instrumentation，并只读取 adapter snapshot；Fury 的 instrumentation 在正式批次内直接启用。该分离避免诊断计数本身污染生产热路径耗时，同时保证 after 主计数全部来自真实 adapter 执行。
- final after：`C:\tmp\element-dungeon-task34-third-final-after-20260807-01`；final before：`C:\tmp\element-dungeon-task34-third-final-before-20260807-01`；两侧第一条 Godot 命令均为 4.7.1 headless editor scan，使用各自独立 profile。
- 同 runner SHA `83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`、seed `4107`、相同 fixture/input 的 5 warmup + 30 measured 交错复测：普通 projectile trace 前后唯一相同；parameter builds `24200 -> 800`（下降 `96.694%`）；median `135703.5us -> 121600us`（改善 `10.393%`）；p95 `144445us -> 131987us`（改善 `8.625%`）。
- 普通 projectile after 的真实计数向量为 query `12000`、intersect `24200`、cast `24000`、rest/probe/candidate 各 `200`、sort `0`、build/scratch `800`；before 除 build/scratch 外同向量，build `24200`，并明确标注 `legacy_code_formula`。
- Fury 5+30 的 after 30 轮 trace 与计数向量均唯一稳定：query `4000`、intersect `12000`、cast `8000`、rest/probe `4000`、candidate `5000`、sort `1000`、build/scratch `4`；enemy `2000`、blocker `1000`、miss `1000`、invalid/failed `0`、成功事务与 Delivery 各 `2000`、拒绝后 Delivery `0`。
- 零 mask 首项 `10/105`；Task34 专项 `11/207`；7 个直接 runner 全通过；完整基线 `29/29 = 300/4095`；Task20 历史单列 `7/68`；RunGame/TestRoom 各 180 帧；最终 rescan 全通过。
- 实际非 headless Windows Viewport 生成 enemy contact / wall first / empty range × 1920×1080 / 2560×1440 六张正确尺寸 PNG，六次 save_error 0；enemy accepted/SP=0/impact=(760,684)，wall/empty 拒绝保持 SP=20、impact=none，无成功残影。
- 185 份正式日志的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。详细证据见 `docs/agent_tasks/evidence/task34/third_replacement_review.md` 和 `third_replacement_final_artifacts/`。
- 第三次接替相对中枢退回点只修改第 14.3 节允许的 5 个实现/测试文件及本任务书/evidence；37 项清单中其余 32 项 SHA 不变。共享 `.godot` 仍为 `754 files / 37416266 bytes`，sidecar 仍为 `548 files / 198646 bytes`，共享 Godot PID `43452` 与 godot-ai PID `21632` 未被运行、控制或关闭。
- 未执行任何 Git 写操作；未修改或启动 Task35～37；未自行 `ACCEPTED`。

## 16. 中枢第二次独立 Review 退回与第四次接替（2026-08-07）

### 16.1 独立结论

- 中枢新建 after `C:\tmp\element-dungeon-task34-central-final-review-after-20260807-01`、before `C:\tmp\element-dungeon-task34-central-final-review-before-20260807-01`、各自独立 profile 与 artifacts；关键文件复制 SHA `0 mismatch`，同 runner SHA 为 `83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`。两侧第一条 Godot 命令均为 4.7.1 headless editor scan，exit 0、错误模式 0。
- 静态与专项确认第 14.2 节两个结构缺陷已修复：公共 Result getter-only 且逐调用新建，contactless 状态无陈旧引用；after 计数来自 `adapter_instrumentation_replay`，runner 未覆盖。Task34 专项 `11/207`、delivery reuse `10/105`，exit 0、错误模式 0。
- 中枢同 seed `4107`、相同 runner/fixture/input、5 warmup + 30 measured 前后交错复测，共 70 个有效进程；trace 前后唯一相同，query/intersect/cast/rest/probe/candidate/sort 完全等价，parameter build `24200 -> 800`（下降 `96.694%`）。
- 但 elapsed median 为 `138758us -> 129572.5us`，只改善 `6.620%`，低于冻结的 `10%` 门槛；p95 `166687us -> 164566us`，改善 `1.272%`。日志错误模式为 0。根据第 7.3 节，计数和行为通过不能替代 median 门禁，Task34 本次独立 Review 结论为 `FAIL / 不得 ACCEPTED`。
- 因性能失败已足以阻止验收，中枢没有把旧第三接替的 29-runner、smoke 或 Viewport 证据拼接为 PASS；第四接替修复后必须重新完成全部正式门禁。

### 16.2 第四接替最小范围与硬约束

只允许修改：

- `combat/targeting/physics_projectile_sweep_query_2d.gd`
- `combat/delivery/projectile_delivery.gd`，仅普通 projectile 默认热路径的最小适配
- `combat/tests/run_task34_performance_tests.gd`，只允许保持双兼容、真实计数和增加防作弊断言；不得降低 fixture、step、Physics 覆盖或把生产必要工作移出 elapsed
- `combat/tests/run_task34_projectile_cast_transaction_tests.gd`，只允许保持/加强 retained-result、计数和行为不变量
- `docs/agent_tasks/pending/34_combat_projectile_cast_transaction.md`
- `docs/agent_tasks/evidence/task34/**`

`ProjectileSweepResult2D` 的当前 getter-only、逐公共调用新建与按 status 清洗字段合同已通过，本轮不得修改或回退；不得修改其他生产文件、资源、场景、Task35～37、Task20、历史任务/evidence 或保护项。需要扩大范围时立即 `BLOCKED` 回传。

性能修复必须发生在普通 projectile 的生产默认热路径内，优先消除已证明不需要的重复状态清理、分支、跨对象 getter 或其他逐 step 开销；不得减少 initial/cast/rest/probe、候选上限、碰撞层、稳定排序、墙 tie、12000 step、敌人数量或输出校验。诊断 instrumentation 可继续显式 opt-in 并在 elapsed 外以同对象/同物理 fixture 重放，但计数必须由 adapter 的真实 Physics 调用累加，runner 只能读取。

最终必须使用修改后的同一双兼容 runner、HEAD `102720086c53a84901b788726ad609d15263d64a`、seed `4107`，在此前不存在的 before/after 冷副本与独立 profile 中重新执行 5+30 交错；trace/计数等价、build 至少下降 95%、median 至少改善 10%、p95 不回退。随后从零完成 Task34 专项、7 个直接 runner、29/29=`300/4095`、Task20 `7/68` 单列、双 180 帧 smoke、真实 Viewport、最终 rescan/日志扫描、SHA/allowlist/共享保护对账；不得拼接旧结论。

### 16.3 上下文压力与派发

- 第三个接替 `019fdaee-3b99-7743-8139-e2a1b2688128` 已发生一次 compaction，为 `YELLOW`；性能热路径仍属高风险代码，按第 4.1 节不继续复用。
- 第四个全新接替：threadId `019fdb2f-e40c-7342-bac9-3ede45d8af21`、hostId `local`。派发前仅有等待正式任务书的准备回合，无 compaction、无旧任务、无未决写入；本任务书可独立重建全部事实，评级 `GREEN / 可派发`。
- 回传中枢仍为 threadId `019fd661-a35e-7732-b295-e70ee42afb69`、hostId `local`。完成只置 `REVIEW`，失败置 `BLOCKED`，自动回传后冻结；禁止子 Agent和全部 Git 写操作。
- 用户冻结决定不变：即使 Task34 最终 `ACCEPTED`，Task35～37 也不得启动；后续优先游戏内容，等待用户另定范围。

## 17. 第四次接替最终执行记录（2026-08-07）

- 最终状态：`REVIEW`；等待中枢在另一份全新冷副本独立验收，不得自行 `ACCEPTED`。即使中枢后续 `ACCEPTED`，Task35～37 仍冻结。
- 上下文压力：派发 `GREEN`；全部正式输入、实现、性能、功能和原始 evidence 固化后发生一次 `contextCompaction`，最终为 `YELLOW`；没有第二次压缩，未命中强制 `BLOCKED`。
- 本轮只修改第 16.2 节允许的 physics adapter、ProjectileDelivery 和 Task34 专项测试。adapter 缓存 consumer 稳定配置并避免逐 step 清理不会泄漏的私有字段；Delivery 在 ready 时缓存 space state、方向、速度和射程，cleanup 完整清除。没有减少 Physics 调用、候选、排序、step、敌人或校验，没有改变 gameplay。
- `ProjectileSweepResult2D` getter-only/逐公共调用新建合同未改，SHA `B4C680EE83C240DE4D01D7BA4642417EA44D7BBC906B3A71F716C24691BDF943`；双兼容性能 runner 未改，SHA `83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`。
- final after：`C:\tmp\element-dungeon-task34-fourth-final-after-20260807-01`；final before：`C:\tmp\element-dungeon-task34-fourth-final-before-20260807-01`；两侧第一条 Godot 命令均为 4.7.1 headless editor scan、exit 0、错误模式 0，并使用独立 profile。
- seed `4107`、同 runner/fixture/input、projectile 5 warmup + 30 measured 交错共 70 个有效进程：trace 前后唯一相同；query/intersect/cast/rest/probe/candidate/sort 为 `12000/24200/24000/200/200/200/0`，前后等价；parameter build `24200 -> 800`（下降 `96.694%`）；median `143674us -> 110659us`（改善 `22.979%`）；p95 `202065us -> 191064us`（改善 `5.444%`）。after 计数来自 elapsed 外同对象/同 fixture 的真实 `adapter_instrumentation_replay`，runner 只读。
- Fury 独立 5+30 after 计数/trace 均唯一稳定：query/intersect/cast/rest/probe/candidate/sort/build/scratch=`4000/12000/8000/4000/4000/5000/1000/4/4`；enemy/blocker/miss=`2000/1000/1000`；成功事务和 Delivery 各 2000，拒绝后 Delivery 0，tie stable true。
- delivery reuse `10/105`；Task34 专项 `11/211`；7 个直接 runner 全通过；正式基线 `29/29 = 300/4095`；Task20 历史非门禁单列 `7/68`；RunGame/TestRoom 各 180 帧；最终 rescan 全通过。
- 实际 Windows Viewport 从本轮正式 after 冷副本生成 enemy contact / wall first / empty range × 1920×1080 / 2560×1440 六张正确物理尺寸 PNG，save_error 均为 0；逐图检查关键 HUD/结果可读，拒绝图无成功残影。
- 185 份正式日志中 `SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 均为 0。详细证据见 `docs/agent_tasks/evidence/task34/fourth_replacement_review.md` 和 `fourth_replacement_final_artifacts/`。
- 相对第三次冻结的 37 项实现/测试 SHA，本轮只有上述 3 项变化，正式 after 与共享冻结树 `37/37`、0 mismatch。共享 `.godot`、sidecar、HEAD、CENTRAL、架构建议和原 Godot/editor/godot-ai 进程均与接替前一致。
- 未执行任何 Git 写操作；未修改或启动 Task35～37；未自行 `ACCEPTED`。完成回传后冻结。

## 18. 中枢最终独立验收与归档（2026-08-07）

- 中枢没有复用第四接替的 cold-copy 结论，而是新建 after `C:\tmp\element-dungeon-task34-central-accept-review-after-20260807-01`、before `C:\tmp\element-dungeon-task34-central-accept-review-before-20260807-01`、各自独立 profile 与 artifacts；两侧第一条 Godot 命令均为 4.7.1 headless editor scan，exit 0、错误模式 0。同一双兼容 runner SHA 为 `83445FECF32241FA916C2B09E8C0E9F7EF968D942F1428FC0D5BFD643B3CC5D7`。
- 普通 projectile 使用 seed `4107`、同 fixture/input、5 warmup + 30 measured 前后交错，共 70 个有效进程。60 个 measured trace 唯一且前后同为 `67ec8c0d02b36bc5d3de4a7d5383b3d71b42d788ae5313f444487d4252b1b798`；query/intersect/cast/rest/probe/candidate/sort 为 `12000/24200/24000/200/200/200/0`，前后等价；parameter build `24200 -> 800`，下降 `96.694%`。
- elapsed median `150816.5us -> 121394us`，改善 `19.509%`；nearest-rank p95 `182129us -> 140537us`，改善 `22.837%`。after 计数来源为真实 `adapter_instrumentation_replay`，before 明确标记 `legacy_code_formula`；达到并超过冻结的 median ≥10%、build 降幅 ≥95%、p95 不回退门禁。
- Fury before 明确 `supported=false`；after 5 warmup + 30 measured 的 trace、status/query/Delivery 向量各自唯一。每样本 query `4000`、intersect `12000`、cast `8000`、rest/probe `4000`、candidate `5000`、sort `1000`、build/scratch `4/4`；enemy/blocker/miss=`2000/1000/1000`，invalid/failed=`0/0`；成功事务及 instantiate/add/free 各 `2000`，拒绝后 Delivery `0`，tie stable。
- Task34 专项 `11/211`、delivery reuse `10/105`；正式基线 `29/29 = 300 tests / 4095 assertions`；Task20 历史非门禁单列 `7/68`；RunGame/TestRoom 各 180 帧；最终 editor rescan全部 exit 0。
- 中枢从本轮 after 冷副本重新生成并人工打开 enemy contact、wall first、empty range × 1920×1080/2560×1440 六张 Windows Viewport。成功为 `accepted=true / SP=0 / impact=(760,684)`；wall/empty 为 `accepted=false / SP=20 / impact=none`，两档分辨率关键信息完整且拒绝图无成功残影，六图 `save_error=0`。
- 本轮 artifacts 共 144 份正式日志，`SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 匹配总数为 0。第四接替 37 项正式实现/测试清单在共享区、独立 after 和冻结 SHA 间 `37/37` 存在、`0 mismatch`；HEAD 仍为 `102720086c53a84901b788726ad609d15263d64a`。
- 共享 `.godot` 保持 `754 files / 37416266 bytes / latest 2026-08-06 12:52:36 UTC+8`；原 Godot PID `43452` 与 godot-ai PID `21632` 均仍为原进程且 Responding。所有 Godot 命令只在新 `C:\tmp` 冷副本与独立 profile；Task35～37 未启动。
- 结构复核确认公共 `ProjectileSweepResult2D` getter-only、逐公共调用新建并按 status 清洗；热路径 scratch/缓存均为 per-consumer 有界状态，cleanup 完整；Player/SkillController 使用公共 `try_cast`；Fury 仍遵循“同步 sweep → enemy impact 锁定 → 离树 prepare → 二次提交校验 → 扣 SP/冷却/状态/事件 → 接树”，没有最近敌人选择和真实隐形飞行 Node。
- 最终结论：Task34 满足结构、性能、行为不变、回归、smoke、视觉、allowlist 与共享保护门禁，状态由中枢置为 `ACCEPTED` 并归档。按用户 2026-08-07 决定，Task35～37 继续冻结；下一优先级为游戏内容，等待用户明确内容范围后另立新任务。
