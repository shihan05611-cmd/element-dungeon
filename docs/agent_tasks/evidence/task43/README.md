# Task43 执行证据

状态：`REVIEW` 候选（执行者不自行 `ACCEPTED`）  
派发 HEAD：`61738aba363f3bba18f80244841613a74f4ea1de`  
冷根：`C:\tmp\element_dungeon_task43_final_20260812_a`  
独立 profile：`C:\tmp\godot_task43_profile_20260812_a`  
Godot：`4.7.1.stable.official.a13da4feb`

## 结果

- Task43 专项：`4 tests / 125 assertions / 0 failures`。
- Task31/32/40/41 直接 runner：`4/534`、`5/181`、`4/118`、`4/112`，全部通过。
- 从头成功正式集合：`34/34`，合计 `319 tests / 6889 assertions`。此前因 Task32 旧自动装配断言中断的批次未回流。
- Task20 单列：`7 tests / 68 assertions`，命令成功但保持历史 `BLOCKED`，不计入接受。
- RunGame 与 TestRoom 各 `180` 帧 smoke：exit 0。
- §16 窄返工后的非 headless 完整 capture 连续运行两次；两次均为 `1 test / 0 failures / 5 PNG`、exit 0、五类标记 0。第二次完整覆盖恰好五图，五图均已按原尺寸检查。
- 平台 capture 使用最多 120 个真实 `physics_frame` 等待，起跳前要求连续 2 帧 `is_on_floor()`；继续通过 `Input.parse_input_event` 发送 jump、`Input.action_press("move_right")` 水平移动，并在后续 physics 帧证明 `velocity.y < 0` 且离地、最后连续两帧落在 LowerPlatform 几何范围。没有读取瞬时 `jump_requested`，没有传送或调用 Player 私有输入。
- 获批空 `.gdignore` 后，返工 final editor rescan：exit 0，五类日志标记均为 0。
- `log_marker_summary.csv` 覆盖 45 个成功日志；`SCRIPT ERROR / Parse Error / ERROR: / WARNING: / CrashHandlerException` 全部为 0。

## 实现合同

1. 普通宝箱技能和商店购买技能在拥有/扣款提交前，先由现有 Runtime 校验同类型第一个空槽；成功获得命令只推进一次 run revision，实际自动装配只推进一次 loadout revision。同类型已满或候选无效时只获得，不覆盖旧槽。
2. 正式 COMBAT 按 `L` 打开独立战斗配装页，不使用 `ShopDraft`。活敌时页面只读且零 authority；真正清场后才由 Host/Coordinator 转发 RunSession 的点击、拖拽、交换和卸下事务。
3. 正式敌人在同步死亡结算后 deferred 释放。Host/Room 先检查失效引用；援军与一次性清房不变，Boss 释放且不再生成弹体。
4. 宝箱根 y 为 501，使现有贴图可见底边落到地面；共用平台模板 LowerPlatform 中心 y 为 442，两个风险房均由真实 Player 输入/physics frame 跳上。
5. Task42 的 50/50、150 梦尘、房间梦尘、商店前余额、单商店、固定 Task31 safe/risk 身份及全部经济/七槽流程不变。

## 历史 CSV 导入 blocker 与冷根夹具

执行者第一条 Godot 命令确为 4.7.1 headless editor scan，scan 前冷根无 `.godot`。该原始日志保留在：

`C:\tmp\element_dungeon_task43_final_20260812_a\task43_first_editor_scan.log`

固定 HEAD 已归档的 Task42 CSV 表头含 `ERROR:` / `WARNING:`。Godot 在 Windows 尝试把它们导入为含冒号的 `.translation` 文件名，因而产生 baseline/import 错误。原日志 SHA256、五类标记以及两次复现记录见 `protection/baseline_import_scan_history.csv`；它们是 blocker 证据，不属于成功正式日志，也未复制到本 evidence 的 logs 目录。

中枢 §14 精确授权后，冷根创建了空的 `docs/agent_tasks/evidence/.gdignore`。它仅属于验证夹具，保持 0 bytes，未回流共享/evidence/Git，并从 source/allowlist 哈希排除。删除前先生成 172 条相对 baseline ZIP 明确新增 sidecar 的精确清单，验证全部目标均位于冷根且存在，再逐项删除；清单见 `protection/cold_generated_sidecars_removed.csv`。之后 final rescan 干净通过。

## 证据索引

- `formal34_summary.csv`：正式 34/34 逐 runner tests/assertions。
- `direct_summary.csv`、`execution_summary.csv`：专项、四个直接 runner、Task20、smoke、capture、rescan。
- `log_marker_summary.csv`：45 个成功日志的五类标记，含两次连续 capture 与返工 final rescan。
- `screenshots.csv` 与 `screenshots/`：第二次 capture 覆盖的恰好五图、尺寸、SHA256、原尺寸检查结论。
- `source_cold_parity.csv`、`uid_summary.csv`：15 个生产/runner/UID 文件冷根与共享哈希一致；两 UID 均 cold-first、UID-first。
- `protection/`：共享 `.godot`、外部 36 import/50 translation、保护文档哈希、外部进程、冷 sidecar 删除清单和初始 scan blocker 对账。
- `evidence_manifest.csv`：本 evidence 正式文件清单与 SHA256。

失败 formal 批次、Review 失败 capture、返工前旧 capture 成功日志、前两次 final rescan blocker 日志以及冷根 `.gdignore` 均没有作为当前成功日志或正式 evidence 文件回流。
