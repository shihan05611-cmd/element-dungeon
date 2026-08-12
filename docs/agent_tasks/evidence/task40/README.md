# Task40 Review evidence

## 结论

Task40 已按任务书完成正式商店鼠标拖拽装配与必要 HUD 紧凑化。拖拽和原点击路径都只调用现有 `RunFlowCoordinator.apply_shop_loadout`，最终进入 `RunSession.apply_shop_loadout_immediately`；UI 不预写槽位、不复制类型/拥有权/revision/钱包权威。正式门禁为 `31/31 runners / 308 tests / 4256 assertions`，Task40 专项为 `4 tests / 94 assertions`；RunGame/TestRoom 双 180 帧 smoke、7 张真实 Viewport capture、capture 后 final editor rescan 均 exit 0。37 份日志中的 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:`、`CrashHandlerException` 都为 0。

## 实现合同

- 正式商店的已拥有技能卡和已装备槽都接入 Godot `set_drag_forwarding`；preview 只显示权威 icon、短名和 ACTIVE/PASSIVE 类型。
- 卡片到槽与同类型槽到槽换位都只构造一个候选 `RuntimeLoadoutSnapshot`，每次 drop 最多调用一次 `apply_shop_loadout`。成功后从权威 result/draft 重读；非法类型、未拥有、陈旧来源或其他权威拒绝均不改钱包、revision 或七槽，并显示既有短反馈。
- “点击技能 → 点击槽位”、卸下、购买、升级、重置和键盘焦点路径保留；鼠标取消拖拽不产生任何提交。没有扩展触摸、手柄、撤销栈、吸附历史或新 UI 架构。
- HUD 常态 ready `State` 为空且隐藏；BusyStrip 不创建。真实 cooldown mask/秒数、SP 不足、忙碌/失败短反馈、键帽、图标、短名、主动等级/SP 成本和被动分区保留。
- 固定几何为 HP/SP `264×76`、主动条 `532×72`、被动条 `496×56`。HP/SP 胶囊从 `y=124` 下移到 `y=168`，没有修改房间标题权威；2560×1440 狭廊标题与胶囊矩形不再相交。

## 冷副本、UID 与 sidecar 来源

- UID 生成副本：`C:\tmp\element-dungeon-task40-exec-20260812-02`。创建时 project 不含 `.godot`，两份 Task40 `.gd.uid` 均不存在；第一条 Godot 命令是独立 `APPDATA/LOCALAPPDATA` profile 下的 Godot `4.7.1` headless editor scan，日志为 `01_initial_editor_scan.log`，exit 0、五类标记 0。
- `combat/tests/run_task40_drag_compact_hud_tests.gd.uid`：`uid://vk3g802cr0j`，18 bytes，SHA-256 `7A83BDBCA15616C3D13CC4EF74EA821A2B2084E07BDB4697FCF6EB3B6AEF493E`。
- `combat/tests/capture_task40_drag_compact_hud_visuals.gd.uid`：`uid://blg2aq4c3ciuf`，20 bytes，SHA-256 `9C392A369F50CEBA5F3B9FA3A1B95F63C3B9B5A61FFAFE9C9502C277CC027850`。
- 上述两个文件由 scan 生成后逐文件精确复制回共享区，值、长度和 SHA-256 全部一致；没有手写 UID，没有复制其他 sidecar，没有触碰任何既有 `.gd.uid`/`.import`。
- 最终门禁副本：`C:\tmp\element-dungeon-task40-final-20260812-03`。创建前不存在，源/副本为 `2526/2526` files、0 only-source、0 only-cold、0 size mismatch；不含 `.git`/`.godot`，独立 profile。第一条 Godot 命令仍为 4.7.1 headless editor scan，两份 UID 与首次生成值及 SHA 完全一致。
- final rescan 在冷副本内为 7 张 PNG 生成了 7 个 `.import`，这些文件没有回流；共享 `evidence/task40` 为 7 PNG、0 `.import`。

## 验证结果

### 正式 runner

`logs/formal31/summary.csv` 记录每个 runner 的路径、exit 与最终 PASSED 行。集合是已冻结的 29 个 accepted baseline，加 Task38、Task40；31/31 全部 exit 0，总计 308 tests / 4256 assertions。Task40 专项覆盖：

- 技能卡合法 drop、主动/被动双向非法 drop、未拥有拒绝、陈旧槽来源拒绝与权威恢复；
- 槽到槽换位、单次 drop 单次 revision、RuntimeLoadout 与 snapshot 一致；
- 取消拖拽零状态变化，原点击路径继续即时生效；
- preview 的权威 icon/短名/类型；
- 常态无“可用”、无 BusyStrip，真实 cooldown mask/秒数、SP 不足和忙碌失败反馈仍可见；
- `2560×1600`、`3840×2160`、`3440×1440` 三档程序化验证：三块核心 HUD 均在安全区、固定尺寸不横向拉伸，主动条保持水平居中，关键 icon/短名/键帽字体可读，核心区域互不覆盖。

Task20 runner 按任务书单列运行，结果为 7 tests / 68 assertions、exit 0；这里只迁移 ready/BusyStrip 直接相关断言，不据此追认 Task20，其历史任务状态继续 `BLOCKED`。

### Smoke、capture 与 rescan

- `logs/run_game_180_frames.log`：RunGame `--quit-after 180`，exit 0。
- `logs/test_room_180_frames.log`：TestRoom `--quit-after 180`，exit 0。
- `logs/task40_visual_capture.log`：真实非 headless RunGame，`1 test / 140 assertions / 7 screenshots`，exit 0；保存前检查尺寸、phase、revision、七槽、RuntimeLoadout、节点可见性、安全区与狭廊标题不相交，保存后逐图像素 round-trip 一致。
- `logs/final_editor_rescan.log`：capture 后 Godot 4.7.1 editor rescan，exit 0。
- `logs/01_final_initial_scan.log`、31 个正式 runner 日志、Task20、双 smoke、capture、rescan 共 37 logs；五类标记全部为 0。

## 7 张最终截图

| 文件 | 尺寸 | bytes | SHA-256 | 原尺寸人工检查 |
|---|---:|---:|---|---|
| `viewport/01_combat_hud_1920x1080.png` | 1920×1080 | 71,754 | `0C7398B847C13D2FD7E659326D0A578CD203784FD7F500D9034B8E87D3316360` | 常态无“可用”和紫条；HP/SP、主动/被动分区清楚。 |
| `viewport/02_shop_before_click_1920x1080.png` | 1920×1080 | 344,947 | `64DD7835FBF1A65783B833089D7607917F26C1C826F85B24C95474348DCDCF68` | 正式商店、拥有卡与七槽初始映射清楚。 |
| `viewport/03_shop_after_click_before_drag_1920x1080.png` | 1920×1080 | 344,312 | `D16858B88418A19CFBA6BB2B1ABD4EAB46E761F95A65F00123D80FE4718AD83F` | 点击兼容路径的待装配选择与焦点清楚，尚未提交。 |
| `viewport/04_shop_after_card_drag_1920x1080.png` | 1920×1080 | 344,445 | `5C521D2BD640CA5342E0DEE4F7367E1CFE0290067B56BB98811C227DBB19694F` | 单次卡片拖拽后 A1 清空、A2 元素弹，权威映射清楚。 |
| `viewport/05_shop_after_slot_swap_2560x1440.png` | 2560×1440 | 506,679 | `DDC6A37F68F115306B67B4331C54F8DE7D358378BE8AD576C2AC69D1ECF2C0AE` | 槽换位后 A1 元素弹、A2 回收；高分辨率未横向拉伸。 |
| `viewport/06_combat_hud_1366x768.png` | 1366×768 | 56,464 | `E2B20DAA2A08959FAEEE8202BA115B988AC6CDFE6210EFB6835933B70796E253` | 最小截图档不越界，键帽、icon、短名与数值仍可读。 |
| `viewport/07_corridor_title_2560x1440.png` | 2560×1440 | 144,144 | `6B729B180077BF0E6DC4C1B6290EA1E4ADC8D4872B0CCC1D8CC9B49867B6A00D` | 狭廊标题完整，HP/SP 胶囊位于标题下方且有明确间隔。 |

## 边界与保护

- Task40 实际生产修改只在 allowlist：`scripts/combat_hud.gd`、`scripts/ui/run_overlay_interface.gd`；直接迁移三个既有 HUD runner，新增 Task40 runner/capture 及两枚 Godot 生成 UID，并写本任务书/evidence。`scripts/ui/combat_ui_tokens.gd`、`scenes/combat_hud.tscn` 无需修改，保持不变。
- 没有修改 RunSession/RunDirector/RuntimeLoadout、经济、等级、槽位规则、房间、敌群、资源或 Task31 历史 evidence。
- Task38/39 并发文件只读消费；没有认领或覆盖。两个未跟踪中文协作规则文档均未由 Task40 写入：`AI协作中枢运行协议_通用版.md` 保持开工 SHA-256 `3745D2725AC0F484CFE447196D387F5D5E888A59BFC0F75A052DEBF6A8A55870`；`AI协作中枢规则_浓缩版.md` 在 Task40 执行期间由外部并发从开工 SHA `13F31E32FC036DFA735013AB75AFCD49D80E003B4464D7053750D168C09B0381` 变为当前 `41F584AEA29B088412D596533E45ECED4B0421ADDC7FC8BA6C73236C41816B1C`（当前 LastWriteTimeUtc `2026-08-12 08:11:33`）。Task40 保留该外部变化，没有恢复、删除、认领或暂存。
- 共享 `.godot` 仍为 990 files / 42,684,249 bytes / latest `2026-08-12T06:26:34.9868811Z`，与开工基线完全一致；共享 `godot-ai` PID 46632 与 Godot 4.7.1 PID 33768 均保持存活且未受 Task40 控制。sidecar 从开工 606 增至 617，精确对应 Task38 的 4 个 UID、Task39 的 5 个 PNG import 与 Task40 的 2 个 UID；Task40 只认领后两者。
- 所有 Godot 都只在 `C:\tmp` 冷副本与独立 profile 中运行；没有控制共享 Godot/editor/godot-ai。没有执行 Git 写操作、暂存、提交、切分支或回滚。
