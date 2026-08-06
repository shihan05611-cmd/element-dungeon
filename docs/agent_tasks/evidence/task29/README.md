# 任务 29 执行证据

执行状态：`REVIEW`（仅执行侧交付，等待中枢 Review 5.0 独立验收；未自行 `ACCEPTED`）
阶段检查点：`1fd7c5d432469e87478cc9e504d16ad30e3d5732`
最终冷副本：`C:\tmp\element-dungeon-task29-exec-20260806-02\project`
独立 profile：`C:\tmp\element-dungeon-task29-exec-20260806-02\profile`

## 1. 实现结论

- `project.godot` 的唯一变化是把 `run/main_scene` 指向新正式入口 `res://scenes/run/run_game.tscn`；`TestRoom` 没有被修改，仍是独立调试/回归入口。
- `RunGame` 整局常驻唯一 `RunSessionHost / RunSession / Player / RunFlowSmokePanel / RuntimeSkillLoadout / PassiveEffectAdapter`。`RunFlowCoordinator` 只在 `RoomStaging` 验证候选并把新的 `RunRoomInstance` 迁入 `RoomContainer`，随后释放上一房实例。
- 冻结图含 15 个静态节点：入口、6 个战斗位置（第2战与第5战各二选一）、3 个商店、2 个路线、占位 Boss 与结果。所有合法路径恰好 `6 combat / 3 shop / 2 route / 1 result`。
- 路线选项冻结真实 target、遭遇、环境、风险与梦尘说明。路线1的压力分支加载 `room_arena_platforms.tscn`，路线2的风险分支加载 `room_arena_corridor.tscn`；不是同房刷怪。
- 战1敌人梦尘20、完成梦尘100，首商店前保底120，足够购买110梦尘主动技能。Boss敌人梦尘与完成梦尘均为0；Boss房完成事件在同一 `RunSession` 事务内冻结成功结果，不生成奖励或Boss后商店。
- 正式命令使用 `command_id + expected_revision`，路线还核对 option/target，商店继续核对 session/offer。重复完成、陈旧路线、场景切换失败、死亡与重复结算均结构化拒绝且不留下部分状态。
- smoke panel 只投影当前权威快照并转发路线/购买/离店命令；没有复制钱包、节点或结算权威，也没有提前实现任务30最终 HUD。

## 2. 常驻节点图与资源映射

```text
RunGame (RunFlowCoordinator, persistent)
├─ RoomStaging (candidate RunRoomInstance, hidden)
├─ RoomContainer (exactly one active RunRoomInstance, replaced per combat)
├─ Player (persistent)
├─ Camera2D (persistent)
├─ CombatFeedback (persistent, rebound to current enemies)
├─ SkillVfxCoordinator (persistent, enemy list rebound per room)
├─ RunSessionHost (persistent; owns one Session/seven-slot/passive runtime)
└─ RunFlowSmokePanel (persistent, read-only projection + command forwarding)
```

```text
run_entry
→ combat_01_entry
→ shop_01_early
→ route_01_first_branch
   ├─ route_01_swarm    → combat_02_swarm
   └─ route_01_pressure → combat_02_pressure
→ combat_03_layer_elite
→ shop_02_mid
→ combat_04_validation
→ route_02_second_branch
   ├─ route_02_stable → combat_05_stable
   └─ route_02_risk   → combat_05_risk
→ shop_03_preboss
→ combat_06_final_boss
→ run_result / RUN_COMPLETE
```

| 战斗资源 | PackedScene模板 | 敌人数 | 敌人梦尘合计 | 完成梦尘 | 备注 |
| --- | --- | ---: | ---: | ---: | --- |
| `combat_01_entry.tres` | `room_arena_flat.tscn` | 1 | 20 | 100 | 首商店保底120 |
| `combat_02_swarm.tres` | `room_arena_flat.tscn` | 2 | 30 | 70 | 路线1标准分支 |
| `combat_02_pressure.tres` | `room_arena_platforms.tscn` | 1 | 40 | 80 | 路线1高台分支 |
| `combat_03_layer_elite.tres` | `room_arena_platforms.tscn` | 1 | 35 | 90 | 第二商店前 |
| `combat_04_validation.tres` | `room_arena_flat.tscn` | 2 | 40 | 85 | 路线2前 |
| `combat_05_stable.tres` | `room_arena_flat.tscn` | 1 | 25 | 100 | 路线2稳妥分支 |
| `combat_05_risk.tres` | `room_arena_corridor.tscn` | 2 | 70 | 140 | 路线2风险分支 |
| `combat_06_final_boss.tres` | `room_arena_boss.tscn` | 1 | 0 | 0 | `final_boss=true`，直达结果 |

## 3. 修改实现与 SHA-256

| 路径 | SHA-256 |
| --- | --- |
| `project.godot` | `510469907C8686487AC845299F75BD22174499FCD208E3518B59073379D1E6FC` |
| `growth/contracts/run_phase.gd` | `9AA557BFAA7F1AFCCDA11CD5BB659B253CD9A382E2DE5D4F93B76B2CCF9CA032` |
| `growth/contracts/route_option.gd` | `57BBC93D3A8D171397502B9BFAF791890AC4D8AD1F991D407F589BD81F01B929` |
| `growth/contracts/route_snapshot.gd` | `1BCA7BF1D0354BB6FA418A258C9CC003EA9B35DB75382E2498CE96218D5D9A3C` |
| `growth/contracts/run_snapshot.gd` | `4498B5678685A77D015CD7F3281E6A8930603059F11225B919BFAA0D7F1B5CC0` |
| `growth/contracts/run_command_result.gd` | `20D2E36FE73A9498083D0CFC252838AD81F52E4462B0E335D999D606838D8659` |
| `growth/contracts/run_node_snapshot.gd` | `D9B6183AA786CE3762361534443F5377D18452F9BD9A5398A4FF30421B548275` |
| `growth/contracts/run_result_snapshot.gd` | `6D1C90D7D888FA88E84BE1528ED939C74602D894A5BFA3E91043A68EFBE57C54` |
| `growth/flow/run_node_kind.gd` | `91CC597F22E719D868F9A4AA596DDCBF3BD19930B90F9CD847AFF2C4CCC4F7D1` |
| `growth/flow/run_flow_definition.gd` | `B221072D4D7194688F25DC61E7DC36A8F52683D520ADAF37FDD40EE1539B764C` |
| `growth/flow/run_node_definition.gd` | `B6F81D1C14EFB54280EC25C8B2E27F7516E0FF4F45CCC015213EFEF9793A27FD` |
| `growth/flow/route_branch_definition.gd` | `6B9AA556D18E3C29A9B7DB1EEA78C0FA4112A94C03B1BA5722811AFAD31B171F` |
| `growth/flow/combat_room_definition.gd` | `CAA66517314D5C0A4FA05A38DE1D46E8971A6A0A027D552821C418F507B6BA19` |
| `growth/flow/enemy_spawn_definition.gd` | `808B936E47810D7AF3BA7CF2A246A93E1719FC36FF10688729ADB92AA501A9D0` |
| `growth/state/route_state.gd` | `D7426FB8FB160913AC482AAB9BC8081C3325760BEEF00EAD8DEA90B043E72B44` |
| `growth/run_director.gd` | `D8D686DA7D8C4DA53488AD26E0151D88C8C166556F1126562F7803C44BCC325C` |
| `growth/run_session.gd` | `BC15697D3FA7595AFE4337173CD09E2CEE8C38B061F67E8BC87E78247B6B3BA3` |
| `scripts/run_session_host.gd` | `FF7673E219B015377CF4A4D9E9F0660B2E765D7AC2D669A8A74B8DEBB8EE5C36` |
| `scripts/enemy.gd` | `AB4236288E0A0C4C9962F37498E56B6D39F47DF53B21B91ACC8B9B28CE763493` |
| `scripts/run/run_flow_coordinator.gd` | `951360685D2A3AF92EC9CCAD4CD3C2F35B54CA24CFEA5CDA4B98127D96BF914D` |
| `scripts/run/run_room_instance.gd` | `641F4EB779B86EDE31382B42D9F08589EFB87EC9A3F16CF4D37F88876FB646AB` |
| `scripts/run/run_flow_smoke_panel.gd` | `D9E02542173220C3FD1007C85E7181E16655BF727D0A3009DEC68B5A3A78EA86` |
| `scenes/run/run_game.tscn` | `57A1FFE0DF042195A69E73641493C51EC02628A346AE78FD8BC513497C40E851` |
| `scenes/run/run_flow_smoke_panel.tscn` | `8637C68209272A77FA4C8BCC55635BBCFE80E0D4F1E8E90CC9286DBF96B3A4DA` |
| `scenes/run/rooms/room_arena_flat.tscn` | `EB83D26421ECC95DCB40EF3FC8C8CB3491B317983861C9A6F72E2F3D895E0E02` |
| `scenes/run/rooms/room_arena_platforms.tscn` | `9F4E1DC72B4F8FBB056D1D58A765AA48C52A0C27940D5C1C1FB7DCDB6D5763A3` |
| `scenes/run/rooms/room_arena_corridor.tscn` | `68F65EAD824B87EC9CDAF699C1AFFF9151BB4564F376357515948BCA79FC0768` |
| `scenes/run/rooms/room_arena_boss.tscn` | `ED30B8D34EE65A598137F191195B4EC91307E54A5F213BF85BD3873FA47A519F` |
| `resources/run/flows/prototype_two_layer_six_combat.tres` | `C78128A6278985EFE6E51B66D3D818E3449937D99E855B0D0FCE9A43110C6060` |
| `resources/run/rooms/combat_01_entry.tres` | `1ABA744240845E201D54E814FA5A3FAEF576C4778438AB36C315EECFECAF2FA7` |
| `resources/run/rooms/combat_02_swarm.tres` | `802335A83F5F4640D6DC45F7EA43013EF7E1145C6A19FF6330A48C80F80C3226` |
| `resources/run/rooms/combat_02_pressure.tres` | `5213A1203714EEE3EFE5E25CACE60AC945DE2F42725751F212BED02ED17BEF58` |
| `resources/run/rooms/combat_03_layer_elite.tres` | `441DFEE1AFBBF926A05C9393EFE36E778AB9532367CACC72ADF04A07D81918C6` |
| `resources/run/rooms/combat_04_validation.tres` | `4ED7C8B00146D6957C622278B8C982C5DD9B5495BB6CC71495598124819D1CD0` |
| `resources/run/rooms/combat_05_stable.tres` | `587C29952168825FC480520C9A7D30FBB3989D25A2BA82210DF7BBF7B5E32202` |
| `resources/run/rooms/combat_05_risk.tres` | `B37CFFFDA1150DE79A0CB7B0E5A935A65D9B6623B7CF8217199095E66099C018` |
| `resources/run/rooms/combat_06_final_boss.tres` | `F7D47ADABB930C4F320403DC454CEBCB9BAE8962F7D6704B66A9EE93ABFCF365` |
| `growth/tests/run_task29_run_flow_contract_tests.gd` | `76556678E21B28012A8DFCBA9AFF7CA348236D367B837413CD25D0E6360FDC6F` |
| `combat/tests/run_task29_real_room_flow_tests.gd` | `A82CC7B078110EA90BDEF88E6AB11408F83EE86B2E4BB86EE948BF69F1F8940E` |
| `combat/tests/capture_task29_full_run_visual.gd` | `BBDEEEDD6694D56D0D94175B5341A0A66BF2C609A2A47EFA3D0E7D4CDD004EE4` |

任务书、本 README、29份正式日志、Task20非门禁日志与四张 PNG 均位于任务29 allowlist 的协调/证据路径；冻结后的中枢交接清单可再次计算其最终 SHA。

## 4. 冷副本与自动化

- 最终复制排除 `.git/.godot/.workbuddy`；共享源与 `-02` 冷副本均为 `1376 files / 39,700,066 bytes`，逐文件 SHA-256 `0 mismatch`。
- `-02` 的第一条 Godot 命令是 Godot `4.7.1.stable.official.a13da4feb` headless editor scan，exit `0`。
- Task29领域 runner：`6 tests / 166 assertions`，exit `0`。
- Task29真实房间 runner：`1 test / 93 assertions`，exit `0`。它从 `run_game.tscn` 开始，经真实 `CombatReceiver` 击杀、商店和路线命令完成六房；没有直接调用终局方法。
- Task29两项合计 `2/2 runners / 7 tests / 259 assertions`；加任务28接受基线后为 `25/25 runners / 273 tests / 2905 assertions`。
- 任务28接受基线逐项恢复：`23/23 runners / 266 tests / 2646 assertions`，每项 exit `0`。Task12/16/18/24 分别保持 `13/110、11/209、9/124、10/190`。
- `res://scenes/run/run_game.tscn` 180帧 smoke：exit `0`；`res://scenes/test_room.tscn` 180帧 smoke：exit `0`。
- 完整一局图形捕获：`1 test / 59 assertions / 4 screenshots`，exit `0`。保存前已断言六战、三商店、两路线、完整结果、Boss零梦尘、六个不同房实例、至少四种模板，以及Host/Session/Player/panel/七槽Runtime/被动Runtime实例ID整局不变。
- 29份正式日志（scan、Task29、23基线、双smoke、capture）中的 `SCRIPT ERROR / Parse Error / ERROR: / WARNING:` 均为 `0`。
- Task20历史 runner单列：仍为 `BLOCKED`，exit `1`，`7 failures / 83 assertions`；`4 SCRIPT ERROR / 0 Parse Error / 1 standalone ERROR / 0 WARNING`，未计入任务29门禁，也未据此接受任务20。

日志索引：`01_editor_scan.log`、`02_task29_contract.log`、`03_task29_real_room.log`、`04_baseline23/*.log`、`05_task20_non_gate.log`、`06_run_game_180_frames.log`、`07_test_room_180_frames.log`、`08_full_run_visual_capture.log`。

## 5. 实际 Viewport 与人工检查

| 文件 | 实际尺寸 | 字节 | SHA-256 | 检查结果 |
| --- | ---: | ---: | --- | --- |
| `01_combat_01_entry_1920x1080.png` | 1920×1080 | 125369 | `F14E401458ED0897CBE2B6E289B9DFA74AA0D789F9F4957347C80370DDEF430E` | 战1平地、Player、敌人与常驻panel清楚；显示房ID和模板路径 |
| `02_route_01_choice_1920x1080.png` | 1920×1080 | 187708 | `A7E64216EFCE75B5C0F9F12AB99363A68D04B57C9E776F14392B4CE54D836CA8` | 两路线的遭遇/环境/风险/梦尘披露及真实选择按钮可读 |
| `03_platform_room_1920x1080.png` | 1920×1080 | 138324 | `E191B2430EB7F58E7EDAB70363FE34767E92375EF1D339BEFE82EB9E2FA435DF` | 压力分支切到紫晶双层平台，和入口平地存在明确模板差异 |
| `04_boss_result_1920x1080.png` | 1920×1080 | 161393 | `7304A05827639F80CCB88E1DEF65E84C67924DD68B680D37CF61B27220CE2F65` | Boss王座仍可见；panel显示通关、六战6/6、商店3/3、路线2/2及Boss零梦尘直达结算 |

捕获由独立、非编辑器、非headless的 Godot 4.7.1 Windows Viewport 从正式 `RunGame` 入口实际完成。执行侧已用原图模式逐张打开四张 PNG：画面非空、尺寸正确；战1与平台房差异明确；路线交互文字可读；Boss后结果没有奖励或第四商店。panel是任务29最小smoke交互层，不代表任务30最终HUD；占位敌人、伤害数字和房间几何留待任务31精调。

## 6. 共享编辑器与保护对账

- 全程未在共享项目调用 Godot/MCP save、reload、reimport、运行、测试或截图；共享 Godot PID `5036` 未被控制或关闭。所有命令仅进入全新 `C:\tmp` 冷副本/profile。
- 开始时共享 `.godot` 为 `704 files / 34,759,094 bytes`，任务执行清单指纹 `40BAE0D6673F4857074F4BCFFAD17053A8CBCE8B9D65935E001F21314125E042`。共享编辑器于17:33被动扫描后变为 `705 files / 34,863,310 bytes`；已观察到 `global_script_class_cache.cfg`、`editor/filesystem_cache10`、`uid_cache.bin`、`editor/project_metadata.cfg` 更新，并新增Task28截图的 `.ctex/.md5` 缓存。未删除或回滚这些共享缓存变化，也未把它们纳入交付。
- 开始时既有19项未跟踪 UID/import 路径保持原样。共享编辑器17:33被动新增9项任务29脚本 sidecar：`growth/flow/{combat_room_definition,enemy_spawn_definition,route_branch_definition,run_flow_definition,run_node_definition,run_node_kind}.gd.uid` 与 `scripts/run/{run_flow_coordinator,run_flow_smoke_panel,run_room_instance}.gd.uid`。最终为28项；这些sidecar未删除、未暂存、未认领为实现文件。
- `.workbuddy/**` 与 `docs/架构评估与扩展性改进建议.md` 继续保持既有未跟踪保护状态。`scenes/test_room.tscn`、`scripts/test_room.gd`、Task20、Task24与历史证据均为零diff。
- `project.godot` diff只有 `run/main_scene` 一行。实现、场景、资源和runner修改严格在任务29 allowlist；`ShopDraft`和`SkillVfxCoordinator`现有接口已经足够，因此保持零diff。
- Git写操作为零：未执行 add、commit、push、reset、restore、checkout、clean、stash 或分支操作；HEAD保持 `1fd7c5d432469e87478cc9e504d16ad30e3d5732`。

## 7. Review提示与遗留风险

- 中枢应重点独立复核 `RunFlowCoordinator` 的“先实例化/验证候选，再提交权威房间激活，再换容器”的顺序，以及失败结果是否满足任务书对旧房/明确失败的边界。
- 正式流程兼容旧 `TestRoom` 是通过无 `RunFlowDefinition` 时保留legacy路径完成；独立Review应同时跑新入口和TestRoom smoke，防止任一分支被后续改动破坏。
- 本任务刻意只提供最小可玩房间与smoke panel。最终HUD/商店/路线/结算UI属于任务30，房间美术、敌人配置、Boss阶段和数值体验属于任务31；本交付不应以这些未完成项否定任务29场景接线门禁，也不应把占位质量视为最终完成。
- 共享 `.godot` 与9项 `.gd.uid` 是用户允许编辑器保持开启时产生的被动漂移，已单列且未处理；中枢独立验收时应继续保护，不要混入任务29修改集。
