# 任务 33：整体架构与性能重构实现契约

状态：ACCEPTED

负责人：关卡流程与系统架构职责对话（threadId `019fc6a1-3fa9-7bb1-8ae7-1f289485b8fb`，hostId `local`）

依赖：任务 31、32 已 `ACCEPTED`；任务 20 继续保持历史 `BLOCKED`

回传中枢：临时中枢（threadId `019fd661-a35e-7732-b295-e70ee42afb69`，hostId `local`）

## 1. 任务定位

本任务只产出下一轮整体架构与性能重构的可执行契约，不修改游戏代码、场景、资源、测试或正式资产。

目标不是按文件机械拆小，而是同时回答并冻结三层问题：

1. 当前单元是否单一职责、高内聚、低耦合，只通过稳定输入输出交互，不共享可变状态，且可独立测试、替换和复用；
2. 已经高内聚的单元能否继续拆成拥有清晰权威、事务、查询与适配器边界的系统；
3. 每个系统是否存在可量化、更高效且不改变行为的实现方式。

契约通过后，中枢按依赖串行派发任务 34～37。实现任务必须产生可复验的性能改善；除第 3 节冻结的元素爆发释放语义外，任何可观察玩法、数值、事件顺序、revision、UI 状态、存档迁移和关卡流程都不得变化。

## 2. 用户冻结目标

### 2.1 整体架构

- 每个模块只承担一个明确职责；领域权威、事务协调、空间查询、表现适配和 UI 展示不得混为一个权威。
- 模块之间只依赖稳定的类型化命令、查询、结果、不可变快照、事件或 Port；不得读取或调用对方私有字段/私有方法。
- 避免跨系统共享可变 `Dictionary`、静态 Node、UI 草稿或可被外部就地修改的集合。
- 关键单元必须能以 fake/stub Port 独立测试，且替换具体物理查询、表现或持久化适配器不改变领域规则。
- 最终沉淀统一的“如何搭建游戏 XX 系统”结构：权威与生命周期、输入命令/查询、不可变输出、事务边界、端口/适配器、确定性测试、性能预算和接线示例。

### 2.2 性能与行为约束

- 每个实现任务必须在其派发基线建立前测和后测；不能仅以“代码更整洁”或理论复杂度声称优化。
- 同一 Godot 4.7.1、同一硬件、同一独立 profile、相同固定输入下，记录确定性操作计数/构建计数，并以多轮计时作为辅助证据。
- 新实现至少在目标热路径上证明更少的线性扫描、重复对象构建、物理查询、跨节点动态查找或每帧无效 UI 写入；不得以增加常驻轮询或无界缓存换取局部加速。
- 所有既有正式门禁保持：`29/29 runners、300 tests / 4095 assertions`；Task20 `7/68` 继续单列且不计入正式门禁；RunGame/TestRoom 各 180 帧 smoke；涉及表现时补充真实 Viewport。
- 行为不变必须核对返回值、失败原因、能量/冷却、命中目标与顺序、伤害/附着、事件顺序与次数、revision、快照字段、存档迁移、六战/三商店/两路线/Boss 直结算，而不只看 runner 退出码。

## 3. 本轮唯一允许改变的玩法：元素爆发

不再增加“同一水平攻击带内选择水平距离最近敌人”的目标选择规则，也不创建真实的超高速隐形 Node 飞行物。

冻结为同步高速隐形弹道/形状扫掠：

- 从施法者按现有飞行物的发射方向、射程、碰撞层、敌我合法性与墙体阻挡规则发起一次确定性查询；不自动转向、不选择最近敌人。
- 若首个有效接触是合法敌方 Hurtbox，则在该命中点产生一次现有元素爆发范围效果。
- 若射程内没有合法敌人、先接触阻挡物、施法者/上下文失效或查询失败，则整次施法拒绝。
- 拒绝时不扣法力、不进入冷却、不生成爆发、不播放成功 VFX/成功事件；成功时才原子提交资源、冷却、执行快照与爆发。
- 同一输入的接触排序必须稳定；弹道查询与爆发范围均以逻辑形状为权威，VFX 不得决定命中。
- 必须复用或抽取现有飞行物规则的公共类型化查询契约，不能复制一套与 `ProjectileDelivery` 日后漂移的碰撞规则。

除上述语义外，元素爆发的伤害倍率、全能量消耗、锁定元素、附着层数、范围倍率、一次爆发命中窗和现有成功反馈保持不变。

## 4. 必须完成的只读审计

至少审计以下高风险区域及其调用者、测试与资源接线：

- `combat/components/skill_executor.gd` 与 `combat/execution/**`；
- `combat/delivery/**`，重点是 `projectile_delivery.gd`、Fury/Beam/Reclaim；
- `combat/content/run_content_catalog.gd` 及内容消费者；
- `growth/run_session.gd`、`growth/contracts/run_snapshot.gd`、`growth/flow/run_flow_definition.gd`；
- `scripts/run_session_host.gd`、`scripts/run/run_flow_coordinator.gd`、`scripts/player.gd`；
- `scripts/vfx/reclaim_vfx_port.gd` 与相关表现事件；
- 任务 14、15、26～32 的正式契约、测试入口和接受事实。

交付必须提供：

1. 现状模块/依赖图和循环依赖表；
2. 超大类、超长方法、私有实现穿透、共享可变状态、重复构建/线性扫描/动态查找清单；
3. 每项问题的证据路径、调用关系、风险等级、行为不变难度与预期性能收益；
4. 明确列出本轮不做的低收益/高风险重构，避免无边界扩张。

## 5. 目标依赖方向与稳定接口

契约必须给出唯一目标依赖图，至少满足：

- 通用契约层不得反向依赖 Growth、UI、VFX 或具体 Node 实现。
- Combat 与 Growth 之间不互相持有对方内部实现；跨域只通过明确的内容读取接口、不可变快照、命令结果或宿主适配器交互。
- `Player`、`RunSessionHost` 和 VFX 只消费公共入口/事件，不调用 `_try_cast_configured`、读取 `_target_plans`/`_receiver_ref` 或其他私有状态。
- 领域权威不执行表现，不让 VFX/UI 的失败回滚玩法事务。
- 缓存必须由单一拥有者维护，并有 revision/失效规则、容量边界和测试替代方案；禁止全局可变缓存。

## 6. 高优先级串行实现图

任务 33 必须把下列草案收敛为可直接派发的正式任务 34～37；允许依据审计合并、缩小或调整顺序，但不得删除性能前后测、行为不变门禁与元素爆发唯一变更。

### 任务 34：战斗查询与施法事务

- 抽取现有飞行物的类型化、确定性同步查询契约与物理适配器。
- 元素爆发使用“预检命中 → 成功才提交法力/冷却 → 命中点爆发”的原子流程。
- 清除 Player 对 SkillExecutor 私有入口的直接调用；公共入口不得暴露内部计划。
- 用 fake 查询端口独立覆盖命中敌人、无命中、墙先命中、相同距离稳定排序、上下文失效和成功行为保持。
- 前后测至少量化 Node 生成/生命周期、物理查询次数、候选排序/扫描次数和批量施法耗时。

### 任务 35：内容目录编译与跨域解耦

- 将静态内容校验与运行时查询分离；只读 catalog 在构建阶段编译为稳定 O(1) 索引，消除高频 `content_for` 线性扫描。
- 拆除 Combat→Growth→Combat 的类型/实现环；定义最小只读内容接口或中立契约，保持全部技能、价格、奖励投影、等级效果与校验结果不变。
- 缓存/索引不得允许消费者修改底层数组或 Dictionary；重复构建、重复 id、非法引用继续得到原有可观察结果。
- 前后测至少量化不同 catalog 规模下的查找比较次数、构建次数、查询耗时与内存/容量边界。

### 任务 36：RunSession 与流程读取模型拆分

- 保留 RunSession 为唯一局内权威，但将经济/配装/流程等事务按稳定协作者拆分，避免一个类承担所有规则与组装。
- 以 revision 为失效条件缓存不可变 RunSnapshot/派生读取模型，避免同一 revision 重复全量构建；调用者不得修改缓存内容。
- RunFlowDefinition 在构建/验证阶段编译节点索引，避免重复线性查找，且保持所有拒绝原因、路线、防重放和场景失败语义。
- 前后测至少量化同 revision 快照构建次数、节点查找比较次数、整局典型查询耗时和缓存失效正确性。

### 任务 37：集成边界收口、最终回归与系统模板

- 将 Host、Player、FlowCoordinator、VFX 的剩余私有字段穿透替换为公共类型化事件/Port；不改变接线顺序与成功反馈。
- 只在前项证明必要时拆分巨型集成类；不为了文件行数移动代码。
- 汇总全轮前后性能证据、全量回归和实际整局不变性；确认没有无界缓存、共享可变状态或新循环依赖。
- 新增可复用的“游戏系统搭建模板/检查表”，至少用技能系统和局内流程系统各做一个映射示例，能指导后续 XX 系统的 Authority、Command/Query、Snapshot/Result、Port/Adapter、Lifecycle、Test 与 Performance Budget。

## 7. 任务拆分交付要求

对任务 34～37，每项都必须在契约中写出：

- 依赖和唯一负责人职责对话；
- 精确到文件/目录的 allowlist，以及后项覆盖前项同一文件时的串行原因；
- 明确禁止/保护文件；
- 当前公共 API、目标公共 API 与迁移步骤；
- 权威、事务边界、失败原子性、事件顺序与缓存失效规则；
- 前测/后测固定数据集、预热/重复次数、确定性计数、辅助计时与通过阈值；
- 专项测试、正式 29-runner、smoke、必要的实际 Viewport 和整局 invariance gate；
- 冷副本/独立 profile、共享工作区不变性、证据路径与自动回传格式。

不得并发派发会修改相同文件或互相依赖公共 API 的实现任务。

## 8. “如何搭建游戏 XX 系统”沉淀结构

契约必须定义一个可复用模板，至少包含：

1. 系统意图、唯一权威和生命周期；
2. 输入 Command/Query 及结构化拒绝；
3. 不可变 Snapshot/Result/Event；
4. 领域事务、提交点和通知顺序；
5. 外部 Port 与具体 Adapter；
6. 配置编译、索引、缓存和失效；
7. 确定性、幂等、重放和失败恢复；
8. 单元/契约/集成/E2E/视觉测试金字塔；
9. 热路径、复杂度、分配和生命周期预算；
10. 接线示例、替换示例和禁止依赖清单。

该模板要能直接复制后填写，而不是只写抽象原则。

## 9. 允许修改范围

- 新增 `docs/design/元素地牢_架构性能重构实现契约.md`
- `docs/agent_tasks/pending/33_architecture_performance_refactor_contract.md`
- 可选新增 `docs/agent_tasks/evidence/task33/**`，仅存放静态依赖/复杂度/性能测量设计清单，不得放共享项目运行产物

`docs/agent_tasks/README.md` 由中枢维护，不属于执行者 allowlist。

## 10. 禁止事项

- 不得修改任何 `.gd`、`.tscn`、`.tres`、`project.godot`、图片、VFX、测试或正式资产。
- 不得修改已归档任务、任务 20、既有设计输入、当前玩法交接稿或未跟踪架构建议文档。
- 不得运行共享 Godot 编辑器/MCP，不得触发 save/reimport/reload/scan；本纯文档任务不需要 Godot。
- 不得执行任何 Git 写操作，不得自行标记 `ACCEPTED`，不得创建子 Agent。
- 不得以 ECS/全局事件总线/Service Locator/新 Autoload 作为默认答案；确有必要必须证明收益、生命周期和测试替代。
- 不得改变元素爆发之外的玩法，也不得把 UI 巨类或 Task20 纳入本轮核心实现。

## 11. Review 门禁

中枢独立 Review 至少核对：

1. 三层问题均有代码证据和目标边界，不是按目录给泛化建议；
2. 任务 34～37 每项可独立派发、可测量、allowlist 无未解释并发重叠；
3. 每项都有前后性能证据与行为不变矩阵，且性能指标不会诱导篡改玩法；
4. 元素爆发语义完整覆盖命中、未命中、墙阻挡、法力/冷却原子性、稳定排序和 VFX 边界；
5. 目标依赖图消除已识别循环和私有实现穿透，不引入新双权威/共享可变状态；
6. 系统模板可直接复用，并由技能/流程两个不同系统验证适用性；
7. 本轮明确延期项合理，整体范围能够串行收敛。

任一门禁失败则退回本职责对话修订文档；中枢不替执行者修改正式交付。

## 12. 基线与保护项

- 派发基线：`HEAD 102720086c53a84901b788726ad609d15263d64a`，message `task31: validate complete run content`。
- 当前正式回归：`29/29 runners、300 tests / 4095 assertions`；Task20 单列 `7/68`。
- 保护且不得删除、修改、认领或暂存：`.workbuddy/**`、所有 `*.gd.uid`、`*.import`、`docs/vfx/tools/__pycache__/**`、`docs/架构评估与扩展性改进建议.md`、共享 `.godot/**` 及所有来源无关未跟踪内容。
- 共享 Godot/editor/godot-ai 进程保持被动，不得控制或关闭。

## 13. 自动回传

完成后只把状态更新为 `REVIEW` 并冻结继续写入，然后直接调用 `send_message_to_thread` 回传临时中枢：threadId `019fd661-a35e-7732-b295-e70ee42afb69`、hostId `local`。

回传必须包含：

- 修改文件及 SHA-256；
- 现状依赖/职责/性能问题摘要；
- 目标依赖图和稳定接口摘要；
- 任务 34～37 的负责人、依赖、精确 allowlist、性能门禁和 invariance gate；
- 系统模板结构；
- 明确延期项、风险和 Git 零写入声明。

如阻塞，改为 `BLOCKED` 并立即自动回传精确阻塞点；不要等待用户转述。回传后保持冻结，等待中枢独立 Review。

## 14. 执行侧交付（2026-08-07）

本职责对话已在第 9 节 Markdown allowlist 内完成任务 33，现置 `REVIEW` 并冻结继续写入，未自行标记 `ACCEPTED`。

### 14.1 上下文压力审计

- 当前职责对话因本轮发生一次 context compaction，评级为 `YELLOW`；无未决旧任务，任务书自包含，且执行前已重新完整读取任务书及权威输入，因此本次纯文档契约继续完成。
- 实现契约已为 Task34～37 分别冻结派发前 `GREEN/YELLOW/RED` 复核：历史职责名称不能直接授权复用；YELLOW 的跨域、高风险或大量代码任务默认使用全新接替对话；RED 禁止复用。
- 未修改 `docs/agent_tasks/CENTRAL_REVIEW_RULES.md`，也未扩大任务 33 allowlist。

### 14.2 修改文件

- 新增 `docs/design/元素地牢_架构性能重构实现契约.md`：57,713 字节，834 行，SHA-256 `DC35FF1D7323635FBD66E81B8DF3BC4F3F39CE00ABF597F50EDE761BF7BE9CFD`。
- 更新本任务书：状态改为 `REVIEW` 并追加本交付记录；最终 SHA-256 由冻结后的自动回传给出，避免自引用改变哈希。
- 未创建可选 `docs/agent_tasks/evidence/task33/**`；全部静态审计、依赖图、复杂度与性能测量设计已直接收敛在正式契约。

### 14.3 审计结论与目标边界

正式契约以代码路径和调用关系确认：

- Player 调用 SkillExecutor 私有施法入口，并在资源/冷却接受后按 Fury/Beam 具体 snapshot 分支创建 Delivery；
- ProjectileDelivery 的 swept shape、稳定候选排序和墙 tie 规则被锁在 Node 私有实现，Fury 不能复用；当前 Fury 以施法者位置直接建范围爆发且没有目标预检；
- RunContentCatalog 高频线性扫描、重复投影/校验并在校验中实例化 Delivery，同时形成 Combat/Growth 内容类型环；
- RunSession 同 revision 重复构造完整快照，RunFlowDefinition 运行期线性查节点；
- 正式遗物停用时 Host 仍每帧 advance 并构造结果/快照，Coordinator 换房扫描子树；
- Reclaim VFX 通过 `_target_plans`/`_receiver_ref` 私有反射读取领域事务。

目标方向是 Composition 一次编译 → Combat/Growth 各自只读 Port → 领域 Authority → 不可变 Result/Snapshot/Event → Host/Player adapter → UI/VFX。RunSession 与 SkillExecutor 分别保留单一领域权威；不引入 ECS、全局事件总线、Service Locator、新 Autoload、全局可变缓存或第二事务权威。

### 14.4 Task34～37 串行实施图

| 任务 | 唯一职责 | 依赖 | 核心性能证明 |
| --- | --- | --- | --- |
| 34 | Combat Execution & Delivery：公共 cast、共享 projectile sweep、Fury 预检和预提交 Delivery | Task33 ACCEPTED | 普通 projectile 同 trace 下 query scratch 构建至少降 95%、median 至少改善 10%；Fury 拒绝 0 飞行/爆发 Node |
| 35 | Content Catalog & Cross-domain：一次编译、双只读 Port、中立 activation kind | Task34 ACCEPTED | 100000 查询由源数组 O(N) 扫描降为常数 index probe，median 至少改善 20%，运行期 delivery 校验实例化 0 |
| 36 | Growth & Run Flow：纯 planner、revision 快照缓存、compiled flow index | Task35 ACCEPTED | 同 revision RunSnapshot 构建 ≤1；flow lookup 常数；读取 median 至少改善 30%、流程至少 20% |
| 37 | Integration/VFX Closure：Host typed API、Beam prepare、Reclaim 公共表现快照、有界房间 Delivery registry、模板 | Task34～36 ACCEPTED | 正式 disabled advance/result/snapshot、子树清理扫描、私有动态 get、post-commit Delivery instantiate 均为 0；固定 trace median 至少改善 10% |

所有逐路径 allowlist、新脚本相邻 UID 规则、禁止路径、API 迁移、失败原子性、专项 fixture/seed/次数/阈值、runner/smoke/Viewport 和自动回传格式分别冻结在正式契约第 7～10 节。第 11 节逐项解释 Player、Executor/Services、RunSession/Inventory、Host/Coordinator 及受影响回归 runner 的串行重叠，唯一顺序为 `34 → 35 → 36 → 37`。

### 14.5 元素爆发与不变量

- Fury 沿正式元素弹相同方向、shape、射程 `850`、collision masks `8/4`、margin `0.01`、wall tie `0.02` 做同步查询，不选最近敌人、不创建隐形飞行 Node。
- 只有首个合法敌方 Hurtbox 接触才锁定命中点并准备原范围 Delivery；miss、wall first、range、invalid context、query/preparation failure 均在提交前拒绝。
- 拒绝的 SP、冷却、元素、execution state、成功 event/VFX 和 Delivery Node 变化均为 0；成功后的伤害倍率、全 SP、元素量、radius scale、等级倍率与一次命中窗不变。
- 除该语义外，3+4、单梦尘、主动等级/70% 返还、成长/遗物停用、命中事件顺序、revision/重放/存档/UI、六战/三商店/两路线/Boss 直结算全部列入逐字段 invariance matrix。

### 14.6 性能与回归合同

- 每个实现任务使用同一 Godot 4.7.1、同一硬件、before/after 两个全新冷副本和独立 profile、相同 runner/fixture SHA、seed 与输入顺序；各 5 次预热、30 次交错正式测量。
- 确定性计数是主证据，median/p95 为辅助；每项都有缓存/索引/registry 容量上界，禁止无界缓存、常驻轮询或减内容/敌人/VFX/断言换性能。
- 正式历史门禁保持 29 runners、`300 tests / 4095 assertions`；只允许登记并替换直接依赖旧 Fury 语义的断言，不得删除或放宽其他断言。Task20 `7/68` 继续单列。
- 每项均含 RunGame/TestRoom 双 180 帧 smoke；Task34、37 要求真实 Viewport，Task35、36 无可见变化时不强制新 capture；Task37 再完成安全/风险路线各一局的真实六战 E2E 和两档关键画面。

### 14.7 系统模板与延期项

正式契约第 12 节提供可直接复制的 10 节模板：意图/唯一权威/生命周期、Command/Query、不可变输出、事务/通知、Port/Adapter、编译/索引/缓存、确定性/幂等/恢复、测试金字塔、性能预算、接线/替换/禁止依赖；第 13 节已用技能施法和局内流程完成两个填写示例。Task37 将其独立沉淀为 `docs/design/元素地牢_游戏系统搭建模板.md`。

本轮明确延期 UI 巨类全面拆分、Task20、角色成长/遗物启用、数值/敌人/Boss/流程再平衡、全仓路径搬迁、ECS/全局框架及没有本轮性能证据的 AI/渲染/音频/存档优化。

### 14.8 执行声明

- 只做静态读取和两份允许 Markdown 的补丁写入；未运行或控制 Godot/editor/godot-ai，未运行游戏、测试、scan、smoke 或 capture。
- 未使用子 Agent，未执行任何 Git 写操作。
- 共享 `CENTRAL_REVIEW_RULES.md`、README、`.workbuddy/**`、全部 sidecar、`.godot/**`、`__pycache__/**`、`docs/架构评估与扩展性改进建议.md` 及来源无关改动均未触碰。

## 15. 中枢独立 Review（2026-08-07）

结论：`PASS / ACCEPTED`。

- 中枢逐段完整读取 834 行实现契约和本任务书，并重新读取实际代码，而非直接采信执行侧摘要。
- 独立确认现状证据成立：Player/SkillController 生产调用者穿透 SkillExecutor 私有施法入口；Player 在 Fury/Beam 已接受后才实例化具体 Delivery；ProjectileDelivery 的 swept-shape、稳定 ID 排序与墙 tie 规则不可复用；Catalog 线性查询和运行校验实例化、RunSnapshot 重建、Flow 节点线性查找、正式遗物禁用空转与 Reclaim 私有反射均存在。
- Task34～37 的 41 个既有实现路径和 22 个既有测试路径全部存在；新增路径、相邻新 `.gd.uid`、串行重叠和禁止范围均逐项明确。唯一实施顺序为 `34 → 35 → 36 → 37`。
- 四项任务均冻结同 fixture before/after、确定性计数、5+30 交错计时、容量上界与性能失败即阻塞；Fury 行为变化没有被当成普通 projectile 的等价性能收益，Task34 另以普通 projectile 同 trace 的 scratch/elapsed 改善证明性能。
- 元素爆发唯一新语义完整：沿现有元素弹 profile 同步扫掠，不选最近敌人、不建隐形飞行 Node；miss、wall first、range、invalid context、query/prepare failure 全部在提交前拒绝且不扣 SP、不进冷却、不发成功事件/VFX；成功后的全 SP、倍率、附着、半径和一次命中窗保持。
- 29 个正式 runner `300/4095`、Task20 单列 `7/68`、双 smoke、必要 Viewport、两条六战 E2E、revision/存档/事件/UI/3+4/单梦尘不变量均已进入后续硬门禁。系统模板具备可复制的十节结构，并以技能施法和局内流程两个不同系统验证。
- 任务 33 是纯文档合同，按任务书无需运行 Godot、runner、smoke 或 capture；共享游戏文件、Godot/editor、sidecar、保护项和 Git 均未被执行者修改。

上下文压力纠正：执行侧回传称本轮一次 `contextCompaction`、评级 `YELLOW`，但中枢读取完整最新回合确认 Task33 期间实际发生两次 `contextCompaction`。按 `CENTRAL_REVIEW_RULES.md §4.1`，该职责对话在交付时升级为 `RED / 禁止复用`。本次文档因任务书自包含且已由中枢独立复核而仍可接受；该原对话不得承接 Task34～37，后续高风险实现必须使用全新接替对话并重新读取正式任务书。

Task33 现归档；Task34 可在建立正式任务书、全新执行对话和派发前基线后串行开始。
