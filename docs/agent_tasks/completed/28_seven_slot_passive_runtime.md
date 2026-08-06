# 任务 28：七槽配装与四被动 Runtime

状态：ACCEPTED  
负责人：Combat Loadout/Passive Runtime Agent 2.0（threadId `019fd269-62d1-7cd0-8fff-59a188534b71`，hostId `local`）  
依赖：任务 27 `ACCEPTED`；任务 20 继续历史 `BLOCKED`

## 1. 目标

依据 `docs/design/元素地牢_局内构筑与成长机制变更需求.md`、`docs/design/元素地牢_局内构筑与关卡流程实现契约.md` 及任务27接受基线，把运行配装正式迁移为严格分区的3主动+4被动：

1. 七个固定槽位：`ACTIVE_1..3` 与 `PASSIVE_1..4`，每槽允许为空。
2. 主动只能进入主动槽，被动只能进入被动槽；同一技能在全部七槽中最多出现一次。
3. 建立旧四槽到七槽的确定性迁移，保留拥有权，溢出技能留在拥有库而不是丢失。
4. 四个被动可同时注册；装备变化、死亡/重生、floor change、run reload 与 run end 的注册/撤销严格幂等，不丢失、不重复。
5. 共享持久化只保存一套七槽快照；RunSession即时装配继续做拥有权、类型、唯一性和最终端口原子验证。

本任务不实现正式关卡、新主场景或最终3+4 HUD；任务29消费七槽 Runtime，任务30完成最终界面。

## 2. 七槽权威合同

- `SkillSlotIds.all()` 顺序固定为三个主动后四个被动，并提供类型查询；未知槽必须结构化拒绝。
- `RuntimeSkillLoadout` 和 `SkillLoadout` 必须验证七槽完整、槽ID唯一、技能ID全局唯一、主动/被动双向类型正确；空槽有效。
- 候选快照、持久化和UI草稿不得绕过 Runtime/RunSession 权威验证。
- 成功装配只推进规定 revision 一次；相同映射幂等；最终持久化/端口拒绝时快照、revision、被动注册和通知均不变。
- Task27梦尘、技能等级和累计升级支出不因迁移、换槽、空槽或floor rebuild改变，也不得触发退款。

## 3. 迁移与被动生命周期

### 3.1 四槽到七槽

- 有效旧 `PASSIVE_1` 优先迁入新 `PASSIVE_1`。
- 旧ACTIVE槽内遗留的被动按 `ACTIVE_1 → ACTIVE_2 → ACTIVE_3` 顺序去重后填入后续被动空槽；其旧ACTIVE位置清空。
- 合法主动保持原主动槽；同技能重复只保留确定性第一项。
- 第五个及以后被动、非法类型和未知技能不得硬塞进槽；合法拥有权保留在库存，并通过类型化迁移结果报告。
- 对同一旧快照重复迁移必须得到相同结果，不重复推进revision；原生七槽快照不得再次降级或重排。

### 3.2 四被动 Runtime

- 四个被动定义各最多注册一次，槽位到实例/订阅映射可审计。
- 装备、卸下、互换、死亡、重生、floor change、run reload、run end各自只产生应有的一次注册或撤销；重复事件不得重复连接信号、计时器或效果。
- floor rebuild 与run reload后，仍装备的四被动恢复一次且仅一次；已卸下被动不得残留。
- 现有 Burning/Unending 规则、元素语义和Task18 VFX边界不得改变。

## 4. 精确 allowlist

```text
combat/loadouts/skill_slot_ids.gd
combat/loadouts/runtime_skill_loadout.gd
combat/loadouts/legacy_element_loadout_migrator.gd
combat/loadouts/shared_four_slot_to_seven_slot_migrator.gd
combat/loadouts/seven_slot_migration_result.gd
combat/definitions/skill_loadout.gd
combat/content/skill_content_definition.gd
combat/content/run_content_catalog.gd
combat/passives/passive_skill_controller.gd
growth/run_session.gd
scripts/shared_loadout_persistence_adapter.gd
resources/shared_skill_loadout.tres
combat/tests/run_agent_d_growth_integration_tests.gd
combat/tests/run_hud_loadout_feedback_tests.gd
combat/tests/run_skill_content_catalog_tests.gd
combat/tests/run_skill_tests.gd
combat/tests/run_skill_vfx_runtime_tests.gd
combat/tests/run_compact_hud_reward_tests.gd
growth/tests/run_growth_06_contract_tests.gd
growth/tests/run_task25_immediate_shop_equip_tests.gd
combat/tests/run_task28_seven_slot_passive_tests.gd
combat/tests/capture_task28_four_passives_visual.gd
docs/agent_tasks/pending/28_seven_slot_passive_runtime.md
docs/agent_tasks/evidence/task28/**
```

除上述路径外不得创建、修改、删除或重序列化任何项目文件。旧runner只允许迁移已废止3+1/快照形状断言；历史evidence/capture不得修改。`run_compact_hud_reward_tests.gd`仍属任务20历史非门禁，只允许为新快照形状保持可运行，必须单列结果，不得据此接受任务20。

## 5. 禁止范围

- 不修改`project.godot`、正式主入口、房间/路线/商店/Boss/结算流程、HUD/Overlay、VFX/图片或正式资产。
- 不改变Task27梦尘公式、购买/升级/重置、等级数值、SP、反应、冷却、范围或技能行为。
- 不保留主动槽可装被动或被动槽可装主动的正式兼容分支。
- 不通过静态变量、第二份持久化资源或UI本地状态保存本局配装。
- 不使用子Agent；不执行Git add/commit/push/reset/restore/checkout/clean/stash。

## 6. 自动化与冷副本

- 共享项目不得运行Godot或触碰共享`.godot`。所有scan、runner、smoke和capture必须位于全新`C:\tmp`冷副本及独立profile，排除`.git/.godot`并逐文件核对；第一条Godot命令必须为4.7.1 headless editor scan。
- 新主runner覆盖：七槽完整性、空槽、双向类型拒绝、重复ID、未知槽、确定性迁移、溢出拥有权、revision/幂等/端口拒绝原子性、四被动同时注册及全部生命周期事件。
- 任务27接受基线为`22/22 runners、260 tests / 2492 assertions`，必须逐个恢复。Task12/16/18/24保持`13/110、11/209、9/124、10/190`。
- 受七槽新合同覆盖且位于allowlist的旧runner更新后必须通过；任务20 runner单列非门禁。不得删测、跳过或降低断言。
- 运行180帧主场景smoke；正式日志中`SCRIPT ERROR / Parse Error / ERROR: / WARNING:`均为0。

## 7. 实际 Viewport

- 使用全新非共享、非编辑器图形Godot 4.7.1进程，在真实TestRoom中保存1920×1080实际Viewport。
- 保存前自动断言七槽快照、四被动同时装备、四个Runtime各注册一次且跨floor rebuild不重复。
- 可添加只读诊断面板，但必须使用1152×648逻辑画布锚点/安全区，实际画面完整可见、文字可读且不遮挡关键HUD、玩家、敌人或技能表现；它不是任务30最终HUD。
- 截图只证明场景接线和可见状态，权威类型、revision与生命周期次数必须由runner断言。

## 8. 完成与自动回传

只有实现、editor scan、Task28专项、22个接受runner、受影响旧runner、180帧smoke、实际Viewport和共享零漂移全部通过后，才可把本任务更新为`REVIEW`并冻结；不得自行`ACCEPTED`。

交付须列出修改文件/SHA、迁移映射、生命周期计数、全部runner数字、日志错误计数、冷副本/profile、Viewport路径/SHA/人工限制、保护对账和Git零写入声明。

完成或阻塞时必须由本职责对话自动回传当前中枢 Review 5.0：threadId `019fc6c7-85e3-77f0-a99b-9cc9ee6055a2`、hostId `local`。完成回传`REVIEW`，阻塞回传`BLOCKED`，不要等待用户转述。

## 9. 执行阻塞（2026-08-05）

- 完成全部必读文档、检查点、工作树、核心实现、受影响旧 runner 与 allowlist 外调用点只读审计；HEAD 精确为 45d5873b4f503cc392acc1647c87dcc128f33725，已跟踪工作树无改动，未发现任务重叠。
- 对 combat/loadouts/skill_slot_ids.gd 先后使用绝对路径和仓库相对路径调用标准 apply_patch；两次均在读取待更新文件阶段因 Windows 沙箱 CreateProcessWithLogonW failed: 1385 失败。
- 失败后立即核对目标 SHA-256 为 3C37CBD14B38AE2B76571E847C95B00838B4C071F8BA1BDB6EBF075377C9BC31，git diff -- combat/loadouts/skill_slot_ids.gd 为空，确认零部分写入。
- 依据 CENTRAL_REVIEW_RULES.md 第 8 节，游戏文件在 apply_patch 失败时禁止使用 PowerShell/Python 回退写入；因此冻结实现并自动回传中枢，等待修复写入环境或明确调整规则。
- 未运行任何 Godot 命令，未触碰共享 .godot，未使用子 Agent，未执行 Git 写操作。

## 10. 中枢审计后恢复重试（2026-08-05）

- 中枢确认前次失败为间歇性环境故障后授权恢复，并限定首个游戏补丁最多执行五次标准 apply_patch。
- 五次均在读取 combat/loadouts/skill_slot_ids.gd 阶段失败，错误完全相同：Windows sandbox CreateProcessWithLogonW failed: 1385；第 3～5 次已缩减为最小单 hunk，结果不变。
- 每次失败后均只读核对目标 SHA-256 与 git diff；五轮结束后 SHA-256 仍为 3C37CBD14B38AE2B76571E847C95B00838B4C071F8BA1BDB6EBF075377C9BC31，目标 diff 为空。
- 已达到中枢规定的五次有界上限；未尝试 PowerShell、Python、重定向或其他游戏文件写入回退，任务继续 BLOCKED 并再次自动回传。
- 本轮仍未运行 Godot、未触碰共享 .godot、未使用子 Agent、未执行 Git 写操作。

## 11. 执行交付（2026-08-06）

### 11.1 实现与边界

- 沙箱恢复后首个标准 `apply_patch` 成功，任务按中枢要求恢复为 `IN_PROGRESS`，并完整保留第 9、10 节两次阻塞记录。最终修改仅落在本任务精确 allowlist。
- 固定七槽 `ACTIVE_1..3 + PASSIVE_1..4`，空槽有效；正式七槽候选严格校验未知/缺失槽、全局技能唯一、主动/被动双向类型、revision 与最终端口原子性。
- 精确旧四槽 `ACTIVE_1..3 + PASSIVE_1` 在持久化与 Runtime 加载边界执行同一确定性迁移，输出立即且只保留七槽；旧 `PASSIVE_1` 优先，旧 ACTIVE 遗留被动按 A1→A2→A3 填后续 P 槽，合法主动留原位；重复、未知、非法类型与第五个以后被动类型化报告，不能装备的合法技能仍保留 owned。六槽等其他短形状继续严格拒绝。
- 四被动 Runtime 对装备/卸下/互换、死亡/重生、floor change、run reload、run end 幂等；纯主动换槽不重建，被动互换复用实例，floor/reload 各撤销一次并建立四个新实例，run end 释放后不复活。
- RunSession 正式 content-catalog 路径在最终端口前完成七槽、拥有权、唯一性和双向类型校验；失败不改变 loadout/run revision、被动注册、Task27 梦尘、技能等级或累计投入。catalog-free 兼容仅服务冻结成长领域夹具自身端口形状，不是正式混装入口。
- 未实现任务29流程、新主场景或任务30最终 HUD；Task20 与 Task24 runner 相对检查点均为零 diff，未修改历史 capture/evidence。

### 11.2 最终冷副本与门禁

- 最终冷副本：`C:\tmp\element-dungeon-task28-exec-20260806-06\project`；独立 profile：`C:\tmp\element-dungeon-task28-exec-20260806-06\profile`。
- 复制前排除 `.git/.godot/.workbuddy`；共享源与冷副本均为 `1278 files / 39,233,750 bytes`，逐文件 SHA-256 `0 mismatch`。
- 第一条 Godot 命令为 4.7.1 headless editor scan：exit 0；`SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 0。
- Task28 主 runner：`6 tests / 154 assertions`，exit 0，四类日志计数均为 0。
- 已接受 22-runner：`22/22 runners / 260 tests / 2492 assertions`；逐 runner exit 0，22 份日志四类计数均为 0。Task12/16/18/24 分别保持 `13/110、11/209、9/124、10/190`。
- 180 帧 `res://scenes/test_room.tscn` smoke：exit 0，四类日志计数均为 0。
- Task20 历史 runner 单列非门禁：仍为 `BLOCKED`，exit 1，`7 failures / 83 assertions`，`4 SCRIPT ERROR / 0 Parse Error / 1 ERROR / 0 WARNING`；未混入任务28门禁，也未据此接受 Task20。

### 11.3 Viewport、保护与冻结

- 独立非编辑器图形 Godot 4.7.1 在真实 TestRoom 保存 `docs/agent_tasks/evidence/task28/01_four_passive_runtime_1920x1080.png`：实际 1920×1080，SHA-256 `2B3CB519A2B9E85653B749670AB8F237D26A41359DD13F0A8BE3837911332D4C`。保存前断言七槽、四个唯一 Runtime、floor rebuild `REG 1→2 / UNREG 0→1`。
- 执行侧已实际打开原图人工检查：诊断板完整可读、P1～P4 和计数清晰，位于 1152×648 逻辑安全区，不遮挡状态 HUD、技能带、玩家、敌人或出口；它只是只读诊断叠层，不冒充任务30最终 HUD。
- 共享 `.godot` 最终仍为 `704 files / 34,759,094 bytes / C85F2ECCE7DAE2649DAC511092F6A7E1745671653BECF0057796C79508277024`，与恢复前基线精确一致；共享编辑器被动漂移为 0。
- 既有 19 项未跟踪 UID/import 的路径、时间、字节和 SHA-256 与恢复前清单一致；未生成 Task28 UID/import，未删除、覆盖、暂存或认领这些保护文件。`.workbuddy` 和无关架构建议文档保持既有未跟踪状态。
- 完整实现、SHA、逐 runner 日志、截图与保护对账见 `docs/agent_tasks/evidence/task28/README.md`。Git 写操作为零；HEAD 仍为 `45d5873b4f503cc392acc1647c87dcc128f33725`。
- 本任务现冻结为 `REVIEW`，等待中枢 Review 5.0 在另一全新冷副本独立验收；不得由执行侧自行 `ACCEPTED`。

## 12. 中枢 Review 5.0 独立验收（2026-08-06）

结论：`PASS / ACCEPTED`。

- 独立验收冷副本为 `C:\tmp\element-dungeon-task28-review5-20260806-01\project`，独立 profile 为 `C:\tmp\element-dungeon-task28-review5-20260806-01\profile`；排除 `.git/.godot/.workbuddy/cache/tmp` 后，当前共享源与冷副本逐文件核对为 `1307/1307 files、39,474,247 bytes、0 mismatch`，首条 Godot 命令前冷副本不存在 `.godot`。
- Godot 4.7.1 headless editor scan 退出 0，完整 stdout 为 36,637 bytes；`SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 0。
- Task28 专项独立复跑为 `6 tests / 154 assertions`；任务27接受基线 22 个 runner 全部逐个通过，为 `260 tests / 2492 assertions`。合计 `23/23 runners、266 tests / 2646 assertions`；Task12/16/18/24 保持 `13/110、11/209、9/124、10/190`。
- 中枢在冷副本增加 Review-only 正式 Host 旧四槽夹具，验证真实 `RunSessionHost + RunContentCatalog` 恢复后保留 `A1=element_bolt、P1=unending、P2=burning`，并同时保留 Burning/Unending owned；该夹具通过，未复制回共享项目。
- `res://scenes/test_room.tscn` 180 帧 smoke 退出 0；正式 scan、23 runner、smoke、capture 日志四类错误标记均为 0。Task20 单独复跑仍为 `7 failures / 83 assertions`、exit 1，继续历史 `BLOCKED`，未进入接受数字。
- 独立非共享图形 Godot 重新生成 1920×1080 Viewport，SHA-256 为 `2E64F6427FF1A7BDE6D7B4CEF0412C5B26C9D08D9B714D3827ED33CE211C0AA8`，与执行者 PNG 不同，证明重新生成；日志断言边框 2735、文字 2620、七槽、四个唯一 Runtime 以及 floor rebuild `REG 1→2 / UNREG 0→1`。人工打开原图确认诊断板完整可读，不遮挡状态 HUD、技能带、玩家、敌人或出口。
- 静态审阅确认迁移只接受精确旧四槽或原生七槽，六槽/未知形状拒绝；正式 content-catalog RunSession 在最终端口前验证七槽、拥有权、全局唯一和双向类型；catalog-free 分支只服务冻结领域夹具。四被动换槽复用实例，死亡/重生、floor/reload、run end 的注册/撤销满足幂等边界。
- Review 后共享 `.godot` 仍为 `704 files / 34,759,094 bytes / C85F2ECCE7DAE2649DAC511092F6A7E1745671653BECF0057796C79508277024`；既有 19 项未跟踪 UID/import 路径集合不变、Task28 sidecar 为 0。20 个实现/runner/resource 文件哈希继续与执行交付逐项一致，allowlist 外无新增漂移。
- 中枢未连接共享 Godot/MCP、未修改游戏实现、未使用子 Agent。任务28现作为任务29正式关卡流程的接受基线归档。
