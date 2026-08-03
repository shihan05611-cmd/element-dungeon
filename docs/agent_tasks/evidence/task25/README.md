# 任务 25 执行证据

状态：ACCEPTED（执行侧交付与中枢独立验收均已完成）  
记录日期：2026-08-03  
正式场景：`res://scenes/test_room.tscn`

## 1. 隔离执行环境

- 最终冷副本：`C:\tmp\element-dungeon-task25-cold-20260803-02\project`
- 独立 profile：`C:\tmp\element-dungeon-task25-profile-20260803-02`
- 冷复制：1184/1184 文件、38,273,217/38,273,217 字节，逐文件 SHA-256 为 0 mismatch；复制后、首条 Godot 命令前不存在 `.godot`。
- 该副本第一条 Godot 命令严格为 Godot 4.7.1 headless editor scan；exit 0。
- scan、20 个 runner、180 帧 smoke 与实际 Viewport capture 均只在该冷副本及独立 profile 中执行；共享项目没有启动 Godot、reload、reimport 或 save。
- `C:\tmp\element-dungeon-task25-cold-20260803-01\project` 是提交拒绝覆盖与选择态清理前的诊断副本，不作为最终结论。
- 最终副本中 scan 后第一次批量 runner 调度曾因 PowerShell 日志路径表达式错误在 Godot 测试启动前退出；未产生有效测试结论或代码变化。修正调度脚本后，以下全部 runner 重新独立执行并留存正式日志。

## 2. 自动门禁

| 门禁 | 结果 |
| --- | --- |
| Task 25 专项 `run_task25_immediate_shop_equip_tests.gd` | 8 tests / 242 assertions，exit 0 |
| 任务 24 已接受基线 | 19/19 runners；234 tests / 1873 assertions |
| Task 25 加基线总计 | 20/20 runners；242 tests / 2115 assertions |
| Task 12 专项 | 13 tests / 110 assertions，exit 0 |
| Task 16 专项 | 11 / 209，exit 0 |
| Task 18 专项 | 9 / 124，exit 0 |
| Task 24 专项 | 10 / 190，exit 0 |
| editor scan | Godot 4.7.1，exit 0 |
| 主场景 smoke | `--quit-after 180`，exit 0 |
| 图形 Viewport capture | 1/1，exit 0；OpenGL/NVIDIA 实际渲染；权威 revision 15 → 16 |

共 23 份正式 scan/runner/smoke/capture 日志；完整日志统计为 `SCRIPT ERROR=0`、`Parse Error=0`、`ERROR:=0`、`WARNING:=0`。

任务 20 旧 runner 未修改、未混入门禁，也没有为使其通过而恢复任务 20 失败实现；其历史状态继续为 `BLOCKED`，任务 24 已记录的非门禁诊断仍是 7 failures / 83 assertions。

## 3. 权威事务与 UI 接线

- `RunSession.apply_shop_loadout_immediately(draft, candidate)` 是商店即时装配的唯一新权威入口。它验证 SHOP 阶段、活动且未陈旧的 ShopDraft、候选槽位映射、技能拥有权及 RuntimeLoadout 合法性，然后才调用 RuntimeLoadout 端口提交。
- 提交失败保持 RuntimeLoadout、RunSession snapshot、run revision、ShopDraft 预览/基线、未确认属性点与通知计数全部不变；相同权威映射重复请求幂等，不提交、不推进 revision、不发重复通知。
- 成功提交只推进一次 RuntimeLoadout revision 和一次 RunSession revision；随后在 `snapshot_changed(..., &"shop_loadout_applied")` 前调用 `ShopDraft.rebase_after_immediate_loadout(...)`，对齐新 revision/loadout 基线并保留未确认属性点。
- 正式 Overlay 的点击技能后点槽、拖放、换槽与清空都调用同一 RunSession 入口；成功后只显示权威 snapshot，并给出“已装配至/已换至/已卸下 · 即时生效”；失败恢复权威 snapshot、保留选择并恢复可见焦点。
- 商店说明为“技能装配即时生效；属性分配在离店时确认”，按钮为“确认属性并离开”。正式 UI 成功即时装配后 draft 已重基线，因此最终 `confirm_shop` 只提交属性并推进离店，不会第二次提交已生效技能映射。
- 战斗阶段正式槽位交互保持只读。任务 24 的奖励卡仍是聚焦不领取，只有独立确认才调用权威领取事务，重复确认保护保持不变。

## 4. Task 25 专项覆盖

1. 合法装配无需 `confirm_shop` 即更新 RuntimeLoadout、RunSession snapshot 与 revision；
2. 换槽和卸下即时生效；
3. 非商店、陈旧草稿、未拥有技能、非法槽位、重复装备、校验失败与端口提交拒绝均全状态不变；
4. 相同映射请求幂等且不重复通知；
5. 即时装配后未确认属性点仍保留；
6. 最终商店确认提交属性并离店，RuntimeLoadout 端口没有第二次提交；
7. 真实 `test_room.tscn` Overlay 的点击、拖放、清空、失败恢复/焦点与战斗只读均通过；
8. 任务 24 奖励聚焦不领取、独立确认、单次提交继续通过。

## 5. 实际 Viewport 证据

| 文件 | 实际尺寸 | SHA-256 | 核验点 |
| --- | ---: | --- | --- |
| `01_shop_immediate_equip_1920x1080.png` | 1920×1080 | `1C5AC767E47F113148564BF38F699EA121B5945BED73BC9D9ED034FBA26C3B2E` | 从真实 RunSession 到达 SHOP，正式点击把 `element_bolt` 从 ACTIVE 1 换至 ACTIVE 2；snapshot 与画面在 revision 15 → 16 后显示权威映射、即时生效反馈、准确商店说明及“确认属性并离开”按钮 |

截图由非编辑器、非 headless 的 Godot 4.7.1 图形进程直接保存实际 Viewport，不是 mockup 或重绘图。capture 在保存前对以下状态逐项断言：SHOP 阶段、ACTIVE 1 已清空、ACTIVE 2 为 `element_bolt`、run revision 只增加 1、即时反馈文本、商店说明和离店按钮文本。

PNG 本地完整性检查：`Format32bppArgb`；8px 网格采样 32,400 点，1,142 种颜色，29,523 点不同于左上角采样色，亮度范围 3.00～253.21，文件非空且有充分画面变化。

执行侧尝试使用本地图片查看器与 computer-use 打开 PNG 时均被 Windows `CreateProcessWithLogonW 1385` 阻断；因此本交付不声称完成主观人工验图。中枢独立 Review 必须在新的冷副本重新生成并人工打开该 Viewport，检查槽位、反馈、说明、按钮、焦点可见性及覆盖/裁切。

## 6. 日志索引

- `editor_scan.log`
- `task25_runner.log`
- `gate_run_*.log`：任务 24 已接受的 19 个 runner，各自独立日志
- `main_scene_smoke_180.log`
- `visual_capture.log`

## 7. 边界与保护对账

- Task 25 写入只发生在正式 allowlist：三个实现脚本、两枚 Task 25 harness、本任务书与 `docs/agent_tasks/evidence/task25/**`。
- 任务 20 evidence、任务 21～23 恢复任务书、任务 24 归档任务书/evidence 共 88 个固化保护文件：88/88，聚合 SHA-256 仍为 `BFF2EAFCD639463A3F652A612430275C7D066B3D8503D0D1C1D1FC20BE1B71CA`，相对最终冷副本 0 mismatch。
- 任务 20/24 runner、capture 与 `scripts/combat_hud.gd`、`scripts/ui/combat_ui_tokens.gd` 六个关键禁止文件相对最终冷副本 0 mismatch；任务 25 五个实现/harness 文件与最终冷副本也为 0 mismatch。
- 三份明确排除文件保持派发哈希：`.workbuddy/memory/2026-07-31.md` 为 `2C3DF72EA416100A7572F927967F5E46C1FEB3B3CC2AB6CDE6B04B8AEAA44E27`，`docs/架构评估与扩展性改进建议.md` 为 `07450B76F22E6FC4BB90E6BDF6C72A120FBD5A8B01C0A75D2BCD317F45CEC247`，`docs/design/元素地牢_关卡流程竞品探测与适配设计报告.md` 为 `754F1BE0D642298205DFB2F86B8A512C25456AED3077CC215CC7C8D1AE2F3F22`。
- 共享 `.godot` 仍为 700 文件，聚合 SHA-256 `E4E4B369A9EFA25854C66DC9BA389C6C290311199DD9C84C91551FDEC6799EB1`；两枚 Task 25 `.gd.uid` 均不存在。
- 未修改 `.tscn`、`.tres`、正式图片/VFX、`project.godot`、CombatHUD、CombatUiTokens、任务 20/24 runner/capture/evidence 或其他 gameplay 文件。
- Git 写操作为零：未 add、commit、push、reset、restore、checkout、clean 或 stash。

## 8. Review 提示与遗留风险

- 执行侧状态只到 `REVIEW`，不得据此自行标记 `ACCEPTED`；中枢需使用新的冷副本/profile，从 headless editor scan 开始独立复跑并人工检查实际 Viewport。
- 为兼容冻结的任务 12 历史测试，Overlay 仍保留一个仅供直接 ShopDraft 夹具调用的预览分支；正式商店输入路径全部走 RunSession 权威事务，正式战斗输入路径只读。独立 Review 应继续以真实场景输入和 revision/snapshot 验证该边界。
- 本任务未改写 RuntimeLoadout、奖励规则、商店路线规则或技能内容；未来新增其他商店装配入口时，必须复用 RunSession 事务，不能直接改 loadout 或草稿。

## 9. 中枢独立验收结果

- Review 冷副本/profile：`C:\tmp\element-dungeon-task25-review-20260803-01\project` 与 `C:\tmp\element-dungeon-task25-review-20260803-01\profile`。
- 复制核对：1212/1212 文件、38,702,864/38,702,864 字节、SHA-256 0 mismatch；第一条 Godot 命令为 4.7.1 headless editor scan，exit 0，四类错误/警告均为 0。
- 正式复跑：Task25 8/242；接受基线 19/19、234/1873；合计 20/20 runners、242 tests / 2115 assertions。180 帧 smoke exit 0，日志干净；任务20未进入门禁。
- 独立图形 capture：1920×1080，SHA-256 `50C3526CEEEC3AC834610EE2A3604133CC44DF029BEA85B297BD32327532DEAD`。人工检查通过权威槽位、即时反馈、说明、离店按钮、完整可见性与无裁切要求。
- 共享区前后对账：非缓存项目、Task25 allowlist、三份排除文件、共享 `.godot` 与 Git 状态均为 0 mismatch。
- 中枢结论：`PASS / ACCEPTED`。
