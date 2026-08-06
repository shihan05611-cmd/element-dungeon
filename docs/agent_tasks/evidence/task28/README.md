# 任务 28 执行证据

执行状态：`REVIEW`（仅执行侧交付，等待中枢独立验收；未自行 `ACCEPTED`）  
检查点：`45d5873b4f503cc392acc1647c87dcc128f33725`  
最终冷副本：`C:\tmp\element-dungeon-task28-exec-20260806-06\project`  
独立 profile：`C:\tmp\element-dungeon-task28-exec-20260806-06\profile`

## 1. 实现结论

- 运行配装固定为 `ACTIVE_1..3 + PASSIVE_1..4`，七槽均允许为空；正式七槽候选执行未知槽、缺槽、重复技能、主动/被动双向类型和最终端口原子校验。
- 精确旧四槽 `ACTIVE_1..3 + PASSIVE_1` 可在加载/Runtime 边界进入确定性迁移，迁移后权威状态立即且只保存七槽；任意其他短形状仍以 `expected_seven_shared_slots` 拒绝。
- 迁移顺序为旧 `PASSIVE_1` 优先占新 `PASSIVE_1`，随后按旧 `ACTIVE_1 → ACTIVE_2 → ACTIVE_3` 把遗留被动填入后续被动空槽；合法主动保持原槽；重复、未知、非法类型和第五个以后被动进入类型化结果，不能装入的合法技能仍保留 owned。
- 四被动控制器维护可审计的槽位、技能、实例和注册/撤销计数。纯主动换槽不重建被动；被动互换复用实例；死亡/重生幂等；floor/reload 各撤销一次并建立四个新实例；run end 释放一次且后续 reload 不复活。
- RunSession 的正式 content-catalog 路径继续先做七槽、拥有权、唯一性和类型校验，再调用最终端口；失败不改变 loadout/run revision、被动注册、Task27 梦尘或技能等级/累计投入。
- 未实现任务29关卡流程、新主场景或任务30最终 HUD；Task24 与 Task20 runner 相对检查点均为零 diff。

## 2. 修改实现与 SHA-256

| 路径 | SHA-256 |
| --- | --- |
| `combat/content/skill_content_definition.gd` | `5EECE5A5FE8CEC7396530AE97C850FD914F60FEDB134EFC749211FDFCA345958` |
| `combat/definitions/skill_loadout.gd` | `8FDC9031AD815558A7CD8AFB8E7F1F190C7A4D6B401047A01D0E2AF9957523CB` |
| `combat/loadouts/legacy_element_loadout_migrator.gd` | `22991AD2EEB30017175DAA5057B2C11B4E1CAFE5532B6725474F27FB18847D62` |
| `combat/loadouts/runtime_skill_loadout.gd` | `36B0EACCFD0D31CB02B761CF315A980EDBCFB6AA09B280727D346E17E4DE2CA3` |
| `combat/loadouts/skill_slot_ids.gd` | `28D41EF4635FA0B2E0D79498BBDAA022A52B5DDBE1B2048A608441573EE017C2` |
| `combat/loadouts/seven_slot_migration_result.gd` | `588B8B999BA0B70519EB4FA11168600098795177C2ACE573A19EA20556CBFEBF` |
| `combat/loadouts/shared_four_slot_to_seven_slot_migrator.gd` | `77A2B95A26F5A8F124A80FCE1E9F9141F06C6A35F8D95A6D0A8F286E93C89884` |
| `combat/passives/passive_skill_controller.gd` | `9293115040077B024349DEC370C914A900A3B7B0F19DB39669903DDC6F358739` |
| `combat/tests/run_agent_d_growth_integration_tests.gd` | `25366DE926302E24A475E33C2D096F2663BFC666C3674CF9C4620EB2D7EE4A60` |
| `combat/tests/run_hud_loadout_feedback_tests.gd` | `4431C453CE366FDEFD16B28D9EBDD5FF3545803A13048888935A555252BE3AFD` |
| `combat/tests/run_skill_content_catalog_tests.gd` | `618098CA6B236368577C64E1422BD662599EB05C65BB4AC88336C7FE565214A8` |
| `combat/tests/run_skill_tests.gd` | `C66BA32111C8BAD57FD87536D6772C477CC559FBD4B3E5C3975E814EBC1E687D` |
| `combat/tests/run_skill_vfx_runtime_tests.gd` | `E1C8789F8247CBA50E8C7B1A67893E088673C2E23CDCE90380657701C785C0B9` |
| `combat/tests/run_task28_seven_slot_passive_tests.gd` | `3F121B309827A53058D781ABD50723DF20ED00C9B5C1F33DFC57DE00472BD13C` |
| `combat/tests/capture_task28_four_passives_visual.gd` | `A90153FEB945B58B919D9FB6BCE709DDA106EE0118E189CC8276CDD259B1497A` |
| `growth/run_session.gd` | `ABFBA744BDD69D69907B08B153809BA8409EB7CBF6E067ECB39A1D834869EE75` |
| `growth/tests/run_growth_06_contract_tests.gd` | `A701A85161D0B7435867686A02C033D869129092989530F82DBD2EDE88FE380E` |
| `growth/tests/run_task25_immediate_shop_equip_tests.gd` | `B08EE0945A9339BE01B42E48000DAA39C273C1B7418280969105A42E26B91DD9` |
| `resources/shared_skill_loadout.tres` | `2FEA6ED74C8FE8F5AD7E6FE026073F2B9BF16E95B46FDA86D18AFE178D33BA32` |
| `scripts/shared_loadout_persistence_adapter.gd` | `BEE03FBD9AFA672FF1A8D6E6B440B99C531A6D422586F2146BAB4D9AE80D3CBA` |

任务书、本 README、日志和 PNG 也是 allowlist 内协调/证据文件；它们的最终 SHA 由冻结后的中枢交接清单给出。

## 3. 冷副本与自动化

- 最终复制前排除 `.git/.godot/.workbuddy`，共享源与 `-06` 冷副本均为 `1278 files / 39,233,750 bytes`，逐文件 SHA-256 `0 mismatch`。
- 第一条 Godot 命令：Godot `4.7.1.stable.official.a13da4feb` headless editor scan，exit `0`；`SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 `0`。
- Task28 主 runner：`6 tests / 154 assertions`，exit `0`，四类日志计数均为 `0`。
- 已接受 22-runner：`22/22 runners / 260 tests / 2492 assertions`，逐 runner exit `0`，22 份日志四类计数均为 `0`。其中 Task12/16/18/24 分别保持 `13/110、11/209、9/124、10/190`。
- 主场景 `res://scenes/test_room.tscn` 180 帧 smoke：exit `0`，四类日志计数均为 `0`。
- Task20 历史 runner 单列：仍为 `BLOCKED`，exit `1`，`7 failures / 83 assertions`，`4 SCRIPT ERROR / 0 Parse Error / 1 ERROR / 0 WARNING`；未计入 Task28 门禁，也未据此接受 Task20。

日志索引：`01_editor_scan.log`、`02_task28_seven_slot_passive.log`、`03_baseline22/*.log`、`04_task20_non_gate.log`、`05_main_scene_180_frames.log`、`06_visual_capture_1920x1080.log`。

## 4. 实际 Viewport

| 文件 | 实际尺寸 | SHA-256 | 自动断言 |
| --- | ---: | --- | --- |
| `01_four_passive_runtime_1920x1080.png` | 1920×1080 | `2B3CB519A2B9E85653B749670AB8F237D26A41359DD13F0A8BE3837911332D4C` | 七槽；四个唯一被动 Runtime；floor rebuild 后 `REG 1→2 / UNREG 0→1`；边框像素 2735、文字像素 2620 |

捕获由独立、非编辑器、非 headless 的 Godot 4.7.1 进程在真实 TestRoom 中保存。执行侧已实际打开原图人工检查：诊断板完整、对比度和文字可读；P1～P4 与 rebuild 计数清楚；位于 1152×648 逻辑安全区的左上区域，不遮挡顶部状态 HUD、底部技能带、玩家、敌人或右侧出口。该板仅为只读诊断叠层，不代表任务30最终 3+4 HUD。

## 5. 共享编辑器与保护对账

- 全程未对共享项目调用 Godot/MCP save、reload、reimport、运行、测试或截图；用户要求保留的共享 Godot 进程未被关闭或控制。
- 共享 `.godot` 最终仍为 `704 files / 34,759,094 bytes / C85F2ECCE7DAE2649DAC511092F6A7E1745671653BECF0057796C79508277024`，与恢复前基线精确一致；共享编辑器被动漂移为 `0 added / 0 removed / 0 changed`。
- 既有 19 项未跟踪 UID/import 仍为 19 项，路径、时间、字节和 SHA-256 与恢复前清单一致；未生成任何 Task28 `.gd.uid` 或 `.import`，未删除、覆盖、暂存或认领既有 19 项。
- `.workbuddy/memory/2026-07-31.md` 与 `docs/架构评估与扩展性改进建议.md` 保持既有未跟踪保护状态。
- 最终修改集合只包含任务28 allowlist：20 个实现/runner/resource 文件、本任务书及 `docs/agent_tasks/evidence/task28/**`；Task20/Task24 runner 均零 diff，未修改历史 capture/evidence、正式场景、HUD、VFX、图片资产或 `project.godot`。
- Git 写操作为零：未 add、commit、push、reset、restore、checkout、clean 或 stash；HEAD 保持 `45d5873b4f503cc392acc1647c87dcc128f33725`。

## 6. 遗留风险与 Review 提示

- `RuntimeSkillLoadout` 只把精确旧四槽识别为迁移输入；正式输出和当前状态始终为七槽。独立 Review 应同时复核旧四槽成功迁移与六槽/未知槽拒绝，防止把迁移边界误扩成通用短快照兼容。
- catalog-free RunSession 分支仅保留冻结成长领域夹具自身的端口形状；配置正式 `RunContentCatalog` 的运行路径强制七槽和双向类型。独立 Review 应继续以 Task28 RunSession 测试确认正式候选在最终端口调用前被拒绝且原子状态不变。
- 任务29消费本七槽 Runtime；任务30负责最终 3+4 HUD。本交付没有提前实现二者。
