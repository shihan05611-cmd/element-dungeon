# 任务 28：七槽配装与四被动 Runtime

状态：IN_PROGRESS  
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