# Task58 rework2 预检阻塞证据

当前状态：`REVIEW / FROZEN`。Task41 与 Task31 的旧自动商店入口夹具均已按 §4.2 精确迁移；全部正式 L3 门禁通过，失败 attempts 保留且不冒充正式结果。

## 已读输入

- 主工作区任务书 §10–11。
- `review_rework1/logs/14_review_shop_unique_entry.log`：`OVERLAY_BEFORE_L=false`、`OVERLAY_AFTER_PHYSICAL_L=true`、`ACTIVE_SHOP_ROOM_AT_L=true`。
- `review_rework1/logs/14_review_shop_unique_entry.stderr.log`：物理 L 绕过皇冠入口的冻结失败。
- `review_rework1/review_task58_shop_unique_entry_diagnostic.gd`：诊断通过真实 `CombatHUD._unhandled_input(InputEventKey{physical_keycode=KEY_L})` 复现。

## 确定性合同冲突

1. `scripts/combat_hud.gd:156–168` 的物理 L 唯一路径为无参 `run_overlay.toggle_loadout()`。
2. rework2 要求该调用在 SHOP 隐藏态显示既有 `combat_loadout`，不得显示 shop、不得创建 ShopDraft 或产生事务。
3. 必须完整重跑的 `growth/tests/run_task41_physical_flow_waves_boss_tests.gd:140–159` 仍要求入店 ShopDraft 与 shop controls 已存在，关闭后同一个 `overlay.toggle_loadout()` 重新显示 `formal_kind == shop`，并复用同一 draft。
4. 主工作区与候选 worktree 的该 Task41 文件 SHA256 相同，说明没有中枢侧已迁移版本可吸收。
5. rework2 的允许新增修改清单只列 `scripts/ui/run_overlay_interface.gd`、`scripts/run/run_flow_coordinator.gd`、Task58 专项/capture、任务书/evidence，未授权修改 Task41 或 CombatHUD。

因此，合规生产修复必然令 Task41 的相反断言失败；保留 Task41 则必然违反皇冠 F 唯一商店入口。利用调用栈、帧序或输入状态区分直接调用与 CombatHUD 调用会形成测试专用旁路，也不满足可靠、最低风险的正式行为。

## 停线范围

- 未修改任何生产、测试或 capture 文件。
- 未创建/复用 rework2 冷根或 profile。
- 未运行 Godot；因此不存在可冒充 rework2 的 scan、专项、截图、180 帧或 final scan。
- 未修改 `overlay_manifest.csv`；候选仍是 rework1 的 `10D / 16M / 6A = 32`，不是未实现的 rework2 预期 `10D / 17M / 6A = 33`。
- 未触碰 `scripts/combat_hud.gd`、scene/node、美术、经济权威、Task57 几何、enemy/delivery、`project.godot`、Player/Enemy 或共享进程。

## 解阻所需最小授权

已获授权：`growth/tests/run_task41_physical_flow_waves_boss_tests.gd` 仅迁移旧的“L 重开 shop/draft”断言为“真实物理 L 打开既有 combat_loadout 且无 merchant/新 ShopDraft/事务；皇冠 F 才打开 shop”。其余范围不变。预期 overlay 为 `10D / 18M / 6A = 34`。

## 当前 Task31 阻塞

- cold-first scan：退出 0，五类标记 0。
- Task58 专项：`3 tests / 104 assertions`，通过。
- Task41：`4 tests / 95 assertions`，通过；波次、Boss、物理移动、出口事务等原门禁保留。
- Task31：`109 failures / 358 assertions`。两次 SHOP 均未皇冠 F，直接索取旧的自动 merchant controls；正式候选不再预构造这些控件，因此购买均未发生。原始日志：`attempts/02_task31_requires_crown_entry.log`。
- 当前白名单与 `10D / 18M / 6A = 34` 目标不允许修改 Task31。精确迁移 Task31 将新增一个 M，目标应为 `10D / 19M / 6A = 35`。

已获最小授权：`combat/tests/run_task31_full_run_e2e_tests.gd` 仅在两次 SHOP 到达后，通过实体 wishing crown 与真实 interact 输入打开商店；其余购买、配装、经济、出口、五阶段、4/1/0 断言原样保留。overlay 目标更新为 `10D / 19M / 6A = 35`。禁止隐藏商店预构造、测试 accessor 懒开或 run-id 特判。

## 正式结果

- 冷根/profile：`task58-exec-rework2-20260814-03` / `task58-exec-rework2-profile-20260814-03`。
- 第一条 Godot：4.7.1 headless cold-first scan，退出 0。
- Task58 `3/104`；Task41 `4/95`；Task43 `4/105`；Task51 `2/49`；Task29 `1/74`；Task31 `4/393`；Task57 `5/205`。合计 `23 tests / 1025 assertions`。
- fresh capture：`1 test / 7 images / 0 failures`；七张 1920×1080 原图已逐张核验。
- post-capture scan、180 帧 smoke、final scan：退出 0；12 份正式日志五类标记全 0。
- final sidecar：`300 → 300`，added/removed/changed 均 0。
- overlay：`10D / 19M / 6A = 35`，候选/冷根 mismatch 0；任务书为 A。
- 正式 PNG SHA、十项删除、旧运行引用、保护文件、共享工作树与共享 PID 对账均通过。

执行者不做 Git 写入，不自行 `ACCEPTED`；候选冻结为 `REVIEW`。
