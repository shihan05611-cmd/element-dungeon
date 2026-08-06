# Task30 执行侧第二次 Review 整改证据

状态：`ACCEPTED`（中枢 Review 5.0 已在第三个全新冷副本独立验收通过；保留两次独立 Review `FAIL` 记录）

## 两次独立 Review 失败记录

1. 第一次 Review 的自动化与共享保护通过，但 `04_colorblind_reduced_motion_1920x1080.png` 中反馈层遮住 P1，且旧 15 图未覆盖真实 RunGame Fury/Laser/Reclaim 与伤害数字。本轮保留该失败记录；正式 HUD 反馈已移入安全带，三档分辨率均在反馈可见时断言其与 status/active/passive 三区不相交，并从真实权威配装/释放路径生成技能证据。
2. 第二次 Review 的 26 runners、双 smoke、`1/427/20` capture、Laser/Fury 与共享保护通过，但其新生成的 17 图在独立验收预览中出现 HP、CurrentElement 与部分 A1–A3 内容缺失。旧断言只覆盖外层 panel，不能证明子内容与最终像素完整，因此任务再次恢复为 `IN_PROGRESS`。本节不覆盖该失败结论。

## 第二次整改定位与门禁

- 只读诊断确认真实 Reclaim 帧的 HUD `CanvasLayer`、Control transform、clip、z-order 和子控件 global rect 均稳定；Godot 实际 Viewport 像素与保存后的正式 PNG 像素中，HP label/bar/value、CurrentElement 形状/短文字/颜色、A1–A3 名称/状态始终存在。第二次 Review 看到的缺失来自大尺寸稀疏全图的预览/读图呈现层，并非游戏 HUD 或 PNG 像素缺失。
- 正式反馈动画现在只改变透明度，不改变 Control 位置；CurrentElement 不再使用 0.52 透明度表达状态，三重语义保持全不透明。
- capture 在连续两个 completed draw 及最终保存帧，对 HP label/bar/value、CurrentElement swatch/shape/text、A1–A3 name/state 分别断言：节点可解析、visible、文本非空、实际 global rect 位于所属 panel 和 Viewport 内、最终 modulate alpha 为 1；另断言 HUD CanvasLayer 不低于 10 且 transform 为 identity。
- 保存前将逻辑 1152×648 几何映射到实际 1920×1080 Viewport，在上述子内容的最终物理矩形内执行亮像素门禁，同时保持真实 Reclaim presentation、伤害数字、玩家、敌人与世界几何活动。保存统一生成无 alpha RGB8 标准 PNG；写回后重新加载、转 RGB8，并逐字节断言解码像素与已通过门禁的 Viewport 图像完全一致。
- 正式 17 图未裁剪、未删除、未换成不含 Reclaim 的时刻，也未移动/修改 VFX；其中仍同时显示 Reclaim、伤害 5、玩家、敌人与房间。诊断用小区域只在项目外只读生成，用于证明同一原 PNG 像素完整，不属于正式 evidence，也没有替代 20 张全图。

## 实现与权威接线

- `RunGame` 使用正式 `CombatHUD`；Host、Player、RoomStaging、RoomContainer、flow 与 content catalog 未改变。
- HUD 严格分为 A1–A3 主动槽和低权重 P1–P4 被动槽，显示 HP、SP、CurrentElement；正式画面不显示目标附着文字、跟随标签或离屏文字回退。
- 商店只读 Task29/27 snapshot；购买、升级、重置、Task25 即时七槽装配与离店命令均经 `RunFlowCoordinator` 薄转发到权威事务。UI 不直接写 `RuntimeLoadout`、钱包、等级、返还或 revision。
- 路线卡只读冻结 snapshot；聚焦不提交，独立确认携带冻结 revision，陈旧/重复请求不本地推进。
- 成功/失败结算只读冻结 `RunResultSnapshot`。Boss 后没有奖励/商店；经验、属性点、遗物与旧免费奖励不进入正式 RunGame。Task20 继续历史 `BLOCKED`、非门禁。

UI/UX 检查使用 `ui-ux-pro-max` 的游戏 HUD、暗色可访问性和响应式指导，落实为固定安全区、颜色+文字/形状冗余、焦点描边、44px 以上动作区、三档边界与减少动态反馈不遮挡。

## 最终冷副本与命令纪律

- 冷副本：`C:\tmp\element-dungeon-task30-reclaim-final2-20260806-01\project`
- 独立 profile：`C:\tmp\element-dungeon-task30-reclaim-final2-20260806-01\profile\Roaming` 与 `...\profile\Local`
- Godot：`4.7.1.stable.official.a13da4feb`
- 根目录此前不存在。复制后、任何 Godot 命令前，把复制来的旧 20 张 PNG 移到 project 外 `copied_old_viewport_backup`；冷副本 Viewport 目录为空。扫描前复制为 1,456 files / 40,574,400 bytes，`.godot` 不存在。
- 第一条 Godot 命令是 4.7.1 headless editor scan，exit `0`，stdout 66,379 bytes、stderr 0；五类标记全 `0`。全部验证后 final editor rescan exit `0`，stdout 6,752 bytes、stderr 0、五类标记全 `0`。
- 最终共享/冷副本 manifest（排除 `.git/.godot/.workbuddy`、全部 `*.gd.uid`/`*.import` 及记录该值的本 README）为 `937 files / 43,903,165 bytes / CCE2BC398F42406D9071CFF0D74D225D6344003405BC10F0B91126B42BCD2805`；only-shared / only-cold / content mismatch 均为 `0`。本 README 另以共享/冷副本 SHA 完全相等核对。

## 自动化结果

- Task30 主 runner：`9 tests / 172 assertions`，exit `0`。
- 既有接受门禁：`25/25 runners / 273 tests / 2955 assertions`，全部 exit `0`。
- 合计正式门禁：`26/26 runners / 282 tests / 3127 assertions`。
- 接受数字迁移：Task12 `13/110 -> 13/113`（+3），Task24 `10/190 -> 10/237`（+47）；Task16 `11/209`、Task18 `9/124` 不变，未删除仍有效合同。
- Task20 非门禁：`7 tests / 68 assertions`，exit `0`；不计入 26-runner，也不改变历史状态。
- `run_game.tscn` 与 `test_room.tscn` 180 帧 smoke：均 exit `0`。
- 非 headless 实际 RunGame capture：OpenGL 3.3 / NVIDIA RTX 2060，`1 test / 1264 assertions / 20 screenshots`，exit `0`。
- 正式证据 32 个日志 / 91,521 bytes；`SCRIPT ERROR` / `Parse Error` / `ERROR:` / `WARNING:` / `CrashHandlerException` 均为 `0`。日志 aggregate SHA-256（相对路径、bytes、单文件 SHA，UTF-8/LF）：`0614FF26A98A65353C2FD5FD0276527EA11F260A6331B8D2EE0E84053A5DA660`。

## Viewport 保存前断言与人工检查

每张 PNG 保存前均断言实际窗口/Viewport 分辨率与 authority phase。三张可访问性图在真实反馈可见时断言其与 status/active/passive 三块 HUD 不相交。Laser/Reclaim/Fury 三图额外断言真实 RunGame phase、权威七槽 mapping、实际 presentation 类型/状态、伤害 label、玩家/敌人/房间/VFX bounds，以及这些世界关键几何不与 HUD 相交。Reclaim 保存还通过上述 1,264 条中的子控件几何、物理像素与 PNG 解码往返门禁。

执行者逐张以原始分辨率打开 20 张正式全图；正式 17 图完整显示 HP、SP、CurrentElement、A1–A3、Reclaim、伤害 5、角色和敌人。Laser、Fury、三档反馈、商店、路线与结算继续通过。某些大尺寸稀疏全图预览器可能偶发不显示孤立 HUD 区域；同一正式 PNG 的精确像素统计、原像素区域读取和 capture 解码往返均证明文件本体完整，此预览器限制作为遗留审阅风险单列，不以裁图规避。

| 文件 | 尺寸 | Bytes | SHA-256 | 人工/门禁结论 |
| --- | ---: | ---: | --- | --- |
| `viewport/01_combat_hud_1920x1080.png` | 1920×1080 | 71,183 | `A00427C6013C0BD23BC46ADF6D28131AD9E8E145AD7A05EA72B1EEC3CBB62DD3` | 基础 HUD/房间像素完整 |
| `viewport/02_combat_hud_2560x1440.png` | 2560×1440 | 105,964 | `80FC1900AF19E7C4F3C6850053C574D4821DAFA85915AEC3647A5A1F3206418E` | 大屏七槽清楚 |
| `viewport/03_combat_hud_1366x768.png` | 1366×768 | 50,110 | `867338192A9067FCA378CAF152A3C9C6841F6D53C5633F8622CE2042F0D2475B` | 压力尺寸无重叠 |
| `viewport/04_colorblind_reduced_motion_1920x1080.png` | 1920×1080 | 86,552 | `57D8F131681F5D2C34FEB0D9F1B9359B565F8F5271A951B2621F279A9AF2CBA7` | 反馈与三 HUD 区不相交 |
| `viewport/04b_colorblind_reduced_motion_2560x1440.png` | 2560×1440 | 127,338 | `C5817A52FF9893875DD80261F59AFA2EDA644743A35D1FE8792AA6E928E86609` | 大屏反馈安全区通过 |
| `viewport/04c_colorblind_reduced_motion_1366x768.png` | 1366×768 | 61,359 | `2A5325721AF0C7515FACF758CFEFBBEACB1588AAE2F100EE0DC04E5303B175B8` | 窄屏反馈安全区通过 |
| `viewport/05_early_shop_1920x1080.png` | 1920×1080 | 308,158 | `4535C867AB65135C3D831831C69035D29DDAE47495EED50F8D206F971F30C1D8` | 账本/候选/七槽完整 |
| `viewport/06_early_shop_2560x1440.png` | 2560×1440 | 451,882 | `ABE8AE935734D1F180332EDF3D0870B862F0A1DD3216DB5D36204E9CC5B54717` | 大屏比例清楚 |
| `viewport/07_early_shop_1366x768.png` | 1366×768 | 205,192 | `890735D068AA0CED482CAEFD57D49DE11AB45D5FFFA98BB8F0FFC41A011137CC` | 无水平溢出，纵向可滚动 |
| `viewport/08_shop_seven_slot_zones_1920x1080.png` | 1920×1080 | 335,594 | `F230693B7EBFC69007BB5B02A66B6DF13BD85BDE45C2A03C1F35C2E98D337F1C` | 即时七槽状态一致 |
| `viewport/09_route_focused_1920x1080.png` | 1920×1080 | 172,289 | `B0AE7DB174424964D1A9E5121726569ABA7017EEBDEB6E3477EB0C80B917B360` | 聚焦不选择、确认独立 |
| `viewport/10_route_focused_2560x1440.png` | 2560×1440 | 254,425 | `C414B14A98CAF2B7C9713157062AD66F2DA7ADDEFFE2E8789124E606CC8CCB58` | 冻结字段完整 |
| `viewport/11_route_focused_1366x768.png` | 1366×768 | 117,061 | `0D4A6C0609083B75269EC4DC454C86F7F8F1E78762C01DA4A4857527CCD1CE4D` | 压力尺寸清楚 |
| `viewport/12_stale_route_recovery_1920x1080.png` | 1920×1080 | 177,045 | `9E067F029622352A7CEE8C51BB6B28E81F3B1AC96030B05E4A4E25E9AD26EE70` | 陈旧拒绝可见且可恢复 |
| `viewport/13_complete_result_1920x1080.png` | 1920×1080 | 202,628 | `89417AB3F399ABCCD26EB8E8CE9F0D59C5F9B6DA1543F3BDBC4A287A5723CABE` | 通关账本/七槽完整 |
| `viewport/14_complete_result_2560x1440.png` | 2560×1440 | 293,251 | `E8207F44C90EE59CE5CCA91B1ECA67FFD8F8C7F5D4255ACF6FADB511379C2D4D` | 大屏结算层级清楚 |
| `viewport/15_failed_result_1920x1080.png` | 1920×1080 | 172,310 | `93030C610CF0A73EE8E9C04B026FC3E7000BEE26B40BA603C746772DD0D2A5B2` | 失败 outcome 明确 |
| `viewport/16_laser_damage_1920x1080.png` | 1920×1080 | 95,875 | `EBEA64E88FA98BD76C4C9E5E7E8D938B801E9CB59F12CF5E4CBE31CE143BE0FF` | 真实 Laser/伤害 4/角色清楚 |
| `viewport/17_reclaim_authority_1920x1080.png` | 1920×1080 | 108,903 | `FEE669F984C768CEA29B19A6DAC122DD96BEB038BDD559ADDB4381C7A57D1BAD` | 真实 Reclaim/伤害 5；HUD 子内容与解码像素门禁通过 |
| `viewport/18_fury_damage_1920x1080.png` | 1920×1080 | 118,060 | `5EDA0D2E0D4D29C690DE63759E207ADAFD847CBD070206AE2A9C150CBF15FCBE` | 真实 Fury/伤害 13/范围清楚 |

PNG 合计 20 个 / 3,515,179 bytes；aggregate SHA-256（相对路径、尺寸、bytes、单文件 SHA，UTF-8/LF）：`EB0E734AAE239A7A35D89622C50115ED55F0FAA36D4FEDCC1FA9FF02ABEC056E`。

## 修改文件与 SHA-256

| 文件 | Bytes | SHA-256 |
| --- | ---: | --- |
| `combat/tests/run_compact_hud_reward_tests.gd` | 15,645 | `47F14CFD8CCFF8861620E21E846DA500833EF1D1CFB4925BD9B0988A09267560` |
| `combat/tests/run_hud_loadout_feedback_tests.gd` | 21,720 | `4D9DB8EC66C87612C07A94E3F41324041C6AC4321BB611DA1C8DA4A90F46EC19` |
| `combat/tests/run_task24_compact_hud_reward_tests.gd` | 23,330 | `16F3C697B7DA2105931E9AA216FB01965E0759C50517FE1FD2F43057DAF90A25` |
| `combat/tests/run_task30_run_ui_tests.gd` | 24,428 | `E1589B21829F0BC2C0AE82EFB2F712265C07957C0C5817FF140BEDBB253F1702` |
| `combat/tests/capture_task30_run_ui_visuals.gd` | 44,576 | `601DDCB979D654B801E7623E47007ADB86512EC98BBA3228B8397DF276408130` |
| `scenes/run/run_game.tscn` | 1,642 | `F2AACE09C00D45DAEBBE96E58EECB2DF3BD5193C0CD3A00B706F4BA774BC6442` |
| `scripts/combat_hud.gd` | 50,031 | `4F5F355554D0C0A22B32FC95556CF8976D4F20970F23A5825B560FEE7B110D27` |
| `scripts/run/run_flow_coordinator.gd` | 11,926 | `DA5738213AD3CEB1E06E4A3A9EEC459752F601E14824EC0F1ED10F9C531109CD` |
| `scripts/ui/run_overlay_interface.gd` | 80,665 | `ED2C56783F7EA281BDCA45BD49B359E87A9F6346FEDACC5B8A8AA337C51A209D` |
| `docs/agent_tasks/pending/30_run_hud_shop_route_results_ui.md` | 24,539 | `092569DBAEE3947FD613DE704CFFF0E8819384D341844DA687E47F01440F70CE` |

本表覆盖全部游戏/runner/capture/任务书变更；本 README、32 个日志和 20 张 PNG 由 aggregate 与逐图 SHA 覆盖。

## 共享区保护与外部被动漂移

- 分发/完成 HEAD 均为 `a33e17e9eea7bba7a76b72e351bd32d40a3e5e56`；Task29 接受实现检查点 `dc834ff27a500b5259b7be244ee3febf61704429` 未被改写。allowlist 外 tracked diff 为 `0`；Task29 authority/场景、Task20/24 历史 evidence 均无 tracked diff。
- 用户要求共享编辑器保持开启。共享 Godot PID 43452 于 `2026-08-06 20:46:17.009 +08:00` 启动；执行者从未调用、控制、保存、reload、reimport、运行或关闭共享 Godot/MCP。
- 中枢给出的启动前基线：共享 `.godot` 705 files / 34,863,310 bytes / aggregate `B1D1398FC97EDA2E06273944F023BE9EE4EF54220E0101120A889F8A6196314E`；未跟踪 sidecar 28 files / 2,613 bytes / aggregate `673AFE3AECE3F7D623FED285C1A61202471236690E92B668A5FCD63E0B730138`。
- 启动后稳定值：共享 `.godot` 754 files / 37,416,266 bytes / aggregate `F414CAE65C785E49FBEA99EA628E51E593B652B671F5CFBBB1AA47AAD7284788`；未跟踪 sidecar 66 files / 28,555 bytes / aggregate `FF18D5159ECCE5F6974A11F9E1E968DBD3273923811C6C99D2A9D359E72D2A3D`。aggregate 均按相对共享根路径、bytes、单文件 SHA、UTF-8/Windows CRLF 计算。
- 38 个新增 sidecar 的写入时间集中在 `20:46:29.269–20:46:32.211`，均在编辑器启动后 12–15 秒；在 `21:38:03`、最终 PNG/日志同步后的 `21:39:34` 以及交付冻结前的 `21:46:29` 三次复核中，数量、字节、aggregate 和最新写入时间完全不变。
- 新增路径精确分组：`combat/loadouts/{seven_slot_migration_result,shared_four_slot_to_seven_slot_migrator}.gd.uid`；`combat/tests/{capture_task24_visuals,capture_task28_four_passives_visual,capture_task29_full_run_visual,capture_task30_run_ui_visuals,run_task24_compact_hud_reward_tests,run_task28_seven_slot_passive_tests,run_task29_real_room_flow_tests,run_task30_run_ui_tests}.gd.uid`；Task28 的 1 张、Task29 的 4 张既有 evidence PNG `.import`；本表 20 张 Task30 PNG 对应的 `.import`；`growth/contracts/{run_node_snapshot,run_result_snapshot}.gd.uid` 与 `growth/tests/run_task29_run_flow_contract_tests.gd.uid`。
- 上述路径均是该编辑器对本轮新增/更新脚本与 evidence 的被动 auto-import，可精确归因且已稳定；执行者不删除、不修改、不认领、不暂存，交由中枢独立复核。若独立验收的图像预览层仍复现稀疏区域漏显，应以正式 PNG 原像素/解码往返和另一个原尺寸解码器交叉核对；这是当前唯一新增审阅风险。
- 当前项目没有独立标题入口，因此“返回入口”明确禁用；“开始新一局”可用。正式场景不实例化 smoke panel，但保留只读兼容别名供 Task29 接受 runner 使用。
- Git 写操作为零：未执行 add/commit/push/reset/restore/checkout/clean/stash，未自行验收。

## 中枢 Review 5.0 独立验收

- 冷副本：`C:\tmp\element-dungeon-task30-review5-final-20260806-02\project`；独立 profile 为同根 `profile\Roaming` / `profile\Local`。复制核对 `1476/1476 files / 44,116,600 bytes / 0 mismatch`，首条 Godot 前 `.godot` 不存在，复制来的旧 20 PNG 与对应 import 已先移至项目外可恢复备份。
- 首条 4.7.1 headless editor scan、`26/26 runners / 282 tests / 3127 assertions`、Task20 单列 `7/68`、RunGame/TestRoom 双 180 帧 smoke、真实 RunGame capture `1/1264/20` 和 capture 后 rescan 全部 exit `0`。32 份 Review 日志共 67,994 bytes，五类错误/警告标记全 `0`。
- 中枢逐张打开本轮 20 张全新 Viewport；全部布局与状态通过。Reclaim 全图在当前预览器中的稀疏行漏显，经同一正式 PNG 的 Windows `System.Drawing` 独立解码整图和原像素裁片交叉复核为完整；正式文件不裁切、不替换，capture 的保存前物理像素门禁与保存后逐字节回读同时通过。
- 验收后 allowlist 外 tracked diff 为 `0`；Task29/20/24 保护路径无 diff；共享 `.godot` 稳定为 `754 files / 37,416,266 bytes`，未跟踪 sidecar 稳定为 `66 files / 28,555 bytes`，共享 Godot 进程保持被动开启且未被 Review 控制。
