# 任务 27：梦尘、主动技能等级与功能模式权威

状态：ACCEPTED  
负责人：Growth/Economy Domain Agent 2.0（threadId `019fd201-d2b5-7593-afbd-d73bd1908acf`，hostId `local`）  
依赖：任务 26 `ACCEPTED`；任务 20 继续历史 `BLOCKED`，不属于本任务基线

## 1. 目标

依据：

- `docs/design/元素地牢_局内构筑与成长机制变更需求.md`
- `docs/design/元素地牢_局内构筑与关卡流程实现契约.md`
- `docs/agent_tasks/completed/26_architecture_build_progression_level_flow_contract.md`

本任务只完成 Growth/Economy 领域首层权威：

1. 建立单一梦尘货币及守恒快照；金币不得继续作为正式局内货币。
2. 商店支持主动/被动技能购买；主动技能购买后固定从 Lv1 开始，被动技能首版无等级。
3. 主动技能可独立升级，曲线数据驱动；重置只返还累计实际升级支出的 `floor(total * 0.70)`，购买价永不返还。
4. 用开局冻结的 `DISABLED / OBSERVE_ONLY / ENABLED` 功能模式保留但关闭经验、属性成长与遗物；正式 RunGame 后续必须显式使用 `DISABLED`，本任务先完成领域合同及现有入口兼容。
5. 建立主动等级效果窄端口：施法接受时冻结等级效果，后续升级不得污染已接受执行；通用等级不得改变 SP、全局反应、冷却、槽位、范围或技能行为。
6. 所有购买、升级、重置和模式相关命令均由 RunSession 权威执行，使用 `command_id / expected_run_revision / shop_session_id`、结构化拒绝、原子提交和幂等保护；UI、本地草稿和截图不得成为权威。

本任务不实现七槽迁移、四被动 Runtime、正式关卡流程、新主场景或最终 HUD；这些分别属于任务 28～30。

## 2. 冻结产品规则

- 正式局内只有梦尘；敌人、房间、风险和商店的梦尘流量必须可审计。
- 初始主动技能按内容配置视为已拥有 Lv1；新购主动同样从 Lv1 开始。
- 升级费用按当前内容定义逐级实际扣除，满级、余额不足、未拥有、非商店、陈旧 revision/session、重复 command 均不得产生部分写入。
- 重置只返还升级支出，不撤销拥有权，不卸下技能，不返购买成本；返还向下取整。
- 普通换装与跨房保留等级，不触发退款。
- 被动技能可购买、拥有和装配，但本任务不得为被动引入等级或升级货币消耗。
- 正式模式关闭时，等级/经验/属性/遗物对权威结果为中性；旧类和旧资源必须仍可加载，不可物理删除。
- SP、CurrentElement、元素附着与反应、既有技能冷却/充能规则维持现状。单技能专精不是预设失败，不加入强制轮换或通用冷却。
- Boss 后零梦尘、无奖励/商店并直达结算是任务 29 的流程责任；本任务只提供可表达“终局零奖励”的领域字段与不产生虚假经济事务的合同。

## 3. 权威事务与快照要求

### 3.1 快照

`RunSnapshot` 应以不可变快照表达：本局冻结的功能模式与规则；当前梦尘余额及守恒字段；已拥有技能、主动等级、累计实际升级支出；商店 session、offers、价格和拒绝原因；与 Task25 即时装配兼容的 revision/loadout 信息。不得把可变内部字典直接暴露给 UI 或执行器。

### 3.2 命令

至少覆盖购买、主动升级、主动重置。每个命令必须：

- 校验阶段、session、expected revision、command id、offer/技能拥有状态、余额、等级和内容定义；
- 先完成全部验证，再一次性提交；失败时余额、拥有权、等级、累计支出、草稿、revision 和通知均不变；
- 同 command id 重放返回一致结果且不重复扣款/返款/通知；相同权威状态的幂等请求不推进 revision；
- 成功只推进规定的 revision 一次，并输出可审计的结构化 summary/cause；
- 与 Task25 即时装配的草稿重基线兼容，不能恢复“离店确认技能装配”。

### 3.3 等级效果端口

- `SkillContentDefinition`/catalog 负责数据，不拥有 RunSession 状态。
- RunSession/adapter 只将某次接受时的权威主动等级解析成类型化效果快照。
- `SkillController`/`SkillExecutor` 在接受点取得并冻结该快照；后续执行上下文只消费冻结值。
- 元素弹、元素之怒、元素激光的首版等级可以缩放伤害；回收可以缩放其技能专属资源收益。共享等级字段不得改变 SP、通用冷却、反应公式、元素层数、碰撞范围或执行策略。
- 端口缺失、模式禁用或内容无等级定义时必须安全返回中性效果。

## 4. 精确 allowlist

除下列路径外不得创建、修改、删除或重序列化任何项目文件：

```text
growth/contracts/run_feature_mode.gd
growth/contracts/run_rules_snapshot.gd
growth/contracts/dream_dust_snapshot.gd
growth/contracts/active_skill_level_effect_snapshot.gd
growth/contracts/skill_progress_snapshot.gd
growth/contracts/shop_offer_snapshot.gd
growth/contracts/shop_snapshot.gd
growth/contracts/run_command_result.gd
growth/contracts/run_snapshot.gd
growth/contracts/skill_inventory_snapshot.gd
growth/contracts/shop_draft_open_result.gd
growth/contracts/shop_commit_summary.gd
growth/definitions/active_skill_level_definition.gd
growth/definitions/active_skill_progression_definition.gd
growth/state/run_economy_state.gd
growth/state/skill_inventory_state.gd
growth/shop/shop_draft.gd
growth/run_session.gd
growth/events/enemy_killed_event.gd
growth/events/room_completed_event.gd
combat/content/skill_content_definition.gd
combat/content/run_content_catalog.gd
combat/contracts/cast_snapshot.gd
combat/ports/active_skill_level_effect_port.gd
combat/components/skill_executor.gd
combat/components/skill_controller.gd
combat/execution/skill_execution_context.gd
combat/execution/all_energy_burst_execution.gd
combat/execution/channel_execution.gd
combat/execution/element_reclaim_execution.gd
scripts/player.gd
scripts/run_skill_level_effect_adapter.gd
resources/content/run_content_catalog.tres
resources/content/skills/element_bolt_content.tres
resources/content/skills/elemental_fury_content.tres
resources/content/skills/elemental_laser_content.tres
resources/content/skills/element_reclaim_content.tres
resources/content/skills/burning_content.tres
resources/content/skills/unending_content.tres
growth/tests/run_growth_tests.gd
growth/tests/run_growth_contract_edge_tests.gd
growth/tests/run_growth_06_contract_tests.gd
growth/tests/run_growth_session_isolation_test.gd
growth/tests/run_reward_authority_tests.gd
growth/tests/run_task25_immediate_shop_equip_tests.gd
growth/tests/run_task27_run_economy_progression_tests.gd
combat/tests/run_task27_skill_level_effect_tests.gd
combat/tests/capture_task27_skill_level_visual.gd
docs/agent_tasks/pending/27_run_economy_skill_progression_authority.md
docs/agent_tasks/evidence/task27/**
```

六个历史 Growth runner 只允许迁移构造方式和与新产品规则冲突的旧模式断言；不得借机重写其他已接受行为。历史 `docs/agent_tasks/evidence/task*/**` 一律不可改。

## 5. 明确禁止

- 不修改 `project.godot`、`scenes/test_room.tscn`、任何 HUD/Overlay、VFX/图片/正式资产、正式关卡场景或流程资源。
- 不修改 `combat/loadouts/**`、`combat/definitions/skill_loadout.gd`、被动 Runtime 或共享七槽资源；任务 28 才负责 3+4。
- 不删除/重命名旧经验、属性、遗物代码或资源；只能通过功能模式中性化其正式权威影响。
- 不把 XP/金币字段改名冒充梦尘，不让 UI 草稿持有余额、等级、价格或退款权威。
- 不改变 SP、CurrentElement、元素附着/反应、既有冷却/充能、范围、碰撞、时序和执行策略。
- 不修改任务 20 未接受 runner/capture/evidence，不将其纳入门禁。
- 不使用当前对话内子 Agent；本职责对话独立完成。
- 不执行 Git add/commit/push/reset/restore/checkout/clean/stash 或其他 Git 写操作。

## 6. 共享区与验证安全

- 共享项目只做 allowlist 文本/资源修改，不在共享目录运行 Godot、测试、scan、smoke、截图或会触发 import 的命令。
- 共享 Godot 编辑器可保持打开，但不得连接其会话执行 save/reimport/reload/project run/validation，也不得依赖共享 `.godot`。
- 所有 Godot 命令和证据必须进入一个全新、此前不存在的 `C:\tmp` 冷副本和独立 profile；排除 `.git`、`.godot` 与缓存并逐文件核对复制。
- 冷副本第一条 Godot 命令必须是 Godot 4.7.1 headless editor scan；scan 通过后才可运行 runner。
- 执行前后固化共享 `git status`、allowlist、任务 20/21～26 保护文件、`.godot` 和 allowlist 外全量基线；若共享区发生非本任务漂移，冻结并回传。

## 7. 自动化门禁

### 7.1 Task27 专项

新 runner 必须覆盖且全部通过：

- 主动/被动购买、主动初始 Lv1、逐级升级、满级、余额不足；
- 退款 `floor(累计实际升级支出 × 0.70)`、购买价不返、重复重置无重复收益；
- 非商店、陈旧 revision/session、未拥有、非法 ID、重复 command、最终端口拒绝的全状态不变；
- 梦尘守恒、成功 revision/通知次数、失败零通知；
- DISABLED/OBSERVE_ONLY/ENABLED 在开局冻结，DISABLED 下 Lv1/XP0/属性0/遗物中性且旧资源可加载；
- 被动技能无等级；普通换装/跨快照保留主动等级且不退款；
- 终局零奖励字段不会生成梦尘或商店事务；
- 元素弹/元素之怒/元素激光伤害等级效果、回收专属资源等级效果；
- 接受后升级不污染旧执行、端口缺失中性、等级不改变 SP/反应/冷却/范围/行为。

### 7.2 回归

- 任务 25 已接受基线为 `20/20 runners，242 tests / 2115 assertions`；必须在最终冷副本逐个恢复并全部通过。
- Task12/16/18/24 专项预期仍分别为 `13/110`、`11/209`、`9/124`、`10/190`。
- Task20 runner 单列历史非门禁，不得混入接受基线，也不得因本任务通过而标记接受。
- 运行 TestRoom 180 帧 smoke；完整 scan、runner、smoke、capture 日志中的 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:` 必须均为 0。

如果新规则必然使某个已接受旧断言失效，只能修改第 4 节明确列出的旧 Growth runner，并在交付中逐条说明旧产品语义、替代语义和为何不影响历史证据。不得通过删测、跳过或降低断言通过。

## 8. 实际 Viewport

- 使用冷副本内全新的非共享、非编辑器图形 Godot 4.7.1 进程，禁止保存。
- 至少生成一张 `1920×1080` 实际 Viewport：真实 TestRoom/现有正式运行链中，权威 Lv2 主动技能产生已由自动化断言的等级效果，并能看见与本任务有关的集成状态。
- 截图只证明实际场景接线和可读反馈，不作为伤害、余额、revision 或返还数值权威；数值必须由 runner 断言。
- Review 会在新的冷副本重新生成并人工打开检查；不得只复用执行侧 PNG。

## 9. 完成定义与交付

只有同时满足以下条件才可进入 `REVIEW`：

1. 第 1～3 节合同完整实现，Task25 即时装配和 Task24 奖励确认语义未回退。
2. Task27 两个专项 runner、接受基线 20 runners、180 帧 smoke 和实际 Viewport 全部通过。
3. scan/runner/smoke/capture 正式日志完整干净。
4. 最终共享工作区只存在 Task27 allowlist 改动，任务 20、任务 21～26、共享 `.godot` 与 allowlist 外基线零漂移。
5. 任务书状态只更新为 `REVIEW`，执行侧冻结继续写入；不得自行 `ACCEPTED`。

交付必须列出：修改/新增文件及 SHA-256；权威事务、快照、模式和等级端口摘要；新旧 runner 数字、总 tests/assertions、退出码和日志错误计数；冷副本/profile 与复制对账；实际 Viewport 路径/尺寸/SHA/权威状态；保护对账；迁移旧断言及遗留风险；Git 写操作为零声明。

完成或阻塞时，必须由本职责对话直接向当前中枢 Review 5.0 自动传话：threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`、hostId `local`。完成回传 `REVIEW`，阻塞回传 `BLOCKED`；不要等待用户转述。回传后保持冻结，等待独立 Review。

## 10. 执行侧交付（2026-08-05）

### 10.1 实现摘要

- 新增开局冻结的 `RunRulesSnapshot` 与 `DISABLED / OBSERVE_ONLY / ENABLED` 模式；正式关闭模式投影 Lv1/XP0/属性0及遗物中性，旧经验、属性、遗物类和资源仍可加载，兼容回归可显式使用旧启用规则。
- 新增单一梦尘钱包和守恒快照；敌人/房间事件独立表达梦尘，终局事件强制零梦尘，旧 XP 不改名、不兑换梦尘。
- `RunSession` 建立商店 session/offers、购买、主动逐级升级和 70% 向下取整重置权威事务；全量预校验后一次提交，结构化 summary/cause，command replay 与 command-id 复用保护，失败保持余额、拥有权、等级、累计升级支出、草稿、revision 和通知不变。
- 主动技能等级/价格/效果由静态内容资源定义；购买主动从 Lv1、被动无等级，重置保留拥有权和装配且不返购买价。Task25 即时装配成功后的草稿重基线继续保留未确认属性分配，普通换装和跨房快照不改变等级或触发退款。
- 新增 `ActiveSkillLevelEffectPort` 与 `RunSkillLevelEffectAdapter`；`SkillExecutor` 在接受点取得并冻结效果。元素弹、元素之怒、元素激光只缩放伤害，回收只缩放专属资源收益；SP、冷却、反应、元素层数、范围、碰撞、时序与执行策略未改变。VFX 端口晚装配场景由接受时临时装饰当前实际回收端口，避免装配顺序覆盖等级效果。

### 10.2 正式验证

- 视觉修正最终冷副本：`C:\tmp\element_dungeon_task27_reviewfix_cold_20260805_01\project`；独立 profile：`C:\tmp\element_dungeon_task27_reviewfix_profile_20260805_01`。
- 复制前路径均不存在；排除 `.git`、`.godot` 与缓存后逐文件核对 `1256/1256`、`39,047,834 / 39,047,834 bytes`、`0 mismatch`。该副本第一条 Godot 命令为 Godot 4.7.1 headless editor scan，exit 0。
- Task27 专项：经济/成长 `11 tests / 291 assertions`，战斗等级效果 `7 / 86`；新增合计 `18 / 377`，两个 runner 均 exit 0。
- 任务25已接受基线逐个恢复为 `20/20 runners，242 tests / 2115 assertions`；连同 Task27 合计 `22/22 runners，260 tests / 2492 assertions`。Task12/16/18/24 专项分别保持 `13/110`、`11/209`、`9/124`、`10/190`。任务20未运行、未混入门禁，继续历史 `BLOCKED`。
- 180 帧 smoke exit 0；非 headless OpenGL/NVIDIA 实际 Viewport capture exit 0。正式 scan、22 runner、smoke、capture 共 25 份日志，`SCRIPT ERROR=0`、`Parse Error=0`、`ERROR:=0`、`WARNING:=0`。

### 10.3 Viewport、保护与边界

- `docs/agent_tasks/evidence/task27/01_authoritative_lv2_element_bolt_1920x1080.png` 为 `1920×1080`、`155,594 bytes`、SHA-256 `812E01F6BA1729E0B3D06E42A90E8227803BA819CBDC011073014194B49AB324`。capture 在真实 TestRoom/RunSession 链中断言：元素弹 Lv2、伤害 `12.5`、梦尘 `25`、revision `16`、SP 余量 `90`。
- 独立 Review 指出的物理坐标错误已修正：面板现在由全屏逻辑 `Control` 的右上锚点和 1152×648 逻辑 offset 定位，并限制在逻辑画布顶部 25% 安全带。capture 新增面板完全位于逻辑安全区及物理截图边框/文字像素门禁；正式日志记录容差计数 `border_pixels=2734`、`text_pixels=8345`。
- 在 Review 相同的物理区域 `x=1050..1919, y=20..339` 中，精确金色边框 `RGB(215,181,109)` 为 `2278` 像素、边界 `x=1270..1879, y=20..205`，亮色文字阈值为 `8515` 像素。执行侧已通过对话内 Base64 缩略预览人工检查：四行文字完整可读，面板与顶部中央 HUD、玩家/敌人区域及弹道均不重叠。
- allowlist 声明 `50` 条。allowlist 外基线仍为 `1182 files / 38,601,409 bytes / 6DF903AACD42AE78C767D01D5E5C958F8E5F530E6F0BDB52417A6C162DB2063E`；共享 `.godot` 仍为 `702 / 34,663,328 / C61FA422F168F1B3BBFD5FE48D43CE480ABD8AAA14221D2BD3F5E24AB89F579E`；任务20/21～26保护集仍为 `120 / 4,885,165 / 48A9C73400F72DF5F76132A34D18A46390F3CA2D756558C45969A1AF6BC685BC`，三组均与执行前相同。
- 六个历史 Growth runner 均无需迁移，旧已接受断言未删除、未跳过、未降低。未实现七槽/四被动 Runtime、正式关卡流程、新主场景或最终 HUD；这些仍属于任务28～30。
- 当前对话未使用子 Agent；未执行任何 Git 写操作；未在共享项目运行 Godot，也未触碰共享 `.godot`。完整日志、证据索引和文件 SHA-256 清单见 `docs/agent_tasks/evidence/task27/README.md` 与 `SHA256SUMS.txt`。

### 10.4 独立 Review 失败项闭环

- 2026-08-05 首次独立 Review 仅判定视觉证据失败：旧 capture 把 `panel.position=(1220,74)`、`size=(620,220)` 当作物理窗口坐标写入 `canvas_items + expand` 的 1152×648 逻辑画布，导致面板整体被推到屏外；核心实现、67项旧哈希、22 runners、smoke 和独立 capture 权威数值均通过。
- 本轮严格只修改 `combat/tests/capture_task27_skill_level_visual.gd`、Task27 evidence 与本任务书，核心实现与所有 runner 保持冻结。修正后的全新冷副本重新执行 scan、22 runners、180帧 smoke 和非 headless capture，结果与原自动化数字一致且日志四类错误仍全部为0。
- 新 PNG 已替换旧失败证据；`.png.import` 仅由冷副本 scan 产生，未复制回共享 evidence。任务现重新交付 `REVIEW`，等待中枢在另一个全新冷副本独立验收。

## 11. 中枢 Review 5.0 独立验收（2026-08-05）

结论：`PASS / ACCEPTED`。

- 首轮独立 Review 已确认 67/67 文件哈希、权威事务、梦尘守恒、70% 向下取整返还、command replay、功能模式与接受时等级效果冻结正确；全新冷副本复现 `22/22 runners、260 tests / 2492 assertions` 与 180 帧 smoke，但因诊断面板使用物理式坐标被 stretch 推到屏外，按门禁退回。
- 修正版只改变 capture、Task27 evidence 与本任务书；中枢将清单中其余 38 个实现/runner 文件与首轮 Review 冷副本逐字节核对，`0 mismatch`。
- 最终独立复验冷副本为 `C:\tmp\element_dungeon_task27_review5_recheck_cold_20260805_02\project`，独立 profile 为 `C:\tmp\element_dungeon_task27_review5_recheck_profile_20260805_02`；当前共享区全量复制 `1256/1256 files、39,109,342 bytes、0 mismatch`，首条 Godot 命令前无 `.godot`。
- Godot 4.7.1 headless editor scan 退出 0，`SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 0。
- 任务25接受基线20个 runner 与两个 Task27 runner 全部逐个复跑：`22/22 runners、260 tests / 2492 assertions`；Task12/16/18/24 专项保持 `13/110、11/209、9/124、10/190`；180帧主场景 smoke 退出0，全部日志错误标记为0。任务20未混入门禁，继续历史 `BLOCKED`。
- 独立非共享图形进程重新生成 1920×1080 PNG，SHA-256 `F35E887F48643D126D6099274F22A66389FF3996C247CCBE82779BFCC1D5F4CF`。原始像素复核得到金色边框2278像素、范围 `x=1270..1879, y=20..205`，亮色文字7163像素；人工查看确认四行 Task27 状态完整可读，且不遮挡顶部中央 HUD、玩家、敌人或弹道。
- Review 完成后共享 Task27 `SHA256SUMS.txt` 仍为67/67、0 mismatch；共享 `.godot` 仍为 `702 files / 34,663,328 bytes`。中枢没有连接共享 Godot、没有修复游戏代码或使用子 Agent。

任务27现已归档；其经济、等级、模式和窄端口合同作为任务28接受基线。